    INCLUDE stm32f411.inc
    INCLUDE hardware_config.inc

    AREA |.text|, CODE, READONLY
    THUMB

    IMPORT TIM3_PWM_Init
    IMPORT TIM3_Set_Frequency
    IMPORT DIO_WriteLogical

    EXPORT Stepper_Init
    EXPORT Stepper_Enable
    EXPORT Stepper_Disable
    EXPORT Stepper_SetDirection
    EXPORT Stepper_SetSpeed

; ============================================================================
; void Stepper_Init(void)
; Initializes the TIM3 PWM for the STEP pin and disables the motor by default.
; Note: GPIOs (DIR, ENABLE, STEP) are already initialized by GPIO_Init_All.
; ============================================================================
Stepper_Init PROC
    push {lr}
    bl TIM3_PWM_Init            ; Initialize hardware timer for STEP pin (PA6)
    bl Stepper_Disable          ; Disable motor safely on startup
    pop {pc}
    ENDP

; ============================================================================
; void Stepper_Enable(void)
; Enables the stepper driver (Sets ENABLE pin LOW -  for tmc2209)
; ============================================================================
Stepper_Enable PROC
    push {lr}
    mov r0, #ID_MOTOR_ENABLE
    mov r1, #0                  ; 0 = Enabled (Active LOW)
    bl DIO_WriteLogical
    pop {pc}
    ENDP

; ============================================================================
; void Stepper_Disable(void)
; Disables the stepper driver (Sets ENABLE pin HIGH) and stops the timer.
; ============================================================================
Stepper_Disable PROC
    push {r4, lr}
    mov r0, #ID_MOTOR_ENABLE
    mov r1, #1                  ; 1 = Disabled
    bl DIO_WriteLogical
    
    mov r0, #0                  ; Set speed to 0 Hz to stop steps
    bl TIM3_Set_Frequency
    pop {r4, pc}
    ENDP

; ============================================================================
; void Stepper_SetDirection(uint32_t dir)
; Input: r0 = Direction (0 for Clockwise, 1 for Counter-Clockwise)
; ============================================================================
Stepper_SetDirection PROC
    push {lr}
    mov r1, r0                  ; Move direction state (0 or 1) to r1
    mov r0, #ID_MOTOR_DIR       ; Set r0 to Logical ID for DIR pin
    bl DIO_WriteLogical
    pop {pc}
    ENDP

; ============================================================================
; void Stepper_SetSpeed(uint32_t speed_hz)
; Input: r0 = Speed in Hz (Steps per second)
; ============================================================================
Stepper_SetSpeed PROC
    ; Tail call directly to the timer driver since it also expects the frequency in r0
                
    b TIM3_Set_Frequency
    ENDP

    END