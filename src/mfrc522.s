; ==============================================================================
; mfrc522.s
; MFRC522 RFID Module Driver - Hardware Abstraction Layer
; ==============================================================================

    INCLUDE mfrc522.inc

    AREA |.text|, CODE, READONLY, ALIGN=2
    THUMB

    ; --- Exported Functions ---
    EXPORT MFRC522_WriteRegister
    EXPORT MFRC522_ReadRegister
    ; Aliases for main.asm compatibility
    EXPORT MFRC522_WriteReg
    EXPORT MFRC522_ReadReg
    EXPORT MFRC522_Init
    EXPORT MFRC522_AntennaOn
    EXPORT MFRC522_ToCard
    EXPORT MFRC522_Request
    EXPORT MFRC522_Anticoll

    ; --- Imported SPI Primitives ---
    IMPORT SPI1_CS_Assert
    IMPORT SPI1_CS_Deassert
    IMPORT SPI1_Transmit
    IMPORT SPI1_Receive
    IMPORT SysTick_delay_ms

; ==============================================================================
; void MFRC522_WriteRegister(uint8_t regAddr, uint8_t data)
; 
; SPI Transaction Sequence:
; 1. Assert CS
; 2. Transmit Address Byte: (Address << 1) & 0x7E (MSB=0 for Write)
; 3. Transmit Data Byte
; 4. Deassert CS
;
; Input:
;   r0 - Register Address
;   r1 - Data Byte to Write
; ==============================================================================
MFRC522_WriteReg
MFRC522_WriteRegister PROC
    PUSH    {r4, r5, lr}        ; Save callee-saved registers and return address
    SUB     sp, sp, #4          ; Pad stack by 4 bytes to maintain 8-byte alignment (16 bytes total)

    MOV     r4, r0              ; r4 = Original Register Address
    MOV     r5, r1              ; r5 = Data to Write

    BL      SPI1_CS_Assert      ; Begin SPI transaction

    ; Format Address for Write: (Address << 1) & 0x7E
    LSL     r0, r4, #1
    AND     r0, r0, #0x7E
    BL      SPI1_Transmit       ; Send Formatted Address

    ; Transmit Data Payload
    MOV     r0, r5
    BL      SPI1_Transmit       ; Send Data Byte

    BL      SPI1_CS_Deassert    ; End SPI transaction

    ADD     sp, sp, #4          ; Restore stack padding
    POP     {r4, r5, pc}        ; Restore registers and return
    ENDP

; ==============================================================================
; uint8_t MFRC522_ReadRegister(uint8_t regAddr)
; 
; SPI Transaction Sequence:
; 1. Assert CS
; 2. Transmit Address Byte: ((Address << 1) & 0x7E) | 0x80 (MSB=1 for Read)
; 3. Receive Data Byte
; 4. Deassert CS
;
; Input:
;   r0 - Register Address
; Output:
;   r0 - Data Byte Read
; ==============================================================================
MFRC522_ReadReg
MFRC522_ReadRegister PROC
    PUSH    {r4, lr}            ; Save r4 and lr (8 bytes pushed = AAPCS aligned)

    ; Format Address for Read: ((Address << 1) & 0x7E) | 0x80
    LSL     r4, r0, #1          ; Use r4 temporarily as workspace
    AND     r4, r4, #0x7E
    ORR     r4, r4, #0x80

    BL      SPI1_CS_Assert      ; Begin SPI transaction
    MOV     r0, r4
    BL      SPI1_Transmit       ; Send Formatted Address

    BL      SPI1_Receive        ; Read the returning Data Byte -> Returns in r0
    MOV     r4, r0              ; Secure the received byte in r4

    BL      SPI1_CS_Deassert    ; End SPI transaction

    MOV     r0, r4              ; Place the received byte back into r0 for return
    POP     {r4, pc}            ; Restore and return
    ENDP

; ==============================================================================
; void MFRC522_AntennaOn(void)
; 
; Turns on the MFRC522 antenna by setting the Tx1RFEn and Tx2RFEn bits (0 and 1)
; in the TXCONTROL register.
; ==============================================================================
MFRC522_AntennaOn PROC
    PUSH    {r4, lr}            ; Maintain 8-byte stack alignment

    ; 1. Read current TXCONTROL register value
    MOV     r0, #MFRC522_REG_TXCONTROL
    BL      MFRC522_ReadRegister
    
    ; 2. Set bits 0 and 1 (Tx1RFEn | Tx2RFEn)
    ORR     r0, r0, #0x03
    MOV     r1, r0              ; Move modified value to r1 for the write payload
    
    ; 3. Write the updated configuration back to TXCONTROL
    MOV     r0, #MFRC522_REG_TXCONTROL
    BL      MFRC522_WriteRegister

    POP     {r4, pc}
    ENDP

; ==============================================================================
; void MFRC522_Init(void)
; 
; Executes the required setup sequence to prepare the MFRC522 state machine,
; setup timeout timers, configure modulation, and enable the antenna.
; ==============================================================================
MFRC522_Init PROC
    PUSH    {r4, lr}            ; Maintain 8-byte stack alignment

    ; 1. Software Reset
    MOV     r0, #MFRC522_REG_COMMAND
    MOV     r1, #MFRC522_CMD_SOFTRESET
    BL      MFRC522_WriteRegister

    ; 2. Delay 50ms for oscillator stabilization and internal state machine reboot
    MOV     r0, #50
    BL      SysTick_delay_ms

    ; 3. Timer Setup (TAuto=1, Timer starts automatically on TX)
    MOV     r0, #MFRC522_REG_TMODE
    MOV     r1, #0x8D
    BL      MFRC522_WriteRegister

    MOV     r0, #MFRC522_REG_TPRESCALER
    MOV     r1, #0x3E
    BL      MFRC522_WriteRegister

    MOV     r0, #MFRC522_REG_TRELOAD_L
    MOV     r1, #30             ; 0x1E
    BL      MFRC522_WriteRegister

    MOV     r0, #MFRC522_REG_TRELOAD_H
    MOV     r1, #0x00
    BL      MFRC522_WriteRegister

    ; 4. Modulation Setup (Force 100% ASK modulation)
    MOV     r0, #MFRC522_REG_TXASK
    MOV     r1, #0x40
    BL      MFRC522_WriteRegister

    MOV     r0, #MFRC522_REG_MODE
    MOV     r1, #0x3D           ; Define CRC preset value (0x6363)
    BL      MFRC522_WriteRegister

    ; 5. Turn Antenna On
    BL      MFRC522_AntennaOn

    POP     {r4, pc}
    ENDP

; ==============================================================================
; uint8_t MFRC522_ToCard(uint8_t command, uint8_t *sendData, uint8_t sendLen, uint8_t *backData)
; 
; Core Transceiver function. Loads the FIFO, executes a command, waits for interrupts,
; and reads back data if requested.
;
; Inputs:
;   r0 - Command (e.g., 0x0C for PCD_TRANSCEIVE)
;   r1 - Pointer to send data buffer (*sendData)
;   r2 - Send data length (sendLen)
;   r3 - Pointer to receive data buffer (*backData, can be NULL/0)
; Output:
;   r0 - Status (0 = MI_OK, 1 = MI_ERR, 2 = MI_ERR_TIMEOUT)
; ==============================================================================
MFRC522_ToCard PROC
    PUSH    {r4-r9, lr}         ; Save 7 registers (28 bytes)
    SUB     sp, sp, #4          ; Pad stack by 4 bytes (Total 32 bytes = 8-byte aligned)

    MOV     r4, r0              ; r4 = Command
    MOV     r5, r1              ; r5 = *sendData
    MOV     r6, r2              ; r6 = sendLen
    MOV     r7, r3              ; r7 = *backData

    ; 1. Clear interrupt flags: COMIRQ (0x04) = 0x7F
    MOV     r0, #0x04
    MOV     r1, #0x7F
    BL      MFRC522_WriteRegister

    ; 2. Flush FIFO pointer: FIFOLEVEL (0x0A) = 0x80
    MOV     r0, #0x0A
    MOV     r1, #0x80
    BL      MFRC522_WriteRegister

    ; 3. Write data to FIFO (0x09)
    MOV     r8, r6              ; Loop counter = sendLen
    CMP     r8, #0
    BEQ     tocard_write_done   ; Skip if sendLen == 0
tocard_write_loop
    MOV     r0, #0x09           ; FIFODATA Register
    LDRB    r1, [r5], #1        ; Load byte and increment pointer
    BL      MFRC522_WriteRegister
    SUBS    r8, r8, #1
    BNE     tocard_write_loop
tocard_write_done

    ; 4. Write Command to COMMAND Register (0x01)
    MOV     r0, #0x01
    MOV     r1, r4
    BL      MFRC522_WriteRegister

    ; 5. If Command is PCD_TRANSCEIVE (0x0C), start transmission (BITFRAMING bit 7)
    CMP     r4, #0x0C
    BNE     tocard_wait_init
    MOV     r0, #0x0D           ; BITFRAMING Register
    BL      MFRC522_ReadRegister
    ORR     r1, r0, #0x80       ; Set StartSend bit (Bit 7)
    MOV     r0, #0x0D
    BL      MFRC522_WriteRegister

tocard_wait_init
    ; 6. Wait loop for interrupt flags
    LDR     r8, =2000           ; Failsafe timeout counter to prevent hanging
tocard_wait_loop
    SUBS    r8, r8, #1
    BEQ     tocard_timeout

    MOV     r0, #0x04           ; COMIRQ Register
    BL      MFRC522_ReadRegister
    
    TST     r0, #0x20           ; Check RxIRq (Bit 5 - Success)
    BNE     tocard_success
    TST     r0, #0x01           ; Check TimerIRq (Bit 0 - Timeout)
    BNE     tocard_timeout
    B       tocard_wait_loop

tocard_timeout
    MOV     r9, #2              ; MI_ERR_TIMEOUT (Status = 2)
    B       tocard_stop_tx

tocard_success
    MOV     r9, #0              ; MI_OK (Status = 0)

tocard_stop_tx
    ; 7. Stop Transmission: Clear StartSend in BITFRAMING (0x0D)
    MOV     r0, #0x0D
    BL      MFRC522_ReadRegister
    BIC     r1, r0, #0x80       ; Clear Bit 7
    MOV     r0, #0x0D
    BL      MFRC522_WriteRegister

    ; Skip error/FIFO reading if timeout occurred
    CMP     r9, #2
    BEQ     tocard_exit

    ; 8. Error check: Read ERROR Register (0x06)
    MOV     r0, #0x06
    BL      MFRC522_ReadRegister
    TST     r0, #0x4A           ; Check BufferOvfl(Bit 6), CollErr(Bit 3), ParityErr(Bit 1) -> 0x40|0x08|0x02 = 0x4A
    BEQ     tocard_no_error
    MOV     r9, #1              ; MI_ERR (Status = 1)
    B       tocard_exit

tocard_no_error
    ; 9. Read back data if requested
    CMP     r7, #0              ; Is *backData == NULL?
    BEQ     tocard_exit
    
    MOV     r0, #0x0A           ; Read FIFOLEVEL
    BL      MFRC522_ReadRegister
    MOV     r8, r0              ; Loop counter = FIFO level
    CMP     r8, #0
    BEQ     tocard_exit
tocard_read_loop
    MOV     r0, #0x09           ; FIFODATA Register
    BL      MFRC522_ReadRegister
    STRB    r0, [r7], #1        ; Store byte and increment pointer
    SUBS    r8, r8, #1
    BNE     tocard_read_loop

tocard_exit
    MOV     r0, r9              ; Place final status in r0 for return
    ADD     sp, sp, #4          ; Remove padding
    POP     {r4-r9, pc}         ; Restore registers and return
    ENDP

; ==============================================================================
; uint8_t MFRC522_Request(uint8_t reqMode, uint8_t *backData)
;
; Transmits an ATQA request to detect nearby RFID cards.
; ==============================================================================
MFRC522_Request PROC
    PUSH    {r4, lr}            ; Save registers (8 bytes)
    SUB     sp, sp, #8          ; Allocate 8 bytes for local buffer (Maintains 8-byte alignment)

    STRB    r0, [sp]            ; Store Request Mode on stack (Acts as a 1-byte sendBuffer)
    MOV     r4, r1              ; Save *backData pointer to r4

    ; 1. Setup BITFRAMING for 7 valid bits in last byte (0x07)
    MOV     r0, #0x0D
    MOV     r1, #0x07
    BL      MFRC522_WriteRegister

    ; 2. Call MFRC522_ToCard
    MOV     r0, #0x0C           ; Command = PCD_TRANSCEIVE
    MOV     r1, sp              ; *sendData = address of our local stack variable
    MOV     r2, #1              ; sendLen = 1 byte
    MOV     r3, r4              ; *backData = input pointer
    BL      MFRC522_ToCard      ; Status will be returned in r0

    ADD     sp, sp, #8          ; Cleanup local stack variables
    POP     {r4, pc}            ; Restore and return
    ENDP

; ==============================================================================
; uint8_t MFRC522_Anticoll(uint8_t *uidBuffer)
;
; Executes the Anti-Collision loop to read a card's 5-byte UID (4 UID + 1 BCC).
;
; Input:
;   r0 - Pointer to a 5-byte buffer to store the UID
; Output:
;   r0 - Status (0 = MI_OK, 1 = MI_ERR)
; ==============================================================================
MFRC522_Anticoll PROC
    PUSH    {r4, lr}            ; Save r4 and lr (8 bytes pushed, AAPCS aligned)
    SUB     sp, sp, #8          ; Allocate 8 bytes for local buffer (Maintains 8-byte alignment)

    MOV     r4, r0              ; Save the *uidBuffer pointer in r4

    ; 1. Write 0x00 to BITFRAMING (0x0D) - 8 valid bits for TX
    MOV     r0, #0x0D
    MOV     r1, #0x00
    BL      MFRC522_WriteRegister

    ; 2. Write 0x00 to COLL (0x0E) - clear previous collision flags
    MOV     r0, #0x0E
    MOV     r1, #0x00
    BL      MFRC522_WriteRegister

    ; 3. Setup local 2-byte transmit buffer: [0x93, 0x20]
    MOV     r0, #0x93           ; PICC_ANTICOLL command
    STRB    r0, [sp, #0]
    MOV     r0, #0x20           ; 2 bytes, requests 5-byte UID back
    STRB    r0, [sp, #1]

    ; 4. Call MFRC522_ToCard
    MOV     r0, #0x0C           ; Command = PCD_TRANSCEIVE
    MOV     r1, sp              ; *sendData = address of our local 2-byte buffer
    MOV     r2, #2              ; sendLen = 2 bytes
    MOV     r3, r4              ; *backData = original UID buffer pointer
    BL      MFRC522_ToCard

    ; 5. Check ToCard return status
    CMP     r0, #0              ; 0 = MI_OK
    BNE     anticoll_err        ; If not MI_OK, exit immediately with error

    ; 6. Checksum Verification (BCC check)
    ; The 5th byte (Index 4) must equal Byte0 ^ Byte1 ^ Byte2 ^ Byte3
    LDRB    r0, [r4, #0]        ; Load UID Byte 0
    LDRB    r1, [r4, #1]        ; Load UID Byte 1
    EOR     r0, r0, r1          ; XOR Byte 0 ^ Byte 1
    
    LDRB    r1, [r4, #2]        ; Load UID Byte 2
    EOR     r0, r0, r1          ; XOR ^ Byte 2
    
    LDRB    r1, [r4, #3]        ; Load UID Byte 3
    EOR     r0, r0, r1          ; XOR ^ Byte 3
    
    LDRB    r1, [r4, #4]        ; Load UID Byte 4 (Block Check Character)
    CMP     r0, r1              ; Compare calculated BCC with received BCC
    BNE     anticoll_err        ; If they don't match, return MI_ERR

anticoll_success
    MOV     r0, #0              ; MI_OK (0)
    B       anticoll_exit

anticoll_err
    MOV     r0, #1              ; MI_ERR (1)

anticoll_exit
    ADD     sp, sp, #8          ; Cleanup local stack buffer
    POP     {r4, pc}            ; Restore registers and return
    ENDP

    END
