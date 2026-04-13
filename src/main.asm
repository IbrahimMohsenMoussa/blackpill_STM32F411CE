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
    
main PROC
    push{r3,lr}
    bl PLLInit
    bl GPIO_Init_All
    ldr r0,=var
    ldr r7 , [r0]

loop
    mov r0,#ID_BUTTON
    bl DIO_ReadLogical
    mov r1, r0
    mov r0, #ID_STATUS_LED
    cmp r1, #0
    beq toggle_led
    

    b loop
    pop{r3,pc}
    ENDP

	ALIGN
    END
