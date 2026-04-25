; STM32F411 Register Definitions
; This file defines the base addresses, register offsets, and bit definitions for the STM32F411 microcontroller.
;@author: Ibrahim Mohsen

; --- Peripheral Bases ---
RCC_BASE    EQU  0x40023800
FLASH_BASE  EQU  0x40023C00
PWR_BASE    EQU  0x40007000
TIM3_BASE   EQU  0x40000400
TIM2_BASE   EQU  0x40000000
GPIOA_BASE  EQU  0x40020000
GPIOB_BASE  EQU  0x40020400
GPIOC_BASE  EQU  0x40020800

; --- RCC Register Offsets ---
RCC_CR       EQU 0x00
RCC_PLLCFGR  EQU 0x04
RCC_CFGR     EQU 0x08
RCC_AHB1ENR  EQU 0x30
RCC_AHB2ENR  EQU 0x34
RCC_APB1ENR  EQU 0x40
RCC_APB2ENR  EQU 0x44

; --- GPIO Register Offsets ---
GPIO_MODER   EQU 0x00
GPIO_OTYPER  EQU 0x04
GPIO_OSPEEDR EQU 0x08
GPIO_PUPDR   EQU 0x0C
GPIO_IDR     EQU 0x10
GPIO_ODR     EQU 0x14
GPIO_BSRR    EQU 0x18
GPIO_AFRL    EQU 0x20
GPIO_AFRH    EQU 0x24

; --- Flash Register Offsets ---
FLASH_ACR    EQU 0x00

; --- Power Register Offsets ---
PWR_CR       EQU 0x00

; --- Bit Definitions ---
HSEON        EQU (1 << 16)
HSERDY       EQU (1 << 17)
PLLON        EQU (1 << 24)
PLLRDY       EQU (1 << 25)
PWREN        EQU (1 << 28)

; --- Peripheral Clock Enable Bits ---
; AHB1 Peripherals
RCC_AHB1_GPIOA EQU (1 << 0)
RCC_AHB1_GPIOB EQU (1 << 1)
RCC_AHB1_GPIOC EQU (1 << 2)
RCC_AHB1_DMA1  EQU (1 << 21)
RCC_AHB1_DMA2  EQU (1 << 22)
; AHB2 Peripherals
RCC_AHB2_OTGFS EQU (1 << 7)
; APB1 Peripherals
RCC_APB1_TIM2   EQU (1 << 0)
RCC_APB1_TIM3   EQU (1 << 1)
RCC_APB1_TIM4   EQU (1 << 2)
RCC_APB1_TIM5   EQU (1 << 3)
RCC_APB1_SPI2   EQU (1 << 14)
RCC_APB1_SPI3   EQU (1 << 15)
RCC_APB1_USART2 EQU (1 << 17)
RCC_APB1_I2C1   EQU (1 << 21)
RCC_APB1_I2C2   EQU (1 << 22)
RCC_APB1_I2C3   EQU (1 << 23)
RCC_APB1_PWR    EQU (1 << 28)

; APB2 Peripherals
RCC_APB2_TIM1   EQU (1 :SHL: 0)
RCC_APB2_USART1 EQU (1 :SHL: 4)
RCC_APB2_USART6 EQU (1 :SHL: 5)
RCC_APB2_ADC1   EQU (1 :SHL: 8)
RCC_APB2_SDIO   EQU (1 :SHL: 11)
RCC_APB2_SPI1   EQU (1 :SHL: 12)
RCC_APB2_SPI4   EQU (1 :SHL: 13)
RCC_APB2_SYSCFG EQU (1 :SHL: 14)
RCC_APB2_TIM9   EQU (1 :SHL: 16)
RCC_APB2_TIM10  EQU (1 :SHL: 17)
RCC_APB2_TIM11  EQU (1 :SHL: 18)
RCC_APB2_SPI5   EQU (1 :SHL: 20)
;=========================================================
; This part was added by spider man
;=========================================================

;---------------------------------------------------------
; CPU CLOCK REFERENCE
;---------------------------------------------------------
F_CPU                   EQU     100000000        ; 100 MHz system clock
	
;---------------------------------------------------------
; AHB PRESCALER VALUES (bits [7:4] of RCC_CFGR)
;---------------------------------------------------------
AHB_DIV_1               EQU     0x0
AHB_DIV_2               EQU     0x8
AHB_DIV_4               EQU     0x9
AHB_DIV_8               EQU     0xA
AHB_DIV_16              EQU     0xB
AHB_DIV_64              EQU     0xC
AHB_DIV_128             EQU     0xD
AHB_DIV_256             EQU     0xE
AHB_DIV_512             EQU     0xF

;---------------------------------------------------------
; APB1 PRESCALER VALUES (bits [12:10] of RCC_CFGR)
;---------------------------------------------------------
APB1_DIV_1              EQU     0x0
APB1_DIV_2              EQU     0x4
APB1_DIV_4              EQU     0x5
APB1_DIV_8              EQU     0x6
APB1_DIV_16             EQU     0x7

;---------------------------------------------------------
; APB2 PRESCALER VALUES (bits [15:13] of RCC_CFGR)
;---------------------------------------------------------
APB2_DIV_1              EQU     0x0
APB2_DIV_2              EQU     0x4
APB2_DIV_4              EQU     0x5
APB2_DIV_8              EQU     0x6
APB2_DIV_16             EQU     0x7
	
;---------------------------------------------------------
; User configuration constants � modify these as needed
;---------------------------------------------------------
AHB_PRESCALER     	EQU     AHB_DIV_1      ; Choose from AHB_DIV_1 ... AHB_DIV_512
APB1_PRESCALER    	EQU     APB1_DIV_2     ; prescaler for APB1
APB2_PRESCALER    	EQU     APB2_DIV_1     ; prescaler for APB2

;=========================================================
; Derived frequency calculations
;=========================================================

;------------------ AHB Decode -------------------------
        IF (AHB_PRESCALER = AHB_DIV_1)
AHB_DIV_FACTOR          EQU     1
        ELIF (AHB_PRESCALER = AHB_DIV_2)
AHB_DIV_FACTOR          EQU     2
        ELIF (AHB_PRESCALER = AHB_DIV_4)
AHB_DIV_FACTOR          EQU     4
        ELIF (AHB_PRESCALER = AHB_DIV_8)
AHB_DIV_FACTOR          EQU     8
        ELIF (AHB_PRESCALER = AHB_DIV_16)
AHB_DIV_FACTOR          EQU     16
        ELIF (AHB_PRESCALER = AHB_DIV_64)
AHB_DIV_FACTOR          EQU     64
        ELIF (AHB_PRESCALER = AHB_DIV_128)
AHB_DIV_FACTOR          EQU     128
        ELIF (AHB_PRESCALER = AHB_DIV_256)
AHB_DIV_FACTOR          EQU     256
        ELIF (AHB_PRESCALER = AHB_DIV_512)
AHB_DIV_FACTOR          EQU     512
        ENDIF

;------------------ APB1 Decode -------------------------
        IF (APB1_PRESCALER = APB1_DIV_1)
APB1_DIV_FACTOR         EQU     1
        ELIF (APB1_PRESCALER = APB1_DIV_2)
APB1_DIV_FACTOR         EQU     2
        ELIF (APB1_PRESCALER = APB1_DIV_4)
APB1_DIV_FACTOR         EQU     4
        ELIF (APB1_PRESCALER = APB1_DIV_8)
APB1_DIV_FACTOR         EQU     8
        ELIF (APB1_PRESCALER = APB1_DIV_16)
APB1_DIV_FACTOR         EQU     16
        ENDIF

;------------------ APB2 Decode -------------------------
        IF (APB2_PRESCALER = APB2_DIV_1)
APB2_DIV_FACTOR         EQU     1
        ELIF (APB2_PRESCALER = APB2_DIV_2)
APB2_DIV_FACTOR         EQU     2
        ELIF (APB2_PRESCALER = APB2_DIV_4)
APB2_DIV_FACTOR         EQU     4
        ELIF (APB2_PRESCALER = APB2_DIV_8)
APB2_DIV_FACTOR         EQU     8
        ELIF (APB2_PRESCALER = APB2_DIV_16)
APB2_DIV_FACTOR         EQU     16
        ENDIF
	
;=========================================================
; Derived clock speeds for reference
;=========================================================

;--- Bus Frequencies ---
AHB_FREQ                EQU     (F_CPU / AHB_DIV_FACTOR)
APB1_FREQ               EQU     (AHB_FREQ / APB1_DIV_FACTOR)
APB2_FREQ               EQU     (AHB_FREQ / APB2_DIV_FACTOR)


;=========================================================
; ADC Register Definitions
;=========================================================

ADC1_BASE     EQU 0x40012000
ADC_SR        EQU 0x00
ADC_CR2       EQU 0x08
ADC_SQR3      EQU 0x34
ADC_DR        EQU 0x4C

;=========================================================
; TIM Register Definitions
;=========================================================
TIM_CR1       EQU 0x00
TIM_SR        EQU 0x10
TIM_EGR       EQU 0x14
TIM_CNT       EQU 0x24
TIM_PSC       EQU 0x28
TIM_ARR       EQU 0x2C
TIM_CCMR1     EQU 0x18
TIM_CCER      EQU 0x20
TIM_CCR1      EQU 0x34

; --- Board Specific ---
LED_PIN      EQU 13
GPIO_PORT_OFFSET EQU 0x400
    END
