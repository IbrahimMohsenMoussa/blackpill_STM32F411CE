    INCLUDE stm32f411.inc

    AREA |.rodata|, DATA, READONLY, ALIGN=2
    EXPORT DIO_Hardware_Map

DIO_Hardware_Map
    ; Index 0: ID_STATUS_LED (Mapped to PC13 on the Black Pill)
    DCD GPIOC_BASE, 13
    DCD GPIOA_BASE, 0 ; Index 1: ID_BUTTON (Mapped to PA0 on the Black Pill)
    DCD GPIOB_BASE, 3 ; Index 2: ID_MOTOR_ENABLE (Mapped to PB3)
    DCD GPIOA_BASE, 15 ; Index 3: ID_MOTOR_DIR (Mapped to PA15)
    DCD GPIOA_BASE, 8 ; Index 4: LED_F0
    DCD GPIOB_BASE, 2 ; Index 5: LED_F1
    DCD GPIOB_BASE, 13 ; Index 6: LED_F2
    

    AREA |.text|, CODE, READONLY
    THUMB
    EXPORT DIO_WritePin
    EXPORT DIO_ReadPin
    EXPORT DIO_TogglePin
    EXPORT DIO_WriteLogical
    EXPORT DIO_ReadLogical
    EXPORT DIO_ToggleLogical
    EXPORT DIO_WritePort
    EXPORT DIO_ReadPort

; ============================================================================
; void DIO_WritePin(uint32_t port_base, uint32_t pin, uint32_t state)
; Input: r0 = Port Base Address (e.g., 0x40020000 for GPIOA)
; Input: r1 = Pin Number (0-15)
; Input: r2 = State (0 for LOW, 1 for HIGH)
; ============================================================================
DIO_WritePin PROC
    cmp r2, #0                  ; Check if the requested state is 0
    beq set_low                 ; If state == 0, branch to set_low

set_high
    ; To drive a pin HIGH, we write a '1' to the lower 16 bits of BSRR.
    ; Logic: BSRR = (1 << pin)
    mov r3, #1
    lsl r3, r3, r1              ; Shift '1' left by the pin number
    str r3, [r0, #GPIO_BSRR]    ; Fire the atomic write
    bx lr                       ; Return

set_low
    ; To drive a pin LOW, we write a '1' to the upper 16 bits of BSRR.
    ; Logic: BSRR = (1 << (pin + 16))
    mov r3, #1
    add r1, r1, #16             ; Add 16 to target the "Reset" half of the register
    lsl r3, r3, r1              ; Shift '1' left by the new offset
    str r3, [r0, #GPIO_BSRR]    ; Fire the atomic write
    bx lr                       ; Return
    ENDP

; ============================================================================
; uint32_t DIO_ReadPin(uint32_t port_base, uint32_t pin)
; Input: r0 = Port Base Address
; Input: r1 = Pin Number (0-15)
; Output: r0 = State (Returns 0 or 1)
; ============================================================================
DIO_ReadPin PROC
    ldr r2, [r0, #GPIO_IDR]     ; Read the full 32-bit Input Data Register
    
    ; Logic Design hook: Slide the target pin down to bit 0, 
    ; then pass it through an AND gate with '1' to mask off all other pins.
    lsr r2, r2, r1              ; Slide the register right by 'pin' spaces
    and r0, r2, #1              ; r0 = r2 & 1 (Masking)
    
    bx lr                       ; Return (AAPCS expects the return value in r0)
    ENDP

; ============================================================================
; void DIO_TogglePin(uint32_t port_base, uint32_t pin)
; Input: r0 = Port Base Address
; Input: r1 = Pin Number (0-15)
; ============================================================================
DIO_TogglePin PROC
    mov r2, #1
    lsl r2, r2, r1              ; r2 = (1 << pin) (This is our mask)

    ; Logic Design hook: Toggling a bit is mathematically an Exclusive OR (XOR).
    ; If you XOR a bit with 1, it flips. If you XOR with 0, it stays the same.
    ldr r3, [r0, #GPIO_ODR]     ; Read the current output state from ODR
    eor r3, r3, r2              ; r3 = r3 ^ r2 (XOR gate flips our specific pin)
    str r3, [r0, #GPIO_ODR]     ; Write the flipped state back to ODR
    
    bx lr                       ; Return
    ENDP

; ============================================================================
; void DIO_WriteLogical(uint32_t logical_id, uint32_t state)
; Input: r0 = Logical ID (e.g., 0, 1, 2)
; Input: r1 = State (0 for LOW, 1 for HIGH)
; ============================================================================
DIO_WriteLogical PROC
    ; We need to pass arguments to the core driver: r0=Port, r1=Pin, r2=State.
    ; Currently, r1 holds the State. Let's move it to r2 safely.
    mov r2, r1                  ; r2 = State

    ; 1. Calculate the table offset: Offset = ID * 8 bytes
    ; Shifting left by 3 is mathematically multiplying by 8.
    lsl r0, r0, #3              ; r0 = r0 * 8

    ; 2. Load the base address of our lookup table
    ldr r3, =DIO_Hardware_Map   

    ; 3. Add the offset to the table's base address
    add r3, r3, r0              ; r3 now points directly to the correct table row

    ; 4. Fetch the Physical Hardware Data
    ldr r0, [r3, #0]            ; Load Word 1 (Port Base Address) into r0
    ldr r1, [r3, #4]            ; Load Word 2 (Pin Number) into r1

    ; 5. Execute the Hardware Write
    ; At this exact moment: r0=Port, r1=Pin, r2=State.
    ; These perfectly match the arguments expected by our core DIO_WritePin!
    
    b DIO_WritePin              ; Branch to the hardware driver (Tail Call)
                                ; DIO_WritePin will 'bx lr' directly to main! 
    ENDP

; ============================================================================
; uint32_t DIO_ReadLogical(uint32_t logical_id)
; Input: r0 = Logical ID
; Output: r0 = State (0 or 1)
; ============================================================================
DIO_ReadLogical PROC
    ; 1. Calculate table offset (ID * 8)
    lsl r0, r0, #3
    
    ; 2. Load table base
    ldr r3, =DIO_Hardware_Map
    add r3, r3, r0
    
    ; 3. Fetch Port and Pin
    ldr r0, [r3, #0]            ; r0 = Port Base
    ldr r1, [r3, #4]            ; r1 = Pin Number
    
    ; 4. Tail call to ReadPin
    b DIO_ReadPin
    ENDP

; ============================================================================
; void DIO_ToggleLogical(uint32_t logical_id)
; Input: r0 = Logical ID (e.g., 0, 1, 2)
; ============================================================================
DIO_ToggleLogical PROC
    ; No state argument needed for toggle

    ; 1. Calculate the table offset: Offset = ID * 8 bytes
    ; Shifting left by 3 is mathematically multiplying by 8.
    lsl r0, r0, #3              ; r0 = r0 * 8

    ; 2. Load the base address of our lookup table
    ldr r3, =DIO_Hardware_Map   

    ; 3. Add the offset to the table's base address
    add r3, r3, r0              ; r3 now points directly to the correct table row

    ; 4. Fetch the Physical Hardware Data
    ldr r0, [r3, #0]            ; Load Word 1 (Port Base Address) into r0
    ldr r1, [r3, #4]            ; Load Word 2 (Pin Number) into r1

    ; 5. Execute the Hardware Write
    ; At this exact moment: r0=Port, r1=Pin, r2=State.
    ; These perfectly match the arguments expected by our core DIO_WritePin!
    
    b DIO_TogglePin             ; Branch to the hardware driver (Tail Call)
                                ; DIO_TogglePin will 'bx lr' directly to main!
    ENDP
; ============================================================================
; Input: r0 = Port Base Address (e.g., 0x40020000 for GPIOA)
; Input: r1 = 16 Bit value to be written to the port (Each bit corresponds to a pin)
; ============================================================================
DIO_WritePort PROC
    ; The upper 16 bits of ODR are reserved and should not be modified.
    strh r1, [r0, #GPIO_ODR]     ; Write the new port state to ODR
    bx lr      ; return from function
    ENDP
DIO_ReadPort PROC
    ldrh r0, [r0, #GPIO_IDR]     ; Read the 16-bit port state from IDR
    bx lr                       ; Return from function
    ENDP

	ALIGN    ; This fixes A1581W
    END
