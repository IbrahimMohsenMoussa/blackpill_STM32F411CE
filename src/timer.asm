    INCLUDE stm32f411.inc

    AREA |.text|, CODE, READONLY
    THUMB
    EXPORT TIM2_Init
    EXPORT TIM2_Delay_ms
    EXPORT TIM3_PWM_Init
    EXPORT TIM3_Set_Frequency

; ============================================================================
; void TIM2_Init(void)
; Initializes TIM2 as a free-running 32-bit microsecond counter.
; ============================================================================
TIM2_Init PROC
    ; 1. Enable TIM2 Clock on APB1 Bus
    ldr r0, =RCC_BASE
    ldr r1, [r0, #RCC_APB1ENR]
    orr r1, r1, #RCC_APB1_TIM2
    str r1, [r0, #RCC_APB1ENR]

    ; 2. Configure TIM2 registers
    ldr r0, =TIM2_BASE
    
    ; Disable timer before configuring (CEN = 0)
    mov r1, #0
    str r1, [r0, #TIM_CR1]
    
    ; Set Prescaler (PSC)
    ; APB1 timer clock is F_CPU (100MHz). Divide by 100 to get 1MHz (1us tick)
    ldr r1, =((F_CPU / 1000000) - 1)
    str r1, [r0, #TIM_PSC]
    
    ; Set Auto-Reload Register (ARR) to max 32-bit value to maximize wrap time
    ldr r1, =0xFFFFFFFF
    str r1, [r0, #TIM_ARR]
    
    ; Generate Update Event to immediately load the new prescaler (UG = 1)
    mov r1, #1
    str r1, [r0, #TIM_EGR]
    
    ; Enable Timer (CEN = 1)
    str r1, [r0, #TIM_CR1]
    
    bx lr
    ENDP

; ============================================================================
; void TIM2_Delay_ms(uint32_t ms)
; Safely delays execution for a specified number of milliseconds.
; Input: r0 = Delay in milliseconds
; ============================================================================
TIM2_Delay_ms PROC
    push {r4, lr}
    
    ; Convert ms to us (1 ms = 1000 us)
    ldr r1, =1000
    mul r0, r0, r1          ; r0 = target wait time in ticks (us)
    
    ldr r1, =TIM2_BASE
    ldr r2, [r1, #TIM_CNT]  ; r2 = start time

wait_loop
    ldr r3, [r1, #TIM_CNT]  ; r3 = current time
    
    ; 2's complement math safely handles timer overflow/wrap-around
    subs r4, r3, r2         ; r4 = elapsed time (current - start)
    cmp r4, r0              ; Compare elapsed time with target
    blo wait_loop           ; Loop if elapsed time < target

    pop {r4, pc}
    ENDP

; ============================================================================
; void TIM3_PWM_Init(void)
; Initializes TIM3 Channel 1 (PA6) for Hardware PWM to drive a stepper motor
; Base clock is set to 1 MHz.
; ============================================================================
TIM3_PWM_Init PROC
    push {r4, lr}
    
    ; 1. Enable GPIOA Clock (for PA6)
    ldr r0, =RCC_BASE
    ldr r1, [r0, #RCC_AHB1ENR]
    orr r1, r1, #RCC_AHB1_GPIOA
    str r1, [r0, #RCC_AHB1ENR]
    
    ; 2. Configure PA6 for Alternate Function (AF2 = TIM3)
    ldr r0, =GPIOA_BASE
    ldr r1, [r0, #GPIO_MODER]
    bic r1, r1, #(3 :SHL: 12)   ; Clear bits 12, 13
    orr r1, r1, #(2 :SHL: 12)   ; Set PA6 to AF mode (10)
    str r1, [r0, #GPIO_MODER]
    
    ldr r1, [r0, #GPIO_AFRL]
    bic r1, r1, #(0xF :SHL: 24) ; Clear AF bits for PA6 (bits 24-27)
    orr r1, r1, #(2 :SHL: 24)   ; Set PA6 to AF2 (0010)
    str r1, [r0, #GPIO_AFRL]
    
    ; 3. Enable TIM3 Clock
    ldr r0, =RCC_BASE
    ldr r1, [r0, #RCC_APB1ENR]
    orr r1, r1, #RCC_APB1_TIM3
    str r1, [r0, #RCC_APB1ENR]
    
    ; 4. Configure TIM3 Registers
    ldr r0, =TIM3_BASE
    mov r1, #0
    str r1, [r0, #TIM_CR1]      ; Disable timer during setup
    
    ; Set Prescaler to achieve 1 MHz timer base clock (1 us per tick)
    ldr r1, =((F_CPU / 1000000) - 1)
    str r1, [r0, #TIM_PSC]
    
    ; Set default frequency to ~1kHz (ARR = 999)
    ldr r1, =999
    str r1, [r0, #TIM_ARR]
    
    ; Set default duty cycle to 50% (CCR1 = 500)
    ldr r1, =500
    str r1, [r0, #TIM_CCR1]
    
    ; Configure CCMR1 for PWM Mode 1 on Channel 1 (OC1M = 110, OC1PE = 1)
    mov r1, #0x68
    str r1, [r0, #TIM_CCMR1]
    
    ; Enable Channel 1 Output in CCER (CC1E = 1)
    mov r1, #1
    str r1, [r0, #TIM_CCER]
    
    ; Enable TIM3 and enable Auto-Reload Preload (ARPE = Bit 7, CEN = Bit 0)
    mov r1, #0x81
    str r1, [r0, #TIM_CR1]
    
    pop {r4, pc}
    ENDP

; ============================================================================
; void TIM3_Set_Frequency(uint32_t frequency_hz)
; Sets the stepper motor step frequency. 50% duty cycle is automatically maintained.
; Input: r0 = Target frequency in Hz (Pass 0 to stop motor)
; ============================================================================
TIM3_Set_Frequency PROC
    push {r4, lr}
    
    cmp r0, #0                  ; If frequency is 0, just stop output
    beq set_zero_freq
    
    ; Calculate ARR: ARR = (1,000,000 / Frequency) - 1
    ldr r1, =1000000
    udiv r2, r1, r0             ; Hardware Unsigned Divide (r2 = 1M / freq)
    subs r2, r2, #1             ; r2 = ARR value
    
    ldr r4, =TIM3_BASE
    str r2, [r4, #TIM_ARR]      ; Update frequency
    
    ; Keep 50% duty cycle: CCR1 = (ARR + 1) / 2
    add r3, r2, #1
    lsr r3, r3, #1              ; Divide by 2
    str r3, [r4, #TIM_CCR1]     ; Update duty cycle
    pop {r4, pc}
    
set_zero_freq
    ldr r4, =TIM3_BASE
    mov r1, #0
    str r1, [r4, #TIM_CCR1]     ; Duty cycle = 0 turns off the square wave
    pop {r4, pc}
    ENDP

    END