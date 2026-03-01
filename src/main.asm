; Assembly program for STM32F411 (Black Pill) to blink the onboard LED (PC13)
; Using CMSIS register definitions logic.

    INCLUDE stm32f411.inc
    INCLUDE hardware_config.inc
    
    AREA |.text|, CODE, READONLY
    THUMB
    EXPORT __main

    IMPORT DIO_ToggleLogical
    IMPORT DIO_ReadLogical
    IMPORT PLLInit
    IMPORT GPIO_Init_All

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

__main PROC
    bl PLLInit
    bl GPIO_Init_All
    
loop
    mov r0,#ID_BUTTON
    bl DIO_ReadLogical
    mov r1, r0
    mov r0, #ID_STATUS_LED
    cmp r1, #0
    beq toggle_led
    
    b loop
    ENDP

    END
