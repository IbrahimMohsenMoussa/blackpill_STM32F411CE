    INCLUDE stm32f411.inc
;==============================================================================
; rcc.asm - RCC (Reset and Clock Control) initialization for STM32F411
; This file contains functions to initialize the PLL to set the system clock to 100MHz using a 25MHz external crystal (HSE)
; It also includes functions to enable clocks for various peripherals on AHB1, AHB2, APB1, and APB2 buses.
;@Author: Ibrahim Mohsen
;==============================================================================

PLL_M      EQU (25 << 0)   ; M=25 (25MHz / 25 = 1MHz) @Bit 0-5
PLL_N      EQU (200 << 6)  ; N=200 (1MHz * 200 = 200MHz) @Bit 6-14
PLL_P      EQU (0 << 16)   ; P=2 (200MHz / 2 = 100MHz) @Bit 16-17 (00 = /2)
PLL_SRC    EQU (1 << 22)   ; HSE Source @Bit 22
PLL_Q      EQU (4 << 24)   ; Q=4 (200MHz / 4 = 50MHz) @Bit 24-27
RCC_PLLCFGR_VALUE EQU (PLL_M | PLL_N | PLL_P | PLL_SRC | PLL_Q) ; Combined PLL configuration value
; APB1_PRESCALER EQU (0x4 << 10)    ; PPRE1 = /2 (50MHz max for APB1) commented byt spider man
; APB2_PRESCALER EQU (0x0 << 13)    ; PPRE2 = /1 (100MHz max for APB2) commented byt spider man
VOS_SCALE1   EQU (3 << 14) ; VOS = 0b11 for Scale 1 (required for 100MHz)
FLASH_ACR_VALUE EQU 0x0703 ; 3 Wait States + Prefetch Enable + Instruction Cache Enable + Data Cache Enable

    AREA |.text|, CODE, READONLY
    THUMB
    EXPORT PLLInit
    EXPORT RCC_AHB1_Enable
    EXPORT RCC_AHB2_Enable
    EXPORT RCC_APB1_Enable
    EXPORT RCC_APB2_Enable

; -----------------------------------------------------------------------------
; Function: PLLInit
; Description: Initializes the PLL to set system clock to 100MHz using 25MHz HSE
; -----------------------------------------------------------------------------
PLLInit PROC
    push {r0-r3, lr}            ; Save registers that will be used protect caller
    ; 1. Enable HSE (External Crystal)
    ldr r0, =RCC_BASE 
    ldr r1, [r0, #RCC_CR]       ; Load RCC_CR
    orr r1, r1, #HSEON          ; Set HSEON bit
    str r1, [r0, #RCC_CR]

wait_hse
    ldr r1, [r0, #RCC_CR]
    tst r1, #HSERDY             ; Check HSERDY bit
    beq wait_hse

    ; 2. Enable Power Controller Clock
    ldr r1, [r0, #RCC_APB1ENR]  ; RCC_APB1ENR
    orr r1, r1, #PWREN          ; PWREN = 1
    str r1, [r0, #RCC_APB1ENR]

    ; 3. Set Voltage Scale 1 (Required for 100MHz)
    ldr r2, =PWR_BASE
    ldr r1, [r2, #PWR_CR]       ; PWR_CR
    bic r1, r1, #VOS_SCALE1     ; Clear VOS bits
    orr r1, r1, #VOS_SCALE1     ; VOS = 0b11
    str r1, [r2, #PWR_CR]

    ; 4. Configure Flash Latency (3 Wait States)
    ldr r2, =FLASH_BASE
    ldr r1, [r2, #FLASH_ACR]    ; FLASH_ACR
    movw r3, #FLASH_ACR_VALUE   ; 3 WS + Prefetch/Cache Enable
    str r3, [r2, #FLASH_ACR]

    ; 5. Configure PLL: M=25, N=200, P=2, Source=HSE
    ; (25MHz / 25) * 200 / 2 = 100MHz
    ldr r1, =RCC_PLLCFGR_VALUE
    str r1, [r0, #RCC_PLLCFGR]  ; RCC_PLLCFGR

    ; 6. Enable PLL
    ldr r1, [r0, #RCC_CR]
    orr r1, r1, #PLLON          ; PLLON = 1
    str r1, [r0, #RCC_CR]

wait_pll
    ldr r1, [r0, #RCC_CR]
    tst r1, #PLLRDY             ; Check PLLRDY bit
    beq wait_pll

    ; 7. Set Bus Prescalers (APB1 must be <= 50MHz)
    ldr r1, [r0, #RCC_CFGR]     ; RCC_CFGR
    orr r1, r1, #(APB1_PRESCALER :OR: APB2_PRESCALER)    ; PPRE1 = /2 (50MHz), PPRE2 = /1 (100MHz)
    str r1, [r0, #RCC_CFGR]

    ; 8. Switch System Clock to PLL
    ldr r1, [r0, #RCC_CFGR]
    bic r1, r1, #0x3            ; Clear SW bits @Bits 1-0
    orr r1, r1, #0x2            ; SW = 0b10 (PLL)
    str r1, [r0, #RCC_CFGR]

wait_switch
    ldr r1, [r0, #RCC_CFGR]
    and r1, r1, #0xC            ; Mask SWS bits
    cmp r1, #0x8                ; 0x8 means PLL is source (0b10 << 2) 
    bne wait_switch
    pop {r0-r3, pc}             ; Restore registers and return
    ENDP

; -----------------------------------------------------------------------------
; Function: RCC_AHB1_Enable
; Description: Enables clock for AHB1 peripherals (GPIO, DMA, CRC)
; Input: R0 = Bitmask of peripherals to enable (e.g., RCC_AHB1_GPIOC)
; -----------------------------------------------------------------------------
RCC_AHB1_Enable PROC
    push {r0-r3, lr}            ; Save R0-R3 and LR protect caller
    ldr r1, =RCC_BASE
    ldr r2, [r1, #RCC_AHB1ENR]
    orr r2, r2, r0              ; Set bits passed in R0
    str r2, [r1, #RCC_AHB1ENR]
    pop {r0-r3, pc}             ; Restore registers and return
    ENDP

; -----------------------------------------------------------------------------
; Function: RCC_AHB2_Enable
; Description: Enables clock for AHB2 peripherals (USB OTG FS)
; Input: R0 = Bitmask of peripherals to enable (RCC_AHB2_OTGFS)
; -----------------------------------------------------------------------------
RCC_AHB2_Enable PROC
    push {r0-r3, lr}            ; Save R0-R3 and LR protect caller
    ldr r1, =RCC_BASE
    ldr r2, [r1, #RCC_AHB2ENR]
    orr r2, r2, r0              ; Set bits passed in R0
    str r2, [r1, #RCC_AHB2ENR]
    pop {r0-r3, pc}             ; Restore registers and return
    ENDP

; -----------------------------------------------------------------------------
; Function: RCC_APB1_Enable
; Description: Enables clock for APB1 peripherals (TIM2-5, USART2, I2C, SPI2/3)
; Input: R0 = Bitmask of peripherals to enable
; -----------------------------------------------------------------------------
RCC_APB1_Enable PROC
    push {r0-r3, lr}            ; Save R0-R3 and LR protect caller
    ldr r1, =RCC_BASE
    ldr r2, [r1, #RCC_APB1ENR]
    orr r2, r2, r0
    str r2, [r1, #RCC_APB1ENR]
    pop {r0-r3, pc}             ; Restore registers and return
    ENDP

; -----------------------------------------------------------------------------
; Function: RCC_APB2_Enable
; Description: Enables clock for APB2 peripherals (TIM1, ADC1, SPI1, USART1/6)
; Input: R0 = Bitmask of peripherals to enable
; -----------------------------------------------------------------------------
RCC_APB2_Enable PROC
    push {r0-r3, lr}            ; Save R0-R3 and LR protect caller
    ldr r1, =RCC_BASE
    ldr r2, [r1, #RCC_APB2ENR]
    orr r2, r2, r0
    str r2, [r1, #RCC_APB2ENR]
    pop {r0-r3, pc}             ; Restore registers and return
    ENDP

	ALIGN
    END
