; Assembly program for STM32F411 (Black Pill) to blink the onboard LED (PC13)

    AREA |.data|, DATA, READWRITE
var DCD 15
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

toggle_led PROC
    mov r0, #ID_STATUS_LED
    bl DIO_ToggleLogical 
    ldr r2, =(25000000/2)                 ; Increased delay for 100 MHz
    bl delay_loop 
    b loop
    ENDP
    
; main PROC
;     push{r3,lr}
;     bl PLLInit
;     bl GPIO_Init_All
;     bl Keys_init 
;     bl Stepper_Init
;     bl Stepper_Enable           ; Enable the stepper motor driver
; loop 
  
;     BL Decode_Keypad            ; Decode the ADC value, ASCII character returned in r0

;     CMP r0, #'1'                ; Check if key '1' is pressed
;     BEQ move_up
    
;     CMP r0, #'2'                ; Check if key '2' is pressed
;     BEQ move_down
    
;     ; If neither '1' nor '2' is pressed, stop the motor
;     MOV r0, #0                  ; 0 Hz = Stop
;     BL Stepper_SetSpeed
;     B loop

; move_up
;     MOV r0, #0                  ; Set Direction 0 (Upward/Clockwise)
;     BL Stepper_SetDirection
;     LDR r0, =5000                ; Low speed (500 steps/sec)
;     BL Stepper_SetSpeed
;     B loop
    
; move_down
;     MOV r0, #1                  ; Set Direction 1 (Downward/Counter-Clockwise)
;     BL Stepper_SetDirection
;     LDR r0, =5000                ; Low speed (500 steps/sec)
;     BL Stepper_SetSpeed
;     B loop
main PROC
                
    bl PLLInit                   ; Initialize PLL to set system clock to 100 MHz
    bl GPIO_Init_All             ; Initialize GPIO pins based on PinConfigTable
    bl TOF_Init                  ; Initialize TOF400F laser ranging module
    bl SysTick_Init              ; Initialize SysTick for delay functions
    bl Keys_init                   ; Initialize ADC for keypad reading
    ;bl Stepper_Init              ; Initialize Timer 3 for stepper control
    ;bl Stepper_Enable            ; Enable the stepper motor driver
loop
    bl TOF_Read_Distance         ; Read distance from TOF sensor, result in r0
    ; --- THE FIX: Pace the Modbus Polling ---
    mov r5, r0                  ; Move distance reading to r1 for potential use
    bl Keys_init                   ; Re-initialize ADC to get a fresh reading for the keypad
    bl Decode_Keypad              ; Decode the ADC value, ASCII character returned in r0

    
    b loop
	ALIGN
    END
