         
   
    IMPORT ADC_Init
    IMPORT ADC_Read
    IMPORT ADC_Read_Channel
    EXPORT Keys_init 


    EXPORT Decode_Keypad


 AREA |.text|, CODE, READONLY
    THUMB
Keys_init PROC
    push {r0-r3, lr}            ; Save registers that will be used to protect caller
    ; Initialize ADC for Keypad Reading
    BL ADC_Init
    pop {r0-r3, pc}             ; Restore registers and return
    ENDP
; ==========================================
; Keypad Decoder Function
; ==========================================
Decode_Keypad PROC
              PUSH {r1, r2, LR}
             MOV r0, #8               ; Set the ADC channel for the keypad (Replace 1 with the actual channel)
             BL ADC_Read_Channel         ; Read the raw ADC value, returned in r0
check_1
              LDR r1, =2013          
              CMP r0, r1
              BLO check_2
              LDR r2, =2053          
              CMP r0, r2
              BHI check_2
              MOV r0, #'1'
              B end_decode

check_2
              LDR r1, =2382
              CMP r0, r1
              BLO check_3
              LDR r2, =2422
              CMP r0, r2
              BHI check_3
              MOV r0, #'2'
              B end_decode

check_3
              LDR r1, =2938
              CMP r0, r1
              BLO check_A
              LDR r2, =2978
              CMP r0, r2
              BHI check_A
              MOV r0, #'3'
              B end_decode

check_A
              LDR r1, =3744
              CMP r0, r1
              BLO check_4
              LDR r2, =3784
              CMP r0, r2
              BHI check_4
              MOV r0, #'A'
              B end_decode

check_4
              LDR r1, =1948
              CMP r0, r1
              BLO check_5
              LDR r2, =1988
              CMP r0, r2
              BHI check_5
              MOV r0, #'4'
              B end_decode

check_5
              LDR r1, =2294
              CMP r0, r1
              BLO check_6
              LDR r2, =2334
              CMP r0, r2
              BHI check_6
              MOV r0, #'5'
              B end_decode

check_6
              LDR r1, =2808
              CMP r0, r1
              BLO check_B
              LDR r2, =2848
              CMP r0, r2
              BHI check_B
              MOV r0, #'6'
              B end_decode

check_B
              LDR r1, =3534
              CMP r0, r1
              BLO check_7
              LDR r2, =3574
              CMP r0, r2
              BHI check_7
              MOV r0, #'B'
              B end_decode

check_7
              LDR r1, =1892
              CMP r0, r1
              BLO check_8
              LDR r2, =1932
              CMP r0, r2
              BHI check_8
              MOV r0, #'7'
              B end_decode

check_8
              LDR r1, =2212
              CMP r0, r1
              BLO check_9
              LDR r2, =2252
              CMP r0, r2
              BHI check_9
              MOV r0, #'8'
              B end_decode

check_9
              LDR r1, =2686
              CMP r0, r1
              BLO check_C
              LDR r2, =2726
              CMP r0, r2
              BHI check_C
              MOV r0, #'9'
              B end_decode

check_C
              LDR r1, =3347
              CMP r0, r1
              BLO check_star
              LDR r2, =3387
              CMP r0, r2
              BHI check_star
              MOV r0, #'C'
              B end_decode

check_star
              LDR r1, =1830
              CMP r0, r1
              BLO check_0
              LDR r2, =1870
              CMP r0, r2
              BHI check_0
              MOV r0, #'*'
              B end_decode

check_0
              LDR r1, =2139
              CMP r0, r1
              BLO check_hash
              LDR r2, =2179
              CMP r0, r2
              BHI check_hash
              MOV r0, #'0'
              B end_decode

check_hash
              LDR r1, =2573
              CMP r0, r1
              BLO check_D
              LDR r2, =2613
              CMP r0, r2
              BHI check_D
              MOV r0, #'#'
              B end_decode

check_D
              LDR r1, =3175
              CMP r0, r1
              BLO no_button
              LDR r2, =3215
              CMP r0, r2
              BHI no_button
              MOV r0, #'D'
              B end_decode

no_button
              MOV r0, #0

end_decode
              POP {r1, r2, PC}
              ENDP

