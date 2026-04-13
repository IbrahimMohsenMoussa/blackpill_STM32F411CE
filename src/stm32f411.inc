; STM32F411 Register Definitions
; This file defines the base addresses, register offsets, and bit definitions for the STM32F411 microcontroller.
;@author: Ibrahim Mohsen

; --- Peripheral Bases ---
RCC_BASE    EQU  0x40023800
FLASH_BASE  EQU  0x40023C00
PWR_BASE    EQU  0x40007000
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
RCC_APB2_TIM1   EQU (1 << 0)
RCC_APB2_USART1 EQU (1 << 4)
RCC_APB2_USART6 EQU (1 << 5)
RCC_APB2_ADC1   EQU (1 << 8)
RCC_APB2_SDIO   EQU (1 << 11)
RCC_APB2_SPI1   EQU (1 << 12)
RCC_APB2_SPI4   EQU (1 << 13)
RCC_APB2_SYSCFG EQU (1 << 14)
RCC_APB2_TIM9   EQU (1 << 16)
RCC_APB2_TIM10  EQU (1 << 17)
RCC_APB2_TIM11  EQU (1 << 18)
RCC_APB2_SPI5   EQU (1 << 20)

; --- Board Specific ---
LED_PIN      EQU 13
GPIO_PORT_OFFSET EQU 0x400
    END
