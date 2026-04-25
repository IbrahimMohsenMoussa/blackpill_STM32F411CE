; Assembly program for STM32F411 (Black Pill) to blink the onboard LED (PC13)


FLOOR0_SP EQU 100
FLOOR1_SP EQU 360
FLOOR2_SP EQU 650

CL_KI EQU 2 ; Closed Loop KI value for speed control (tune as needed)
CL_KP EQU 28; Closed Loop KP value for speed control (tune as needed)
    AREA |.data|, DATA, READWRITE
CurrentFloor DCD FLOOR0_SP






; Using CMSIS register definitions logic.
; wiggle wiggle wiggo

    INCLUDE stm32f411.inc
    INCLUDE hardware_config.inc
    
    AREA |.text|, CODE, READONLY
    THUMB
    EXPORT main

    IMPORT DIO_ToggleLogical
    IMPORT DIO_ReadLogical
    IMPORT PLLInit
    IMPORT GPIO_Init_All
    IMPORT DIO_WritePort
	IMPORT SysTick_Init
	IMPORT SysTick_delay_ms
    IMPORT Keys_init 
    IMPORT Decode_Keypad
    IMPORT ADC_Read_Channel
    IMPORT Stepper_Init
    IMPORT Stepper_Enable
    IMPORT Stepper_SetDirection
    IMPORT Stepper_SetSpeed
    IMPORT TOF_Init
    IMPORT TOF_Read_Distance

delay_loop PROC
    subs r2, r2, #1
    bne delay_loop
    bx lr 
    ENDP
    

main PROC
    b WAKEUP_STATE

loop
; shall never reach here 
    b loop
	
    ENDP




WAKEUP_STATE PROC
    ; This function is called on wakeup from sleep mode.
    ; It should reinitialize any peripherals that were turned off before sleeping.
    bl PLLInit                   ; Reinitialize PLL to restore system clock
    bl GPIO_Init_All             ; Reinitialize GPIO pins
    bl TOF_Init                  ; Reinitialize TOF400F module
    bl SysTick_Init              ; Reinitialize SysTick timer
    bl Keys_init                   ; Reinitialize ADC for keypad
    bl Stepper_Init              ; Reinitialize Timer 3 for stepper control
    bl Stepper_Enable            ; Re-enable the stepper motor driver
   

    ldr r0, =FLOOR1_SP
    b START_MOTION_STATE
    ENDP


START_MOTION_STATE PROC
     push {r0}                  ; Save target floor safely to the stack
     bl Stepper_Enable 
     ;lock current door , update oled , wait 2 seconds 

     ldr r0,=2000
     bl SysTick_delay_ms
     pop {r0}                   ; Restore target floor
     b MOVING_STATE
    ENDP



;;Takes destination from caller in r0 
MOVING_STATE PROC
    mov r5, r0 
    mov r9, #0                  ; r9 = Integral Accumulator (Initialize to 0)
    mov r11, #0                 ; r11 = Missed Frame Counter (Initialize to 0)
    mov r12, #0                 ; r12 = Current Speed (Initialize to 0)
loop_moving
    push {r5, r9, r11, r12}     ; Defensively save state registers
    bl TOF_Read_Distance         ; Read distance from TOF400F sensor
    pop {r5, r9, r11, r12}      ; Restore registers
    
    ; --- Handle Sensor Timeout/Error ---
    ldr r1, =0xFFFFFFFF
    cmp r0, r1
    bne valid_reading           ; If valid, continue processing
    
    b loop_moving               ; Always ignore error and coast at current speed

valid_reading
    mov r11, #0                 ; Reset frame error counter on valid read
    mov r4, r0                  ; Move distance reading to r4 for processing
    ;;;check deaad band for 10mm to avoid noise
    ;;; error in r6 
    subs r6, r5, r4       ; r6 = sp - distance
    
    ; --- Get Absolute Error for Deadband Check ---
    cmp r6, #0
    ite lt
    rsblt r7, r6, #0            ; If r6 < 0, r7 = -r6
    movge r7, r6                ; If r6 >= 0, r7 = r6
    
    cmp r7, #10                 ; Check absolute error against deadband
    blo within_deadband
    
    ; --- Update Integral Accumulator with Anti-Windup ---
    add r9, r9, r6              ; Accumulator += Error
    ldr r10, =500              ; Positive clamp limit (reduced to prevent windup)
    cmp r9, r10
    it gt
    movgt r9, r10
    ldr r10, =-500             ; Negative clamp limit (reduced to prevent windup)
    cmp r9, r10                ; FIX: Compare accumulator against negative limit
    it lt
    movlt r9, r10
    
    ; --- Calculate Signed PI Output ---
    ldr r10, =CL_KP
    mul r7, r6, r10             ; P_term = Error * KP
    ldr r10, =CL_KI
    sdiv r8, r9, r10             ; I_term = Accumulator / KI
    add r7, r7, r8              ; PI_Output = P_term + I_term
    
    ; --- Determine Direction and Absolute Speed ---
    cmp r7, #0
    ite ge
    movge r0, #1               ; Direction 0 (Positive)
    movlt r0, #0               ; Direction 1 (Negative)
    it lt
    rsblt r7, r7, #0            ; Absolute speed = |PI_Output|
    cmp r7, #16                 ; Minimum safe speed for 16-bit timer at 1MHz
    it lt
    movlt r7, #16 
    ldr r10, =8000             ; Max safe speed to prevent stepper motor stall
    cmp r7, r10
    it gt
    movgt r7, r10
    
    ; --- Soft Starter (Acceleration Ramp) ---
    cmp r7, r12                 ; Compare desired speed (r7) with current speed (r12)
    ble apply_speed             ; If decelerating or steady, let PI handle it directly
    
    subs r10, r7, r12           ; Calculate speed difference (acceleration)
    cmp r10, #100               ; Compare with max acceleration step (100 Hz/loop)
    ble apply_speed             ; If within limits, apply desired speed
    
    add r7, r12, #100           ; Otherwise, cap the speed to current + 100
    
apply_speed
    mov r12, r7                 ; Store new speed as current speed for next loop iteration
    
    push {r5, r7, r9, r11, r12} ; Protect registers across function calls
    bl Stepper_SetDirection     ; Set direction (r0)
    pop {r5, r7, r9, r11, r12}
    push {r5, r7, r9, r11, r12}
    mov r0, r7                  ; Load absolute speed (r7)
    bl Stepper_SetSpeed         ; Set speed (r0)
    pop {r5, r7, r9, r11, r12}  ; Restore registers

    b loop_moving
within_deadband
    mov r0, #0
    bl Stepper_SetSpeed        ; Adjust stepper speed based on distance error (you can implement a control algorithm here using CL_KP and CL_KI)
    ldr r3, =CurrentFloor       ; Get address of CurrentFloor variable
    str r5, [r3]                ; Save the new floor state to memory
    b STOP_MOTION_STATE

    ENDP


STOP_MOTION_STATE PROC
    mov r0, #0                  ; Set speed to 0 to stop the motor
    bl Stepper_SetSpeed        ; Set stepper speed to 0 to stop it
    ;unlock door , update oled 
    b IDLE_STATE
    ENDP



IDLE_STATE PROC
idle_loop
    bl Decode_Keypad            ; Check if any key is pressed and decode it
    cmp r0, #0                  ; If r0 = 0, no key is pressed
    
    push {r0}                  ; Save decoded key safely to the stack
    mov r0, #15
    bl SysTick_delay_ms         ; Short delay to debounce keypad input
    pop {r0}                   ; Restore decoded key after delay
    beq idle_loop
    ; --- Handle Key Presses ---
    cmp r0, #'0'                ; Check if key '0' is pressed
    beq go_floor0
    cmp r0, #'1'                ; Check if key '1' is pressed
    beq go_floor1
    cmp r0, #'2'                ; Check if key '2' is pressed
    beq go_floor2
    
    b idle_loop                 ; If any other key is pressed, ignore it

go_floor0
    ldr r0, =FLOOR0_SP
    b START_MOTION_STATE
go_floor1
    ldr r0, =FLOOR1_SP
    b START_MOTION_STATE
go_floor2
    ldr r0, =FLOOR2_SP
    b START_MOTION_STATE
    ENDP

    ALIGN
    END