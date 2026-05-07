; =============================================================================
; DFPlayer Mini Command Constants
; =============================================================================

; Command codes from datasheet
DFP_CMD_NEXT            EQU     0x01    ; Next track
DFP_CMD_PREV            EQU     0x02    ; Previous track
DFP_CMD_PLAY_TRACK      EQU     0x03    ; Specify track to play (0-2999)
DFP_CMD_VOL_UP          EQU     0x04    ; Increase volume
DFP_CMD_VOL_DOWN        EQU     0x05    ; Decrease volume
DFP_CMD_SET_VOLUME      EQU     0x06    ; Set volume (0-30)
DFP_CMD_SET_EQ          EQU     0x07    ; Set EQ (0-5)
DFP_CMD_SET_MODE        EQU     0x08    ; Set playback mode
DFP_CMD_SET_DEVICE      EQU     0x09    ; Set playback device
DFP_CMD_STANDBY         EQU     0x0A    ; Enter standby
DFP_CMD_NORMAL          EQU     0x0B    ; Normal working
DFP_CMD_RESET           EQU     0x0C    ; Reset module
DFP_CMD_PLAY            EQU     0x0D    ; Play
DFP_CMD_PAUSE           EQU     0x0E    ; Pause
DFP_CMD_PLAY_FOLDER     EQU     0x0F    ; Play specific folder and file
DFP_CMD_VOL_ADJ         EQU     0x10    ; Volume adjust set
DFP_CMD_REPEAT_PLAY     EQU     0x11    ; Repeat play
DFP_CMD_STOP			EQU		0x16

; Device selection (for CMD 0x09)
DFP_DEVICE_U_DISK       EQU     0x01
DFP_DEVICE_TF_CARD      EQU     0x02    ; Default for SD/TF card
DFP_DEVICE_AUX          EQU     0x03
DFP_DEVICE_SLEEP        EQU     0x04
DFP_DEVICE_FLASH        EQU     0x05

; EQ settings (for CMD 0x07)
DFP_EQ_NORMAL           EQU     0x00
DFP_EQ_POP              EQU     0x01
DFP_EQ_ROCK             EQU     0x02
DFP_EQ_JAZZ             EQU     0x03
DFP_EQ_CLASSIC          EQU     0x04
DFP_EQ_BASS             EQU     0x05

; Playback modes (for CMD 0x08)
DFP_MODE_REPEAT         EQU     0x00    ; Repeat all
DFP_MODE_FOLDER_REPEAT  EQU     0x01    ; Folder repeat
DFP_MODE_SINGLE_REPEAT  EQU     0x02    ; Single repeat
DFP_MODE_RANDOM         EQU     0x03    ; Random
	
; ++++
DFP_START_BYTE			EQU		0x7E
DFP_VERSION				EQU		0xFF
DFP_DATA_LENGTH			EQU		0x06
DFP_END_BYTE			EQU		0xEF
; =============================================================================
; Default Configuration
; =============================================================================
DFP_DEFAULT_VOLUME      EQU     30      ; 50% of max 30 volume
DFP_DEFAULT_DEVICE      EQU     DFP_DEVICE_TF_CARD
DFP_DEFAULT_EQ          EQU     DFP_EQ_NORMAL
DFP_DEFAULT_MODE        EQU     DFP_MODE_SINGLE_REPEAT
	
; =============================================================================
; CUSTOM TRACK NUMBERS - YOU MUST HAVE THESE!
; =============================================================================
TRACK_GROUND            EQU     1
TRACK_FIRST             EQU     2
TRACK_SECOND            EQU     3
TRACK_OVERLOAD          EQU     4
TRACK_POWER_FAIL        EQU     5

		END