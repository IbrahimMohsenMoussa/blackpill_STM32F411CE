; ==============================================================================
; Servo Motor Driver for STM32F411 (Elevator Doors)
; Bare-Metal ARM Cortex-M4 Assembly (Thumb-2)
; ==============================================================================

    INCLUDE stm32f411.inc

; ------------------------------------------------------------------------------
; External Dependencies
; ------------------------------------------------------------------------------
    IMPORT RCC_APB1_Enable

; ------------------------------------------------------------------------------
; Constants
; ------------------------------------------------------------------------------
TIM2_PSC_VAL    EQU 99          ; Divides 100MHz down to 1MHz (1 microsecond per tick)
TIM2_ARR_VAL    EQU 19999       ; 20,000 ticks = 20ms period (50Hz)

; Distinct Servo Calibration Values per Floor (1us per tick)
; Using standard 180-degree mapping: 0°=500us, 90°=1500us, 180°=2500us
F0_SERVO_OPEN_VAL   EQU 2500    ; Floor 0 Open (180 degrees)
F0_SERVO_CLOSE_VAL  EQU 1500    ; Floor 0 Close (90 degrees)

F1_SERVO_OPEN_VAL   EQU 500     ; Floor 1 Open (0 degrees)
F1_SERVO_CLOSE_VAL  EQU 1833    ; Floor 1 Close (120 degrees)

F2_SERVO_OPEN_VAL   EQU 500     ; Floor 2 Open (0 degrees)
F2_SERVO_CLOSE_VAL  EQU 1500    ; Floor 2 Close (90 degrees)

; TIM2 Register Definitions


; ------------------------------------------------------------------------------
; Code Section
; ------------------------------------------------------------------------------
    AREA    |.text|, CODE, READONLY, ALIGN=2
    THUMB
    EXPORT  Servo_Init
    EXPORT  Servo_OpenDoor
    EXPORT  Servo_CloseDoor

; ------------------------------------------------------------------------------
; Servo_Init
; Enables TIM2 Clock, configures PWM modes and outputs.
; ------------------------------------------------------------------------------
Servo_Init PROC
    push    {r4, lr}
    
    ; Enable TIM2 Clock (Bit 0 on APB1)
    movs    r0, #1
    bl      RCC_APB1_Enable
    
    ; Configure TIM2 Base 
    ldr     r4, =TIM2_BASE
    
    ldr     r1, =TIM2_PSC_VAL
    str     r1, [r4, #TIM_PSC]
    
    ldr     r1, =TIM2_ARR_VAL
    str     r1, [r4, #TIM_ARR]
    
    ; Configure PWM Mode 1 (TIM_CCMR1 and TIM_CCMR2)
    ; CCMR1: CH1 & CH2 (OCxM=110, OCxPE=1)
    ldr     r1, =0x6868
    str     r1, [r4, #TIM_CCMR1]
    
    ; CCMR2: CH3 (OCxM=110, OCxPE=1)
    ldr     r1, =0x0068
    str     r1, [r4, #TIM_CCMR2]
    
    ; Enable Outputs for CH1, CH2, CH3 (TIM_CCER)
    ldr     r1, =0x0111
    str     r1, [r4, #TIM_CCER]
    
    ; Enable Timer (TIM_CR1)
    ldr     r1, [r4, #TIM_CR1]
    orr     r1, r1, #1
    str     r1, [r4, #TIM_CR1]
    
    pop     {r4, pc}
    ENDP

; ------------------------------------------------------------------------------
; Servo_OpenDoor
; Input: r0 = Floor Number (0, 1, or 2)
; ------------------------------------------------------------------------------
Servo_OpenDoor PROC
    push    {r4, lr}
    ldr     r4, =TIM2_BASE
    
    cmp     r0, #0
    beq     open_f0
    cmp     r0, #1
    beq     open_f1
    cmp     r0, #2
    beq     open_f2
    b       open_end
    
open_f0
    ldr     r1, =F0_SERVO_OPEN_VAL
    str     r1, [r4, #TIM_CCR2]
    b       open_end
open_f1
    ldr     r1, =F1_SERVO_OPEN_VAL
    str     r1, [r4, #TIM_CCR1]
    b       open_end
open_f2
    ldr     r1, =F2_SERVO_OPEN_VAL
    str     r1, [r4, #TIM_CCR3]

open_end
    pop     {r4, pc}
    ENDP

; ------------------------------------------------------------------------------
; Servo_CloseDoor
; Input: r0 = Floor Number (0, 1, or 2)
; ------------------------------------------------------------------------------
Servo_CloseDoor PROC
    push    {r4, lr}
    ldr     r4, =TIM2_BASE
    
    cmp     r0, #0
    beq     close_f0
    cmp     r0, #1
    beq     close_f1
    cmp     r0, #2
    beq     close_f2
    b       close_end
    
close_f0
    ldr     r1, =F0_SERVO_CLOSE_VAL
    str     r1, [r4, #TIM_CCR2]
    b       close_end
close_f1
    ldr     r1, =F1_SERVO_CLOSE_VAL
    str     r1, [r4, #TIM_CCR1]
    b       close_end
close_f2
    ldr     r1, =F2_SERVO_CLOSE_VAL
    str     r1, [r4, #TIM_CCR3]

close_end
    pop     {r4, pc}
    ENDP
    
    END