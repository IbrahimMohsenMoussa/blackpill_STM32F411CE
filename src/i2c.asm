;==============================================================================
; I2C1 Bare-Metal Driver for STM32F411
; @Description: Provides Init, Start, Write, and Stop primitives for I2C1.
; @Dependencies: stm32f411.inc, rcc.asm (RCC_APB1_Enable)
; @Note: PB6 (SCL) and PB7 (SDA) must be configured as AF4 Open-Drain externally by port.asm.
;==============================================================================

    INCLUDE stm32f411.inc

; ----------------------------------------------------------------------------
; Local Peripheral Definitions
; ----------------------------------------------------------------------------
I2C1_BASE       EQU 0x40005400
I2C_CR1         EQU 0x00
I2C_CR2         EQU 0x04
I2C_OAR1        EQU 0x08
I2C_OAR2        EQU 0x0C
I2C_DR          EQU 0x10
I2C_SR1         EQU 0x14
I2C_SR2         EQU 0x18
I2C_CCR         EQU 0x1C
I2C_TRISE       EQU 0x20

; I2C Bit Masks
I2C_CR1_PE      EQU (1 :SHL: 0)     ; Peripheral Enable
I2C_CR1_SWRST   EQU (1 :SHL: 15)    ; Software Reset
I2C_CR1_START   EQU (1 :SHL: 8)     ; Start Generation
I2C_CR1_STOP    EQU (1 :SHL: 9)     ; Stop Generation
I2C_CR1_ACK     EQU (1 :SHL: 10)    ; Acknowledge Enable

I2C_SR1_SB      EQU (1 :SHL: 0)     ; Start Bit generated
I2C_SR1_ADDR    EQU (1 :SHL: 1)     ; Address sent
I2C_SR1_BTF     EQU (1 :SHL: 2)     ; Byte Transfer Finished
I2C_SR1_RXNE	EQU (1 :SHL: 6)		; Added: Receive Data Register Not Empty
I2C_SR1_TXE     EQU (1 :SHL: 7)     ; Data Register Empty
I2C_SR1_AF      EQU (1 :SHL: 10)    ; Acknowledge Failure

; ----------------------------------------------------------------------------
; Dynamic Fast Mode (400kHz) Timing Calculations
; APB1_FREQ is pulled directly from stm32f411.inc
; ----------------------------------------------------------------------------
; 1. FREQ field in CR2 is the APB1 frequency in MHz
I2C_FREQ_MHZ    EQU (APB1_FREQ / 1000000)

; 2. CCR calculation for Fast Mode (Duty Cycle = 0, Tlow/Thigh = 2)
; Ti2c = 3 * CCR * Tpclk1  =>  CCR = APB1_FREQ / (3 * 400,000)
I2C_CCR_VAL     EQU (APB1_FREQ / 1200000)
I2C_CCR_FAST    EQU (0x8000 :OR: I2C_CCR_VAL) ; Bit 15 selects Fast Mode

; 3. TRISE calculation for Fast Mode (Max rise time = 300ns)
; TRISE = (Freq_MHz * 300ns / 1000ns) + 1
I2C_TRISE_VAL   EQU ((I2C_FREQ_MHZ * 300) / 1000) + 1

; ----------------------------------------------------------------------------
; Code Section
; ----------------------------------------------------------------------------
    AREA |.text|, CODE, READONLY, ALIGN=2
    THUMB
    EXPORT I2C1_Init
    EXPORT I2C1_Start
    EXPORT I2C1_Write
    EXPORT I2C1_Stop
	EXPORT I2C1_StopTx
	EXPORT I2C1_StopRx
    EXPORT I2C1_ReadAck
    EXPORT I2C1_ReadNack
    IMPORT RCC_APB1_Enable

; ----------------------------------------------------------------------------
; I2C1_Init
; Enables I2C1 clock and configures dynamically calculated timings.
; ----------------------------------------------------------------------------
I2C1_Init PROC
    push    {r4, lr}
    
    ; 1. Enable I2C1 Clock on APB1
    ldr     r0, =RCC_APB1_I2C1
    bl      RCC_APB1_Enable
    
    ldr     r4, =I2C1_BASE
    
    ; 2. Software Reset I2C peripheral to ensure a clean state
    ldr     r1, =I2C_CR1_SWRST
    str     r1, [r4, #I2C_CR1]
    
    ; 3. Disable I2C peripheral (release reset) to configure registers safely
    mov     r1, #0
    str     r1, [r4, #I2C_CR1]
    
    ; 4. Configure CR2 (Peripheral Clock Frequency)
    ldr     r1, =I2C_FREQ_MHZ
    str     r1, [r4, #I2C_CR2]
    
    ; 5. Configure CCR (Clock Control Register for 400kHz Fast Mode)
    ldr     r1, =I2C_CCR_FAST
    str     r1, [r4, #I2C_CCR]
    
    ; 6. Configure TRISE (Maximum Rise Time)
    ldr     r1, =I2C_TRISE_VAL
    str     r1, [r4, #I2C_TRISE]
    
    ; 7. Enable I2C peripheral (Seif : with ACK)
	LDR     r1, [r4, #I2C_CR1]
	ORR 	r1, r1, #I2C_CR1_PE
	ORR 	r1, r1, #I2C_CR1_ACK
	STR     r1, [r4, #I2C_CR1]
    
    pop     {r4, pc}
    ENDP

; ----------------------------------------------------------------------------
; I2C1_Start
; Generates a START condition and sends the 8-bit device address.
; Input: R0 = 8-bit I2C Address (e.g., 0x78 for SSD1306 Write)
; ----------------------------------------------------------------------------
I2C1_Start PROC
    push    {r4, lr}
    ldr     r4, =I2C1_BASE
    
    ; 1. Set START bit in CR1
    ldr     r1, [r4, #I2C_CR1]
    orr     r1, r1, #I2C_CR1_START
    str     r1, [r4, #I2C_CR1]
    
wait_sb
    ; 2. Wait for Start Bit generated (SB) flag in SR1
    ldr     r1, [r4, #I2C_SR1]
    tst     r1, #I2C_SR1_SB
    beq     wait_sb
    
    ; 3. Send the Device Address to the Data Register
    str     r0, [r4, #I2C_DR]
    
wait_addr
    ; 4. Wait for Address sent (ADDR) flag in SR1
    ldr     r1, [r4, #I2C_SR1]
    
    tst     r1, #I2C_SR1_AF      ; Check if Address was NACKed
    bne     i2c_start_nack       ; If NACK, abort to prevent hang
    
    tst     r1, #I2C_SR1_ADDR
    beq     wait_addr
    
    ; 5. Clear the ADDR flag by reading SR1, followed by reading SR2
    ldr     r1, [r4, #I2C_SR1]
    ldr     r1, [r4, #I2C_SR2]
    
    mov     r0, #0               ; Return 0 (Success)
    pop     {r4, pc}

i2c_start_nack
    ; Clear AF flag by writing 0 to it
    bic     r1, r1, #I2C_SR1_AF
    str     r1, [r4, #I2C_SR1]
    bl      I2C1_Stop            ; Release the bus
    mov     r0, #1               ; Return 1 (Error)
    pop     {r4, pc}
    ENDP

; ----------------------------------------------------------------------------
; I2C1_Write
; Transmits a single byte of data over the bus.
; Input: R0 = Data byte to send
; ----------------------------------------------------------------------------
I2C1_Write PROC
    push    {r4, lr}
    ldr     r4, =I2C1_BASE
    
wait_txe
    ; 1. Wait until Data Register is Empty (TXE)
    ldr     r1, [r4, #I2C_SR1]
    
    tst     r1, #I2C_SR1_AF      ; Check if previous byte was NACKed
    bne     i2c_write_nack       ; If NACK, abort
    
    tst     r1, #I2C_SR1_TXE
    beq     wait_txe
    
    ; 2. Write the data byte
    strb     r0, [r4, #I2C_DR]
    
    mov     r0, #0               ; Return 0 (Success)
    pop     {r4, pc}

i2c_write_nack
    ; Clear AF flag and generate STOP
    bic     r1, r1, #I2C_SR1_AF
    str     r1, [r4, #I2C_SR1]
    ldr     r1, [r4, #I2C_CR1]
    orr     r1, r1, #I2C_CR1_STOP
    str     r1, [r4, #I2C_CR1]
    mov     r0, #1               ; Return 1 (Error)
    pop     {r4, pc}
    ENDP
		
; ----------------------------------------------------------------------------
; I2C2_ReadAck
; Reads a byte and automatically sends an ACK to continue receiving.
; Output: R0 = Received Byte
; ----------------------------------------------------------------------------
I2C1_ReadAck PROC
    push    {r4, lr}
    ldr     r4, =I2C1_BASE

    ; 1. Enable Acknowledge (ACK = 1)
    ldr     r1, [r4, #I2C_CR1]
    orr     r1, r1, #I2C_CR1_ACK
    str     r1, [r4, #I2C_CR1]

wait_rxne_ack
    ; 2. Wait until Receive Data Register is not empty (RXNE)
    ldr     r1, [r4, #I2C_SR1]
    tst     r1, #I2C_SR1_RXNE
    beq     wait_rxne_ack

    ; 3. Read data from DR
    ldrb     r0, [r4, #I2C_DR]

    pop     {r4, pc}
    ENDP

; ----------------------------------------------------------------------------
; I2C1_ReadNack
; Reads the last byte and sends a NACK to signal end of reception.
; Output: R0 = Received Byte
; ----------------------------------------------------------------------------
I2C1_ReadNack PROC
    push    {r4, lr}
    ldr     r4, =I2C1_BASE

    ; 1. Disable Acknowledge (ACK = 0) to send NACK after next byte
    ldr     r1, [r4, #I2C_CR1]
    bic     r1, r1, #I2C_CR1_ACK
    str     r1, [r4, #I2C_CR1]

wait_rxne_nack
    ; 2. Wait until Receive Data Register is not empty (RXNE)
    ldr     r1, [r4, #I2C_SR1]
    tst     r1, #I2C_SR1_RXNE
    beq     wait_rxne_nack

    ; 3. Read data from DR
    ldrb     r0, [r4, #I2C_DR]

    pop     {r4, pc}
    ENDP

; ----------------------------------------------------------------------------
; I2C1_Stop
; Generates a STOP condition, releasing the bus.
; ----------------------------------------------------------------------------
I2C1_Stop PROC
    push    {r4, lr}
    ldr     r4, =I2C1_BASE
    
wait_btf
    ; 1. Wait for Byte Transfer Finished (BTF) to ensure last byte cleared shift register
    ldr     r1, [r4, #I2C_SR1]
    
    tst     r1, #I2C_SR1_AF      ; If NACK occurs on final byte, BTF will never set
    bne     i2c_stop_force       ; Break out to force STOP
    
    tst     r1, #I2C_SR1_BTF
    beq     wait_btf
    
    ; 2. Set STOP bit in CR1
    ldr     r1, [r4, #I2C_CR1]
    orr     r1, r1, #I2C_CR1_STOP
    str     r1, [r4, #I2C_CR1]
    
    mov     r0, #0               ; Return 0 (Success)
    pop     {r4, pc}

i2c_stop_force
    bic     r1, r1, #I2C_SR1_AF  ; Clear AF flag
    str     r1, [r4, #I2C_SR1]
    ldr     r1, [r4, #I2C_CR1]
    orr     r1, r1, #I2C_CR1_STOP
    str     r1, [r4, #I2C_CR1]
    mov     r0, #1               ; Return 1 (Error)
    pop     {r4, pc}
    ENDP
		
; ----------------------------------------------------------------------------
; I2C1_StopTx
;
; Generates STOP condition after TRANSMIT operations.
; Intended for:
;   - OLED writes
;   - MPU register writes
;   - Any TX transaction
;
; Waits for BTF before STOP generation.
;
; Return:
;   R0 = 0 success
;   R0 = 1 error (NACK detected)
; ----------------------------------------------------------------------------
I2C1_StopTx PROC
	push    {r4, lr}
	ldr     r4, =I2C1_BASE

wait_btf_tx
	; Read SR1
	ldr     r1, [r4, #I2C_SR1]

	; If NACK occurred, abort gracefully
	tst     r1, #I2C_SR1_AF
	bne     i2c_stop_tx_force

	; Wait until byte transfer finished
	tst     r1, #I2C_SR1_BTF
	beq     wait_btf_tx

	; Generate STOP
	ldr     r1, [r4, #I2C_CR1]
	orr     r1, r1, #I2C_CR1_STOP
	str     r1, [r4, #I2C_CR1]

	mov     r0, #0

	pop     {r4, pc}

; Error path
i2c_stop_tx_force
    ; Clear AF flag
	bic     r1, r1, #I2C_SR1_AF
	str     r1, [r4, #I2C_SR1]

	; Force STOP
	ldr     r1, [r4, #I2C_CR1]
	orr     r1, r1, #I2C_CR1_STOP
	str     r1, [r4, #I2C_CR1]
	mov     r0, #1

	pop     {r4, pc}
	ENDP


; ----------------------------------------------------------------------------
; I2C1_StopRx
;
; Generates STOP condition after RECEIVE operations.
; Intended for:
;   - MPU6050 burst reads
;
; IMPORTANT:
;   Does NOT wait for BTF.
;
; Reason:
;   In RX mode after final NACK,
;   BTF may never become set.
;
; Also restores ACK for future transactions.
;
; Return:
;   R0 = 0 (no use for it but maintains same approach as I2C1_StopTx)
; ----------------------------------------------------------------------------
I2C1_StopRx PROC
    push    {r4, lr}

    ldr     r4, =I2C1_BASE

    ; Generate STOP immediately
    ldr     r1, [r4, #I2C_CR1]
    orr     r1, r1, #I2C_CR1_STOP
    str     r1, [r4, #I2C_CR1]

    ; Restore ACK for future reads
    ldr     r1, [r4, #I2C_CR1]
    orr     r1, r1, #I2C_CR1_ACK
    str     r1, [r4, #I2C_CR1]

    mov     r0, #0

    pop     {r4, pc}
	ENDP

	ALIGN
    END