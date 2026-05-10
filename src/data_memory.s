; ==========================================
; data_memory.s
; ==========================================
                AREA    Data_Section, DATA, READWRITE, ALIGN=3
                
                EXPORT  FFT_Data
                EXPORT  Sample_Count
                EXPORT  Data_Ready_Flag
                EXPORT  Max_Magnitude
                EXPORT  Maintenance_Flag

FFT_Data        SPACE   2048    ; 256 points * 8 bytes (Real & Imag)
Sample_Count    DCD     0
Data_Ready_Flag DCD     0
Max_Magnitude   DCFS    0.0     ; Store maximum vibration magnitude
Maintenance_Flag DCD    0       ; 0 = Normal, 1 = Maintenance Required

                END