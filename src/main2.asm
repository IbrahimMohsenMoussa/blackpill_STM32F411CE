; ====================================================================
; main.asm - SH1106 Display & RTC Integration Test
; Bare-Metal ARM Cortex-M4 Assembly (Thumb-2)
; ====================================================================

    INCLUDE stm32f411.inc

; --------------------------------------------------------------------
; External Dependencies
; --------------------------------------------------------------------
    IMPORT I2C1_Init
    IMPORT RTC_Init
    IMPORT OLED_Init
    IMPORT OLED_ClearBuffer
    IMPORT OLED_SetCursor
    IMPORT OLED_PrintStr
    IMPORT OLED_UpdateScreen
    IMPORT RTC_GetTimeString
    IMPORT RTC_GetDateString
    IMPORT PLLInit
    IMPORT GPIO_Init_All
    IMPORT TOF_Init
    IMPORT TOF_Read_Distance

; --------------------------------------------------------------------
; Read-Only Text Strings
; --------------------------------------------------------------------
    AREA |.rodata|, DATA, READONLY, ALIGN=2
str_title   DCB "SH1106 1.3 TEST", 0
str_time    DCB "TIME:", 0
str_date    DCB "DATE:", 0
str_ok      DCB "SYSTEM ONLINE", 0
str_mm      DCB "mm", 0
; --------------------------------------------------------------------
; RAM Allocations
; --------------------------------------------------------------------
    AREA |.data|, DATA, READWRITE, ALIGN=2
TOF_String  SPACE 16        ; Buffer to hold our generated string

; --------------------------------------------------------------------
; TOF_FormatDistance
; Converts an unsigned 32-bit integer in R0 to a decimal ASCII string.
; Returns: R0 = Pointer to the start of the valid string.
; --------------------------------------------------------------------
    AREA |.text|, CODE, READONLY, ALIGN=2
    THUMB
    EXPORT TOF_FormatDistance

TOF_FormatDistance PROC
    push    {r4-r7, lr}
    
    ; 1. Point to the very END of the 16-byte buffer
    ldr     r1, =TOF_String
    add     r1, r1, #15     
    
    ; 2. Insert the Null Terminator at the end
    mov     r2, #0x00
    strb    r2, [r1]        
    
    mov     r2, r0          ; R2 = The number to convert
    mov     r4, #10         ; R4 = Divisor (10)
    
convert_loop
    ; 3. Math: Quotient = N / 10, Remainder = N - (Quotient * 10)
    udiv    r5, r2, r4      ; R5 = Quotient
    mls     r6, r5, r4, r2  ; R6 = Remainder (Cortex-M4 Multiply & Subtract)
    
    ; 4. Convert remainder to ASCII and store it backwards
    add     r6, r6, #0x30   ; Add ASCII '0'
    sub     r1, r1, #1      ; Move pointer backward
    strb    r6, [r1]        ; Store the character
    
    ; 5. Check if we are done
    mov     r2, r5          ; Number = Quotient
    cmp     r2, #0
    bne     convert_loop    ; If Quotient isn't 0, keep dividing
    
    ; 6. Return the pointer to the first valid character
    mov     r0, r1          
    pop     {r4-r7, pc}
    ENDP
; --------------------------------------------------------------------
; Main Application Loop
; --------------------------------------------------------------------
    AREA |.text|, CODE, READONLY, ALIGN=2
    THUMB
    EXPORT main

main PROC
    ; 1. Initialize Hardware Subsystems
       ldr     r5, =10000000
delay_poweron
    subs    r5, r5, #1
    bne     delay_poweron

    bl      PLLInit             ; Initialize PLL to restore system clock
    bl      GPIO_Init_All       ; Initialize GPIO pins
    bl      I2C1_Init           ; Boot the I2C1 Bus
    bl      RTC_Init            ; Boot the RTC (Checks coin cell / sets default)
    bl      OLED_Init           ; Send SH1106 Boot Sequence
    bl      TOF_Init            ; Initialize the Time-of-Flight Sensor

main_loop
    ; ... inside your main loop ...
    bl      OLED_ClearBuffer     ; Clear the display buffer for fresh drawing           ; Replace this with 'bl TOF_Read_Distance' later
    bl      TOF_Read_Distance           ; Read distance from the TOF sensor, result in R0
    ; 2. Convert the integer to an ASCII string
    bl      TOF_FormatDistance  ; Returns pointer to string in R0
    mov     r4, r0              ; Save the string pointer safely in R4
    
    ; 3. Print the Distance Value on Page 5
    mov     r0, #64             ; X = 64 (Start of the right pane)
    mov     r1, #5              ; Y = Page 5
    bl      OLED_SetCursor
    mov     r0, r4              ; Restore string pointer
    bl      OLED_PrintStr
    
    ; 4. Print the " mm" unit suffix
    ; (OLED_PrintStr automatically advances Cursor_X, so we just print right after it)
    ldr     r0, =str_mm         ; Load pointer to " mm"
    bl      OLED_PrintStr
    
    ; 5. Blast to the screen
    bl      OLED_UpdateScreen

    ; ... rest of your delay and loop ...
    ldr     r5, =100
delay_loop
    subs    r5, r5, #1
    bne     delay_loop

    ; 9. Repeat indefinitely
    b       main_loop
    ENDP

    ALIGN
    END