; ====================================================================
; RTC Bare-Metal Driver for STM32F411
; @Description: Initializes LSE and VBAT RTC, provides Time/Date strings
; Bare-Metal ARM Cortex-M4 Assembly (Thumb-2)
; ====================================================================

    INCLUDE stm32f411.inc

; --------------------------------------------------------------------
; External Dependencies
; --------------------------------------------------------------------
    IMPORT RCC_APB1_Enable

; --------------------------------------------------------------------
; Constants
; --------------------------------------------------------------------
DEFAULT_TIME    EQU 0x00051100  ; 05:11:00 in BCD (0x05 for 05 hours, 0x11 for 11 minutes, 0x00 for seconds)

; Corrected DEFAULT_DATE hex (0x002612704 is 36-bit and invalid). 
; Format: [23:16] Year, [15:13] WDU, [12:8] Month, [5:0] Day
; Year 25 (0x25), WDU 6 (0x6), Month 05 (0x05), Day 09 (0x09) => 0x0025C509
DEFAULT_DATE    EQU 0x0025C509 ; 9th May 2025, WDU=6 (Saturday)

; --------------------------------------------------------------------
; RAM Allocations
; --------------------------------------------------------------------
    AREA |.data|, DATA, READWRITE, ALIGN=2

Time_String     SPACE 9         ; "HH:MM:SS\0"
Date_String     SPACE 9         ; "DD-MM-YY\0"

; --------------------------------------------------------------------
; Code Section
; --------------------------------------------------------------------
    AREA |.text|, CODE, READONLY, ALIGN=2
    THUMB
    EXPORT RTC_Init
    EXPORT RTC_GetTimeString
    EXPORT RTC_GetDateString

; --------------------------------------------------------------------
; RTC_Init
; Enables RTC, configures LSE, and checks BKP0R for power loss
; --------------------------------------------------------------------
; --------------------------------------------------------------------
; RTC_Init
; Enables RTC, configures LSE, bypasses shadows, and checks BKP0R
; --------------------------------------------------------------------
RTC_Init PROC
    push    {r4-r11, lr}
    
    ; 1. Enable PWR clock on APB1
    ldr     r0, =RCC_APB1_PWR
    bl      RCC_APB1_Enable
    
    ; 2. Set DBP bit in PWR_CR to disable backup domain write protection
    ldr     r4, =PWR_BASE
    ldr     r1, [r4, #PWR_CR]
    orr     r1, r1, #(1 :SHL: 8)    ; DBP is bit 8
    str     r1, [r4, #PWR_CR]
    
    ; 3. Enable LSE in RCC_BDCR and wait for LSERDY
    ldr     r4, =RCC_BASE
    ldr     r1, [r4, #RCC_BDCR]
    orr     r1, r1, #(1 :SHL: 0)    ; LSEON is bit 0
    str     r1, [r4, #RCC_BDCR]
wait_lse
    ldr     r1, [r4, #RCC_BDCR]
    tst     r1, #(1 :SHL: 1)        ; LSERDY is bit 1
    beq     wait_lse
    
    ; 4. Select LSE as RTC clock (RTCSEL = 01) and enable RTCEN
    ldr     r1, [r4, #RCC_BDCR]
    bic     r1, r1, #(3 :SHL: 8)    ; Clear RTCSEL bits (9:8)
    orr     r1, r1, #(1 :SHL: 8)    ; RTCSEL = 01 (LSE)
    orr     r1, r1, #(1 :SHL: 15)   ; RTCEN is bit 15
    str     r1, [r4, #RCC_BDCR]

    ; 5. Unlock RTC_WPR (Required to modify RTC_CR or set time)
    ldr     r4, =RTC_BASE
    mov     r1, #0xCA
    str     r1, [r4, #RTC_WPR]
    mov     r1, #0x53
    str     r1, [r4, #RTC_WPR]

    ; 6. Bypass Shadow Registers (MUST happen on every boot)
    ldr     r1, [r4, #0x08]         ; 0x08 is RTC_CR offset
    orr     r1, r1, #(1 :SHL: 5)    ; Set BYPSHAD (Bit 5)
    str     r1, [r4, #0x08]
    
    ; 7. The Smart Check: Read RTC_BKP0R
    ldr     r1, [r4, #RTC_BKP0R]
    ldr     r2, =0x32F2
    cmp     r1, r2
    beq     rtc_lock_and_exit       ; If 0x32F2, skip to lock and exit
    
    ; 8. The Fallback Setup (Battery dead or first boot)
    ; Set INIT bit (bit 7) in RTC_ISR, wait for INITF (bit 6)
    ldr     r1, [r4, #RTC_ISR]
    orr     r1, r1, #(1 :SHL: 7)
    str     r1, [r4, #RTC_ISR]
wait_initf
    ldr     r1, [r4, #RTC_ISR]
    tst     r1, #(1 :SHL: 6)
    beq     wait_initf
    
    ; Write Prescalers to RTC_PRER (Async=0x7F, Sync=0xFF)
    ldr     r1, =(0x7F :SHL: 16) :OR: (0xFF)
    str     r1, [r4, #RTC_PRER]
    
    ; Write DEFAULT_TIME and DEFAULT_DATE
    ldr     r1, =DEFAULT_TIME
    str     r1, [r4, #RTC_TR]
    ldr     r1, =DEFAULT_DATE
    str     r1, [r4, #RTC_DR]
    
    ; Clear INIT bit to start the calendar
    ldr     r1, [r4, #RTC_ISR]
    bic     r1, r1, #(1 :SHL: 7)
    str     r1, [r4, #RTC_ISR]
    
    ; Write 0x32F2 to RTC_BKP0R to mark calendar as initialized
    ldr     r1, =0x32F2
    str     r1, [r4, #RTC_BKP0R]
    
rtc_lock_and_exit
    ; Write 0xFF to RTC_WPR to re-lock registers
    mov     r1, #0xFF
    str     r1, [r4, #RTC_WPR]
    
    pop     {r4-r11, pc}
    ENDP
; --------------------------------------------------------------------
; RTC_GetTimeString
; Reads RTC_TR, unpacks BCD, formats into "HH:MM:SS", returns PTR in R0
; --------------------------------------------------------------------
RTC_GetTimeString PROC
    push    {r4-r7, lr}
    ldr     r4, =RTC_BASE
    ldr     r1, [r4, #RTC_TR]       ; Read Time Register
    ldr     r0, =Time_String        ; Output buffer
    
    ; Extract and convert BCD nibbles using UBFX, add 0x30 ('0') for ASCII
    ubfx    r2, r1, #20, #2         ; HH Tens
    add     r2, r2, #0x30
    strb    r2, [r0, #0]
    ubfx    r2, r1, #16, #4         ; HH Units
    add     r2, r2, #0x30
    strb    r2, [r0, #1]
    
    mov     r2, #':'
    strb    r2, [r0, #2]
    
    ubfx    r2, r1, #12, #3         ; MM Tens
    add     r2, r2, #0x30
    strb    r2, [r0, #3]
    ubfx    r2, r1, #8, #4          ; MM Units
    add     r2, r2, #0x30
    strb    r2, [r0, #4]
    
    mov     r2, #':'
    strb    r2, [r0, #5]
    
    ubfx    r2, r1, #4, #3          ; SS Tens
    add     r2, r2, #0x30
    strb    r2, [r0, #6]
    ubfx    r2, r1, #0, #4          ; SS Units
    add     r2, r2, #0x30
    strb    r2, [r0, #7]
    
    mov     r2, #0x00               ; Null Terminator
    strb    r2, [r0, #8]
    
    pop     {r4-r7, pc}             ; R0 already holds pointer
    ENDP

; --------------------------------------------------------------------
; RTC_GetDateString
; Reads RTC_DR, unpacks BCD, formats into "DD-MM-YY", returns PTR in R0
; --------------------------------------------------------------------
RTC_GetDateString PROC
    push    {r4-r7, lr}
    ldr     r4, =RTC_BASE
    ldr     r1, [r4, #RTC_DR]       ; Read Date Register
    ldr     r0, =Date_String        ; Output buffer
    
    ; Extract DD
    ubfx    r2, r1, #4, #2          ; DD Tens
    add     r2, r2, #0x30
    strb    r2, [r0, #0]
    ubfx    r2, r1, #0, #4          ; DD Units
    add     r2, r2, #0x30
    strb    r2, [r0, #1]
    
    mov     r2, #'-'
    strb    r2, [r0, #2]
    
    ; Extract MM
    ubfx    r2, r1, #12, #1         ; MM Tens
    add     r2, r2, #0x30
    strb    r2, [r0, #3]
    ubfx    r2, r1, #8, #4          ; MM Units
    add     r2, r2, #0x30
    strb    r2, [r0, #4]
    
    mov     r2, #'-'
    strb    r2, [r0, #5]
    
    ; Extract YY
    ubfx    r2, r1, #20, #4         ; YY Tens
    add     r2, r2, #0x30
    strb    r2, [r0, #6]
    ubfx    r2, r1, #16, #4         ; YY Units
    add     r2, r2, #0x30
    strb    r2, [r0, #7]
    
    mov     r2, #0x00               ; Null Terminator
    strb    r2, [r0, #8]
    
    pop     {r4-r7, pc}             ; R0 already holds pointer
    ENDP




; ====================================================================
; RTC Day of Week Lookup Table
; ====================================================================

    AREA |.rodata|, DATA, READONLY, ALIGN=2

; 1. Define the actual strings
str_err DCB "UNKNOWN", 0
str_mon DCB "MONDAY", 0
str_tue DCB "TUESDAY", 0
str_wed DCB "WEDNESDAY", 0
str_thu DCB "THURSDAY", 0
str_fri DCB "FRIDAY", 0
str_sat DCB "SATURDAY", 0
str_sun DCB "SUNDAY", 0

    ALIGN

; 2. Define the Pointer Array (DCD = Define Constant Doubleword / 32-bit)
; Index 0 is an error string, Indices 1-7 point to the actual days
Day_Pointer_Table
    DCD str_err     ; Index 0 (RTC Weekday is 1-7, 0 is invalid)
    DCD str_mon     ; Index 1
    DCD str_tue     ; Index 2
    DCD str_wed     ; Index 3
    DCD str_thu     ; Index 4
    DCD str_fri     ; Index 5
    DCD str_sat     ; Index 6
    DCD str_sun     ; Index 7

; ====================================================================
; RTC_GetDayString
; Reads the day number from the hardware, returns string pointer in R0
; ====================================================================
    AREA |.text|, CODE, READONLY, ALIGN=2
    THUMB
    EXPORT RTC_GetDayString
; ====================================================================
; RTC_GetDayString
; Reads the day number from the hardware, returns string pointer in R0
; ====================================================================
RTC_GetDayString PROC
    push    {r4-r5, lr}
    
    ; 1. Read the actual hardware RTC Date Register (RTC_DR)
    ldr     r4, =0x40002800     ; Load RTC Base Address
    ldr     r0, [r4, #0x04]     ; Load the 32-bit RTC_DR register into R0
    
    ; 2. Extract the Weekday (WDU) bits 15:13
    lsr     r0, r0, #13         ; Shift right 13 bits (moves WDU to the bottom)
    and     r0, r0, #0x07       ; Mask out everything except those bottom 3 bits
    
    ; 3. Safety Check: Ensure the day is between 1 and 7
    cmp     r0, #1
    blt     day_error
    cmp     r0, #7
    bgt     day_error
    b       lookup_string
    
day_error
    mov     r0, #0              ; Force to Index 0 (str_err) if hardware gives bad data

lookup_string
    ; 4. Fetch the string pointer from the table
    ldr     r1, =Day_Pointer_Table
    lsl     r0, r0, #2          ; Multiply index by 4 (bytes per pointer)
    ldr     r0, [r1, r0]        ; Load the 32-bit memory address into R0
    
    pop     {r4-r5, pc}         
    ENDP
    ALIGN
    END
