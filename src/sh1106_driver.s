; ====================================================================
; SH1106 OLED Driver (Bare-Metal ARM Cortex-M4 Assembly)
; Resolution: 128x64 | I2C Address: 0x78
; ====================================================================
    INCLUDE font.inc


    AREA |.data|, DATA, READWRITE, ALIGN=2

OLED_Buffer SPACE 1024          ; 1024-byte SRAM Shadow Buffer
Cursor_X    SPACE 1             ; Global Cursor X (0-127)
Cursor_Y    SPACE 1             ; Global Cursor Y/Page (0-7)

; ====================================================================

    AREA |.text|, CODE, READONLY, ALIGN=2
    THUMB

    EXPORT SH1106_WriteCmd
    EXPORT OLED_Init
    EXPORT OLED_ClearBuffer
    EXPORT OLED_UpdateScreen
    EXPORT OLED_SetCursor
    EXPORT OLED_PutChar
    EXPORT OLED_PrintStr
    EXPORT OLED_DrawBitmap

    IMPORT I2C1_Start
    IMPORT I2C1_Write
    IMPORT I2C1_Stop
    

; --------------------------------------------------------------------
; SH1106_WriteCmd
; Sends a single command byte to the SH1106
; Input: R0 = Command
; --------------------------------------------------------------------
SH1106_WriteCmd PROC
    push    {r4-r11, lr}
    mov     r4, r0              ; Save command byte safely

    mov     r0, #0x78           ; I2C Address (0x78) + Write bit (0)
    bl      I2C1_Start
    cmp     r0, #1              ; Check for error
    beq     cmd_error

    mov     r0, #0x00           ; Co=0, D/C#=0 (Command stream)
    bl      I2C1_Write
    cmp     r0, #1
    beq     cmd_error

    mov     r0, r4              ; The actual command
    bl      I2C1_Write
    cmp     r0, #1
    beq     cmd_error

cmd_exit
    bl      I2C1_Stop
    pop     {r4-r11, pc}

cmd_error
    bl      I2C1_Stop
    pop     {r4-r11, pc}
    ENDP

; --------------------------------------------------------------------
; OLED_Init
; Sends the SH1106 initialization sequence
; --------------------------------------------------------------------
OLED_Init_Cmds
    DCB 0xAE, 0xA8, 0x3F, 0xD3, 0x00, 0x40, 0xA1, 0xC8
    DCB 0xDA, 0x12, 0x81, 0xCF, 0xAD, 0x8B, 0xA4, 0xA6, 0xAF
    ALIGN

OLED_Init PROC
    push    {r4-r11, lr}
    ldr     r4, =OLED_Init_Cmds
    mov     r5, #17             ; 17 initialization commands
init_loop
    ldrb    r0, [r4], #1        ; Load command, increment pointer
    bl      SH1106_WriteCmd
    subs    r5, r5, #1
    bne     init_loop
    pop     {r4-r11, pc}
    ENDP

; --------------------------------------------------------------------
; OLED_ClearBuffer
; Fills the 1024-byte SRAM buffer with 0x00
; --------------------------------------------------------------------
OLED_ClearBuffer PROC
    push    {r4-r11, lr}
    ldr     r4, =OLED_Buffer
    mov     r5, #1024
    mov     r6, #0x00
clear_loop
    strb    r6, [r4], #1
    subs    r5, r5, #1
    bne     clear_loop
    pop     {r4-r11, pc}
    ENDP

; --------------------------------------------------------------------
; OLED_UpdateScreen
; Writes the SRAM buffer to the SH1106 using Page Addressing Mode
; --------------------------------------------------------------------
OLED_UpdateScreen PROC
    push    {r4-r11, lr}
    mov     r4, #0              ; r4 = Current Page (0 to 7)
    ldr     r5, =OLED_Buffer    ; r5 = Pointer to SRAM buffer

update_page_loop
    ; Set Page Address (0xB0 + Page)
    orr     r0, r4, #0xB0
    bl      SH1106_WriteCmd

    ; Set Lower Column Address to 2 (0x02) - Mandatory for SH1106 offset
    mov     r0, #0x02
    bl      SH1106_WriteCmd

    ; Set Upper Column Address to 0 (0x10)
    mov     r0, #0x10
    bl      SH1106_WriteCmd

    ; Start I2C Data Stream
    mov     r0, #0x78           ; I2C Address + Write
    bl      I2C1_Start
    cmp     r0, #1
    beq     update_error

    mov     r0, #0x40           ; Co=0, D/C#=1 (Data stream)
    bl      I2C1_Write
    cmp     r0, #1
    beq     update_error

    mov     r6, #128            ; 128 columns per page
update_col_loop
    ldrb    r0, [r5], #1        ; Read sequentially from SRAM buffer
    bl      I2C1_Write
    cmp     r0, #1
    beq     update_error

    subs    r6, r6, #1
    bne     update_col_loop

    ; Stop I2C after each page is finished
    bl      I2C1_Stop

    add     r4, r4, #1
    cmp     r4, #8
    bne     update_page_loop

    pop     {r4-r11, pc}

update_error
    bl      I2C1_Stop
    pop     {r4-r11, pc}
    ENDP

; --------------------------------------------------------------------
; OLED_SetCursor
; Updates global coordinates for text rendering
; Input: R0 = X (0-127), R1 = Y Page (0-7)
; --------------------------------------------------------------------
OLED_SetCursor PROC
    push    {r4-r11, lr}
    ldr     r4, =Cursor_X
    strb    r0, [r4]
    ldr     r4, =Cursor_Y
    strb    r1, [r4]
    pop     {r4-r11, pc}
    ENDP

; --------------------------------------------------------------------
; OLED_PutChar
; Writes a 5x7 ASCII char to SRAM buffer + 1 spacing col, advances X
; Input: R0 = ASCII Char
; --------------------------------------------------------------------
OLED_PutChar PROC
    push    {r4-r11, lr}
    cmp     r0, #0x20
    blo     putchar_end         ; Ignore unprintable characters

    sub     r0, r0, #0x20       ; Zero-index the character
    mov     r1, #5
    mul     r4, r0, r1          ; r4 = Font array offset (char * 5)

    ldr     r5, =Font5x7
    add     r5, r5, r4          ; r5 = Pointer to target character data

    ldr     r4, =Cursor_X
    ldrb    r6, [r4]            ; r6 = Current X
    ldr     r4, =Cursor_Y
    ldrb    r7, [r4]            ; r7 = Current Y (Page)

    ; Calculate Buffer Addr: OLED_Buffer + X + (Y * 128)
    ldr     r4, =OLED_Buffer
    add     r4, r4, r6
    mov     r8, #128
    mul     r9, r7, r8
    add     r4, r4, r9          ; r4 = Buffer destination pointer

    mov     r8, #5              ; Font width is 5
putchar_loop
    ldrb    r0, [r5], #1        ; Read from Font ROM
    strb    r0, [r4], #1        ; Write to SRAM Buffer
    subs    r8, r8, #1
    bne     putchar_loop

    ; 6th pixel column (spacing)
    mov     r0, #0x00
    strb    r0, [r4]

    ; Advance Cursor_X by 6
    add     r6, r6, #6
    ldr     r4, =Cursor_X
    strb    r6, [r4]

putchar_end
    pop     {r4-r11, pc}
    ENDP

; --------------------------------------------------------------------
; OLED_PrintStr
; Prints a null-terminated string using PutChar
; Input: R0 = Pointer to string
; --------------------------------------------------------------------
OLED_PrintStr PROC
    push    {r4-r11, lr}
    mov     r4, r0              ; r4 = String pointer
printstr_loop
    ldrb    r0, [r4], #1
    cmp     r0, #0
    beq     printstr_end
    bl      OLED_PutChar
    b       printstr_loop
printstr_end
    pop     {r4-r11, pc}
    ENDP

; --------------------------------------------------------------------
; OLED_DrawBitmap
; Copies a ROM array directly into the SRAM buffer at X/Y
; Input: R0=X, R1=Y Page, R2=Width, R3=Height, Stack Arg 5=ROM Ptr
; --------------------------------------------------------------------
OLED_DrawBitmap PROC
    push    {r4-r11, lr}
    ; SP was modified by push. 9 regs * 4 bytes = 36 bytes.
    ; So the 5th argument is located at SP + 36.
    ldr     r4, [sp, #36]       ; r4 = Pointer to ROM Bitmap Array

    mov     r5, r0              ; r5 = Start X
    mov     r6, r1              ; r6 = Current Y Page
    mov     r7, r2              ; r7 = Width
    mov     r8, r3              ; r8 = Height (Pages remaining)

bitmap_page_loop
    cmp     r8, #0
    beq     bitmap_end

    ; Dest Address = OLED_Buffer + Start_X + (Current_Y * 128)
    ldr     r9, =OLED_Buffer
    add     r9, r9, r5
    mov     r10, #128
    mul     r11, r6, r10
    add     r9, r9, r11         ; r9 = Destination pointer in Buffer

    mov     r10, r7             ; r10 = Columns remaining for this page
bitmap_col_loop
    cmp     r10, #0
    beq     bitmap_col_end
    ldrb    r0, [r4], #1        ; Read byte from ROM
    strb    r0, [r9], #1        ; Write byte to SRAM
    subs    r10, r10, #1
    b       bitmap_col_loop

bitmap_col_end
    add     r6, r6, #1          ; Move to next Page/Y
    subs    r8, r8, #1          ; Decrement Height counter
    b       bitmap_page_loop

bitmap_end
    pop     {r4-r11, pc}
    ENDP

    ALIGN
    END