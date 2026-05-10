;==============================================================================
; Port Initialization Module for STM32F411 (Black Pill)
; This module provides a data Table driven approach to initialize GPIO pins based on a configuration table.
; The configuration table allows for easy addition of new pins without modifying the initialization logic.
; Each entry in the table is a 32-bit word encoding 
;@Author: Ibrahim Mohsen
;==============================================================================

    INCLUDE stm32f411.inc

; ============================================================================
; 1. DATA-DRIVEN PORT CONFIGURATION TABLE
; ============================================================================
; Configuration Word Format:
; Each setting gets 4 bits (1 Hex Digit).
; [31:28] FULL PORT if not = 0 
; [27:24] PIN:   Pin Number (0-15)
; [23:20] PORT:  Port Index (0=A, 1=B, 2=C...)
; [19:16] MODE:  0=In, 1=Out, 2=AF, 3=Analog
; [15:12] OTYPE: 0=PP, 1=OD
; [11:08] SPEED: 0=Low, 1=Med, 2=Fast, 3=High
; [07:04] PUPD:  0=No, 1=PU, 2=PD
; [03:00] AF:    Alternate Function (0-15)

    AREA    |.text|, CODE, READONLY, ALIGN=2
    THUMB
    EXPORT  PinConfigTable
    EXPORT  GPIO_Init_All
    EXPORT  GPIO_Pin_Init
    IMPORT  RCC_AHB1_Enable

PinConfigTable
    
    ; Example 1: PC13 (Onboard LED)
    ; Pin=D(13), Port=2(C), Mode=1(Out), OT=0, Spd=0, PUPD=0, AF=0
    ; Hex: 0x0 D 2 1 0 0 0 0
    DCD     0x0D210000
    ; Example 2: onboard button (PA0)
    ; Pin=A(0), Port=0(A), Mode=0(In), OT=0, Spd=0, PUPD=1, AF=0
    ; Hex: 0x0 0 0 0 0 0 1 0
    DCD     0x00000010
    ; I2C1 SCL (PB6) - Pin=6, Port=1(B), Mode=2(AF), OT=1(OD), Spd=2, PUPD=1(PU), AF=4
    DCD     0x06121214
    ; I2C1 SDA (PB7) - Pin=7, Port=1(B), Mode=2(AF), OT=1(OD), Spd=2, PUPD=1(PU), AF=4
    DCD     0x07121214
    ; PB0 - Pin=0, Port=1(B), Mode=3(Analog), OT=0, Spd=0, PUPD=0, AF=0
    ; Hex: 0x0 0 1 3 0 0 0 0
    DCD     0x00130000
    ; PB1 - Pin=1, Port=1(B), Mode=3(Analog), OT=0, Spd=0, PUPD=0, AF=0
    ; Hex: 0x0 1 1 3 0 0 0 0
    DCD     0x01130000
    ; PB4 - Pin=4, Port=1(B), Mode=2(AF), OT=0, Spd=2, PUPD=0, AF=2 (TIM3_CH1)
    ; Hex: 0x0 4 1 2 0 2 0 2
    DCD     0x04120202
    ; PB3 - Pin=3, Port=1(B), Mode=1(Out), OT=0, Spd=0, PUPD=0, AF=0 (Motor Enable)
    ; Hex: 0x0 3 1 1 0 0 0 0
    DCD     0x03110000
    ; PA15 - Pin=F(15), Port=0(A), Mode=1(Out), OT=0, Spd=0, PUPD=0, AF=0 (Motor DIR)
    ; Hex: 0x0 F 0 1 0 0 0 0
    ; PA11 - Pin=B(11), Port=0(A), Mode=2(AF), OT=0, Spd=3(High), PUPD=0, AF=8 (USART6_TX)
    ; Hex: 0x0 B 0 2 0 3 0 8
    DCD     0x0B020308
    ; PA12 - Pin=C(12), Port=0(A), Mode=2(AF), OT=0, Spd=3(High), PUPD=0, AF=8 (USART6_RX)
    ; Hex: 0x0 C 0 2 0 3 0 8
    DCD     0x0C020308
    
    ; PA9 - Pin=9, Port=0(A), Mode=2(AF), OT=0(PP), Spd=3(High), PUPD=0(None), AF=7 (USART1_TX)
    DCD     0x09020307


    DCD     0x0F010000
    
    ; PB2 - Pin=2, Port=1(B), Mode=1(Out), OT=0, Spd=0, PUPD=0, AF=0
    ; Hex: 0x0 2 1 1 0 0 0 0
    DCD     0x02110000
    ; PA8 - Pin=8, Port=0(A), Mode=1(Out), OT=0, Spd=0, PUPD=0, AF=0
    ; Hex: 0x0 8 0 1 0 0 0 0
    DCD     0x08010000
    ; PB13 - Pin=D(13), Port=1(B), Mode=1(Out), OT=0, Spd=0, PUPD=0, AF=0
    ; Hex: 0x0 D 1 1 0 0 0 0
    DCD     0x0D110000

    ; PB8 - Pin=8, Port=1(B), Mode=0(In), OT=0, Spd=0, PUPD=0, AF=0 supply on divider 
    ; Hex: 0x0 8 1 0 0 0 0 0
    DCD     0x08100000

    ; PA0 - Floor 1 Servo -> TIM2_CH1 (Pin=0, Port=A, Mode=AF, OType=PP, Speed=Fast, PUPD=None, AF=1)
    DCD     0x00020201
    ; PA1 - Floor 2 Servo -> TIM2_CH2 (Pin=1, Port=A, Mode=AF, OType=PP, Speed=Fast, PUPD=None, AF=1)
    DCD     0x01020201
    ; PA2 - Floor 0 Servo -> TIM2_CH3 (Pin=2, Port=A, Mode=AF, OType=PP, Speed=Fast, PUPD=None, AF=1)
    DCD     0x02020201

    ; PA3 - Load Cell SCK (Pin=3, Port=0(A), Mode=1(Out), OT=0(PP), Spd=2(Fast), PUPD=0(None), AF=0)
    ; Hex: 0x0 3 0 1 0 2 0 0
    DCD     0x03010200

    ; PC13 - Load Cell DT (Pin=D(13), Port=2(C), Mode=0(In), OT=0(PP), Spd=0(Low), PUPD=1(PU), AF=0)
    ; Hex: 0x0 D 2 0 0 0 1 0
    DCD     0x0D200010

    ; PB9 - Mechanical Brake Servo -> TIM4_CH4 (Pin=9, Port=1(B), Mode=2(AF), OType=0(PP), Speed=2(Fast), PUPD=0, AF=2)
    ; Hex: 0x0 9 1 2 0 2 0 2
    DCD     0x09120202

    ; SPI1 & External Hardware Control Pins
    DCD     0x05020205    ; PA5 (SPI1 SCK) -> AF5, Push-Pull, Fast
    DCD     0x06020215    ; PA6 (SPI1 MISO) -> AF5, Push-Pull, Fast, Pull-up
    DCD     0x07020205    ; PA7 (SPI1 MOSI) -> AF5, Push-Pull, Fast
    DCD     0x0C110200    ; PB12 (SPI CS) -> Out, Push-Pull, Fast
    DCD     0x0A110200    ; PB10 (SPI RST) -> Out, Push-Pull, Fast

    ; End of Table Terminator (Sentinel)
    DCD     0xFFFFFFFF    


; ============================================================================
; 2. DRIVER PROCEDURES 
; ============================================================================

; ----------------------------------------------------------------------------
; GPIO_Init_All
; Loops through PinConfigTable, extracts the Port bits to calculate the base 
; address, and passes the full config word to GPIO_Pin_Init.
; ----------------------------------------------------------------------------
GPIO_Init_All PROC
    push    {r4, lr}
    ldr     r4, =PinConfigTable
table_loop
    ldr     r0, [r4], #4        ; Load config word and increment pointer
    cmp     r0, #0xFFFFFFFF     ; Check for sentinel (0xFFFFFFFF)
    beq     table_done
    bl      GPIO_Pin_Init       ; Initialize pin
    b       table_loop
table_done
    pop     {r4, pc}
    ENDP

; ----------------------------------------------------------------------------
; GPIO_Pin_Init
; INPUT R0: Config Word 
; Unpacks the bitfield and applies masks to MODER, OTYPER, OSPEEDR, PUPDR, AFR.
; ----------------------------------------------------------------------------
;------------------------------ REGISTER USAGE -------------------------------
; r4 holds The configuration word 
; r1 holds Port index
; r5 holds GPIOx_BASE
; r6 holds Pin index
;------------------------------------------------------------------------------
GPIO_Pin_Init PROC
    push    {r4-r8, lr}        ; Save registers to protect the caller 
    mov     r4, r0             ; R4 = Config Word

    ; 1. Enable GPIO Clock (using RCC_AHB1_Enable from rcc.asm)
    ubfx    r1, r4, #20, #4    ; Extract Port Index (Bits 23-20)
    mov     r0, #1     
    lsl     r0, r0, r1         ; R0 = 1 << PortIndex check stm32f411.inc for a better epxlaination of the register structure
    bl      RCC_AHB1_Enable    ; Call RCC_AHB1_Enable from rcc.asm to Enable clock for the current GPIO port 
    ; this doesn't need to be called every time as its only needed once per port but to for ease its called every time a pin is intialized 

    ; 2. Calculate Port Base Address
    ubfx    r1, r4, #20, #4    ; Extract Port Index again
    ldr     r2, =GPIOA_BASE
    mov     r3, #GPIO_PORT_OFFSET
    mla     r5, r1, r3, r2     ; R5 = GPIOA_BASE + (PortIndex * 0x400)
    
    ubfx    r6, r4, #28, #4    ; Extract Pin Number
    cmp     r6, #0
    beq     pinInit
    bne     portInit
    
pinInit
    ; 3. Extract Pin Number
    ubfx    r6, r4, #24, #4    ; R6 = Pin Number (Bits 27-24)

    ; 4. Configure MODER (2 bits per pin)
    ldr     r2, [r5, #GPIO_MODER]
    mov     r3, #0x3
    lsl     r7, r6, #1         ; R7 = Pin * 2
    lsl     r3, r3, r7         ; Mask = 0x3 << (Pin * 2)
    bic     r2, r2, r3         ; Clear mode bits
    ubfx    r1, r4, #16, #2    ; Extract Mode (Bits 19-16), Width=2
    lsl     r7, r6, #1         ; R7 = Pin * 2
    lsl     r1, r1, r7         ; Shift Mode to position
    orr     r2, r2, r1
    str     r2, [r5, #GPIO_MODER]

    ; 5. Configure OTYPER (1 bit per pin)
    ldr     r2, [r5, #GPIO_OTYPER]
    mov     r3, #0x1
    lsl     r3, r3, r6         ; Mask = 0x1 << Pin
    bic     r2, r2, r3
    ubfx    r1, r4, #12, #1    ; Extract OType (Bits 15-12), Width=1
    lsl     r1, r1, r6
    orr     r2, r2, r1
    str     r2, [r5, #GPIO_OTYPER]

    ; 6. Configure OSPEEDR (2 bits per pin)
    ldr     r2, [r5, #GPIO_OSPEEDR]
    mov     r3, #0x3
    lsl     r7, r6, #1
    lsl     r3, r3, r7
    bic     r2, r2, r3
    ubfx    r1, r4, #8, #2     ; Extract Speed (Bits 11-8), Width=2
    lsl     r1, r1, r7
    orr     r2, r2, r1
    str     r2, [r5, #GPIO_OSPEEDR]

    ; 7. Configure PUPDR (2 bits per pin)
    ldr     r2, [r5, #GPIO_PUPDR]
    mov     r3, #0x3
    lsl     r7, r6, #1
    lsl     r3, r3, r7
    bic     r2, r2, r3
    ubfx    r1, r4, #4, #2     ; Extract PUPD (Bits 7-4), Width=2
    lsl     r1, r1, r7
    orr     r2, r2, r1
    str     r2, [r5, #GPIO_PUPDR]

    ; 8. Configure AFR (4 bits per pin)
    ; Determine if AFRL (Pins 0-7) or AFRH (Pins 8-15)
    cmp     r6, #8
    ite     lt                 ; if - then - else 
    movlt   r7, #GPIO_AFRL     ; Offset 0x20
    movge   r7, #GPIO_AFRH     ; Offset 0x24
    
    and     r8, r6, #0x7       ; Pin % 8 (Index within register)
    lsl     r8, r8, #2         ; Shift amount = (Pin % 8) * 4

    ldr     r2, [r5, r7]    
    mov     r3, #0xF
    lsl     r3, r3, r8         ; Mask = 0xF << Shift
    bic     r2, r2, r3
    ubfx    r1, r4, #0, #4     ; Extract AF (Bits 3-0), Width=4
    lsl     r1, r1, r8 
    orr     r2, r2, r1
    str     r2, [r5, r7]
    b       end_pin_init

portInit
    ; Configure all 16 pins of the port with the same settings
    ; 1. MODER: 2 bits per pin * 16 pins = 32 bits. 
    ; We create a 32-bit pattern by repeating the 2-bit mode.
    ubfx    r1, r4, #16, #2    ; Extract Mode
    mov     r2, r1
    orr     r2, r2, r2, lsl #2 ; 2 bits -> 4 bits first 2 bit 0b11 becomes 0b1111
    orr     r2, r2, r2, lsl #4 ; 4 bits -> 8 bits
    orr     r2, r2, r2, lsl #8 ; 8 bits -> 16 bits
    orr     r2, r2, r2, lsl #16; 16 bits -> 32 bits
    str     r2, [r5, #GPIO_MODER]

    ; 2. OTYPER: 1 bit per pin. Repeat 1-bit OType 16 times.
    ubfx    r1, r4, #12, #1    ; Extract OType
    mov     r2, r1
    orr     r2, r2, r2, lsl #1 ; 1 bit -> 2 bits
    orr     r2, r2, r2, lsl #2 ; 2 bits -> 4 bits
    orr     r2, r2, r2, lsl #4 ; 4 bits -> 8 bits
    orr     r2, r2, r2, lsl #8 ; 8 bits -> 16 bits
    str     r2, [r5, #GPIO_OTYPER]

    ; 3. OSPEEDR: 2 bits per pin.
    ubfx    r1, r4, #8, #2     ; Extract Speed
    mov     r2, r1
    orr     r2, r2, r2, lsl #2
    orr     r2, r2, r2, lsl #4
    orr     r2, r2, r2, lsl #8
    orr     r2, r2, r2, lsl #16
    str     r2, [r5, #GPIO_OSPEEDR]

    ; 4. PUPDR: 2 bits per pin.
    ubfx    r1, r4, #4, #2     ; Extract PUPD
    mov     r2, r1
    orr     r2, r2, r2, lsl #2
    orr     r2, r2, r2, lsl #4
    orr     r2, r2, r2, lsl #8
    orr     r2, r2, r2, lsl #16
    str     r2, [r5, #GPIO_PUPDR]

end_pin_init
    pop     {r4-r8, pc}
    ENDP

    END
