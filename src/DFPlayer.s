		AREA DFPlayer_Driver, CODE, READONLY
		THUMB

        ; Export public APIs
		EXPORT DFP_Init
		EXPORT DFP_PlayTrack
		EXPORT DFP_PlayImmediate
			
		EXPORT DFP_Sleep
		EXPORT DFP_WakeUp
		EXPORT DFP_Pause
		EXPORT DFP_Resume
		EXPORT DFP_Stop
		EXPORT DFP_SetVolume
		EXPORT DFP_ResetBeforePlay
        
        ; Import UART functions
        IMPORT UART1_Init
        IMPORT UART1_Transmit
		IMPORT SysTick_delay_ms
		
	
		
		GET		DFPlayer_defs.s

; =============================================================================
; Private Function: DFP_sendCommand
; Description: Sends command frame to DFPlayer Mini
; Input: R0 = command, R1 = param1 (high byte), R2 = param2 (low byte)
; Frame format: 7E FF 06 CMD FB param1 param2 CHK_H CHK_L EF
; Where: CHK = -(0xFF + 0x06 + CMD + FB + param1 + param2)
; =============================================================================
DFP_sendCommand PROC
        PUSH    {R0-R7, LR}
        
        ; Save parameters
        MOV     R7, R0          ; R7 = command
        MOV     R6, R1          ; R6 = param1 (high byte)
        MOV     R5, R2          ; R5 = param2 (low byte)
        
        ; Feedback: 0x01 = enable feedback, 0x00 = disable
        ; We'll use 0x00 for no feedback (simpler)
        MOV     R4, #0x00       ; R4 = feedback (0x00 for no feedback)
        
        ; Calculate checksum
        ; CHK = -(0xFF + 0x06 + CMD + FB + param1 + param2)
        MOV     R3, #0xFF       ; Start with 0xFF (version)
        ADD     R3, #0x06       ; Add length
        ADD     R3, R7          ; Add command
        ADD     R3, R4          ; Add feedback
        ADD     R3, R6          ; Add param1 (high byte)
        ADD     R3, R5          ; Add param2 (low byte)
        RSB     R3, R3, #0      ; R3 = -R3 (two's complement)
        UXTH    R3, R3          ; Zero-extend halfword (clears upper 16 bits, keeps lower 16)
        
        ; R3 now contains 16-bit checksum
        ; Split into high and low bytes
        MOV     R2, R3, LSR #8  ; R2 = checksum high byte
        AND     R2, R2, #0xFF
        AND     R3, R3, #0xFF   ; R3 = checksum low byte
        
        ; Send frame bytes
        ; Start byte: 0x7E : $S sign
        MOV     R0, #DFP_START_BYTE
        BL      UART1_Transmit
        
        ; Version: 0xFF
        MOV     R0, #DFP_VERSION
        BL      UART1_Transmit
        
        ; Length: 0x06 (checksum not counted)
        MOV     R0, #DFP_DATA_LENGTH
        BL      UART1_Transmit
        
        ; Command
        MOV     R0, R7
        BL      UART1_Transmit
        
        ; Feedback
        MOV     R0, R4
        BL      UART1_Transmit
        
        ; Parameter 1 (high byte)
        MOV     R0, R6
        BL      UART1_Transmit
        
        ; Parameter 2 (low byte)
        MOV     R0, R5
        BL      UART1_Transmit
        
        ; Checksum high byte
        MOV     R0, R2
        BL      UART1_Transmit
        
        ; Checksum low byte
        MOV     R0, R3
        BL      UART1_Transmit
        
        ; End byte: 0xEF : $O
        MOV     R0, #DFP_END_BYTE
        BL      UART1_Transmit
        
        ; Small delay to ensure command is processed
        MOV     R0, #200
        BL      SysTick_delay_ms
        
        POP     {R0-R7, PC}
        ENDP

; =============================================================================
; Public Function: DFP_Init
; Description: Initializes DFPlayer Mini module
; 1. Initialize UART (9600 baud, 8N1)
; 2. Reset module
; 3. Set default volume (100%)
; 4. Set default EQ
; 5. Set playback mode
; 6. Select TF card as playback device
; =============================================================================
DFP_Init PROC
		PUSH    {R0-R2, LR}
		
		; 1. Initialize UART (9600 baud)
		BL      UART1_Init
		
		; 2. Reset module
		MOV     R0, #DFP_CMD_RESET
		MOV     R1, #0
		MOV     R2, #0
		BL      DFP_sendCommand
		
		; CRITICAL: Wait for reset to complete (1.5-3 seconds per datasheet)
		MOV     R0, #2000         ; 2 seconds - safe margin
		BL      SysTick_delay_ms
		
		; 3. Select TF card as playback device
		MOV     R0, #DFP_CMD_SET_DEVICE
		MOV     R1, #0
		MOV     R2, #0x02         ; 0x02 for TF card (from datasheet page 7)
		BL      DFP_sendCommand
		
		MOV     R0, #100
		BL      SysTick_delay_ms
		
		; 4. Set volume to 100% (30 out of 30)
		MOV     R0, #DFP_CMD_SET_VOLUME
		MOV     R1, #0
		MOV     R2, #DFP_DEFAULT_VOLUME
		BL      DFP_sendCommand
		
		MOV     R0, #100
		BL      SysTick_delay_ms
		
		; 5. Set EQ to Normal
		MOV     R0, #DFP_CMD_SET_EQ
		MOV     R1, #0
		MOV     R2, #DFP_DEFAULT_EQ
		BL      DFP_sendCommand
		
		MOV     R0, #100
		BL      SysTick_delay_ms
		
		; 6. Set playback mode (Commented out for safety)
		; Many clones crash or behave erratically when receiving the mode command.
		; MOV     R0, #DFP_CMD_SET_MODE
		; MOV     R1, #0
		; MOV     R2, #DFP_DEFAULT_MODE
		; BL      DFP_sendCommand
		
        ; 7. Play test sound
		MOV		R0, #TRACK_GROUND
		BL		DFP_PlayTrack
		
		POP     {R0-R2, PC}
		ENDP

; =============================================================================
; Play specific track number (0-2999)
; Input: R0 = track number
; =============================================================================
DFP_PlayTrack PROC
        PUSH    {R0-R2, LR}
        
        ; Split 16-bit track number into high and low bytes
        MOV     R1, R0, LSR #8      ; High byte
        AND     R2, R0, #0xFF       ; Low byte
        
        ; Send "Play MP3 Folder" command (0x12) instead of standard Play (0x03)
        ; This forces the module to read filenames (0001.mp3) instead of FAT table index
        ; NOTE: Your files MUST be placed inside a folder named "MP3" on the SD Card!
        MOV     R0, #0x12
        BL      DFP_sendCommand
        
        POP     {R0-R2, PC}
        ENDP

; =============================================================================
; Public Function: DFP_ResetBeforePlay
; Description: sends random initialization frame that happens to make it work LOL
; =============================================================================
DFP_ResetBeforePlay PROC
		PUSH    {R0-R2, LR}
		
		; 3. Select TF card as playback device
		MOV     R0, #DFP_CMD_SET_DEVICE
		MOV     R1, #0
		MOV     R2, #0x02         ; 0x02 for TF card (from datasheet page 7)
		BL      DFP_sendCommand
		
		MOV     R0, #100
		BL      SysTick_delay_ms
		
		POP     {R0-R2, PC}
		ENDP
			
; =============================================================================
; Public Function: DFP_Sleep
; Description: Puts DFPlayer Mini into sleep/low power mode
; Command: 0x0A (Standby)
; =============================================================================
DFP_Sleep PROC
        PUSH    {R0-R2, LR}
        
        ; Send standby command (0x0A)
        MOV     R0, #DFP_CMD_STANDBY
        MOV     R1, #0
        MOV     R2, #0
        BL      DFP_sendCommand
        
        POP     {R0-R2, PC}
        ENDP

; =============================================================================
; Public Function: DFP_WakeUp
; Description: Wakes up DFPlayer Mini from sleep mode
; Command: 0x0B (Normal working)
; =============================================================================
DFP_WakeUp PROC
        PUSH    {R0-R2, LR}
        
        ; Send wakeup command (0x0B)
        MOV     R0, #DFP_CMD_NORMAL
        MOV     R1, #0
        MOV     R2, #0
        BL      DFP_sendCommand
        
        POP     {R0-R2, PC}
        ENDP
			

; Set volume (0-30)
; Input: R0 = volume level (0-30)
DFP_SetVolume PROC
        PUSH    {R0-R2, LR}
        
        ; Ensure volume is within range
        CMP     R0, #30
        MOVGT   R0, #30
        CMP     R0, #0
        MOVLT   R0, #0
        
        MOV     R1, #0          ; High byte
        MOV     R2, R0          ; Low byte = volume
        MOV     R0, #DFP_CMD_SET_VOLUME
        BL      DFP_sendCommand
        
        POP     {R0-R2, PC}
        ENDP

; Pause playback
DFP_Pause PROC
        PUSH    {R0-R2, LR}
        
        MOV     R0, #DFP_CMD_PAUSE
        MOV     R1, #0
        MOV     R2, #0
        BL      DFP_sendCommand
        
        POP     {R0-R2, PC}
        ENDP

; Resume playback
DFP_Resume PROC
        PUSH    {R0-R2, LR}
        
        MOV     R0, #DFP_CMD_PLAY
        MOV     R1, #0
        MOV     R2, #0
        BL      DFP_sendCommand
        
        POP     {R0-R2, PC}
        ENDP
			
; =============================================================================
; Public Function: DFP_Stop
; Description: Stops current playback on DFPlayer Mini
; =============================================================================
DFP_Stop PROC
		PUSH    {R0-R4, LR}
        
		; Send stop command (0x16)
		MOV     R0, #DFP_CMD_STOP
		MOV     R1, #0
		MOV     R2, #0
		BL      DFP_sendCommand
		
		MOV     R0, #50           ; 50ms delay
		BL      SysTick_delay_ms
        
        POP     {R0-R4, PC}
		ENDP
			
; =============================================================================
; Play track with interruption of current
; =============================================================================
DFP_PlayImmediate PROC
		PUSH    {R0-R2, LR}
        
		; Stop command removed; 0x03 natively interrupts playback on DFPlayer.
		; Sending 0x16 followed immediately by 0x03 crashes many clones.
		
        ; Now play the new track
        ; R0 already contains track number
        BL      DFP_PlayTrack
        
        POP     {R0-R2, PC}
        ENDP
			
        ALIGN                   ; Ensure word alignment
        END