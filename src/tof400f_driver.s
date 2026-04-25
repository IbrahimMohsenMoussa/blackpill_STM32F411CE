;==============================================================================
; TOF400F Laser Ranging Module Driver for STM32F411
; @Description: Initializes USART6 and reads distance from the TOF400F via Modbus.
; @Dependencies: stm32f411.inc, rcc.asm (RCC_APB2_Enable)
; @Note: GPIO configuration (PA11/PA12 AF8) is handled externally in port.asm.
;==============================================================================

    INCLUDE stm32f411.inc

; ----------------------------------------------------------------------------
; Local Peripheral Definitions (Not present in stm32f411.inc)
; ----------------------------------------------------------------------------
USART6_BASE     EQU 0x40011400
USART_SR        EQU 0x00
USART_DR        EQU 0x04
USART_BRR       EQU 0x08
USART_CR1       EQU 0x0C

; USART Control/Status Bits
TXE_BIT         EQU (1 :SHL: 7)     ; Transmit Data Register Empty
RXNE_BIT        EQU (1 :SHL: 5)     ; Read Data Register Not Empty
USART_EN_BITS   EQU 0x200C          ; UE (Bit 13), TE (Bit 3), RE (Bit 2)

; ----------------------------------------------------------------------------
; Dynamic Baud Rate Calculation
; Uses APB2_FREQ from stm32f411.inc to calculate exact BRR value at assembly time.
; BRR = f_CK / BaudRate. We add (BaudRate/2) for integer rounding accuracy.
; ----------------------------------------------------------------------------
TOF_BAUD        EQU 115200
BRR_VALUE       EQU (APB2_FREQ + (TOF_BAUD / 2)) / TOF_BAUD

; ----------------------------------------------------------------------------
; Data Section: RAM Buffer for Modbus Reply
; ----------------------------------------------------------------------------
    AREA |.data|, DATA, READWRITE
rx_buffer       SPACE 7             ; 7-byte buffer for TOF400F Modbus response

; ----------------------------------------------------------------------------
; Code Section
; ----------------------------------------------------------------------------
    AREA |.text|, CODE, READONLY, ALIGN=2
    THUMB
    EXPORT TOF_Init
    EXPORT TOF_Read_Distance
    IMPORT RCC_APB2_Enable

; ----------------------------------------------------------------------------
; TOF_Init
; Enables USART6 clock and configures baud rate & control registers.
; ----------------------------------------------------------------------------
TOF_Init PROC
    push    {r4, lr}
    
    ; 1. Enable USART6 Clock via APB2 (Bit 5)
    ldr     r0, =RCC_APB2_USART6
    bl      RCC_APB2_Enable
    
    ; 2. Configure USART6
    ldr     r4, =USART6_BASE
    
    ; Write dynamically calculated Baud Rate
    ldr     r1, =BRR_VALUE
    str     r1, [r4, #USART_BRR]
    
    ; Enable USART, Transmitter, and Receiver
    ldr     r1, =USART_EN_BITS
    str     r1, [r4, #USART_CR1]
    
    pop     {r4, pc}
    ENDP

; ----------------------------------------------------------------------------
; Modbus Command Sequence (Stored in ROM)
; ----------------------------------------------------------------------------
tof400f_read_cmd
    ; Read holding register: Slave 0x01, Func 0x03, Reg 0x0010, Qty 0x0001, CRC
    DCB     0x01, 0x03, 0x00, 0x10, 0x00, 0x01, 0x85, 0xCF 
cmd_end
    ALIGN

; ----------------------------------------------------------------------------
; TOF_Read_Distance
; Transmits 8 bytes, waits for 7 byte reply, and parses distance.
; Returns: R0 = Distance in millimeters.
; ----------------------------------------------------------------------------
TOF_Read_Distance PROC
   
    push    {r4-r7, lr}
    ldr     r4, =USART6_BASE
    
    ; --- NEW: Flush any stale garbage out of the RX hardware buffer ---
    ldr     r7, [r4, #USART_SR]      ; Dummy read Status Register
    ldr     r7, [r4, #USART_DR]      ; Dummy read Data Register to clear RXNE flag

    ; --- Phase 1: Transmit Modbus Command ---
    ldr     r5, =tof400f_read_cmd
    ldr     r6, =cmd_end
tx_loop
    cmp     r5, r6
    beq     rx_phase                ; If array end reached, branch to receive
wait_txe
    ldr     r7, [r4, #USART_SR]
    tst     r7, #TXE_BIT            ; Poll TXE
    beq     wait_txe
    ldrb    r7, [r5], #1            ; Load byte and post-increment
    strb    r7, [r4, #USART_DR]     ; Transmit
    b       tx_loop

rx_phase
    ; --- Phase 2: Receive 7-byte Modbus Reply ---
    ldr     r5, =rx_buffer
    mov     r6, #7                  ; Bytes to receive
rx_loop
    cmp     r6, #0
    beq     parse_data
wait_rxne
    ldr     r7, [r4, #USART_SR]
    tst     r7, #RXNE_BIT           ; Poll RXNE
    beq     wait_rxne
    ldrb    r7, [r4, #USART_DR]     ; Read incoming byte
    strb    r7, [r5], #1            ; Store in buffer and post-increment
    subs    r6, r6, #1              ; Decrement counter
    b       rx_loop

parse_data
    ; --- Phase 3: Extract Distance (mm) ---
    ; Expected response format: [01] [03] [02] [High Byte] [Low Byte] [CRC_H] [CRC_L]
    ldr     r5, =rx_buffer
    ldrb    r0, [r5, #3]            ; Load High Byte (Index 3)
    ldrb    r1, [r5, #4]            ; Load Low Byte (Index 4)
    
    lsl     r0, r0, #8              ; Shift High Byte to MSB
    orr     r0, r0, r1              ; Bitwise OR with Low Byte
    
    pop     {r4-r7, pc}             ; Return with distance in R0
    ENDP

    END