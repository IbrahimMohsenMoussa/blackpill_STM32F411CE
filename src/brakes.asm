;==============================================================================
; brakes.asm
; Bare-metal driver for 3-state mechanical braking system using MG995 on TIM4.
;==============================================================================

TIM4_BASE       EQU 0x40000800
TIM_CR1         EQU 0x00
TIM_CCMR2       EQU 0x1C
TIM_CCER        EQU 0x20
TIM_PSC         EQU 0x28
TIM_ARR         EQU 0x2C
TIM_CCR4        EQU 0x40

TIM4_PSC_VAL    EQU 99          ; 100MHz APB1 -> 1MHz counter
TIM4_ARR_VAL    EQU 19999       ; 1MHz / 20000 = 50Hz PWM (20ms)

SERVO_STOP_VAL    EQU 1500
SERVO_APPLY_VAL   EQU 2000
SERVO_RELEASE_VAL EQU 1000

TIME_FULL_BRAKE   EQU 600
TIME_SLOW_BRAKE   EQU 500
TIME_RELEASE      EQU 600

    AREA |.text|, CODE, READONLY, ALIGN=2
    THUMB
    EXPORT Brakes_Init
    EXPORT Brakes_ApplyFull
    EXPORT Brakes_ApplySlow
    EXPORT Brakes_Release

    IMPORT RCC_APB1_Enable
    IMPORT SysTick_delay_ms

; ----------------------------------------------------------------------------
; Brakes_Init
; Initializes TIM4_CH4 for PWM Mode 1 to control the brake servo.
; ----------------------------------------------------------------------------
Brakes_Init PROC
    PUSH    {r4-r5, lr}

    ; 1. Enable TIM4 Clock (Mask is 4, which is Bit 2 in APB1ENR)
    MOVS    r0, #4
    BL      RCC_APB1_Enable

    LDR     r4, =TIM4_BASE

    ; 2. Configure Prescaler and Auto-Reload Register
    LDR     r5, =TIM4_PSC_VAL
    STR     r5, [r4, #TIM_PSC]

    LDR     r5, =TIM4_ARR_VAL
    STR     r5, [r4, #TIM_ARR]

    ; 3. Configure CCMR2 for PWM Mode 1 on CH4 (OC4M = 110, OC4PE = 1)
    ; Bits [14:12] = 110 (0x6), Bit 11 = 1 -> 0x6800
    LDR     r5, [r4, #TIM_CCMR2]
    LDR     r0, =0x6800
    ORR     r5, r5, r0
    STR     r5, [r4, #TIM_CCMR2]

    ; 4. Enable capture/compare output for CH4 (CC4E = 1 in CCER, Bit 12)
    LDR     r5, [r4, #TIM_CCER]
    ORR     r5, r5, #(1 << 12)
    STR     r5, [r4, #TIM_CCER]

    ; 5. Enable TIM4 counter (CEN = 1 in CR1, Bit 0)
    LDR     r5, [r4, #TIM_CR1]
    ORR     r5, r5, #1
    STR     r5, [r4, #TIM_CR1]

    POP     {r4-r5, pc}
    ENDP

; ----------------------------------------------------------------------------
; State Functions
; ----------------------------------------------------------------------------
Brakes_ApplyFull PROC
    PUSH    {r4, lr}
    LDR     r4, =TIM4_BASE
    
    LDR     r1, =SERVO_APPLY_VAL
    STR     r1, [r4, #TIM_CCR4]
    
    LDR     r0, =TIME_FULL_BRAKE
    BL      SysTick_delay_ms
    
    LDR     r1, =SERVO_STOP_VAL
    STR     r1, [r4, #TIM_CCR4]
    
    POP     {r4, pc}
    ENDP

Brakes_ApplySlow PROC
    PUSH    {r4, lr}
    LDR     r4, =TIM4_BASE
    
    LDR     r1, =SERVO_APPLY_VAL
    STR     r1, [r4, #TIM_CCR4]
    
    LDR     r0, =TIME_SLOW_BRAKE
    BL      SysTick_delay_ms
    
    LDR     r1, =SERVO_STOP_VAL
    STR     r1, [r4, #TIM_CCR4]
    
    POP     {r4, pc}
    ENDP

Brakes_Release PROC
    PUSH    {r4, lr}
    LDR     r4, =TIM4_BASE
    
    LDR     r1, =SERVO_RELEASE_VAL
    STR     r1, [r4, #TIM_CCR4]
    
    LDR     r0, =TIME_RELEASE
    BL      SysTick_delay_ms
    
    LDR     r1, =SERVO_STOP_VAL
    STR     r1, [r4, #TIM_CCR4]
    
    POP     {r4, pc}
    ENDP

    END
