; ============================================================================
; fft_math.s
; 256-Point Radix-2 FFT implementation using FPU (Cortex-M4F)
; ============================================================================

                AREA    |.text|, CODE, READONLY, ALIGN=2
                THUMB
                
                IMPORT  FFT_Data
                IMPORT  Max_Magnitude
                
                EXPORT  Bit_Reversal_Sort
                EXPORT  FFT_Calculate
                EXPORT  Calculate_Magnitude

; ============================================================================
; 1. Bit-Reversal Sorting
; ============================================================================
Bit_Reversal_Sort PROC
                PUSH    {R0-R7, LR}
                LDR     R0, =FFT_Data   
                MOVS    R1, #0          ; i = 0

Sort_Loop
                CMP     R1, #256
                BGE     End_Sort

                RBIT    R2, R1          
                LSR     R2, R2, #24     ; Shift right 24 bits (for N=256)

                CMP     R1, R2
                BGE     Next_Element

                LSL     R3, R1, #3      ; i * 8
                LSL     R4, R2, #3      ; j * 8
                
                ADD     R5, R0, R3      
                ADD     R6, R0, R4      

                VLDR    S0, [R5]        
                VLDR    S1, [R5, #4]    
                VLDR    S2, [R6]        
                VLDR    S3, [R6, #4]    

                VSTR    S2, [R5]        
                VSTR    S3, [R5, #4]    
                VSTR    S0, [R6]        
                VSTR    S1, [R6, #4]    

Next_Element
                ADD     R1, R1, #1      
                B       Sort_Loop

End_Sort
                POP     {R0-R7, PC}
                ENDP

; ============================================================================
; 2. FFT Main Loop (Radix-2 DIT)
; ============================================================================
FFT_Calculate   PROC
                PUSH    {R0-R12, LR}
                
                LDR     R0, =FFT_Data           ; R0 = Base address of data
                LDR     R12, =Twiddle_Table     ; R12 = Base address of twiddle factors
                
                MOVS    R1, #1                  ; R1 = Stage Counter (1 to 8)
                MOVS    R2, #256                ; N = 256
                MOVS    R3, #1                  ; HalfSize = 1

Stage_Loop
                CMP     R1, #9                  ; 8 stages total for N=256
                BGE     End_FFT

                ; Calculate Twiddle Step: Step = N / (2 * HalfSize)
                LSL     R4, R3, #1              ; R4 = 2 * HalfSize
                UDIV    R5, R2, R4              ; R5 = Step

                MOVS    R6, #0                  ; R6 = Group Counter (j = 0)
Group_Loop
                CMP     R6, R3                  ; j < HalfSize
                BGE     Next_Stage

                ; Get Twiddle Factor (W = Twiddle_Table[j * Step])
                MUL     R7, R6, R5              ; R7 = Index
                LSL     R7, R7, #3              ; Multiply by 8 bytes
                ADD     R8, R12, R7
                VLDR    S10, [R8]               ; S10 = W_real
                VLDR    S11, [R8, #4]           ; S11 = W_imag

                ; R9 = Element Counter (i = j)
                MOV     R9, R6                  
Element_Loop
                CMP     R9, R2                  ; i < 256
                BGE     Next_Group

                ; Top Index = i * 8
                LSL     R10, R9, #3             
                ADD     R10, R0, R10            ; R10 = &Data[i]
                
                ; Bottom Index = (i + HalfSize) * 8
                ADD     R11, R9, R3             
                LSL     R11, R11, #3
                ADD     R11, R0, R11            ; R11 = &Data[i + HalfSize]

                ; --- FPU Butterfly Math ---
                VLDR    S0, [R11]               ; Bottom Real
                VLDR    S1, [R11, #4]           ; Bottom Imag

                ; Complex Multiply: Bottom * W
                VMUL.F32 S2, S0, S10
                VMUL.F32 S3, S1, S11
                VSUB.F32 S4, S2, S3             ; S4 = Temp_Real
                
                VMUL.F32 S2, S0, S11
                VMUL.F32 S3, S1, S10
                VADD.F32 S5, S2, S3             ; S5 = Temp_Imag

                VLDR    S6, [R10]               ; Top Real
                VLDR    S7, [R10, #4]           ; Top Imag

                ; New Bottom = Top - Temp
                VSUB.F32 S8, S6, S4             ; New_Bottom_Real
                VSUB.F32 S9, S7, S5             ; New_Bottom_Imag
                VSTR    S8, [R11]
                VSTR    S9, [R11, #4]

                ; New Top = Top + Temp
                VADD.F32 S6, S6, S4             ; New_Top_Real
                VADD.F32 S7, S7, S5             ; New_Top_Imag
                VSTR    S6, [R10]
                VSTR    S7, [R10, #4]

                ; i += 2 * HalfSize
                ADD     R9, R9, R4              
                B       Element_Loop

Next_Group
                ADD     R6, R6, #1              ; j++
                B       Group_Loop

Next_Stage
                LSL     R3, R3, #1              ; HalfSize *= 2
                ADD     R1, R1, #1              ; Stage++
                B       Stage_Loop

End_FFT
                POP     {R0-R12, PC}
                ENDP

; ============================================================================
; 3. Calculate Magnitude & Find Maximum
; ============================================================================
Calculate_Magnitude PROC
                PUSH    {R0-R4, LR}
                LDR     R0, =FFT_Data
                MOVS    R1, #0          ; i = 0
                MOV     R2, #0          ; Load integer 0 (0x00000000)
                VMOV    S6, R2          ; Move to S6 (IEEE-754 Float 0.0)

Mag_Loop
                CMP     R1, #128        ; First half only (Nyquist limit)
                BGE     End_Mag
                
                LSL     R2, R1, #3
                ADD     R3, R0, R2
                
                VLDR    S0, [R3]        ; Real
                VLDR    S1, [R3, #4]    ; Imaginary
                
                VMUL.F32 S2, S0, S0     ; Real^2
                VMUL.F32 S3, S1, S1     ; Imag^2
                VADD.F32 S4, S2, S3     ; Real^2 + Imag^2
                
                VSQRT.F32 S5, S4        ; Magnitude = sqrt()
                
                VCMP.F32 S5, S6         ; Compare S5 (current) with S6 (max)
                VMRS    APSR_nzcv, FPSCR
                BLE     Next_Mag
                VMOV.F32 S6, S5         ; Update Max

Next_Mag
                ADD     R1, R1, #1
                B       Mag_Loop

End_Mag
                LDR     R0, =Max_Magnitude
                VSTR    S6, [R0]        ; Store max
                POP     {R0-R4, PC}
                ENDP
			    LTORG

; ============================================================================
; 4. Twiddle Factors Table
; ============================================================================
Twiddle_Table
                 DCFS       1.000000,  -0.000000    ; k=0
                DCFS       0.999699,  -0.024541    ; k=1
                DCFS       0.998795,  -0.049068    ; k=2
                DCFS       0.997290,  -0.073565    ; k=3
                DCFS       0.995185,  -0.098017    ; k=4
                DCFS       0.992480,  -0.122411    ; k=5
                DCFS       0.989177,  -0.146730    ; k=6
                DCFS       0.985278,  -0.170962    ; k=7
                DCFS       0.980785,  -0.195090    ; k=8
                DCFS       0.975702,  -0.219101    ; k=9
                DCFS       0.970031,  -0.242980    ; k=10
                DCFS       0.963776,  -0.266713    ; k=11
                DCFS       0.956940,  -0.290285    ; k=12
                DCFS       0.949528,  -0.313682    ; k=13
                DCFS       0.941544,  -0.336890    ; k=14
                DCFS       0.932993,  -0.359895    ; k=15
                DCFS       0.923880,  -0.382683    ; k=16
                DCFS       0.914210,  -0.405241    ; k=17
                DCFS       0.903989,  -0.427555    ; k=18
                DCFS       0.893224,  -0.449611    ; k=19
                DCFS       0.881921,  -0.471397    ; k=20
                DCFS       0.870087,  -0.492898    ; k=21
                DCFS       0.857729,  -0.514103    ; k=22
                DCFS       0.844854,  -0.534998    ; k=23
                DCFS       0.831470,  -0.555570    ; k=24
                DCFS       0.817585,  -0.575808    ; k=25
                DCFS       0.803208,  -0.595699    ; k=26
                DCFS       0.788346,  -0.615232    ; k=27
                DCFS       0.773010,  -0.634393    ; k=28
                DCFS       0.757209,  -0.653173    ; k=29
                DCFS       0.740951,  -0.671559    ; k=30
                DCFS       0.724247,  -0.689541    ; k=31
                DCFS       0.707107,  -0.707107    ; k=32
                DCFS       0.689541,  -0.724247    ; k=33
                DCFS       0.671559,  -0.740951    ; k=34
                DCFS       0.653173,  -0.757209    ; k=35
                DCFS       0.634393,  -0.773010    ; k=36
                DCFS       0.615232,  -0.788346    ; k=37
                DCFS       0.595699,  -0.803208    ; k=38
                DCFS       0.575808,  -0.817585    ; k=39
                DCFS       0.555570,  -0.831470    ; k=40
                DCFS       0.534998,  -0.844854    ; k=41
                DCFS       0.514103,  -0.857729    ; k=42
                DCFS       0.492898,  -0.870087    ; k=43
                DCFS       0.471397,  -0.881921    ; k=44
                DCFS       0.449611,  -0.893224    ; k=45
                DCFS       0.427555,  -0.903989    ; k=46
                DCFS       0.405241,  -0.914210    ; k=47
                DCFS       0.382683,  -0.923880    ; k=48
                DCFS       0.359895,  -0.932993    ; k=49
                DCFS       0.336890,  -0.941544    ; k=50
                DCFS       0.313682,  -0.949528    ; k=51
                DCFS       0.290285,  -0.956940    ; k=52
                DCFS       0.266713,  -0.963776    ; k=53
                DCFS       0.242980,  -0.970031    ; k=54
                DCFS       0.219101,  -0.975702    ; k=55
                DCFS       0.195090,  -0.980785    ; k=56
                DCFS       0.170962,  -0.985278    ; k=57
                DCFS       0.146730,  -0.989177    ; k=58
                DCFS       0.122411,  -0.992480    ; k=59
                DCFS       0.098017,  -0.995185    ; k=60
                DCFS       0.073565,  -0.997290    ; k=61
                DCFS       0.049068,  -0.998795    ; k=62
                DCFS       0.024541,  -0.999699    ; k=63
                DCFS       0.000000,  -1.000000    ; k=64
                DCFS      -0.024541,  -0.999699    ; k=65
                DCFS      -0.049068,  -0.998795    ; k=66
                DCFS      -0.073565,  -0.997290    ; k=67
                DCFS      -0.098017,  -0.995185    ; k=68
                DCFS      -0.122411,  -0.992480    ; k=69
                DCFS      -0.146730,  -0.989177    ; k=70
                DCFS      -0.170962,  -0.985278    ; k=71
                DCFS      -0.195090,  -0.980785    ; k=72
                DCFS      -0.219101,  -0.975702    ; k=73
                DCFS      -0.242980,  -0.970031    ; k=74
                DCFS      -0.266713,  -0.963776    ; k=75
                DCFS      -0.290285,  -0.956940    ; k=76
                DCFS      -0.313682,  -0.949528    ; k=77
                DCFS      -0.336890,  -0.941544    ; k=78
                DCFS      -0.359895,  -0.932993    ; k=79
                DCFS      -0.382683,  -0.923880    ; k=80
                DCFS      -0.405241,  -0.914210    ; k=81
                DCFS      -0.427555,  -0.903989    ; k=82
                DCFS      -0.449611,  -0.893224    ; k=83
                DCFS      -0.471397,  -0.881921    ; k=84
                DCFS      -0.492898,  -0.870087    ; k=85
                DCFS      -0.514103,  -0.857729    ; k=86
                DCFS      -0.534998,  -0.844854    ; k=87
                DCFS      -0.555570,  -0.831470    ; k=88
                DCFS      -0.575808,  -0.817585    ; k=89
                DCFS      -0.595699,  -0.803208    ; k=90
                DCFS      -0.615232,  -0.788346    ; k=91
                DCFS      -0.634393,  -0.773010    ; k=92
                DCFS      -0.653173,  -0.757209    ; k=93
                DCFS      -0.671559,  -0.740951    ; k=94
                DCFS      -0.689541,  -0.724247    ; k=95
                DCFS      -0.707107,  -0.707107    ; k=96
                DCFS      -0.724247,  -0.689541    ; k=97
                DCFS      -0.740951,  -0.671559    ; k=98
                DCFS      -0.757209,  -0.653173    ; k=99
                DCFS      -0.773010,  -0.634393    ; k=100
                DCFS      -0.788346,  -0.615232    ; k=101
                DCFS      -0.803208,  -0.595699    ; k=102
                DCFS      -0.817585,  -0.575808    ; k=103
                DCFS      -0.831470,  -0.555570    ; k=104
                DCFS      -0.844854,  -0.534998    ; k=105
                DCFS      -0.857729,  -0.514103    ; k=106
                DCFS      -0.870087,  -0.492898    ; k=107
                DCFS      -0.881921,  -0.471397    ; k=108
                DCFS      -0.893224,  -0.449611    ; k=109
                DCFS      -0.903989,  -0.427555    ; k=110
                DCFS      -0.914210,  -0.405241    ; k=111
                DCFS      -0.923880,  -0.382683    ; k=112
                DCFS      -0.932993,  -0.359895    ; k=113
                DCFS      -0.941544,  -0.336890    ; k=114
                DCFS      -0.949528,  -0.313682    ; k=115
                DCFS      -0.956940,  -0.290285    ; k=116
                DCFS      -0.963776,  -0.266713    ; k=117
                DCFS      -0.970031,  -0.242980    ; k=118
                DCFS      -0.975702,  -0.219101    ; k=119
                DCFS      -0.980785,  -0.195090    ; k=120
                DCFS      -0.985278,  -0.170962    ; k=121
                DCFS      -0.989177,  -0.146730    ; k=122
                DCFS      -0.992480,  -0.122411    ; k=123
                DCFS      -0.995185,  -0.098017    ; k=124
                DCFS      -0.997290,  -0.073565    ; k=125
                DCFS      -0.998795,  -0.049068    ; k=126
                DCFS      -0.999699,  -0.024541    ; k=127
                
                ALIGN
                END