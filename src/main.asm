; ==============================================================================
; main.asm
; RTOS State Machine & Main Event Loop Router
; ==============================================================================

    ; --- State Definitions ---
STATE_IDLE      equ 0
STATE_START     equ 1
STATE_MOVING    equ 2
STATE_STOP      equ 3
STATE_EMERGENCY equ 4

    ; --- Floor Position Constants ---
FLOOR0_SP       equ 52
FLOOR1_SP       equ 360
FLOOR2_SP       equ 650

    ; --- Control Loop Constants ---
CL_KP           equ 28
CL_KI           equ 2

    ; ==============================================================================
    ; SRAM Variables
    ; ==============================================================================
    area |.bss|, DATA, READWRITE
    align 4

    INCLUDE stm32f411.inc
    INCLUDE hardware_config.inc
System_State             space 1
Sys_Emergency_Flag       space 1
Sys_Power_Restored       space 1
Sys_Display_Needs_Update space 1
Current_Target_Floor     space 4

    ; Export required variable(s) for external drivers
    export Sys_Display_Needs_Update

    ; ==============================================================================
    ; Main Application Code
    ; ==============================================================================
    area |.text|, CODE, READONLY, ALIGN=2
    thumb
    
    EXPORT main
    
    ; --- Hardware & Subsystem Imports ---
    IMPORT DIO_ToggleLogical
    IMPORT DIO_ReadLogical
    IMPORT DIO_WriteLogical
    IMPORT PLLInit
    IMPORT GPIO_Init_All
    IMPORT DIO_WritePort
	IMPORT SysTick_Init
	IMPORT SysTick_delay_ms
    IMPORT Keys_init 
    IMPORT Decode_Keypad
    IMPORT Read_Button_Values
    IMPORT ADC_Read_Channel
    IMPORT Stepper_Init
    IMPORT Stepper_Enable
    IMPORT Stepper_SetDirection
    IMPORT Stepper_SetSpeed
    IMPORT TOF_Init
    IMPORT TOF_Read_Distance
    IMPORT I2C1_Init
    IMPORT RTC_Init
    IMPORT OLED_Init
    IMPORT OLED_ClearBuffer
    IMPORT UI_Init
    IMPORT UI_SetCurrentFloor
    IMPORT UI_SetTargetFloor
   
    IMPORT UI_Update
    IMPORT UI_TargetFloor
    IMPORT UI_CurrentFloor
    IMPORT UI_Update_Chunked
    IMPORT DFP_Init
    IMPORT DFP_PlayImmediate
    IMPORT brakes_on
    IMPORT brakes_off
    IMPORT EXTI_Pin_Init
    IMPORT UI_SetScreen
    IMPORT UI_SetEmergencyReason
main

    ; 1. Set up initial system state
    ldr r0, =System_State
    movs r1, #STATE_IDLE
    strb r1, [r0]

    ; 2. Hardware Initialization Sequence
    bl PLLInit

    bl GPIO_Init_All
    bl RTC_Init
    bl SysTick_Init
    mov r0, #500
    bl  SysTick_delay_ms
    bl brakes_on
    bl TOF_Init
    bl I2C1_Init
    bl OLED_Init
    bl UI_Init
    bl DFP_Init
    bl Keys_init
    bl Stepper_Init
    bl Stepper_Enable
    

    ; Initialize PB8 EXTI (Power Monitor)
    movs r0, #1      ; r0 = Port B (1)
    movs r1, #8      ; r1 = Pin 8
    movs r2, #2      ; r2 = Trigger configuration
    bl EXTI_Pin_Init

    ; ==============================================================================
    ; Main Event Router (RTOS Scheduler)
    ; ==============================================================================
main_loop
    ; --- Priority 1: Emergency Preemption (Highest) ---
    ldr r0, =Sys_Emergency_Flag
    ldrb r1, [r0]
    cmp r1, #1
    beq.w EXECUTE_EMERGENCY

    ; --- Priority 2: Core State Machine ---
    ldr r0, =System_State
    ldrb r1, [r0]
    
    cmp r1, #STATE_IDLE
    beq.w EXECUTE_IDLE
    cmp r1, #STATE_START
    beq.w EXECUTE_START
    cmp r1, #STATE_MOVING
    beq.w EXECUTE_MOVING
    cmp r1, #STATE_STOP
    beq.w EXECUTE_STOP

    ; --- Priority 3: Background UI Task (Lowest) ---
    ldr r0, =Sys_Display_Needs_Update
    ldrb r1, [r0]
    cmp r1, #1
    bne loop_restart

    bl UPDATE_DISPLAY_ROUTINE

loop_restart
    b main_loop

    ; ==============================================================================
    ; Subsystem Stubs
    ; ==============================================================================
EXECUTE_EMERGENCY
    push {r0-r3, lr}
    movs r0, #5
    bl DFP_PlayImmediate

    movs r0, #0
    bl UI_SetEmergencyReason
    movs r0, #4
    bl UI_SetScreen
    bl UI_Update
EMERGENCY_TRAP
    b EMERGENCY_TRAP

EXECUTE_MOVING
    ldr r5, =Current_Target_Floor
    ldr r5, [r5]
    movs r9, #0
    movs r11, #0
    movs r12, #0

loop_moving
    ; --- Preemption Check ---
    ldr r0, =Sys_Emergency_Flag
    ldrb r1, [r0]
    cmp r1, #1
    beq EXECUTE_EMERGENCY

    ; --- Read Distance ---
    push {r5, r9, r11, r12}
    bl TOF_Read_Distance
    pop {r5, r9, r11, r12}

    ; Check for sensor error (0xFFFFFFFF)
    ldr r1, =0xFFFFFFFF
    cmp r0, r1
    beq loop_moving

    movs r11, #0
    mov r4, r0
    sub r6, r5, r4

    ; Absolute error into R7
    cmp r6, #0
    ite mi
    rsbmi r7, r6, #0
    movpl r7, r6

    ; Deadband check
    cmp r7, #10
    blt within_deadband

    ; Integral Accumulator
    add r9, r9, r6
    
    ; Clamp Integral
    ldr r1, =500
    cmp r9, r1
    it gt
    movgt r9, r1
    ldr r1, =-500
    cmp r9, r1
    it lt
    movlt r9, r1

    ; P-Term and I-Term
    ldr r1, =CL_KP
    mul r1, r6, r1
    ldr r2, =CL_KI
    sdiv r2, r9, r2
    add r7, r1, r2

    ; Direction and Abs Speed
    cmp r7, #0
    ite ge
    movge r0, #1
    movlt r0, #0
    it lt
    rsblt r7, r7, #0

    ; Speed Clamps
    cmp r7, #16
    it lt
    movlt r7, #16
    ldr r1, =7000
    cmp r7, r1
    it gt
    movgt r7, r1

    ; Soft Starter
    cmp r7, r12
    ble skip_soft_start
    sub r1, r7, r12
    cmp r1, #95
    ble skip_soft_start
    add r7, r12, #95
skip_soft_start

    ; Apply Speed
    mov r12, r7

    push {r5, r7, r9, r11, r12}
    bl Stepper_SetDirection
    pop {r5, r7, r9, r11, r12}

    push {r5, r7, r9, r11, r12}
    mov r0, r7
    bl Stepper_SetSpeed
    pop {r5, r7, r9, r11, r12}

   ; Quick Display Update Hack inside the tight loop
    ldr r0, =Sys_Display_Needs_Update
    ldrb r1, [r0]
    cmp r1, #1
    bne skip_display
    
    ; Protect r4 as well, since we are reading it for the distance map
    push {r4, r5, r7, r9, r11, r12}
    
    ; --- LIVE UI BUFFER UPDATE ---
    ; r4 contains the live TOF distance in mm.
    ; Compare against spatial midpoints to determine the UI floor graphic.
    cmp r4, #206
    blt live_floor_0
    ldr r1, =505
    cmp r4, r1
    blt live_floor_1
    b live_floor_2

live_floor_0
    movs r0, #0
    b update_ui_buffer
live_floor_1
    movs r0, #1
    b update_ui_buffer
live_floor_2
    movs r0, #2

update_ui_buffer
    ; Call the UI subroutine to actually draw the new floor to SRAM
    bl UI_SetCurrentFloor    

    ; Now that the SRAM buffer has live data, push 1 page of it to the OLED
    bl UI_Update_Chunked    
    
    pop {r4, r5, r7, r9, r11, r12}
    
    ldr r0, =Sys_Display_Needs_Update
    movs r1, #0
    strb r1, [r0]
skip_display

    b loop_moving

within_deadband
    ldr r0, =System_State
    movs r1, #STATE_STOP
    strb r1, [r0]
    b loop_restart

EXECUTE_STOP
    push {r0-r3, lr}
    bl brakes_on

    movs r0, #3
    bl UI_SetScreen
    movs r0, #1
    ldr r1, =Sys_Display_Needs_Update
    strb r0, [r1]
    
    ldr r1, =Current_Target_Floor
    ldr r1, [r1]
    
    ldr r2, =FLOOR0_SP
    cmp r1, r2
    beq STOP_FLOOR_0
    
    ldr r2, =FLOOR1_SP
    cmp r1, r2
    beq STOP_FLOOR_1
    
    ldr r2, =FLOOR2_SP
    cmp r1, r2
    beq STOP_FLOOR_2
    
    b STOP_DONE

EXECUTE_IDLE
    ; --- 1. Check Inside Cabin Keypad ---
    bl Decode_Keypad       ; Returns ASCII in r0, or 0 if none
    cmp r0, #'0'
    beq IDLE_FLOOR_0
    cmp r0, #'1'
    beq IDLE_FLOOR_1
    cmp r0, #'2'
    beq IDLE_FLOOR_2

    ; --- 2. Check External Hall Calling Buttons ---
    bl Read_Button_Values  ; Returns 0, 1, 2, or 0xFF
    cmp r0, #0
    beq IDLE_FLOOR_0
    cmp r0, #1
    beq IDLE_FLOOR_1
    cmp r0, #2
    beq IDLE_FLOOR_2

    ; --- 3. Nothing Pressed (e.g., 0xFF) ---
    b IDLE_END

IDLE_FLOOR_0
    ldr r1, =Current_Target_Floor
    ldr r2, =FLOOR0_SP
    str r2, [r1]
    movs r0, #0
    bl UI_SetTargetFloor
    movs r0, #0            ; Turn on physical LED
    bl LED_ON_FLOOR
    b IDLE_TRANSITION

IDLE_FLOOR_1
    ldr r1, =Current_Target_Floor
    ldr r2, =FLOOR1_SP
    str r2, [r1]
    movs r0, #1
    bl UI_SetTargetFloor
    movs r0, #1            ; Turn on physical LED
    bl LED_ON_FLOOR
    b IDLE_TRANSITION

IDLE_FLOOR_2
    ldr r1, =Current_Target_Floor
    ldr r2, =FLOOR2_SP
    str r2, [r1]
    movs r0, #2
    bl UI_SetTargetFloor
    movs r0, #2            ; Turn on physical LED
    bl LED_ON_FLOOR
    b IDLE_TRANSITION

IDLE_TRANSITION
    ldr r1, =System_State
    movs r2, #STATE_START
    strb r2, [r1]          ; State transition triggers next cycle execution

IDLE_END
    b loop_restart

EXECUTE_START
    push {r0-r3, lr}
    bl brakes_off
    bl Stepper_Enable

    movs r0, #2
    bl UI_SetScreen
    movs r0, #1
    ldr r1, =Sys_Display_Needs_Update
    strb r0, [r1]

    
    ; Transition to MOVING state
    ldr r1, =System_State
    movs r2, #STATE_MOVING
    strb r2, [r1]
    
    pop {r0-r3, lr}
    b loop_restart

STOP_FLOOR_0
    movs r0, #1
    bl DFP_PlayImmediate
    b STOP_DONE

STOP_FLOOR_1
    movs r0, #2
    bl DFP_PlayImmediate
    b STOP_DONE

STOP_FLOOR_2
    movs r0, #3
    bl DFP_PlayImmediate
    b STOP_DONE

STOP_DONE
    movs r0, #0
    bl UI_SetScreen
    bl UI_Update

    ; Transition back to IDLE so we can take new calls
    ldr r0, =System_State
    movs r1, #STATE_IDLE
    strb r1, [r0]
    pop {r0-r3, lr}
    b loop_restart

UPDATE_DISPLAY_ROUTINE 
    push {lr}
    bl UI_Update
    ldr r0, =Sys_Display_Needs_Update
    movs r1, #0
    strb r1, [r0]
    pop {pc}   

    

LED_ON_FLOOR PROC
    ; Input: r0 = Floor Number (0, 1, or 2)
    push {r4, lr}
    mov r4, r0                  ; Save floor number

    ; Turn off all floor LEDs first
    mov r1, #0                  ; State = LOW
    mov r0, #ID_LED_F0
    bl DIO_WriteLogical
    mov r1, #0                  
    mov r0, #ID_LED_F1
    bl DIO_WriteLogical
    mov r1, #0                 
    mov r0, #ID_LED_F2
    bl DIO_WriteLogical

    ; Turn on the specific floor LED
    cmp r4, #0
    moveq r0, #ID_LED_F0
    cmp r4, #1
    moveq r0, #ID_LED_F1
    cmp r4, #2
    moveq r0, #ID_LED_F2
    
    mov r1, #1                  ; State = HIGH
    bl DIO_WriteLogical

    pop {r4, pc}
	ENDP
    ALIGN 
    end