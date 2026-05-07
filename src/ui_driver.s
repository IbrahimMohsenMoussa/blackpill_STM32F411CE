; ====================================================================
; UI Driver - Elevator State Machine
; Bare-Metal ARM Cortex-M4 Assembly (Thumb-2)
; ====================================================================

    AREA |.data|, DATA, READWRITE, ALIGN=2

UI_CurrentFloor SPACE 1
UI_TargetFloor  SPACE 1
UI_SystemState  SPACE 1
Target_String   SPACE 2

; ====================================================================

    AREA |.rodata|, DATA, READONLY, ALIGN=2

str_locked      DCB "LOCKED", 0
str_scancard    DCB "SCAN CARD", 0
str_authorized  DCB "AUTHORIZED", 0
str_selectflr   DCB "SELECT FLR", 0
str_moving      DCB "MOVING", 0
str_target      DCB "TARGET: ", 0

    ALIGN

; ====================================================================

    AREA |.text|, CODE, READONLY, ALIGN=2
    THUMB

    IMPORT OLED_ClearBuffer
    IMPORT OLED_SetCursor
    IMPORT OLED_PrintStr
    IMPORT OLED_DrawBitmap
    IMPORT OLED_UpdateScreen
    IMPORT RTC_GetTimeString
    IMPORT RTC_GetDateString
    IMPORT RTC_GetDayString
    IMPORT bmp_digit_0
    IMPORT bmp_digit_1
    IMPORT bmp_digit_2
    IMPORT bmp_arrow_up
    IMPORT bmp_arrow_down

    EXPORT UI_Init
    EXPORT UI_SetCurrentFloor
    EXPORT UI_SetTargetFloor
    EXPORT UI_SetSystemState
    EXPORT UI_Update
    EXPORT UI_TargetFloor
    EXPORT UI_CurrentFloor

; --------------------------------------------------------------------
; UI_Init
; Initializes all UI variables to 0 (IDLE State, Floor 0)
; --------------------------------------------------------------------
UI_Init PROC
    push    {r4-r11, lr}
    
    mov     r0, #0
    ldr     r4, =UI_CurrentFloor
    strb    r0, [r4]
    ldr     r4, =UI_TargetFloor
    strb    r0, [r4]
    ldr     r4, =UI_SystemState
    strb    r0, [r4]
    
    pop     {r4-r11, pc}
    ENDP

; --------------------------------------------------------------------
; UI_SetCurrentFloor (Input R0)
; --------------------------------------------------------------------
UI_SetCurrentFloor PROC
    push    {r4-r11, lr}
    ldr     r4, =UI_CurrentFloor
    strb    r0, [r4]
    pop     {r4-r11, pc}
    ENDP

; --------------------------------------------------------------------
; UI_SetTargetFloor (Input R0)
; --------------------------------------------------------------------
UI_SetTargetFloor PROC
    push    {r4-r11, lr}
    ldr     r4, =UI_TargetFloor
    strb    r0, [r4]
    pop     {r4-r11, pc}
    ENDP

; --------------------------------------------------------------------
; UI_SetSystemState (Input R0)
; 0 = IDLE, 1 = AUTH, 2 = MOVING
; --------------------------------------------------------------------
UI_SetSystemState PROC
    push    {r4-r11, lr}
    ldr     r4, =UI_SystemState
    strb    r0, [r4]
    pop     {r4-r11, pc}
    ENDP

; --------------------------------------------------------------------
; UI_DrawLeftPane (Internal Routine)
; Renders Current Floor Digit and Directional Arrows (if MOVING)
; --------------------------------------------------------------------
UI_DrawLeftPane PROC
    push    {r4-r11, lr}
    
    ; Draw current floor digit
    ldr     r4, =UI_CurrentFloor
    ldrb    r0, [r4]
    
    cmp     r0, #0
    beq     draw_digit_0
    cmp     r0, #1
    beq     draw_digit_1
    cmp     r0, #2
    beq     draw_digit_2
    b       check_moving

draw_digit_0
    ldr     r4, =bmp_digit_0
    b       do_draw_digit
draw_digit_1
    ldr     r4, =bmp_digit_1
    b       do_draw_digit
draw_digit_2
    ldr     r4, =bmp_digit_2
    
do_draw_digit
    mov     r0, #8              ; X = 8
    mov     r1, #1              ; Y Page = 1
    mov     r2, #32             ; Width = 32
    mov     r3, #6              ; Height = 6
    push    {r4}                ; Stack Arg 5 = ROM Pointer
    bl      OLED_DrawBitmap
    add     sp, sp, #4          ; Clean up stack arg

check_moving
    ldr     r4, =UI_SystemState
    ldrb    r0, [r4]
    cmp     r0, #2              ; 2 = MOVING
    bne     left_pane_end
    
    ldr     r4, =UI_CurrentFloor
    ldrb    r1, [r4]
    ldr     r4, =UI_TargetFloor
    ldrb    r2, [r4]
    
    cmp     r2, r1
    bhi     draw_arrow_up       ; Target > Current
    blo     draw_arrow_down     ; Target < Current
    b       left_pane_end

draw_arrow_up
    ldr     r4, =bmp_arrow_up
    b       do_draw_arrow
draw_arrow_down
    ldr     r4, =bmp_arrow_down
    
do_draw_arrow
    mov     r0, #44             ; FIXED: X = 44 (Fits safely between 40 and 64)
    mov     r1, #2              ; Y Page = 2 (Centers it vertically)
    mov     r2, #16             ; FIXED: Width = 16 pixels
    mov     r3, #4              ; Height = 4 pages (32 pixels)
    push    {r4}                ; Stack Arg 5 = ROM Pointer
    bl      OLED_DrawBitmap
    add     sp, sp, #4          ; Clean up stack arg

left_pane_end
    pop     {r4-r11, pc}
    ENDP
; --------------------------------------------------------------------
; UI_DrawRightPane (Internal Routine)
; Renders Date/Time and State Context textual information
; --------------------------------------------------------------------
UI_DrawRightPane PROC
    push    {r4-r11, lr}
    
    ; Draw Time
    mov     r0, #64
    mov     r1, #0
    bl      OLED_SetCursor
    bl      RTC_GetTimeString
    bl      OLED_PrintStr
    
    ; Draw Date
    mov     r0, #64
    mov     r1, #2
    bl      OLED_SetCursor
    bl      RTC_GetDateString
    bl      OLED_PrintStr
    
    ; ---> NEW: Draw Day of the Week <---
    mov     r0, #64             ; X = 64 (Align with right pane text)
    mov     r1, #3             ; Y = Page 4 (Safely between Date and Status)
    bl      OLED_SetCursor
    bl      RTC_GetDayString    ; Fetch string pointer
    bl      OLED_PrintStr

    
    ; Check System State
    ldr     r4, =UI_SystemState
    ldrb    r0, [r4]
    
    cmp     r0, #0
    beq     draw_idle
    cmp     r0, #1
    beq     draw_auth
    cmp     r0, #2
    beq     draw_moving
    b       right_pane_end

draw_idle
    mov     r0, #64
    mov     r1, #5
    bl      OLED_SetCursor
    ldr     r0, =str_locked
    bl      OLED_PrintStr
    
    mov     r0, #64
    mov     r1, #7
    bl      OLED_SetCursor
    ldr     r0, =str_scancard
    bl      OLED_PrintStr
    b       right_pane_end

draw_auth
    mov     r0, #64
    mov     r1, #5
    bl      OLED_SetCursor
    ldr     r0, =str_authorized
    bl      OLED_PrintStr
    
    mov     r0, #64
    mov     r1, #7
    bl      OLED_SetCursor
    ldr     r0, =str_selectflr
    bl      OLED_PrintStr
    b       right_pane_end

draw_moving
    mov     r0, #64
    mov     r1, #5
    bl      OLED_SetCursor
    ldr     r0, =str_moving
    bl      OLED_PrintStr
    
    mov     r0, #64
    mov     r1, #7
    bl      OLED_SetCursor
    ldr     r0, =str_target
    bl      OLED_PrintStr
    
    ; Format Target Floor as string and print immediately
    ldr     r4, =UI_TargetFloor
    ldrb    r0, [r4]
    add     r0, r0, #0x30       ; Convert integer 0-9 to ASCII '0'-'9'
    
    ldr     r4, =Target_String
    strb    r0, [r4]            ; Store ASCII char
    mov     r0, #0x00
    strb    r0, [r4, #1]        ; Null-terminate
    
    ldr     r0, =Target_String
    bl      OLED_PrintStr

right_pane_end
    pop     {r4-r11, pc}
    ENDP

; --------------------------------------------------------------------
; UI_Update
; Master GUI render pipeline function. Redraws screen based on states.
; --------------------------------------------------------------------
UI_Update PROC
    push    {r4-r11, lr}
    
    bl      OLED_ClearBuffer
    bl      UI_DrawLeftPane
    bl      UI_DrawRightPane
    bl      OLED_UpdateScreen
    
    pop     {r4-r11, pc}
    ENDP

    ALIGN
    END
