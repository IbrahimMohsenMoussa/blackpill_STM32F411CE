; -------------------------------------------------------------------------
    ; Register Definitions for STM32F411
    ; -------------------------------------------------------------------------
RCC_BASE        EQU 0x40023800
RCC_AHB1ENR     EQU 0x30
RCC_APB2ENR     EQU 0x44

GPIOA_BASE      EQU 0x40020000
GPIOA_MODER     EQU 0x00
GPIOA_AFRH      EQU 0x24

USART6_BASE     EQU 0x40011400
USART_SR        EQU 0x00
USART_DR        EQU 0x04
USART_BRR       EQU 0x08
USART_CR1       EQU 0x0C

    ; Bit Masks
TXE_BIT         EQU (1 :SHL: 7)     ; Transmit Data Register Empty
RXNE_BIT        EQU (1 :SHL: 5)     ; Read Data Register Not Empty

    ; -------------------------------------------------------------------------
    ; Data Section
    ; -------------------------------------------------------------------------
    AREA |.data|, DATA, READWRITE
rx_buffer       SPACE 7             ; Buffer to hold the 7-byte Modbus response

    ; -------------------------------------------------------------------------
    ; Code Section
    ; -------------------------------------------------------------------------
    AREA |.text|, CODE, READONLY
    EXPORT init_uart6
    EXPORT read_tof_distance
    ALIGN

; -------------------------------------------------------------------------
; Procedure: init_uart6
; Initializes USART6 on PA11(TX) and PA12(RX) at 115200 baud
; -------------------------------------------------------------------------
init_uart6 PROC
    ; 1. Enable Clocks for GPIOA (AHB1) and USART6 (APB2)
    LDR R0, =RCC_BASE
    
   
    LDR R1, [R0, #RCC_APB2ENR]
    ORR R1, R1, #(1 :SHL: 5)        ; Bit 5 enables USART6
    STR R1, [R0, #RCC_APB2ENR]


    ; 4. Configure USART6 Control and Baud Registers
    LDR R0, =USART6_BASE

    ; Set Baud Rate to 115200 (Assuming 16MHz APB2 Clock)
    ; USARTDIV = 16,000,000 / (16 * 115200) = 8.6805
    ; Mantissa = 8. Fraction = 0.6805 * 16 = 11 (0xB). BRR = 0x008B.
    LDR R1, =0x008B
    STR R1, [R0, #USART_BRR]

    ; Enable USART (Bit 13), TX (Bit 3), and RX (Bit 2)
    LDR R1, =0x200C
    STR R1, [R0, #USART_CR1]

    BX LR
ENDP

; -------------------------------------------------------------------------
; Constant Modbus Read Command
; Address 0x01, Function 0x03, Reg 0x0010, Read 1 Register, CRC
; -------------------------------------------------------------------------
tof400f_read_cmd
    DCB 0x01, 0x03, 0x00, 0x10, 0x00, 0x01, 0x85, 0xCF 
cmd_end

    ALIGN

; -------------------------------------------------------------------------
; Procedure: read_tof_distance
; Transmits the read command, parses the reply, returns distance (mm) in R0
; -------------------------------------------------------------------------
read_tof_distance PROC
    PUSH {R4-R7, LR}

    LDR R4, =USART6_BASE

    ; --- Phase 1: Transmit the 8-byte command ---
    LDR R5, =tof400f_read_cmd
    LDR R6, =cmd_end

tx_loop
    CMP R5, R6                      ; Check if all bytes are sent
    BEQ rx_phase                    ; If done, move to receive phase

wait_txe
    LDR R7, [R4, #USART_SR]         ; Read Status Register
    TST R7, #TXE_BIT                ; Test Transmit Data Register Empty bit
    BEQ wait_txe                    ; Poll until empty

    LDRB R7, [R5], #1               ; Load byte from command array, increment ptr
    STRB R7, [R4, #USART_DR]        ; Write byte to Data Register
    B tx_loop

rx_phase
    ; --- Phase 2: Receive the 7-byte response ---
    LDR R5, =rx_buffer
    MOV R6, #7                      ; We expect exactly 7 bytes

rx_loop
    CMP R6, #0                      ; Check if all bytes received
    BEQ parse_data

wait_rxne
    LDR R7, [R4, #USART_SR]
    TST R7, #RXNE_BIT               ; Test Read Data Register Not Empty bit
    BEQ wait_rxne                   ; Poll until byte arrives

    LDRB R7, [R4, #USART_DR]        ; Read received byte
    STRB R7, [R5], #1               ; Store byte in RAM buffer, increment ptr
    SUBS R6, R6, #1                 ; Decrement byte counter
    B rx_loop

parse_data
    ; --- Phase 3: Extract distance ---
    ; The TOF400F replies with: 01 03 02 [Data_High] [Data_Low] CRC_H CRC_L
    ; The distance in mm is located at buffer indices [3] and [4]
    LDR R5, =rx_buffer
    LDRB R0, [R5, #3]               ; Load High Byte
    LDRB R1, [R5, #4]               ; Load Low Byte
    
    LSL R0, R0, #8                  ; Shift High Byte left by 8 bits
    ORR R0, R0, R1                  ; Bitwise OR with Low Byte

    POP {R4-R7, PC}                 ; Return from procedure. Result is in R0.
ENDP

    END