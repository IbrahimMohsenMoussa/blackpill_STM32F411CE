    INCLUDE stm32f411.inc
; ====================================================================
; SysTick Driver for ARM Cortex-M
; APIs: SysTick_Init, SysTick_delay_ms, SysTick_delay_us
; @Author : Spider Man
; ====================================================================

; --------------------------------------------------------------------
; SysTick Register Definitions
; --------------------------------------------------------------------
SYSTICK_BASE            EQU     0xE000E010

SYSTICK_CTRL            EQU     SYSTICK_BASE + 0x00
SYSTICK_LOAD            EQU     SYSTICK_BASE + 0x04
SYSTICK_VAL             EQU     SYSTICK_BASE + 0x08
SYSTICK_CALIB           EQU     SYSTICK_BASE + 0x0C

; Bit definitions for SYSTICK_CTRL register
SYSTICK_CTRL_ENABLE_BIT         EQU     0
SYSTICK_CTRL_TICKINT_BIT        EQU     1
SYSTICK_CTRL_CLKSOURCE_BIT      EQU     2
SYSTICK_CTRL_COUNTFLAG_BIT      EQU     16


; SysTick clock = AHB/8 = 2 MHz (for greater delay range)
SYSTICK_CLK_FREQ        EQU     (AHB_FREQ / 8)  ; 12.5 MHz
SYSTICK_CLK_PERIOD_NS   EQU     (1000000000 / SYSTICK_CLK_FREQ) ; 80 ns
	
SYSTICK_MAX_TICKS       EQU     0x00FFFFFF
SEC_TO_mSEC             EQU     1000
SEC_TO_uSEC             EQU     1000000
MAX_TIME_mSEC			EQU		1342	; MAX_TIME_mSEC = (SYSTICK_MAX_TICKS * SEC_TO_mSEC) / F_SYSTICK
										; = (0x00FFFFFF * 1000) / 12,500,000 = ~1,342.18 ms
MAX_TIME_uSEC			EQU		1342177	; MAX_TIME_uSEC = (SYSTICK_MAX_TICKS * SEC_TO_uSEC) / F_SYSTICK
										; = (0x00FFFFFF * 1,000,000) / 12,500,000 = ~1,342,177.28 us
; --------------------------------------------------------------------
; Exported Procedures
; --------------------------------------------------------------------
    AREA |.text|, CODE, READONLY
    THUMB
    EXPORT  SysTick_Init
    EXPORT  SysTick_delay_ms
    EXPORT  SysTick_delay_us

; --------------------------------------------------------------------
; SysTick_Init
; Initializes SysTick timer to use AHB/8 clock (12.5 MHz)
; Input: None
; Output: None
; --------------------------------------------------------------------
SysTick_Init PROC
    PUSH    {R0, LR}
    
    ; Disable SysTick first
    LDR     R0, =SYSTICK_CTRL
    LDR     R1, [R0]
    BIC     R1, R1, #(1 << SYSTICK_CTRL_ENABLE_BIT)
    STR     R1, [R0]
    
    ; Clear current value
    LDR     R0, =SYSTICK_VAL
    MOV     R1, #0
    STR     R1, [R0]
    
    ; Set clock source to AHB/8 (clear CLKSOURCE bit)
    LDR     R0, =SYSTICK_CTRL
    LDR     R1, [R0]
    BIC     R1, R1, #(1 << SYSTICK_CTRL_CLKSOURCE_BIT)
    STR     R1, [R0]
    
    ; Disable interrupt (we're using polling)
    BIC     R1, R1, #(1 << SYSTICK_CTRL_TICKINT_BIT)
    STR     R1, [R0]
    
    POP     {R0, PC}
    ENDP

; --------------------------------------------------------------------
; SysTick_Start (Equivalent to SYSTICK_voidStart)
; Input: R0 = LoadValue (ticks)
; --------------------------------------------------------------------
SysTick_Start PROC
    ; Load required number of ticks
    SUBS    R0, R0, #1       ; Counts from LOAD to 0
    LDR     R1, =SYSTICK_LOAD
    STR     R0, [R1]
    
    ; Clear current value and COUNTFLAG
    LDR     R1, =SYSTICK_VAL
    MOV     R0, #0
    STR     R0, [R1]
    
    ; Start the timer
    LDR     R1, =SYSTICK_CTRL
    LDR     R0, [R1]
    ORR     R0, R0, #(1 << SYSTICK_CTRL_ENABLE_BIT)
    STR     R0, [R1]
    
    BX      LR
    ENDP

; --------------------------------------------------------------------
; SysTick_delay_ms (Equivalent to SYSTICK_voidDelay_ms)
; Input: R0 = time_in_ms
; --------------------------------------------------------------------
SysTick_delay_ms PROC
    PUSH    {R4, LR}
    MOV     R4, R0           ; Save time_in_ms
    
delay_ms_loop
    LDR     R1, =MAX_TIME_mSEC
    CMP     R4, R1
    BLS     delay_ms_final
    
    ; Handle values above maximum
    SUB     R4, R4, R1       ; time_in_ms -= MAX_TIME_mSEC
    
    ; Count max possible ticks
    LDR     R0, =SYSTICK_MAX_TICKS
    BL      SysTick_Start
    
    ; Wait for count flag
    LDR     R1, =SYSTICK_CTRL
wait_ms_loop1
    LDR     R2, [R1]
    TST     R2, #(1 << SYSTICK_CTRL_COUNTFLAG_BIT)
    BEQ     wait_ms_loop1
    
    ; Stop timer
    LDR     R1, =SYSTICK_CTRL
    LDR     R2, [R1]
    BIC     R2, R2, #(1 << SYSTICK_CTRL_ENABLE_BIT)
    STR     R2, [R1]
    
    B       delay_ms_loop

delay_ms_final
    ; Calculate ticks: ((SYSTICK_CLK_FREQ/SEC_TO_mSEC) * time_in_ms) - 1
    ; = (12500 * time_in_ms) - 1
    LDR     R0, =12500
    MUL     R0, R4, R0
    SUBS    R0, R0, #1
    
    BL      SysTick_Start
    
    ; Wait for count flag
    LDR     R1, =SYSTICK_CTRL
wait_ms_loop2
    LDR     R2, [R1]
    TST     R2, #(1 << SYSTICK_CTRL_COUNTFLAG_BIT)
    BEQ     wait_ms_loop2
    
    ; Stop timer
    LDR     R1, =SYSTICK_CTRL
    LDR     R2, [R1]
    BIC     R2, R2, #(1 << SYSTICK_CTRL_ENABLE_BIT)
    STR     R2, [R1]
    
    POP     {R4, PC}
    ENDP

; --------------------------------------------------------------------
; SysTick_delay_us (Equivalent to SYSTICK_voidDelay_us)
; Input: R0 = time_in_us
; --------------------------------------------------------------------
SysTick_delay_us PROC
    PUSH    {R4, LR}
    MOV     R4, R0           ; Save time_in_us
    
delay_us_loop
    LDR     R1, =MAX_TIME_uSEC
    CMP     R4, R1
    BLS     delay_us_final
    
    ; Handle values above maximum
    SUB     R4, R4, R1       ; time_in_us -= MAX_TIME_uSEC
    
    ; Count max possible ticks
    LDR     R0, =SYSTICK_MAX_TICKS
    BL      SysTick_Start
    
    ; Wait for count flag
    LDR     R1, =SYSTICK_CTRL
wait_us_loop1
    LDR     R2, [R1]
    TST     R2, #(1 << SYSTICK_CTRL_COUNTFLAG_BIT)
    BEQ     wait_us_loop1
    
    ; Stop timer
    LDR     R1, =SYSTICK_CTRL
    LDR     R2, [R1]
    BIC     R2, R2, #(1 << SYSTICK_CTRL_ENABLE_BIT)
    STR     R2, [R1]
    
    B       delay_us_loop

delay_us_final
    ; Calculate ticks: ((F_SYSTICK/SEC_TO_uSEC) * time_in_us) - 1
    ; = (2 * time_in_us) - 1
    LSL     R0, R4, #1       ; Multiply by 2
    SUBS    R0, R0, #1
    
    BL      SysTick_Start
    
    ; Wait for count flag
    LDR     R1, =SYSTICK_CTRL
wait_us_loop2
    LDR     R2, [R1]
    TST     R2, #(1 << SYSTICK_CTRL_COUNTFLAG_BIT)
    BEQ     wait_us_loop2
    
    ; Stop timer
    LDR     R1, =SYSTICK_CTRL
    LDR     R2, [R1]
    BIC     R2, R2, #(1 << SYSTICK_CTRL_ENABLE_BIT)
    STR     R2, [R1]
    
    POP     {R4, PC}
    ENDP
    ALIGN
    END