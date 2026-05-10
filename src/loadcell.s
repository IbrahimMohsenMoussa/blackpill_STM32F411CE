; ==============================================================================
; loadcell.s
; Bare-metal driver for HX711 Load Cell Amplifier
; ==============================================================================

    INCLUDE hardware_config.inc ; Brings in ID_LC_SCK and ID_LC_DT

    AREA |.bss|, DATA, READWRITE, ALIGN=2
LoadCell_Offset SPACE 4

    AREA |.text|, CODE, READONLY, ALIGN=2
    THUMB

    EXPORT LoadCell_Tare
    EXPORT LoadCell_CheckOverload

    IMPORT DIO_WriteLogical
    IMPORT DIO_ReadLogical

; --- Tuning Constants ---
WEIGHT_CAL_FACTOR EQU 1040       ; Adjust this to match your physical load cell calibration
MAX_WEIGHT_LIMIT  EQU 500      ; Maximum weight capacity limit before flagging overload

; ============================================================================
; int32_t LoadCell_ReadRaw(void)
; Outputs: r0 = 32-bit signed raw load cell reading
; ============================================================================
LoadCell_ReadRaw PROC
    push {r4-r5, lr}            ; AAPCS: Save scratch registers

    ; 1. SCK LOW to prepare HX711
    movs r0, #ID_LC_SCK
    movs r1, #0
    bl DIO_WriteLogical

wait_ready
    ; 2. Wait until DT == 0 (HX711 Ready)
    movs r0, #ID_LC_DT
    bl DIO_ReadLogical
    cmp r0, #0
    bne wait_ready

    ; 3. Setup shifting loop
    movs r4, #0                 ; r4 = Accumulator = 0
    movs r5, #24                ; r5 = 24 data bits to shift in

read_loop
    ; SCK HIGH
    movs r0, #ID_LC_SCK
    movs r1, #1
    bl DIO_WriteLogical

    ; Read DT
    movs r0, #ID_LC_DT
    bl DIO_ReadLogical

    ; Shift accumulator left by 1, OR with the read bit
    lsl r4, r4, #1
    orr r4, r4, r0

    ; SCK LOW
    movs r0, #ID_LC_SCK
    movs r1, #0
    bl DIO_WriteLogical

    subs r5, r5, #1             ; Decrement loop counter
    bne read_loop               ; Loop until 24 bits are read

    ; 4. 25th SCK Pulse (Configure HX711 for Channel A, Gain 128 for next read)
    movs r0, #ID_LC_SCK
    movs r1, #1
    bl DIO_WriteLogical
    movs r0, #ID_LC_SCK
    movs r1, #0
    bl DIO_WriteLogical

    ; 5. Sign-Extend 24-bit 2's complement into a 32-bit signed integer
    sbfx r0, r4, #0, #24        ; Extract 24 bits from r4, sign extend to 32 bits into r0

    pop {r4-r5, pc}             ; Restore registers and return
    ENDP

; ============================================================================
; void LoadCell_Tare(void)
; ============================================================================
LoadCell_Tare PROC
    push {r4-r5, lr}

    movs r4, #0                 ; r4 = Sum Accumulator
    movs r5, #8                 ; r5 = Take 8 samples

tare_loop
    bl LoadCell_ReadRaw         ; r0 = Raw signed reading
    add r4, r4, r0              ; Sum += r0
    subs r5, r5, #1
    bne tare_loop

    asr r4, r4, #3              ; Divide the sum by 8 (Arith. Shift Right by 3)
    ldr r5, =LoadCell_Offset
    str r4, [r5]                ; Save calculated offset into SRAM

    pop {r4-r5, pc}
    ENDP

; ============================================================================
; uint32_t LoadCell_CheckOverload(void)
; Output: r0 = 1 if (Weight > MAX_WEIGHT_LIMIT), else 0
; ============================================================================
LoadCell_CheckOverload PROC
    push {r4-r5, lr}

    ; 1. Read Raw Weight
    bl LoadCell_ReadRaw         ; r0 = Raw

    ; 2. Apply Tare Offset
    ldr r4, =LoadCell_Offset
    ldr r4, [r4]
    subs r0, r0, r4             ; r0 = Raw - Offset

    ; 3. Convert raw delta to physical units
    ldr r1, =WEIGHT_CAL_FACTOR
    sdiv r0, r0, r1             ; r0 = Real Weight

    ; Absolute value logic (if Weight < 0 -> Weight = -Weight)
    cmp r0, #0
    it lt
    rsblt r0, r0, #0

    ; 4. Check Overload limit
    ldr r1, =MAX_WEIGHT_LIMIT
    cmp r0, r1
    ite gt
    movgt r0, #1                ; Overload (Return 1)
    movle r0, #0                ; Safe (Return 0)

    pop {r4-r5, pc}
    ENDP

    END