    INCLUDE stm32f411.inc
;==============================================================================
; Port Initialization Module for STM32F411 (Black Pill)
; This module provides a data Table driven approach to initialize GPIO pins based on a configuration table.
; The configuration table allows for easy addition of new pins without modifying the initialization logic.
; Each entry in the table is a 32-bit word encoding 
;@Author: Ibrahim Mohsen
;==============================================================================

; ============================================================================
; 1. DATA-DRIVEN PORT CONFIGURATION TABLE
; ============================================================================
; Configuration Word Format:
; Each setting gets 4 bits (1 Hex Digit).
; [31:28] Reserved
; [27:24] PIN:   Pin Number (0-15)
; [23:20] PORT:  Port Index (0=A, 1=B, 2=C...)
; [19:16] MODE:  0=In, 1=Out, 2=AF, 3=Analog
; [15:12] OTYPE: 0=PP, 1=OD
; [11:08] SPEED: 0=Low, 1=Med, 2=Fast, 3=High
; [07:04] PUPD:  0=No, 1=PU, 2=PD
; [03:00] AF:    Alternate Function (0-15)
    
    AREA |.rodata|, DATA, READONLY, ALIGN=2
    EXPORT PinConfigTable

PinConfigTable
    ; Example 1: PC13 (Onboard LED)
    ; Pin=D(13), Port=2(C), Mode=1(Out), OT=0, Spd=0, PUPD=0, AF=0
    ; Hex: 0x0 D 2 1 0 0 0 0
    DCD 0x0D210000
    ; Example 2: onboard button (PA0)
    ; Pin=A(0), Port=0(A), Mode=0(In), OT=0, Spd=0, PUPD=1, AF=0
    ; Hex: 0x0 0 0 0 0 0 1 0
    DCD 0x00000010

    ; End of Table Terminator (Sentinel)
    DCD 0xFFFFFFFF    

; ============================================================================
; 2. DRIVER PROCEDURES 
; ============================================================================
    
    AREA |.text|, CODE, READONLY
    THUMB
    EXPORT GPIO_Init_All
    EXPORT GPIO_Pin_Init
    IMPORT RCC_AHB1_Enable

; ----------------------------------------------------------------------------
; GPIO_Init_All
; Loops through PinConfigTable, extracts the Port bits to calculate the base 
; address, and passes the full config word to GPIO_Pin_Init.
; ----------------------------------------------------------------------------
GPIO_Init_All PROC
    push {r0-r4, lr} ; Save registers to protect the caller
    ldr r4, =PinConfigTable
table_loop
    ldr r0, [r4], #4        ; Load config word and increment pointer
    cmp r0, #0xFFFFFFFF     ; Check for sentinel (0xFFFFFFFF)
    beq table_done
    bl GPIO_Pin_Init        ; Initialize pin
    b table_loop
table_done
    pop {r0-r4, pc}
    ENDP

; ----------------------------------------------------------------------------
; GPIO_Pin_Init
;INPUT R0: Config Word 
; Unpacks the bitfield and applies masks to MODER, OTYPER, OSPEEDR, PUPDR, AFR.
; ----------------------------------------------------------------------------
;------------------------------ REGISTER USAGE -------------------------------
;r4 holds The configuration word 
;r1 holds Port index
;r5 holds GPIOx_BASE
;r6 holds Pin index
;------------------------------------------------------------------------------
GPIO_Pin_Init PROC
    push {r4-r8, lr}        ; Save registers to protect the caller 
    mov r4, r0              ; R4 = Config Word

    ; 1. Enable GPIO Clock (using RCC_AHB1_Enable from rcc.asm)
    ubfx r1, r4, #20, #4    ; Extract Port Index (Bits 23-20)
    mov r0, #1     
    lsl r0, r0, r1          ; R0 = 1 << PortIndex check stm32f411.inc for a better epxlaination of the register structure
    bl RCC_AHB1_Enable      ; Call RCC_AHB1_Enable from rcc.asm to Enable clock for the current GPIO port 
    ; this doesn't need to be called every time as its only needed once per port but to for ease its called every time a pin is intialized 

    ; 2. Calculate Port Base Address
    ubfx r1, r4, #20, #4    ; Extract Port Index again
    ldr r2, =GPIOA_BASE
    mov r3, #GPIO_PORT_OFFSET
    mla r5, r1, r3, r2      ; R5 = GPIOA_BASE + (PortIndex * 0x400)

    ; 3. Extract Pin Number
    ubfx r6, r4, #24, #4    ; R6 = Pin Number (Bits 27-24)

    ; 4. Configure MODER (2 bits per pin)
    ldr r2, [r5, #GPIO_MODER]
    mov r3, #0x3
    lsl r7, r6, #1          ; R7 = Pin * 2
    lsl r3, r3, r7          ; Mask = 0x3 << (Pin * 2)
    bic r2, r2, r3          ; Clear mode bits
    ubfx r1, r4, #16, #2    ; Extract Mode (Bits 19-16), Width=2
    lsl r7, r6, #1          ; R7 = Pin * 2
    lsl r1, r1, r7          ; Shift Mode to position
    orr r2, r2, r1
    str r2, [r5, #GPIO_MODER]

    ; 5. Configure OTYPER (1 bit per pin)
    ldr r2, [r5, #GPIO_OTYPER]
    mov r3, #0x1
    lsl r3, r3, r6          ; Mask = 0x1 << Pin
    bic r2, r2, r3
    ubfx r1, r4, #12, #1    ; Extract OType (Bits 15-12), Width=1
    lsl r1, r1, r6
    orr r2, r2, r1
    str r2, [r5, #GPIO_OTYPER]

    ; 6. Configure OSPEEDR (2 bits per pin)
    ldr r2, [r5, #GPIO_OSPEEDR]
    mov r3, #0x3
    lsl r7, r6, #1
    lsl r3, r3, r7
    bic r2, r2, r3
    ubfx r1, r4, #8, #2     ; Extract Speed (Bits 11-8), Width=2
    lsl r1, r1, r7
    orr r2, r2, r1
    str r2, [r5, #GPIO_OSPEEDR]

    ; 7. Configure PUPDR (2 bits per pin)
    ldr r2, [r5, #GPIO_PUPDR]
    mov r3, #0x3
    lsl r7, r6, #1
    lsl r3, r3, r7
    bic r2, r2, r3
    ubfx r1, r4, #4, #2     ; Extract PUPD (Bits 7-4), Width=2
    lsl r1, r1, r7
    orr r2, r2, r1
    str r2, [r5, #GPIO_PUPDR]

    ; 8. Configure AFR (4 bits per pin)
    ; Determine if AFRL (Pins 0-7) or AFRH (Pins 8-15)
    cmp r6, #8
    ite lt                  ; if - then - else 
    movlt r7, #GPIO_AFRL    ; Offset 0x20
    movge r7, #GPIO_AFRH    ; Offset 0x24
    
    and r8, r6, #0x7        ; Pin % 8 (Index within register)
    lsl r8, r8, #2          ; Shift amount = (Pin % 8) * 4

    ldr r2, [r5, r7]        ; Load AFR register
    mov r3, #0xF
    lsl r3, r3, r8          ; Mask = 0xF << Shift
    bic r2, r2, r3
    ubfx r1, r4, #0, #4     ; Extract AF (Bits 3-0), Width=4
    lsl r1, r1, r8 
    orr r2, r2, r1
    str r2, [r5, r7]

    pop {r4-r8, pc}
    ENDP

	ALIGN
    END
