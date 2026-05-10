; ==============================================================================
; mfrc522.inc
; Register macros for the MFRC522 RFID module.
; ==============================================================================

; --- Command and Status Registers ---
MFRC522_REG_COMMAND           EQU     0x01
MFRC522_REG_COMIEN            EQU     0x02
MFRC522_REG_DIVIEN            EQU     0x03
MFRC522_REG_COMIRQ            EQU     0x04
MFRC522_REG_DIVIRQ            EQU     0x05
MFRC522_REG_ERROR             EQU     0x06
MFRC522_REG_STATUS1           EQU     0x07
MFRC522_REG_STATUS2           EQU     0x08
MFRC522_REG_FIFODATA          EQU     0x09
MFRC522_REG_FIFOLEVEL         EQU     0x0A
MFRC522_REG_WATERLEVEL        EQU     0x0B
MFRC522_REG_CONTROL           EQU     0x0C
MFRC522_REG_BITFRAMING        EQU     0x0D
MFRC522_REG_COLL              EQU     0x0E

; --- Transmitter and Receiver Configuration ---
MFRC522_REG_MODE              EQU     0x11
MFRC522_REG_TXMODE            EQU     0x12
MFRC522_REG_RXMODE            EQU     0x13
MFRC522_REG_TXCONTROL         EQU     0x14
MFRC522_REG_TXASK             EQU     0x15
MFRC522_REG_TXSEL             EQU     0x16
MFRC522_REG_RXSEL             EQU     0x17
MFRC522_REG_RXTHRESHOLD       EQU     0x18
MFRC522_REG_DEMOD             EQU     0x19
MFRC522_REG_RFCFG             EQU     0x1A
MFRC522_REG_GSN               EQU     0x1B
MFRC522_REG_CWGSP             EQU     0x1C
MFRC522_REG_MODGSP            EQU     0x1D

; --- Timer Registers ---
MFRC522_REG_TMODE             EQU     0x2A
MFRC522_REG_TPRESCALER        EQU     0x2B
MFRC522_REG_TRELOAD_H         EQU     0x2C
MFRC522_REG_TRELOAD_L         EQU     0x2D
MFRC522_REG_TCOUNTER_H        EQU     0x2E
MFRC522_REG_TCOUNTER_L        EQU     0x2F

; --- Test Registers ---
MFRC522_REG_TESTSEL1          EQU     0x31
MFRC522_REG_TESTSEL2          EQU     0x32
MFRC522_REG_TESTPINEN         EQU     0x33
MFRC522_REG_TESTPINVALUE      EQU     0x34
MFRC522_REG_TESTBUS           EQU     0x35
MFRC522_REG_AUTOTEST          EQU     0x36
MFRC522_REG_VERSION           EQU     0x37
MFRC522_REG_ANALOGTEST        EQU     0x38
MFRC522_REG_TESTDAC1          EQU     0x39
MFRC522_REG_TESTDAC2          EQU     0x3A
MFRC522_REG_TESTADC           EQU     0x3B

; --- Standard Commands ---
MFRC522_CMD_IDLE              EQU     0x00
MFRC522_CMD_SOFTRESET         EQU     0x0F
