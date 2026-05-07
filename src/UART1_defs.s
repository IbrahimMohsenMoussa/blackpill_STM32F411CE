; =============================================================================
; UART1 Definitions for STM32F401CC
; =============================================================================

; --------------------------------------------------------------------
; UART Base Addresses (STM32F401CC specific)
; --------------------------------------------------------------------
UART1_BASE              EQU     0x40011000

; --------------------------------------------------------------------
; UART Register Offsets
; --------------------------------------------------------------------
UART1_SR                EQU     0x00    ; Status Register
UART1_DR                EQU     0x04    ; Data Register
UART1_BRR               EQU     0x08    ; Baud Rate Register
UART1_CR1               EQU     0x0C    ; Control Register 1
UART1_CR2               EQU     0x10    ; Control Register 2
UART1_CR3               EQU     0x14    ; Control Register 3

; --------------------------------------------------------------------
; CR1 Bit Positions
; --------------------------------------------------------------------
UE_BIT                  EQU     13      ; USART Enable
M_BIT                   EQU     12      ; Word Length (0=8-bit, 1=9-bit)
PCE_BIT                 EQU     10      ; Parity Control Enable
PS_BIT                  EQU     9       ; Parity Selection (0=Even, 1=Odd)
TE_BIT                  EQU     3       ; Transmitter Enable
RE_BIT                  EQU     2       ; Receiver Enable
OVER8_BIT               EQU     15      ; Oversampling Mode (0=16x, 1=8x)

; --------------------------------------------------------------------
; CR2 Bit Positions
; --------------------------------------------------------------------
STOP_BIT0               EQU     12      ; Stop Bit 0
STOP_BIT1               EQU     13      ; Stop Bit 1

; --------------------------------------------------------------------
; SR Bit Positions
; --------------------------------------------------------------------
TXE_BIT                 EQU     7       ; Transmit Data Register Empty
TC_BIT                  EQU     6       ; Transmission Complete
RXNE_BIT                EQU     5       ; Receive Data Register Not Empty

; --------------------------------------------------------------------
; Baud Rate Constants
; --------------------------------------------------------------------
KBPS1200                EQU     1200
KBPS2400                EQU     2400
KBPS9600                EQU     9600
KBPS19200               EQU     19200
KBPS38400               EQU     38400
KBPS57600               EQU     57600
KBPS115200              EQU     115200
KBPS230400              EQU     230400
KBPS460800              EQU     460800
KBPS921600              EQU     921600

; --------------------------------------------------------------------
; Oversampling Constants
; --------------------------------------------------------------------
SAMPLING_RATE8          EQU     1
SAMPLING_RATE16         EQU     0

; --------------------------------------------------------------------
; Pre-configured UART Parameters
; --------------------------------------------------------------------
; Default configuration for DF Player Mini:
PRE_CONF_BAUD_RATE      EQU     KBPS9600    ; 9600 baud for DF Player
	
	END