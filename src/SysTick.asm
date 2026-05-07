;==============================================================================
; SysTick RTOS Heartbeat Driver
; @Description: Refactored continuous heartbeat for RTOS timekeeping.
; Removes blocking polling modes in favor of a continuous 1ms background 
; interrupt tick that tracks global uptime and manages a 200ms display scheduler.
;==============================================================================

SYSTICK_BASE    EQU     0xE000E010
SYSTICK_CTRL    EQU     0x00
SYSTICK_LOAD    EQU     0x04
SYSTICK_VAL     EQU     0x08

    ; ========================================================================
    ; Global RAM Variables (.bss Section)
    ; ========================================================================
    AREA |.bss|, DATA, READWRITE
    ALIGN
Global_Tick_ms          SPACE 4     ; 32-bit absolute system time counter
RTOS_Display_Counter    SPACE 4     ; 32-bit countdown for display updates

    ; ========================================================================
    ; Code Section
    ; ========================================================================
    AREA |.text|, CODE, READONLY, ALIGN=2
    THUMB

    EXPORT SysTick_Init
    EXPORT SysTick_delay_ms
    EXPORT SysTick_Handler
    
    ; Import the external display update flag from main
    IMPORT Sys_Display_Needs_Update

; ----------------------------------------------------------------------------
; SysTick_Init
; Configures the timer to run continuously with a 1ms interrupt.
; ----------------------------------------------------------------------------
SysTick_Init PROC
    PUSH    {R0-R2, LR}
    
    LDR     R0, =SYSTICK_BASE
    
    ; 1. Program Reload Value (12499 for exactly 1ms tick at 12.5 MHz AHB/8)
    LDR     R1, =12499
    STR     R1, [R0, #SYSTICK_LOAD]
    
    ; 2. Clear Current Value register
    MOV     R1, #0
    STR     R1, [R0, #SYSTICK_VAL]
    
    ; 3. Initialize Global Counters for the RTOS Heartbeat
    LDR     R2, =Global_Tick_ms
    STR     R1, [R2]                ; Zero out Global_Tick_ms
    
    LDR     R2, =RTOS_Display_Counter
    MOV     R1, #50                   ; Start with 50ms to allow initial system stabilization
    STR     R1, [R2]                ; Initialize display countdown to 50ms
    
    ; 4. Write to CTRL: Enable Timer (Bit 0), Enable Interrupt (Bit 1), AHB/8 (Bit 2 = 0)
    MOV     R1, #3                  
    STR     R1, [R0, #SYSTICK_CTRL]
    
    POP     {R0-R2, PC}
    ENDP

; ----------------------------------------------------------------------------
; SysTick_Handler (ISR)
; The core RTOS heartbeat interrupt firing every 1ms.
; ----------------------------------------------------------------------------
SysTick_Handler PROC
    PUSH    {R0-R3, LR}             ; Protect caller registers
    
    ; 1. Increment the absolute global time counter
    LDR     R0, =Global_Tick_ms
    LDR     R1, [R0]
    ADD     R1, R1, #1
    STR     R1, [R0]
    
    ; 2. Decrement the 200ms display scheduler
    LDR     R0, =RTOS_Display_Counter
    LDR     R1, [R0]
    SUBS    R1, R1, #1
    STR     R1, [R0]
    
    ; Check if display counter hit 0 (Z-flag set by SUBS)
    BNE     SysTick_Handler_Done    
    
    ; 3. Reload display counter with 50ms
    MOV     R1, #50
    STR     R1, [R0]
    
    ; 4. Flag the main loop that the display needs to be updated
    LDR     R2, =Sys_Display_Needs_Update
    MOV     R3, #1
    STRB    R3, [R2]                ; Write 1 to the external byte flag

SysTick_Handler_Done
    POP     {R0-R3, PC}             ; Return from exception (EXC_RETURN via PC)
    ENDP

; ----------------------------------------------------------------------------
; SysTick_delay_ms
; Non-blocking polling delay utilizing the new continuous global time tick.
; Input: R0 = requested delay in milliseconds
; ----------------------------------------------------------------------------
SysTick_delay_ms PROC
    PUSH    {R1-R3, LR}
    
    LDR     R1, =Global_Tick_ms
    
    ; Read Start Time
    LDR     R2, [R1]

delay_loop
    ; Read Current Time
    LDR     R3, [R1]
    
    ; Calculate Elapsed = Current Time - Start Time
    ; (Unsigned subtraction inherently handles the 32-bit overflow rollover seamlessly)
    SUBS    R3, R3, R2
    
    ; Check if Elapsed < Requested (R0)
    CMP     R3, R0
    BLO     delay_loop              ; Continue polling if not yet completed
    
    POP     {R1-R3, PC}
    ENDP

    END