;==============================================================================
; SPI1 Driver for STM32F411 (Keil ARM Thumb-2 Assembly)
;
; Peripheral : SPI1, mapped to APB2
; Data Pins  : PA5 = SCK, PA6 = MISO, PA7 = MOSI  (AF5, configured via port.asm)
; Control    : PB12 = CS (active-low), PB10 = RST (active-low)  (GPIO output)
; Protocol   : Master, Mode 0 (CPOL=0 CPHA=0), 8-bit frame, MSB-first,
;              software NSS (SSM=1 SSI=1)
; SPI Clock  : APB2 (100 MHz) / 16 = 6.25 MHz  -- within MFRC522 10 MHz max
;
; Public API
; ----------
;   SPI1_Init            -- clock gate, peripheral config, de-assert CS/RST
;   SPI1_TransmitReceive -- full-duplex single-byte exchange (blocking)
;   SPI1_Transmit        -- send one byte, discard RX
;   SPI1_Receive         -- clock out 0x00, return RX byte
;   SPI1_CS_Assert       -- drive PB12 LOW  (select MFRC522)
;   SPI1_CS_Deassert     -- drive PB12 HIGH (deselect MFRC522)
;   SPI1_RST_Assert      -- drive PB10 LOW  (hold MFRC522 in reset)
;   SPI1_RST_Deassert    -- drive PB10 HIGH (release MFRC522 from reset)
;
; Dependencies (must be linked)
;   stm32f411.inc        -- peripheral bases, RCC offsets, GPIO offsets
;   hardware_config.inc  -- ID_RFID_CS (10), ID_RFID_RST (11)
;   dio.asm              -- DIO_WriteLogical
;
; @Author : Ibrahim Mohsen
;==============================================================================

    INCLUDE stm32f411.inc
    INCLUDE hardware_config.inc

;==============================================================================
; LOCAL CONSTANT DEFINITIONS
;==============================================================================

; --- SPI1 peripheral base (APB2 bus, RM0383 Table 1) ---
SPI1_BASE           EQU     0x40013000

; --- SPI register offsets (common to all STM32F4 SPI peripherals) ---
SPI_CR1             EQU     0x00    ; Control register 1
SPI_CR2             EQU     0x04    ; Control register 2
SPI_SR              EQU     0x08    ; Status register
SPI_DR              EQU     0x0C    ; Data register

; --- CR1 bit positions ---
SPI_CR1_CPHA        EQU     (1 :SHL: 0)     ; Clock phase (0 = first edge)
SPI_CR1_CPOL        EQU     (1 :SHL: 1)     ; Clock polarity (0 = idle LOW)
SPI_CR1_MSTR        EQU     (1 :SHL: 2)     ; Master selection
; BR[2:0] at bits [5:3] -- value 0b011 = fPCLK/16
SPI_CR1_BR_DIV16    EQU     (0x3 :SHL: 3)   ; 100 MHz / 16 = 6.25 MHz
SPI_CR1_BR_DIV64    EQU     (0x5 :SHL: 3)   ; 100 MHz / 64 = 1.56 MHz
SPI_CR1_SPE         EQU     (1 :SHL: 6)     ; SPI enable
SPI_CR1_SSI         EQU     (1 :SHL: 8)     ; Internal NSS tied high (SW NSS mode)
SPI_CR1_SSM         EQU     (1 :SHL: 9)     ; Software slave management enable

; --- SR bit positions ---
SPI_SR_RXNE         EQU     (1 :SHL: 0)     ; Receive buffer not empty
SPI_SR_TXE          EQU     (1 :SHL: 1)     ; Transmit buffer empty
SPI_SR_BSY          EQU     (1 :SHL: 7)     ; Peripheral busy

; --- Composed CR1 init value (SPE not set yet; added last in SPI1_Init) ---
;   CPOL=0, CPHA=0  -> Mode 0
;   MSTR=1          -> Master
;   BR=011          -> /16
;   SSM=1, SSI=1    -> software NSS, NSS internally pulled high
;   DFF=0 (default) -> 8-bit frame
;   LSBFIRST=0      -> MSB first
SPI_CR1_INIT_VAL    EQU     (SPI_CR1_MSTR :OR: SPI_CR1_BR_DIV64 :OR: \
                             SPI_CR1_SSM  :OR: SPI_CR1_SSI)

;==============================================================================
; CODE SECTION
;==============================================================================

    AREA    |.text|, CODE, READONLY, ALIGN=2
    THUMB

    EXPORT  SPI1_Init
    EXPORT  SPI1_TransmitReceive
    EXPORT  SPI1_Transmit
    EXPORT  SPI1_Receive
    EXPORT  SPI1_CS_Assert
    EXPORT  SPI1_CS_Deassert
    EXPORT  SPI1_RST_Assert
    EXPORT  SPI1_RST_Deassert

    IMPORT  DIO_WriteLogical

;------------------------------------------------------------------------------
; SPI1_Init
;
; Description : Enables the SPI1 APB2 peripheral clock, configures the SPI1
;               peripheral for Mode 0 master operation, and places the MFRC522
;               in its idle state (CS deasserted, RST deasserted).
;               GPIO pins (PA5/PA6/PA7 AF5, PB12/PB10 outputs) MUST already
;               be configured -- they are set up by the port.asm table.
;
; Input  : None
; Output : None
; Saved  : r4-r5 (callee-saved per AAPCS)
;------------------------------------------------------------------------------
SPI1_Init PROC
    PUSH    {r4, r5, lr}

    ;------------------------------------------------------------------
    ; 1. Enable SPI1 clock on APB2
    ;    RCC_APB2ENR is at RCC_BASE + 0x44
    ;    SPI1EN = bit 12  (RCC_APB2_SPI1 defined in stm32f411.inc)
    ;------------------------------------------------------------------
    LDR     r4, =(RCC_BASE + RCC_APB2ENR)
    LDR     r0, [r4]
    ORR     r0, r0, #RCC_APB2_SPI1
    STR     r0, [r4]

    ;------------------------------------------------------------------
    ; 2. Place MFRC522 in idle state before touching SPI
    ;    CS  HIGH  --> device deselected (CS is active-low)
    ;    RST HIGH  --> device running    (RST is active-low)
    ;------------------------------------------------------------------
    MOV     r0, #ID_RFID_CS
    MOV     r1, #1                  ; HIGH = deasserted
    BL      DIO_WriteLogical

    MOV     r0, #ID_RFID_RST
    MOV     r1, #1                  ; HIGH = released from reset
    BL      DIO_WriteLogical

    ;------------------------------------------------------------------
    ; 3. Configure SPI1 CR1
    ;    Per RM0383 §20.3.3: disable SPE before modifying CR1 fields.
    ;------------------------------------------------------------------
    LDR     r5, =SPI1_BASE

    MOV     r0, #0
    STR     r0, [r5, #SPI_CR1]     ; SPE=0, clean slate

    LDR     r0, =SPI_CR1_INIT_VAL
    STR     r0, [r5, #SPI_CR1]     ; Write Mode / baud / NSS config

    ;------------------------------------------------------------------
    ; 4. Configure SPI1 CR2 -- no DMA, no interrupts, FRXTH not needed
    ;    (FRXTH is an F0 feature; on F4 leave CR2 = 0)
    ;------------------------------------------------------------------
    MOV     r0, #0
    STR     r0, [r5, #SPI_CR2]

    ;------------------------------------------------------------------
    ; 5. Enable SPI1 (SPE = 1)
    ;------------------------------------------------------------------
    LDR     r0, [r5, #SPI_CR1]
    ORR     r0, r0, #SPI_CR1_SPE
    STR     r0, [r5, #SPI_CR1]

    ;------------------------------------------------------------------
    ; 6. Flush RX Buffer (Dummy read SR then DR) to clear stale data
    ;------------------------------------------------------------------
    LDR     r0, [r5, #SPI_SR]
    LDRB    r0, [r5, #SPI_DR]

    POP     {r4, r5, pc}
    ENDP

;------------------------------------------------------------------------------
; SPI1_TransmitReceive
;
; Description : Full-duplex single-byte transfer. Loads one byte into the TX
;               FIFO, waits for the shift register to complete, then reads the
;               simultaneously received byte back from the RX FIFO.
;
;               Transfer sequence (per RM0383 §20.3.5 full-duplex procedure):
;                 1. Wait for TXE = 1  (TX buffer empty, safe to load)
;                 2. Write TX byte to DR
;                 3. Wait for RXNE = 1 (RX buffer has the received byte)
;                 4. Read RX byte from DR
;                 5. Wait for BSY = 0  (shift register fully idle)
;
; Input  : r0 = byte to transmit (only bits [7:0] are used)
; Output : r0 = byte received
; Saved  : r4 (callee-saved)
;------------------------------------------------------------------------------
SPI1_TransmitReceive PROC
    PUSH    {r4, lr}
    LDR     r4, =SPI1_BASE

    ;------------------------------------------------------------------
    ; Step 1: Wait for TXE (TX buffer empty) -- safe to write
    ;------------------------------------------------------------------
SPI_TXE_Wait
    LDR     r1, [r4, #SPI_SR]
    TST     r1, #SPI_SR_TXE
    BEQ     SPI_TXE_Wait            ; Loop while TXE = 0

    ;------------------------------------------------------------------
    ; Step 2: Load TX byte into DR (byte-width write -- DFF=0 enforces
    ;         8-bit packing on the F4 even when DR is memory-mapped as
    ;         a 16-bit register)
    ;------------------------------------------------------------------
    STRB    r0, [r4, #SPI_DR]

    ;------------------------------------------------------------------
    ; Step 3: Wait for RXNE (received byte available in RX buffer)
    ;------------------------------------------------------------------
SPI_RXNE_Wait
    LDR     r1, [r4, #SPI_SR]
    TST     r1, #SPI_SR_RXNE
    BEQ     SPI_RXNE_Wait           ; Loop while RXNE = 0

    ;------------------------------------------------------------------
    ; Step 4: Read received byte (clears RXNE automatically)
    ;------------------------------------------------------------------
    LDRB    r0, [r4, #SPI_DR]      ; r0 = received byte

    ;------------------------------------------------------------------
    ; Step 5: Wait for BSY = 0 before releasing bus to caller
    ;         (guards against a following CS deassert arriving too soon)
    ;------------------------------------------------------------------
SPI_BSY_Wait
    LDR     r1, [r4, #SPI_SR]
    TST     r1, #SPI_SR_BSY
    BNE     SPI_BSY_Wait            ; Loop while BSY = 1

    POP     {r4, pc}
    ENDP

;------------------------------------------------------------------------------
; SPI1_Transmit
;
; Description : Transmit one byte; received byte is silently discarded.
;
; Input  : r0 = byte to transmit
; Output : None  (r0 is clobbered with the discarded RX byte)
;------------------------------------------------------------------------------
SPI1_Transmit PROC
    PUSH    {lr}
    BL      SPI1_TransmitReceive    ; Returned RX byte in r0 -- intentionally ignored
    POP     {pc}
    ENDP

;------------------------------------------------------------------------------
; SPI1_Receive
;
; Description : Clock out a dummy 0x00 byte and return the byte received.
;               Used for read transactions where the TX content is irrelevant.
;
; Input  : None
; Output : r0 = received byte
;------------------------------------------------------------------------------
SPI1_Receive PROC
    PUSH    {lr}
    MOV     r0, #0x00               ; Dummy TX byte
    BL      SPI1_TransmitReceive
    POP     {pc}                    ; r0 still holds the received byte
    ENDP

;------------------------------------------------------------------------------
; SPI1_CS_Assert
;
; Description : Drive CS line (PB12, logical ID_RFID_CS) LOW to select the
;               MFRC522.  Call this BEFORE the first SPI byte of a transaction.
;
; Input  : None
; Output : None
;------------------------------------------------------------------------------
SPI1_CS_Assert PROC
    PUSH    {lr}
    MOV     r0, #ID_RFID_CS
    MOV     r1, #0                  ; LOW = asserted (active-low CS)
    BL      DIO_WriteLogical
    NOP                             ; Guarantee MFRC522 setup time
    NOP
    NOP
    NOP
    POP     {pc}
    ENDP

;------------------------------------------------------------------------------
; SPI1_CS_Deassert
;
; Description : Drive CS line (PB12) HIGH to deselect the MFRC522.
;               Call this AFTER the last SPI byte of a transaction.
;
; Input  : None
; Output : None
;------------------------------------------------------------------------------
SPI1_CS_Deassert PROC
    PUSH    {lr}
    NOP                             ; Guarantee MFRC522 hold time before CS goes high
    NOP
    MOV     r0, #ID_RFID_CS
    MOV     r1, #1                  ; HIGH = deasserted
    BL      DIO_WriteLogical
    POP     {pc}
    ENDP

;------------------------------------------------------------------------------
; SPI1_RST_Assert
;
; Description : Drive RST line (PB10, logical ID_RFID_RST) LOW to place the
;               MFRC522 in hardware reset.  Datasheet requires RST LOW for at
;               least 100 ns; a SysTick_delay_ms(1) call after this is safe.
;
; Input  : None
; Output : None
;------------------------------------------------------------------------------
SPI1_RST_Assert PROC
    PUSH    {lr}
    MOV     r0, #ID_RFID_RST
    MOV     r1, #0                  ; LOW = in reset (active-low RST)
    BL      DIO_WriteLogical
    POP     {pc}
    ENDP

;------------------------------------------------------------------------------
; SPI1_RST_Deassert
;
; Description : Drive RST line (PB10) HIGH to release the MFRC522 from reset.
;               After calling this, the MFRC522 needs ~37 ms to reach T_osc
;               stable state before SPI communication can begin.
;               Use SysTick_delay_ms(50) in the MFRC522 init to be safe.
;
; Input  : None
; Output : None
;------------------------------------------------------------------------------
SPI1_RST_Deassert PROC
    PUSH    {lr}
    MOV     r0, #ID_RFID_RST
    MOV     r1, #1                  ; HIGH = released from reset
    BL      DIO_WriteLogical
    POP     {pc}
    ENDP

    END