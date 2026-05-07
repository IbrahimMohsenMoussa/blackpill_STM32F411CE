;==============================================================================
; EXTI Driver Module for STM32F411
; @Description: Generic, dynamic initialization of External Interrupts (EXTI).
;==============================================================================

    AREA |.text|, CODE, READONLY, ALIGN=2
    THUMB
    EXPORT EXTI_Pin_Init
    IMPORT RCC_APB2_Enable

; ----------------------------------------------------------------------------
; EXTI_Pin_Init
; Configures SYSCFG, EXTI, and NVIC for a given GPIO pin dynamically.
;
; Parameters (AAPCS):
;   R0: Port Index (0 = Port A, 1 = Port B, 2 = Port C, etc.)
;   R1: Pin Number (0 to 15)
;   R2: Trigger Edge (0 = Falling, 1 = Rising, 2 = Both)
; ----------------------------------------------------------------------------
EXTI_Pin_Init PROC
    PUSH    {R4-R7, LR}         ; Protect caller's registers

    ; ========================================================================
    ; 1. Enable SYSCFG Clock in RCC
    ; ========================================================================
    PUSH    {R0-R2}             ; Save input parameters (Port, Pin, Edge)
    MOV     R0, #(1 << 14)      ; Set Bit 14 to enable SYSCFG clock
    BL      RCC_APB2_Enable     ; Call the shared RCC driver
    POP     {R0-R2}             ; Restore input parameters

    ; ========================================================================
    ; 2. SYSCFG_EXTICR Configuration (Dynamic Routing)
    ; ========================================================================
    LDR     R3, =0x40013800     ; SYSCFG_BASE
    
    ; Calculate the target EXTICR register offset: 0x08 + ((R1 / 4) * 4)
    ; BIC with #3 acts as an integer divide-by-4 followed by multiply-by-4 
    ; by simply dropping the remainder (the lowest 2 bits).
    BIC     R4, R1, #3          ; R4 = (R1 / 4) * 4
    ADD     R4, R4, #0x08       ; R4 = 0x08 base offset for EXTICR1
    
    ; Calculate the bit shift within the target register: (R1 % 4) * 4
    AND     R5, R1, #3          ; R5 = R1 MOD 4 (keeps only the lowest 2 bits)
    LSL     R5, R5, #2          ; R5 = (R1 MOD 4) * 4 (shift amount)
    
    ; Apply port mapping to EXTICRx
    LDR     R6, [R3, R4]        ; Read current SYSCFG_EXTICR register value
    MOV     R7, #0xF            ; Create a 4-bit mask for the targeted slot
    LSL     R7, R7, R5          ; Shift mask to the correct pin position
    BIC     R6, R6, R7          ; Clear existing port mapping in this slot
    
    MOV     R7, R0              ; Copy requested Port Index
    LSL     R7, R7, R5          ; Shift Port Index into the correct slot
    ORR     R6, R6, R7          ; OR the updated slot into the register
    STR     R6, [R3, R4]        ; Write back to SYSCFG_EXTICR

    ; ========================================================================
    ; 3. EXTI Line Configuration
    ; ========================================================================
    LDR     R3, =0x40013C00     ; EXTI_BASE
    MOV     R4, #1
    LSL     R4, R4, R1          ; R4 = EXTI Line Mask
    
    ; Unmask the interrupt line
    LDR     R5, [R3, #0x00]     ; EXTI_IMR
    ORR     R5, R5, R4
    STR     R5, [R3, #0x00]
    
    ; --- The Bulletproof Edge Configuration ---
    
    ; 1. Assume both are OFF initially by clearing both registers
    LDR     R5, [R3, #0x08]     ; EXTI_RTSR
    BIC     R5, R5, R4          ; Clear rising bit
    STR     R5, [R3, #0x08]
    
    LDR     R5, [R3, #0x0C]     ; EXTI_FTSR
    BIC     R5, R5, R4          ; Clear falling bit
    STR     R5, [R3, #0x0C]
    
    ; 2. Apply requested edge
    CMP     R2, #1
    BEQ     set_rising
    CMP     R2, #2
    BEQ     set_both

set_falling
    LDR     R5, [R3, #0x0C]     ; EXTI_FTSR
    ORR     R5, R5, R4
    STR     R5, [R3, #0x0C]
    B       exti_done

set_both
    LDR     R5, [R3, #0x0C]     ; EXTI_FTSR
    ORR     R5, R5, R4
    STR     R5, [R3, #0x0C]
    ; Fall through to set rising as well
    
set_rising
    LDR     R5, [R3, #0x08]     ; EXTI_RTSR
    ORR     R5, R5, R4
    STR     R5, [R3, #0x08]

exti_done

    ; ========================================================================
    ; 4. NVIC Dynamic Configuration
    ; ========================================================================
    ; Determine correct IRQ number based on Pin Number (R1)
    CMP     R1, #4
    BLE     nvic_irq_low        ; If R1 <= 4
    CMP     R1, #9
    BLE     nvic_irq_mid        ; If 5 <= R1 <= 9
    
    MOV     R4, #40             ; Else 10 <= R1 <= 15: IRQ = 40 (EXTI15_10)
    B       nvic_enable
nvic_irq_low
    ADD     R4, R1, #6          ; IRQ = R1 + 6 (EXTI0=6, EXTI1=7, etc.)
    B       nvic_enable
nvic_irq_mid
    MOV     R4, #23             ; IRQ = 23 (EXTI9_5)

nvic_enable
    LSR     R5, R4, #5          ; R5 = IRQ / 32
    LSL     R5, R5, #2          ; R5 = (IRQ / 32) * 4 (Calculate NVIC_ISER offset)
    AND     R6, R4, #31         ; R6 = IRQ MOD 32
    MOV     R7, #1
    LSL     R7, R7, R6          ; R7 = 1 << (IRQ MOD 32) (Calculate ISER bit position)
    
    LDR     R3, =0xE000E100     ; NVIC_ISER Base
    STR     R7, [R3, R5]        ; Write-1-to-set enables the interrupt directly

    POP     {R4-R7, PC}         ; Restore registers and return
    ENDP

    END
