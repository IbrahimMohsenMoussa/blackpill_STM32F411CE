; ==========================================
; Definitions and Memory Addresses (Keil Syntax)
; ==========================================

    INCLUDE stm32f411.inc  ; Include the header file for STM32F4 series
   

; ==========================================
; Area Definition (Start of Code Segment)
; ==========================================
		AREA    |.text|, CODE, READONLY
             
		ALIGN

		IMPORT RCC_APB2_Enable
		EXPORT ADC_Init
		EXPORT ADC_Read
		EXPORT ADC_Read_Channel

; ==========================================
; ADC Initialization Function
; ==========================================
ADC_Init      PROC
	push {r0-r3, lr}            ; Save registers that will be used to protect caller


	LDR r0, =RCC_APB2_ADC1
	BL RCC_APB2_Enable
        
	LDR r0, =ADC1_BASE
	LDR r1, [r0, #ADC_CR2]
	ORR r1, r1, #0x01           
	STR r1, [r0, #ADC_CR2]

	pop {r0-r3, pc}             ; Restore registers and return
	ENDP

; ==========================================
; ADC Read Function
; ==========================================
ADC_Read      PROC
	LDR r1, =ADC1_BASE
              
	; 1. Select the ADC channel
	STR r0, [r1, #ADC_SQR3]  

	; 2. Start conversion (Bit 30 in CR2)
	LDR r2, [r1, #ADC_CR2]
	ORR r2, r2, #0x40000000   
	STR r2, [r1, #ADC_CR2]

Wait_EOC
	; 3. Wait for End of Conversion (Bit 1 in SR)
	LDR r2, [r1, #ADC_SR]
	ANDS r2, r2, #0x02   
	BEQ Wait_EOC

	; 4. Read result
	LDR r0, [r1, #ADC_DR]    
              
	BX LR
	ENDP
            
; ==========================================
; ADC Read Function (Updated to read channel from R0)
; ==========================================
ADC_Read_Channel PROC
	PUSH {R1, R2, LR}         ; Save registers
	LDR R1, =ADC1_BASE
              
	; 1. Select the ADC channel (Channel number is in R0)
	; SQR3 bits [4:0] define the 1st conversion in regular sequence
	STR R0, [R1, #ADC_SQR3]  

	; 2. Start conversion (SWSTART: Bit 30 in CR2)
	LDR R2, [R1, #ADC_CR2]
	ORR R2, R2, #0x40000000   
	STR R2, [R1, #ADC_CR2]

Wait_EOC_Channel
	; 3. Wait for End of Conversion (EOC: Bit 1 in SR)
	LDR R2, [R1, #ADC_SR]
	ANDS R2, R2, #0x02   
	BEQ Wait_EOC_Channel
	
	; 4. Read result from Data Register
	LDR R0, [R1, #ADC_DR]    
              
	POP {R1, R2, PC}          ; Restore and return
	ENDP

	ALIGN
	END