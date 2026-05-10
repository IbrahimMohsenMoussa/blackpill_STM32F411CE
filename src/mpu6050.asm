; ----------------------------------------------------------------------------
; MPU6050 Driver
; STM32F411 + I2C1
; ----------------------------------------------------------------------------

	AREA |.text|, CODE, READONLY, ALIGN=2
	THUMB

	EXPORT MPU6050_Init
	EXPORT MPU6050_ReadAccelRaw

	IMPORT I2C1_Start
	IMPORT I2C1_Write
	IMPORT I2C1_StopTx
	IMPORT I2C1_StopRx
	IMPORT I2C1_ReadAck      ; TODO: implement this in i2c driver (Seif : DONE)
	IMPORT I2C1_ReadNack     ; TODO: implement this in i2c driver (Seif : DONE)

; ----------------------------------------------------------------------------
; MPU6050 I2C Address
; ----------------------------------------------------------------------------

MPU6050_ADDR_WRITE EQU 0xD0
MPU6050_ADDR_READ  EQU 0xD1

; ----------------------------------------------------------------------------
; MPU6050 Registers
; ----------------------------------------------------------------------------

PWR_MGMT_1     EQU 0x6B
ACCEL_CONFIG   EQU 0x1C
CONFIG_REG     EQU 0x1A
SMPLRT_DIV     EQU 0x19

ACCEL_XOUT_H   EQU 0x3B

; ----------------------------------------------------------------------------
; MPU6050_Init
;
; Step 1 : Wake sensor
; Step 2 : Configure accelerometer range
; Step 3 : Configure DLPF
; Step 4 : Configure sample rate
;
; Return:
;   R0 = 0 success
;   R0 = 1 failure
; ----------------------------------------------------------------------------
MPU6050_Init PROC
	push {r4-r7, lr}
	
	; Step 1 � Wake sensor
	; Write 0x00 to PWR_MGMT_1
	mov  r0, #MPU6050_ADDR_WRITE
	bl   I2C1_Start
	cmp  r0, #0
	bne  mpu_init_fail

	mov  r0, #PWR_MGMT_1
	bl   I2C1_Write
	cmp  r0, #0
	bne  mpu_init_fail_stop

	mov  r0, #0x00
	bl   I2C1_Write
	cmp  r0, #0
	bne  mpu_init_fail_stop

	bl   I2C1_StopTx        ; Use StopTx after Write

	; Step 2 � Configure accelerometer range
	; �2g => 0x00
	mov  r0, #MPU6050_ADDR_WRITE
	bl   I2C1_Start
	cmp  r0, #0
	bne  mpu_init_fail

	mov  r0, #ACCEL_CONFIG
	bl   I2C1_Write
	cmp  r0, #0
	bne  mpu_init_fail_stop

	mov  r0, #0x00
	bl   I2C1_Write
	cmp  r0, #0
	bne  mpu_init_fail_stop

	bl   I2C1_StopTx        ; Use StopTx after Write

	; Step 3 � Configure Digital Low Pass Filter
	; DLPF = 3
	mov  r0, #MPU6050_ADDR_WRITE
	bl   I2C1_Start
	cmp  r0, #0
	bne  mpu_init_fail

	mov  r0, #CONFIG_REG
	bl   I2C1_Write
	cmp  r0, #0
	bne  mpu_init_fail_stop

	mov  r0, #0x03
	bl   I2C1_Write
	cmp  r0, #0
	bne  mpu_init_fail_stop

	bl   I2C1_StopTx        ; Use StopTx after Write

	; Step 4 � Configure sample rate
	;
	; Sample Rate =
	; Gyro Output Rate / (1 + SMPLRT_DIV)
	;
	; 1kHz / (1 + 9) = 100 Hz
	mov  r0, #MPU6050_ADDR_WRITE
	bl   I2C1_Start
	cmp  r0, #0
	bne  mpu_init_fail

	mov  r0, #SMPLRT_DIV
	bl   I2C1_Write
	cmp  r0, #0
	bne  mpu_init_fail_stop

	mov  r0, #9
	bl   I2C1_Write
	cmp  r0, #0
	bne  mpu_init_fail_stop

	bl   I2C1_StopTx        ; Use StopTx after Write

	; Success
    mov  r0, #0
    pop  {r4-r7, pc}

	; Failure handlers
mpu_init_fail_stop
	bl   I2C1_StopRx

mpu_init_fail
	mov  r0, #1
	pop  {r4-r7, pc}

	ENDP
; ----------------------------------------------------------------------------
; MPU6050_ReadAccelRaw
;
; Returns:
;   R2 = Accel X
;   R1 = Accel Y
;   R0 = Accel Z
;
; Reads:
;   ACCEL_XOUT_H/L
;   ACCEL_YOUT_H/L
;   ACCEL_ZOUT_H/L
; ----------------------------------------------------------------------------
MPU6050_ReadAccelRaw PROC
    push {r4-r11, lr}

	; Send register address
    mov  r0, #MPU6050_ADDR_WRITE
    bl   I2C1_Start
    cmp  r0, #0
    bne  accel_read_fail

    mov  r0, #ACCEL_XOUT_H
    bl   I2C1_Write
    cmp  r0, #0
    bne  accel_read_fail_stop

	; Repeated START for read
	mov  r0, #MPU6050_ADDR_READ
    bl   I2C1_Start
    cmp  r0, #0
    bne  accel_read_fail_stop

	; Read X High
    bl   I2C1_ReadAck
	mov  r4, r0

	; Read X Low
	bl   I2C1_ReadAck
	mov  r5, r0

	; Combine X
	lsl  r4, r4, #8
	orr  r6, r4, r5

	; Read Y High
	bl   I2C1_ReadAck
	mov  r4, r0

	; Read Y Low
	bl   I2C1_ReadAck
	mov  r5, r0

	; Combine Y
	lsl  r4, r4, #8
	orr  r7, r4, r5

	; Read Z High
	bl   I2C1_ReadAck
	mov  r4, r0

	; Read Z Low (LAST BYTE => NACK)
	bl   I2C1_ReadNack
	mov  r5, r0

	; Combine Z
	lsl  r4, r4, #8
	orr  r8, r4, r5

	; STOP condition
	bl   I2C1_StopRx        ; Use StopRx after burst read

	; Sign extension (16-bit signed) and move to standard return registers
	sxth r0, r6
	sxth r1, r7
	sxth r2, r8
    
	pop  {r4-r11, pc}

; Failure handlers
accel_read_fail_stop
	bl   I2C1_StopRx

accel_read_fail
	mov  r2, #0
	mov  r1, #0
	mov  r0, #0

	pop  {r4-r11, pc}

	ENDP

	ALIGN
    END