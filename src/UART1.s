        AREA UART_Driver, CODE, READONLY
        THUMB

        EXPORT UART1_Init
        EXPORT UART1_Transmit
        EXPORT UART1_Receive
        EXPORT UART1_setBaudRate
		
		IMPORT RCC_APB2_Enable
		
		INCLUDE		stm32f411.inc
		GET		UART1_defs.s
;---------------------------------------------------------
; void USART1_Init(void)
;
; One-time setup of UART for polling operation
; Steps:
; 1. Configure oversampling (16x)
; 2. Set baud rate
; 3. Configure 8N1 format
; 4. Enable transmitter and receiver
; 5. Enable USART1 peripheral
;---------------------------------------------------------
UART1_Init PROC
        PUSH    {R0-R4, LR}                 ; Save registers
        
        ; Enable USART1 clock (APB2 Bit 4)
        MOV     R0, #(1 << 4)
        BL      RCC_APB2_Enable
        
        ; Configure UART1 registers
		LDR     R0, =UART1_BASE
        
		; Disable UART first
		LDR     R1, [R0, #UART1_CR1]
		BIC     R1, R1, #(1 << UE_BIT)
		STR     R1, [R0, #UART1_CR1]
		
		; 1. Configure oversampling rate (always 16x with current setting)
		LDR     R0, =UART1_BASE
		LDR     R1, [R0, #UART1_CR1]
		BIC     R1, R1, #(1 << OVER8_BIT)
        STR     R1, [R0, #UART1_CR1]
        
		; 2. Set baud rate
		MOV     R0, #PRE_CONF_BAUD_RATE
		BL      UART1_setBaudRate
        
        ; 3. Configure parity (always disabled with current settings)
        LDR     R1, [R0, #UART1_CR1]
        BIC     R1, R1, #(1 << PCE_BIT)      ; Disable parity
        STR     R1, [R0, #UART1_CR1]
        
        ; 4. Configure data word length (always 8 with current setting)
        LDR     R1, [R0, #UART1_CR1]
		BIC     R1, R1, #(1 << M_BIT)    ; 8 data bits  
		STR     R1, [R0, #UART1_CR1]
        
        ; 5. Configure stop bits (always 1 with current settings)
		LDR     R1, [R0, #UART1_CR2]
		BIC     R1, R1, #(1 << STOP_BIT0)
		BIC     R1, R1, #(1 << STOP_BIT1)
		STR     R1, [R0, #UART1_CR2]
        
        ; 6. Enable transmitter and receiver
		LDR     R1, [R0, #UART1_CR1]
        ORR     R1, R1, #(1 << TE_BIT)      ; Enable transmitter
        ; ORR     R1, R1, #(1 << RE_BIT)      ; Enable receiver
        STR     R1, [R0, #UART1_CR1]
        
        ; 7. Finally enable UART1 peripheral
		LDR     R1, [R0, #UART1_CR1]
		ORR     R1, R1, #(1 << UE_BIT)      ; Enable UART1
		STR     R1, [R0, #UART1_CR1]
        
		POP     {R0-R4, PC}                 ; Restore registers and return
        ENDP

;---------------------------------------------------------
; void USART1_Transmit(uint8 data in R0)
;
; Polling transmission - sends one byte via UART
; Waits for TXE flag before transmitting
;---------------------------------------------------------
UART1_Transmit PROC
        PUSH    {R0-R2, LR}                 ; Save registers
        
        ; Save data to R2
        MOV     R2, R0
        
        LDR     R0, =UART1_BASE
        
UART1_Transmit_Wait
        ; Wait for TXE (Transmit Data Register Empty) flag
        LDR     R1, [R0, #UART1_SR]
        TST     R1, #(1 << TXE_BIT)
        BEQ     UART1_Transmit_Wait
        
        ; Write data to DR register
        STRB    R2, [R0, #UART1_DR]
        
        POP     {R0-R2, PC}                 ; Restore and return
        ENDP

;---------------------------------------------------------
; uint8 USART1_Receive(void)
; Returns: R0 = received data
;
; Polling reception - receives one byte via UART
; Waits for RXNE flag before reading
;---------------------------------------------------------
UART1_Receive PROC
        PUSH    {R0-R1, LR}                    ; Save registers
        
        LDR     R0, =UART1_BASE
        
UART1_Receive_Wait
        ; Wait for RXNE (Receive Data Register Not Empty) flag
        LDR     R1, [R0, #UART1_SR]
        TST     R1, #(1 << RXNE_BIT)
        BEQ     UART1_Receive_Wait
        
        ; Read data from DR register
        LDRB    R0, [R0, #UART1_DR]
        
        POP     {R0-R1, PC}                    ; Restore and return
        ENDP

;---------------------------------------------------------
; void setBaudRate(uint16 baudRate_Bps in R0)
;
; Sets the baud rate using integer arithmetic
; Uses 16x oversampling by default
;---------------------------------------------------------
UART1_setBaudRate PROC
        PUSH    {R1-R7, LR}                 ; Save registers
        
        ; Save baud rate
        MOV     R4, R0
        
        LDR     R0, =UART1_BASE
        
        ; Check oversampling mode (assume 16x for now)
        LDR     R1, [R0, #UART1_CR1]
        TST     R1, #(1 << OVER8_BIT)
        BNE     setBaudRate_8x
        
        ; --------------------------------------------------------------------
        ; 16x oversampling calculation
        ; USARTDIV = F_CPU / (16 * baudrate)
        ; mantissa = integer part
        ; fraction = (USARTDIV - mantissa) * 16 (rounded)
        ; --------------------------------------------------------------------
setBaudRate_16x
        ; Calculate divisor = 16 * baudrate
        MOV     R1, #16
        MUL     R5, R4, R1                  ; R5 = 16 * baudrate
        
        ; Calculate mantissa = F_CPU / divisor
        LDR     R6, =F_CPU
        UDIV    R2, R6, R5                  ; R2 = mantissa
        
        ; Calculate remainder
        MUL     R3, R2, R5                  ; R3 = mantissa * divisor
        SUB     R3, R6, R3                  ; R3 = remainder = F_CPU - (mantissa * divisor)
        
        ; Calculate fraction = (remainder * 16 + divisor/2) / divisor
        MOV     R1, #16
        MUL     R3, R3, R1                  ; R3 = remainder * 16
        MOV     R1, R5, LSR #1              ; R1 = divisor / 2
        ADD     R3, R3, R1                  ; R3 = (remainder * 16) + (divisor / 2)
        UDIV    R3, R3, R5                  ; R3 = fraction
        
        ; Keep only 4 bits for fraction
        AND     R3, R3, #0x0F
        
        ; Combine mantissa and fraction
        MOV     R2, R2, LSL #4              ; Shift mantissa left by 4
        ORR     R2, R2, R3                  ; Combine with fraction
        
        B       setBaudRate_Store
        
        ; --------------------------------------------------------------------
        ; 8x oversampling calculation
        ; USARTDIV = F_CPU / (8 * baudrate)
        ; mantissa = integer part
        ; fraction = (USARTDIV - mantissa) * 8 (rounded)
        ; --------------------------------------------------------------------
setBaudRate_8x
        ; Calculate divisor = 8 * baudrate
        MOV     R1, #8
        MUL     R5, R4, R1                  ; R5 = 8 * baudrate
        
        ; Calculate mantissa = F_CPU / divisor
        LDR     R6, =F_CPU
        UDIV    R2, R6, R5                  ; R2 = mantissa
        
        ; Calculate remainder
        MUL     R3, R2, R5                  ; R3 = mantissa * divisor
        SUB     R3, R6, R3                  ; R3 = remainder
        
        ; Calculate fraction = (remainder * 8 + divisor/2) / divisor
        MOV     R1, #8
        MUL     R3, R3, R1                  ; R3 = remainder * 8
        MOV     R1, R5, LSR #1              ; R1 = divisor / 2
        ADD     R3, R3, R1                  ; R3 = (remainder * 8) + (divisor / 2)
        UDIV    R3, R3, R5                  ; R3 = fraction
        
        ; Keep only 3 bits for fraction
        AND     R3, R3, #0x07
        
        ; Combine mantissa and fraction
        MOV     R2, R2, LSL #4              ; Shift mantissa left by 4
        ORR     R2, R2, R3                  ; Combine with fraction
        
setBaudRate_Store
        ; Store to BRR register
        LDR     R0, =UART1_BASE
        STR     R2, [R0, #UART1_BRR]
        
        POP     {R1-R7, PC}                 ; Restore and return
        ENDP

;---------------------------------------------------------
; uint8 USART1_IsDataAvailable(void)
; Returns: R0 = 1 if data available, 0 otherwise
;
; Checks if data is available to read (non-blocking)
;---------------------------------------------------------
UART1_IsDataAvailable PROC
		PUSH    {R1}                        ; Save register
        
		LDR     R1, =UART1_BASE
		LDR     R0, [R1, #UART1_SR]
		AND     R0, R0, #(1 << RXNE_BIT)    ; Check RXNE flag
		CMP     R0, #0
		MOVNE   R0, #1                      ; Return 1 if data available
		MOVEQ   R0, #0                      ; Return 0 if no data
        
		POP     {R1}                        ; Restore register
		BX      LR                          ; Return
		ENDP

        ALIGN
        END