;----------------------------------------
;R.ASM->RAIDER.EXE
;========================================
;CONSTANTS
;========================================
PORT_378	EQU 378h	;parallel port 2?

PORT_3C0	EQU 3C0h	;EGA attribute controller
PORT_3C4	EQU 3C4h	;EGA sequencer
PORT_3CE	EQU 3CEh
PORT_3D4	EQU 3D4h
PORT_3DA	EQU 3DAh	;status register

SEG_A000	EQU 0A000h

KBD_F1	EQU 3Bh

;FIX_BUGS	EQU 1
;========================================
;MACROS
;========================================
WAIT_M	MACRO	del
	LOCAL _loop

	MOV	CX,del	;B9 xx xx
_loop:
	CALL	Synchro_x4	;E8 xx xx
	LOOP	_loop	;E2 FB
ENDM
;---- ----
THINK_M	MACRO
	LOCAL _end

	CMP	[SI]._thcounter,0
	JZ	_end
	DEC	[SI]._thcounter
_end:
ENDM
;========================================
;STRUCTURES
;========================================
s_actor	STRUC	;size 22h
	_map_x	dw ?	;00
	_map_y	dw ?	;02
	_max_accel	dw ?	;04
	_power	db ?	;06
	_active	db ?	;07
	_energy	db ?	;08
	_p_spr	dw ?	;09
	_typ4radar	db ?	;0a
	_p_cb_refresh	dw ?	;0c
	_p_cb_control	dw ?	;0e
	_shoot_typ	db ?	;10
	_dir_mask	db ?	;11
	_frame	db ?	;12
	;-- --
	_accel_x	dw ?	;13
	_speed_x	dw ?	;15
	_accel_y	dw ?	;17
	_speed_y	dw ?	;19
	;-- --
	f_1b	db ?	;shoot related
	_thcounter	db ?	;1c("think" counter?)
	_max_frame	db ?	;1d(for destruction anim?)
	f_1e	dw ?	;@ s_actor
	p_shootXY	dw ?	;20
s_actor	ENDS

SizeOf_s_actor	EQU 22h
;---- ----
s_raiderShoot	STRUC	;size 8
	_f_00	dw ?	;00(shoot base x)
	_f_02	dw ?	;02(shoot base y)
	;-- --
	_p_shot_spr	dw ?	;04(goes to s_actor._p_spr)
	_shot_dir	db ?	;06(raider shoot direction info[+accessed as word])
	_f_07	db ?	;+
s_raiderShoot	ENDS
;---- ----
s_surface	STRUC	;size 0Dh
	_voffset	dw ?	;00
	_vscroll	dw ?	;02
	fff_04	dw ?	;@ :tilemap related?
	fff_06	dw ?	;@ :sprites related?
	fff_08	dw ?	;@ :gems related?
	fff_0a	dw ?	;voffset:radar frame related
	_render_flag	db ?	;0C
s_surface	ENDS
;---- ----
s_surfElement	STRUC	;size 8
	_dst_offset	dw ?	;00
	_src_offset	dw ?	;02
	_bytes_per_line	db ?	;04
	_line_count	db ?	;05
	__06	db ?
	__07	db ?
s_surfElement	ENDS
;---- ----
s_sprite	STRUC	;size 10h
	_p_data_spr	dw ?	;00(offset in sprite segment)
	;-- --
	_spr_x db ?	;02
	_spr_y db ?	;03
	_spr_w db ?	;04
	_spr_h db ?	;05
	;-- some box(upper part)? --
	_box1_left db ?	;06
	_box1_top db ?	;07
	_box1_right db ?	;08
	_box1_bottom db ?	;09
	;-- some box(lower part)? --
	;(ffff_0e must be not null)
	_box2_left db ?	;0a
	_box2_top db ?	;0b
	_box2_right db ?	;0c
	_box2_bottom db ?	;0d
	;-- --
	ffff_0e db ?	;z?tag?(always 0B1h for ships)
	;-- --
	_____0f db ?
s_sprite	ENDS
;---- ----
s_radarObject	STRUC	;size 8
	_radar_type	db ?	;00
	_radar_x	dw ?	;01
	_radar_y	dw ?	;03
	__05	db ?,?,?
s_radarObject	ENDS
;========================================
;SEGMENTS DEFINITION
;========================================
_TEXT	SEGMENT PUBLIC BYTE	;len 2F20h[0AB7]
	ASSUME CS:_TEXT
_TEXT	ENDS

_DATA	SEGMENT PUBLIC PARA	;len E110h[0DA9]
	ASSUME DS:_DATA
_DATA	ENDS

_STACK	SEGMENT	STACK	;len 200h[1BBA]
	ASSUME SS:_STACK
_STACK	ENDS

SEG_1BDA	SEGMENT	PUBLIC PARA	;spites:len EBD0h
SEG_1BDA	ENDS

SEG_2A97	SEGMENT	PUBLIC PARA	;spites:len D700h
	;some ship + ...?
SEG_2A97	ENDS

SEG_3807	SEGMENT	PUBLIC PARA	;spites:len BFD0h
	;some ship + ...?
SEG_3807	ENDS

SEG_4404	SEGMENT	PUBLIC PARA	;spites:len 2760h
	;some ship + ...?
SEG_4404	ENDS

SEG_467A	SEGMENT	PUBLIC PARA	;spites:len 7890h
	;gauge
SEG_467A	ENDS

SEG_4E03	SEGMENT	PUBLIC PARA	;bitmap:len 7800h
	;inside raider[40x192]
SEG_4E03	ENDS

SEG_5583	SEGMENT	PUBLIC PARA	;bitmap:len 7800h
	;splash[40x192]
SEG_5583	ENDS

SEG_5D03	SEGMENT	PUBLIC PARA	;bitmap:len 7800h
	;level[40x192]
SEG_5D03	ENDS

SEG_6483	SEGMENT	PUBLIC PARA	;bitmap:len 12C0h?
	;HELLRAIDER logo[40x30]
SEG_6483	ENDS
;----------------------------------------

;########################################0AB7
_TEXT	SEGMENT PUBLIC BYTE
;----------------------------------------0000
Start:
	MOV	AX,_DATA
	MOV	DS,AX

	MOV	BYTE PTR g_stop_int8,0FFh

	CALL	SetInt9	;[bugged]
	CALL	SetInt8
	CALL	SetInt24h
	CALL	GrMode

	MOV	DX,PORT_378
	MOV	AL,0FFh	;all out high
	OUT	DX,AL

	CALL	SplashImage

	;-- "randomize timer" --
	MOV	AH,2Ch	;get system time
	INT	21h
	MOV	CX,DX
	AND	CX,3FFh
	ADD	CX,3F3h
C_002D:
	CALL	Rand
	LOOP	C_002D

	;-- "BLOCKS.DAT" --
C_0032:
	CALL	LoadBlocks
	JNB	C_0041
	WAIT_M	12
	JMP	C_0032
	;-- "MAP.DAT" --
C_0041:
	CALL	LoadMap
	JNB	C_0050
	WAIT_M	12
	JMP	C_0041
C_0050:
	;-- --
	CALL	LoadHiscores
	CALL	LoadKeys
	;-----------------
	;-- Splash Loop --0056
SplashLoop:
	CALL	Credits

	MOV	CX,62
	CALL	DelayWaitKey
	JNZ	StartGame

	CALL	SplashScreen
	JNZ	StartGame

	CALL	HighScores

	MOV	CX,62
	CALL	DelayWaitKey
	JNZ	StartGame

	CALL	SplashScreen
	JZ	SplashLoop

	JMP	SHORT StartGame
;---- ----0078
;SplashImage+DelayWaitKey
SplashScreen:
	CALL	SplashImage

	MOV	CX,100
;---- ----007E
DelayWaitKey:
C_007E:
	CALL	GetInputMask_both
	TEST	AL,10h
	JNZ	C_009B

	CALL	GetKBDScancode
	JNB	C_0094
	CMP	AL,KBD_F1
	JNZ	C_0094
	CALL	C_21D5	;"keys.dat":user input

	MOV	CX,1
C_0094:
	CALL	Synchro_x4
	LOOP	C_007E

	CMP	AL,AL
C_009B:
	RET
;---- ----009C
StartGame:
	XOR	AX,AX
	MOV	g_map,AL
	MOV	g_level,AL
	MOV	g_score[0],AX
	MOV	g_score[2],AX

	MOV	SI,OFFSET _DATA:D_0B5C	;"orbital"
	MOV	DI,OFFSET _DATA:D_0452	;orbital #1
	CALL	SetShipInfos
	MOV	DI,OFFSET _DATA:D_0474	;orbital #2
	CALL	SetShipInfos
	MOV	DI,OFFSET _DATA:D_0496	;orbital #3
	CALL	SetShipInfos
	MOV	DI,OFFSET _DATA:D_04B8	;orbital #4
	CALL	SetShipInfos
	;-----------------
	;-- start level --
	;-----------------00C5
StartLevel:
	MOV	SP,200h

	MOV	BYTE PTR g_stop_int8,0FFh

	MOV	g_pUserShip,OFFSET _DATA:D_0430	;raider

	XOR	AX,AX
	MOV	g_gems,AX
	MOV	g_level_clear,AL
	MOV	D_0042,AL
	MOV	g_killTotal,AL
	;-- --
	MOV	BX,OFFSET _DATA:g_killCounts
	MOV	CX,8
C_00E7:
	MOV	[BX],AX
	ADD	BX,2
	LOOP	C_00E7
	;-- --
	MOV	CX,4
	MOV	BX,OFFSET _DATA:D_0452
C_00F4:
	MOV	[BX]._active,AL
	ADD	BX,SizeOf_s_actor
	LOOP	C_00F4
	;-- --
	CALL	C_16E2
	CALL	C_1490

	MOV	BYTE PTR g_radarOn,0

	CALL	C_0260	;make random position->DH,DL?
	MOV	SI,OFFSET _DATA:D_0B3A	;"raider"
	MOV	DI,OFFSET _DATA:D_0430	;raider
	CALL	SetShipInfos

	CALL	C_02B4	;init enemy[7/8] "big ship"+"turret"
	;-- set palette (g_level&7) --
	MOV	DL,g_level
	AND	DX,7
	SHL	DX,1
	SHL	DX,1
	SHL	DX,1
	SHL	DX,1
	ADD	DX,OFFSET _DATA:D_00DF
	MOV	AX,DS
	MOV	ES,AX
	MOV	AX,(10h SHL 8) OR 2
	INT	10h
	;-- --
	CALL	LevelStartAnim
	CALL	InsideRaider

	MOV	BYTE PTR g_stop_int8,0
	;%%%%%%%%%%%%%%%
	;%% MAIN LOOP %%
	;%%%%%%%%%%%%%%%
C_013D:
	CALL	C_03B2	;call actors refresh callback
	CALL	MainRenderer
	CALL	DoFlip

	CALL	C_0298	;tile animation:enemy "generator"?
	CALL	EnemySpawn
	;****************************
	;*** Manage Inside Raider ***
	;***    Level Cleared     ***
	;***     and Game Over    ***
	;****************************
	;-- controling the raider? --
	MOV	SI,g_pUserShip
	CMP	SI,OFFSET _DATA:D_0430	;raider
	JNZ	C_0183
	;-- yes: raider destroyed->game over --
	CMP	[SI]._active,0
	JNZ	C_015F
	JMP	GameOver
C_015F:
	;-- --
	MOV	AL,g_kbd_cur_scan
	CMP	AL,D_B810[0Bh]	;"control raider"
	JZ	C_0172
	;-- --
	CMP	BYTE PTR g_level_clear,0
	JZ	C_0183
	JMP	LevelClear
	;-- on "R" key:"inside raider" --
C_0172:
	MOV	g_stop_int8,0FFh	;(+nop)

	CALL	InsideRaider

	MOV	g_stop_int8,0	;(+nop)

	JMP	SHORT C_01DA
	;-- --
C_0183:
	;-- current ship destroyed? --
	MOV	SI,g_pUserShip
	CMP	[SI]._active,0
	JNZ	C_01BB
	;-- raider destroyed? --
	CMP	D_0430._active,0
	JNZ	C_0197
	JMP	GameOver
C_0197:
	;-- --
	MOV	g_pUserShip,OFFSET _DATA:D_0430	;raider

	CMP	D_0430._max_frame,0	;raider
	JNZ	C_01DA
	;-- orbital destroyed:"inside raider" --
	MOV	BYTE PTR g_stop_int8,0FFh

	CMP	BYTE PTR g_level_clear,0
	JZ	C_01B3
	JMP	LevelClear
C_01B3:
	CALL	InsideRaider

	MOV	BYTE PTR g_stop_int8,0
	;-- --
C_01BB:
	CMP	BYTE PTR g_docking,0FFh
	JNZ	C_01DA
	;-- docking:"inside raider" --
	MOV	g_stop_int8,0FFh	;(+nop)

	CMP	BYTE PTR g_level_clear,0
	JZ	C_01D2
	JMP	LevelClear	;(+nop)
C_01D2:
	CALL	InsideRaider

	MOV	BYTE PTR g_stop_int8,0
	;-- --
C_01DA:
	;*******************
	;*** manage keys ***
	;*** F10 and F5  ***
	;*******************
	MOV	AL,g_kbd_cur_scan
	;-------------------
	;-- <F10> suicide --
	CMP	AL,44h	;<F10>
	JNZ	C_01F4

	MOV	DI,g_pUserShip
	CALL	DestroyShip

	MOV	DI,OFFSET _DATA:D_0430	;raider
	CMP	DI,g_pUserShip
	JZ	C_01F4

	CALL	DestroyShip
C_01F4:
	;----------------
	;-- <F5> pause --
	CMP	AL,3Fh	;<F5>
	JNZ	C_0209

	MOV	BYTE PTR g_stop_int8,0FFh

C_01FD:
	CALL	GetInputMask_both
	TEST	AL,1Fh
	JZ	C_01FD

	MOV	BYTE PTR g_stop_int8,0
C_0209:
	;-- --
	MOV	BYTE PTR g_kbd_cur_scan,0
	;*********
	;***   ***
	;*********
	;-- synchro: wait int 8 --
C_020E:
	CMP	BYTE PTR g_int8_triggered,0
	JZ	C_020E
	MOV	g_int8_triggered,0	;(+nop)
	;-- --
	JMP	C_013D
	;%%%%%%%%%%%%%%%%%%%
	;%% END MAIN LOOP %%
	;%%%%%%%%%%%%%%%%%%%
;---------------
;-- game over --
;---------------021E
GameOver:
	MOV	BYTE PTR g_stop_int8,0FFh

	WAIT_M	25

	CALL	BonusScreen

	MOV	DX,g_score[2]
	MOV	AX,g_score[0]
	CALL	C_20EB

	WAIT_M	40

	JMP	SplashLoop
;----------------
;-- next level --
;----------------0243
LevelClear:
	MOV	BYTE PTR g_stop_int8,0FFh

	CALL	LevelEndAnim
	CALL	BonusScreen
	;-- level ++ --
	INC	BYTE PTR g_level
	;-- map ++ --
	CMP	BYTE PTR g_map,7
	JZ	C_025D
	INC	BYTE PTR g_map
C_025D:
	;-- --
	JMP	StartLevel
;----------------------------------------
;make random position->DH,DL?
C_0260:
X_0260:
	CALL	Rand
	AND	AL,1Fh
	MOV	DH,AL

	CALL	Rand
	AND	AL,1Fh
	MOV	DL,AL

	MOV	SI,OFFSET _DATA:D_00B5
	MOV	CX,9
C_0274:
	ADD	DL,[SI]
	INC	SI
	ADD	DH,[SI]
	INC	SI
	CALL	C_0282	;get map info at DL,DH
	JNZ	X_0260

	LOOP	C_0274

	RET
;---- ----
;get map info at DL,DH
C_0282:
	AND	DX,(1Fh SHL 8) OR 1Fh
	MOV	BH,DH
	XOR	BL,BL
	SHR	BX,1
	SHR	BX,1
	SHR	BX,1
	ADD	BL,DL
	CMP	BYTE PTR g_tilemap[BX],0

	RET
;----------------------------------------
;tile animation:enemy "generator"?
C_0298:
	MOV	SI,OFFSET _DATA:D_0067
C_029B:
	MOV	BX,[SI]
	ADD	SI,2
	CMP	BX,-1
	JZ	C_02B3
	;cycle [5,6,7]
	MOV	AL,[BX]
	INC	AL
	CMP	AL,8
	JNZ	C_02AF
	MOV	AL,5
C_02AF:
	MOV	[BX],AL

	JMP	C_029B
C_02B3:
	RET
;----------------------------------------
;init enemy[7/8] "big ship"+"turret"
C_02B4:
	CALL	C_0260	;make random position->DH,DL?
	MOV	SI,OFFSET _DATA:D_0C6C	;enemy[7] "big ship"
	MOV	DI,OFFSET _DATA:D_05EA
	CALL	SetShipInfos

	MOV	AX,SizeOf_s_actor
	ADD	SI,AX	;__0C8E:enemy[8] "big ship turret"
	ADD	DI,AX
	CALL	SetShipInfos

	MOV	SI,DI
	SUB	SI,SizeOf_s_actor	;D_05EA

	MOV	AX,[SI]._map_y
	ADD	AX,-4
	AND	AX,7FFh
	MOV	[DI]._map_y,AX

	MOV	AX,[SI]._map_x
	MOV	[DI]._map_x,AX

	RET
;----------------------------------------02E0
EnemySpawn:
	;-- --
	CALL	Rand
	AND	AL,1Fh
	JNZ	C_0343
	;-- --
	MOV	BX,OFFSET _DATA:D_04DA
	MOV	CX,8
	XOR	AH,AH
C_02EF:
	CMP	[BX]._active,0
	JZ	C_02F7
	INC	AH
C_02F7:
	ADD	BX,SizeOf_s_actor
	LOOP	C_02EF
	;-- --
	MOV	BL,g_killTotal
	SHR	BL,1
	SHR	BL,1
	SHR	BL,1
	ADD	BL,g_map
	CMP	BL,8
	JB	C_0311
	MOV	BL,7
C_0311:
	XOR	BH,BH
	MOV	AL,D_00CF[BX]
	CMP	AH,AL
	JNB	C_0344
	SHL	BX,1
	SHL	BX,1
	SHL	BX,1
	SHL	BX,1
	CALL	Rand
	AND	AL,0Eh
	ADD	BL,AL
	MOV	SI,D_0190[BX]
	AND	SI,SI
	JZ	C_0343

	MOV	DI,OFFSET _DATA:D_04DA
	MOV	CX,8
	;
C_0338:
	CMP	[DI]._active,0
	JZ	C_037D
	ADD	DI,SizeOf_s_actor
	LOOP	C_0338
	;-- --
C_0343:
	RET
	;-- --
C_0344:
	MOV	BX,OFFSET _DATA:D_0672
	MOV	CX,8
	XOR	AH,AH
C_034C:
	CMP	[BX]._active,0
	JZ	C_0354
	INC	AH
C_0354:
	ADD	BX,SizeOf_s_actor
	LOOP	C_034C

	MOV	BL,g_map
	XOR	BH,BH
	MOV	AL,D_00D7[BX]
	CMP	AH,AL
	JZ	C_037C

	MOV	SI,OFFSET _DATA:D_0C28	;enemy[5] "mine"

	MOV	DI,OFFSET _DATA:D_0672
	MOV	CX,COUNT_0008	;(+nop)
C_0371:
	CMP	[DI]._active,0
	JZ	C_037D
	ADD	DI,SizeOf_s_actor
	LOOP	C_0371
	;-- --
C_037C:
	RET
	;-- --
C_037D:
	;-- pick "generator" address --
	CALL	Rand
	AND	AX,3
	INC	AX
	MOV	CX,AX
C_0386:
	MOV	BX,OFFSET _DATA:D_0067
C_0389:
	MOV	DX,[BX]
	ADD	BX,2
	CMP	DX,-1
	JZ	C_0386
	LOOP	C_0389

	SUB	DX,OFFSET _DATA:g_tilemap
	MOV	AX,DX
	AND	AL,1Fh
	SHL	DX,1
	SHL	DX,1
	SHL	DX,1
	MOV	DL,AL
	AND	DX,(1Fh SHL 8) OR 1Fh
	CALL	SetShipInfos
	;-- sfx --
	MOV	BX,OFFSET _DATA:D_1195
	JMP	SND_play
	;-- --
;----------------------------------------
;call actors refresh callback
C_03B2:
	MOV	SI,OFFSET _DATA:X_0210
	MOV	CX,45h
C_03B8:
	CMP	[SI]._active,0
	JZ	C_03CB
	MOV	BX,[SI]._p_cb_refresh
	AND	BX,BX
	JZ	C_03CB

	PUSH	SI
	PUSH	CX
	CALL	BX
	POP	CX
	POP	SI
C_03CB:
	ADD	SI,SizeOf_s_actor
	;
	LOOP	C_03B8
	;-- --
	RET
;----------------------------------------
;timer refresh[called by int 8]
C_03D1:
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	SI
	PUSH	DI
	PUSH	BP
	;-- --
	CMP	BYTE PTR g_stop_int8,0
	JNZ	C_0432
	;-- --
	TEST	BYTE PTR g_int8_cnt,3
	JNZ	C_040B
	;-- every 4 ticks --
	MOV	g_int8_triggered,0FFh	;(+nop)
	;-- call actors callback --
	MOV	SI,OFFSET _DATA:X_0210
	;
C_03EF:
	CMP	[SI]._active,0
	JZ	C_0402
	MOV	BX,[SI]._p_cb_control
	AND	BX,BX
	JZ	C_0402

	PUSH	SI
	PUSH	CX
	CALL	BX
	POP	CX
	POP	SI
C_0402:
	ADD	SI,SizeOf_s_actor
	CMP	SI,OFFSET _DATA:X_0B3A
	JB	C_03EF
	;-- --
C_040B:
	TEST	BYTE PTR g_int8_cnt,0FFh
	JNZ	C_0432
	;-- orbitals repair[every 100h ticks] --
	MOV	CX,4
	MOV	BX,OFFSET _DATA:D_0452
C_0418:
	CMP	[BX]._energy,0
	JZ	C_042D
	CMP	[BX]._active,0
	JNZ	C_042D
	CMP	[BX]._energy,48	;max
	JZ	C_042D
	INC	[BX]._energy
C_042D:
	ADD	BX,SizeOf_s_actor
	LOOP	C_0418
	;-- --
C_0432:
	POP	BP
	POP	DI
	POP	SI
	POP	DX
	POP	CX
	POP	BX
	POP	AX
	RET
;----------------------------------------
__043A:
	PUSH	AX	;backup parameter
	MOV	DX,PORT_3C0
	MOV	AL,11h	;overscan color register?
	OUT	DX,AL
	POP	AX	;restore parameter
	OUT	DX,AL

	MOV	AL,20h	;enable display?
	OUT	DX,AL
	OUT	DX,AL

	RET
;----------------------------------------
;ACTORS CALLBACKS
;----------------------------------------0448
CB_REF_destroy_orbital:
	INC	[SI]._frame
	MOV	AL,[SI]._max_frame
	CMP	AL,[SI]._frame
	JNB	C_0464	;set ship's pos to scroll

	MOV	[SI]._active,0
	MOV	[SI]._energy,0

	JMP	SHORT C_0464	;set ship's pos to scroll
;----------------------------------------045D
CB_REF_orbital:
	MOV	SI,g_pUserShip
	CALL	UpdatePos
;----------------------------------------0464
;set ship's pos to scroll
;SI: @
C_0464:
	MOV	AX,[SI]._map_x
	SUB	AX,224
	MOV	DX,[SI]._accel_x
	MOV	CL,7
	SAR	DX,CL
	ADD	AX,DX
	AND	AX,7FFh
	MOV	g_scroll_x,AX

	MOV	AX,[SI]._map_y
	SUB	AX,160
	MOV	DX,[SI]._accel_y
	SAR	DX,CL
	ADD	AX,DX
	AND	AX,7FFh
	MOV	g_scroll_y,AX

	JMP	UpdateScrollInfo
;----------------------------------------048E
CB_CON_orbital:
	MOV	SI,g_pUserShip
	;******************************
	;** manage terrain collision **
	;******************************
	CALL	CollisionTerrainTest
	JNB	C_04D3
	;-- instant destruction? --
	CMP	AH,2
	JB	C_04A1
	MOV	DI,SI
	JMP	DestroyShip
C_04A1:
	;-- --
	CMP	AH,1
	JNZ	C_04B7

	TEST	BYTE PTR g_int8_cnt,6
	JNZ	C_04D3

	;-- take damage --
	DEC	[SI]._energy
	JNZ	C_04D3
	MOV	DI,SI
	JMP	DestroyShip
	;-- --
C_04B7:
	MOV	BL,AL
	XOR	BH,BH
	MOV	BL,D_00C7[BX]
	ADD	BL,[SI]._frame
	AND	BL,0Fh
	MOV	AL,D_0095[BX]
	;

	;-- take damage --
	DEC	[SI]._energy
	JNZ	C_04E1
	MOV	DI,SI
	JMP	DestroyShip
	;-- --
C_04D3:
	;*******
	;**   **
	;*******
	CALL	GetInputMask_both
	TEST	AL,10h
	JZ	C_04E1
	PUSH	AX
	CALL	C_04EB	;orbital shoot!
	POP	AX
	AND	AL,0Fh
C_04E1:
	MOV	[SI]._dir_mask,AL

	CALL	UpdateSpeed
	CALL	UpdateFrame

	RET
;---- ----
;orbital shoot!
C_04EB:
	;-- pick available actor --
	MOV	DI,OFFSET _DATA:D_0782
	MOV	CX,COUNT_0008	;(+nop)
C_04F2:
	CMP	[DI]._active,0
	JZ	C_04FE
	ADD	DI,SizeOf_s_actor
	LOOP	C_04F2

	RET
C_04FE:
	;-- --
	MOV	BL,[SI]._frame
	MOV	[DI]._frame,BL
	XOR	BH,BH
	SHL	BX,1
	SHL	BX,1

	MOV	AX,D_1031[BX]
	MOV	[DI]._accel_x,AX

	MOV	AX,D_1031[BX+02]
	MOV	[DI]._accel_y,AX

	SHL	BX,1
	OR	BL,D_0D30
	XOR	BYTE PTR D_0D30,4
	ADD	BX,OFFSET _DATA:D_0CB0

	MOV	AX,[SI]._map_x
	ADD	AX,[BX+00]
	AND	AX,7FFh
	MOV	[DI]._map_x,AX

	MOV	AX,[SI]._map_y
	ADD	AX,[BX+02]
	AND	AX,7FFh
	MOV	[DI]._map_y,AX

	XOR	AX,AX
	MOV	[DI]._p_spr,OFFSET _DATA:D_B982
	MOV	[DI]._speed_x,AX
	MOV	[DI]._speed_y,AX
	MOV	[DI]._dir_mask,AL
	MOV	[DI]._max_frame,AL

	MOV	[DI]._typ4radar,10
	MOV	[DI]._thcounter,15
	MOV	[DI]._shoot_typ,1
	MOV	[DI]._p_cb_refresh,OFFSET _TEXT:CB_REF_shoot_orbital
	MOV	[DI]._p_cb_control,OFFSET _TEXT:CB_CON_shoot_orbital
	MOV	[DI]._active,0FFh
	;-- sfx --
	MOV	BX,OFFSET _DATA:D_1171
	CALL	SND_play
	;-- --
	RET
;----------------------------------------0570
CB_REF_raider:
	CALL	CheckDocking
	CALL	UpdatePos
	;-- --
	CMP	SI,g_pUserShip
	JNZ	C_057F
	CALL	C_0464	;set ship's pos to scroll
C_057F:
	;-- --
	CALL	CheckGems

	RET
;---- ----0583
CheckDocking:
	PUSH	SI
	;-- --
	MOV	SI,g_pUserShip
	MOV	DI,OFFSET _DATA:D_0430	;raider
	CMP	SI,DI
	JZ	C_05C7
	;-- some delay before check --
	CMP	BYTE PTR g_docking,0
	JZ	C_059C

	DEC	BYTE PTR g_docking

	JMP	SHORT C_05C7
C_059C:
	;-- --
	MOV	AX,[DI]._accel_x
	OR	AX,[DI]._accel_y
	JNZ	C_05C7

	MOV	AL,[SI]._frame
	SUB	AL,[DI]._frame
	JNB	C_05AE
	NEG	AL
C_05AE:
	CMP	AL,2
	JNB	C_05C7
	ADD	[DI]._frame,10h

	CALL	CollisionTest
	JNB	C_05C0
	MOV	BYTE PTR g_docking,0FFh	;docked!
C_05C0:

	MOV	DI,OFFSET _DATA:D_0430	;raider
	SUB	[DI]._frame,10h
	;-- --
C_05C7:
	POP	SI
	RET
;----------------------------------------05C9
CB_CON_raider:
	CMP	SI,g_pUserShip
	JNZ	C_05E4

	CALL	GetInputMask_orbital
	MOV	D_0042,AL
	MOV	DL,AL	;unused?
	TEST	AL,10h
	JZ	C_05E4

	MOV	BYTE PTR D_0042,0

	AND	AL,0Fh
	JNZ	C_05EB
C_05E4:
	CALL	GetInputMask_raider
	;----
	;note: when using the "stop raider" key
	; bit 5 is set, then _dir_mask is set to 0
	; which causes the raider to stop.
	;----
	TEST	AL,1Fh
	JZ	C_05F0
C_05EB:
	AND	AL,0Fh
	MOV	[SI]._dir_mask,AL
C_05F0:
	;******************************
	;** manage terrain collision **
	;******************************
	CALL	CollisionTerrainTest
	JNB	C_062A
	;-- --
	;
	;
	;
	;
	;
	;-- --
	CMP	AH,1
	JNZ	C_060B

	TEST	BYTE PTR g_int8_cnt,0Eh
	JNZ	C_062A

	;-- take damage --
	DEC	[SI]._energy
	JNZ	C_062A
	MOV	DI,SI
	JMP	DestroyShip
	;-- --
C_060B:
	MOV	BL,AL
	XOR	BH,BH
	MOV	BL,D_00C7[BX]
	ADD	BL,[SI]._frame
	AND	BL,0Fh
	MOV	AL,D_0095[BX]
	MOV	[SI]._dir_mask,AL

	;-- take damage --
	DEC	[SI]._energy
	JNZ	C_062A
	MOV	DI,SI
	JMP	DestroyShip
	;-- --
C_062A:
	;*******
	;**   **
	;*******
	CALL	Deceleration_raider
	CALL	UpdateSpeed
	CALL	UpdateFrame

	THINK_M

	MOV	AL,[SI]._frame
	SHR	AL,1
	AND	AL,7
	MOV	[SI]._typ4radar,AL

	MOV	AL,D_0042
	AND	AL,0Fh
	JZ	C_0659
	MOV	BL,AL
	XOR	BH,BH
	MOV	AL,D_00A5[BX]
	CMP	AL,0FFh
	JNZ	C_065A
C_0659:
	RET
C_065A:
	CMP	SI,g_pUserShip
	JZ	C_066B
	ADD	AL,4
	AND	AL,7
	CMP	[SI]._thcounter,0
	JZ	C_066B

	RET
C_066B:
	MOV	BYTE PTR D_0042,0

	MOV	BL,[SI]._frame
	TEST	BL,1
	JNZ	C_069A
	SHL	BX,1
	SHL	BX,1
	ADD	BL,AL
	SHL	BX,1
	SHL	BX,1
	SHL	BX,1
	ADD	BX,OFFSET _DATA:D_0E31
	;-- pick available actor --
	MOV	DI,OFFSET _DATA:D_0892
	MOV	CX,COUNT_0004	;(+nop)
C_068F:
	CMP	[DI]._active,0
	JZ	C_069B
	ADD	DI,SizeOf_s_actor
	LOOP	C_068F
C_069A:
	RET
C_069B:
	;-- --
	MOV	AX,WORD PTR [BX]._shot_dir
	CMP	AL,8
	JNB	C_069A

	MOV	[DI].p_shootXY,BX
	MOV	[DI]._shoot_typ,AH
	MOV	AH,AL
	SHL	AL,1
	ADD	AH,AL
	MOV	[DI]._frame,AH
	ADD	AH,2
	MOV	[DI].f_1b,AH

	MOV	CX,[BX]._p_shot_spr
	MOV	[DI]._p_spr,CX

	MOV	CX,[BX+00]	;shoot base x
	ADD	CX,[SI]._map_x
	AND	CX,7FFh
	MOV	[DI]._map_x,CX

	MOV	CX,[BX+02]	;shoot base y
	ADD	CX,[SI]._map_y
	AND	CX,7FFh
	MOV	[DI]._map_y,CX

	XOR	AH,AH
	MOV	BX,AX
	SHL	BX,1
	SHL	BX,1

	MOV	AX,D_1031[BX]
	MOV	[DI]._accel_x,AX

	MOV	AX,D_1031[BX+02]
	MOV	[DI]._accel_y,AX

	XOR	AX,AX
	MOV	[DI]._speed_x,AX
	MOV	[DI]._speed_y,AX
	MOV	[DI]._max_frame,AL

	MOV	[DI]._thcounter,13
	MOV	[SI]._thcounter,6
	MOV	[DI]._typ4radar,10
	MOV	AL,[SI]._frame
	MOV	[DI]._dir_mask,AL
	MOV	[DI]._p_cb_refresh,OFFSET _TEXT:CB_REF_shoot_generic
	MOV	[DI]._p_cb_control,OFFSET _TEXT:CB_CON_shoot_raider
	MOV	[DI]._active,0FFh
	;-- sfx --
	CMP	SI,g_pUserShip
	JZ	C_071C
	RET
C_071C:
	MOV	BX,OFFSET _DATA:D_117D
	JMP	SND_play
	;-- --
;---- ----0722
Deceleration_raider:
	MOV	AL,[SI]._dir_mask
	;-- x acceleration --
	TEST	AL,3
	JNZ	C_0748
	;-- --
	MOV	DX,[SI]._accel_x
	AND	DX,DX
	JZ	C_0748
	TEST	DH,80h
	JZ	C_073E
	ADD	DX,64
	JNB	C_0745

	XOR	DX,DX
	JMP	SHORT C_0745
C_073E:
	SUB	DX,64
	JNB	C_0745

	XOR	DX,DX
C_0745:
	MOV	[SI]._accel_x,DX
C_0748:
	;-- y acceleration --
	TEST	AL,0Ch
	JNZ	C_076B
	;-- --
	MOV	DX,[SI]._accel_y
	AND	DX,DX
	JZ	C_076B
	TEST	DH,80h
	JZ	C_0761
	ADD	DX,64
	JNB	C_0768

	XOR	DX,DX
	JMP	SHORT C_0768
C_0761:
	SUB	DX,64
	JNB	C_0768

	XOR	DX,DX
C_0768:
	MOV	[SI]._accel_y,DX
C_076B:
	;-- --
	RET
;----------------------------------------076C
CB_CON_shoot_raider:
	MOV	AL,[SI]._frame
	CMP	AL,[SI].f_1b
	JZ	C_079C

	MOV	AL,[SI]._dir_mask
	CMP	AL,D_0430._frame	;raider
	JNZ	C_07B5

	MOV	BX,[SI].p_shootXY
	MOV	DI,OFFSET _DATA:D_0430	;raider

	MOV	CX,[BX+00]	;shoot base x
	ADD	CX,[DI]._map_x
	AND	CX,7FFh
	MOV	[SI]._map_x,CX

	MOV	CX,[BX+02]	;shoot base y
	ADD	CX,[DI]._map_y
	AND	CX,7FFh
	MOV	[SI]._map_y,CX

	JMP	SHORT C_07B9
C_079C:
	MOV	AX,[SI]._accel_x
	ADD	[SI]._speed_x,AX

	MOV	AX,[SI]._accel_y
	ADD	[SI]._speed_y,AX

	CALL	UpdatePos
	
	CALL	CollisionWEnemy
	JB	C_07BA
	
	DEC	[SI]._thcounter
	JNZ	C_07B9
C_07B5:
	MOV	[SI]._active,0
C_07B9:
	RET
	;-- --
C_07BA:
	JMP	DoCollision
;----------------------------------------07BD
CB_REF_destroy_raider:
	CMP	[SI]._thcounter,1
	JZ	C_07D3
	JB	C_07E4
	;-- --
	CALL	C_07F0	;check active orbital?
	AND	BX,BX
	JZ	C_07E7

	CALL	C_0805
	DEC	[SI]._thcounter

	RET
C_07D3:	;-- think counter is 1 --
	DEC	[SI]._thcounter

	MOV	[SI]._frame,0
	MOV	[SI]._p_spr,OFFSET _DATA:D_D120
	MOV	[SI]._max_frame,9

	RET
C_07E4:	;-- think counter is 0 --
	CALL	CB_REF_destroy_raider_2
	;-- --
C_07E7:
	CMP	SI,g_pUserShip
	JNZ	C_0804
	JMP	C_0464	;set ship's pos to scroll
;---- ----
;check active orbital?
C_07F0:
	MOV	CX,COUNT_0004	;(+nop)
	MOV	BX,OFFSET _DATA:D_0892
C_07F7:
	CMP	[BX]._active,0
	JZ	C_0804
	ADD	BX,SizeOf_s_actor
	LOOP	C_07F7

	XOR	BX,BX
C_0804:
	RET
;---- ----
C_0805:
	CALL	Rand
	TEST	AL,80h
	JZ	C_0858

	MOV	DX,OFFSET _DATA:D_D244
	MOV	CL,7
	TEST	AL,40h
	JZ	C_081A
	MOV	DX,OFFSET _DATA:D_D2C6
	MOV	CL,09
C_081A:
	MOV	[BX]._p_spr,DX
	MOV	[BX]._max_frame,CL
	MOV	[BX]._frame,0
	CALL	Rand
	MOV	DL,AH

	AND	AX,1Fh
	SUB	AX,0Fh
	ADD	AX,[SI]._map_x
	AND	AX,7FFh
	MOV	[BX]._map_x,AX

	AND	DX,1Fh
	SUB	DX,0Fh
	ADD	DX,[SI]._map_y
	AND	DX,7FFh
	MOV	[BX]._map_y,DX

	MOV	[BX]._p_cb_control,0
	MOV	[BX]._typ4radar,0FFh
	MOV	[BX]._p_cb_refresh,OFFSET _TEXT:CB_REF_destroy_raider_2
	MOV	[BX]._active,0FFh
C_0858:
	RET
;---- ----0859
CB_REF_destroy_raider_2:
	INC	[SI]._frame
	MOV	AL,[SI]._max_frame
	CMP	AL,[SI]._frame
	JNB	C_0868
	MOV	[SI]._active,0
C_0868:
	RET
;----------------------------------------0869
CB_REF_shoot_orbital:
	CALL	CollisionTerrainTest
	CMP	AH,2
	JB	C_0874
	JMP	DoTerrainCollision	;(+nop)
C_0874:
	RET
;----------------------------------------0875
CB_CON_shoot_orbital:
	CALL	CollisionWEnemy
	JB	DoCollision

	CALL	UpdateSpeed
	CALL	UpdatePos
	;-- --
	DEC	[SI]._thcounter
	JNZ	C_0889
	MOV	[SI]._active,0
C_0889:
	;-- --
	RET
;----------------------------------------088A
;SI: @
DoCollision:
	MOV	[SI]._p_cb_control,0
	MOV	[SI]._frame,0
	MOV	[SI]._max_frame,5
	MOV	[SI]._p_spr,OFFSET _DATA:D_D368
	MOV	[SI]._p_cb_refresh,OFFSET _TEXT:CB_REF_collision

	CMP	[SI]._shoot_typ,5
	JNZ	C_08B0
	MOV	[SI]._max_frame,8
	MOV	[SI]._p_spr,OFFSET _DATA:D_D244
C_08B0:

	MOV	AL,[SI]._shoot_typ
	CMP	AL,5
	JNZ	C_08B9
	MOV	AL,8
C_08B9:
	;-- take damage --
	SUB	[DI]._energy,AL
	JA	C_08C5
	MOV	[DI]._energy,0
	JMP	DestroyShip
C_08C5:
	RET
;---- ----08C6
;SI: @
DoTerrainCollision:
	MOV	[SI]._p_cb_control,0
	MOV	[SI]._frame,0
	;
	MOV	[SI]._p_spr,OFFSET _DATA:D_D368
	MOV	[SI]._p_cb_refresh,OFFSET _TEXT:CB_REF_collision

	RET
;---- ----08DA
CB_REF_collision:
	INC	[SI]._frame
	MOV	AL,[SI]._frame
	CMP	AL,[SI]._max_frame
	JBE	C_08E9
	MOV	[SI]._active,0
C_08E9:
	RET
;----------------------------------------08EA
CB_REF_enemy0:
	CMP	[SI]._thcounter,0
	JNZ	C_0940

	CALL	C_0FB8	;aim player related?
	JB	C_0900
	CALL	AimOrbital_near
	MOV	AH,0FFh
	JB	C_0900

	MOV	DL,3Fh
	JMP	SHORT C_0941	;(AL:dir_mask,DL:counter_mask)?
C_0900:
	MOV	[SI]._dir_mask,AL
	AND	AH,AH
	JZ	C_0940
	MOV	BL,AL
	XOR	BH,BH
	MOV	AL,[SI]._frame
	SHR	AL,1
	CMP	AL,D_0071[BX]
	JNZ	C_0940
	CMP	[SI]._thcounter,0
	JNZ	C_0940
	CALL	StartShoot
	JB	C_0940
	MOV	AL,[SI]._frame
	AND	AL,0Eh
	;
	SHL	AL,1
	;
	MOV	[DI]._frame,AL
	ADD	AL,3
	MOV	[DI].f_1b,AL

	MOV	BX,OFFSET _DATA:D_0D51
	MOV	[DI]._p_spr,OFFSET _DATA:D_BDA2
	MOV	AX,(4 SHL 8) OR 0Dh
	MOV	DL,2
	CALL	MakeShoot
C_0940:
	RET
;----------------------------------------0941
;(AL:dir_mask,DL:counter_mask)?
C_0941:
	;-- --
	CMP	[SI]._thcounter,0
	JNZ	C_0956
	CALL	Rand
	AND	AL,DL
	SHR	DL,1
	ADD	AL,DL
	MOV	[SI]._thcounter,AL

	CALL	Rand
C_0956:
	;-- --
	MOV	[SI]._dir_mask,AL

	RET
;----------------------------------------095A
CB_CON_enemy0:
	TEST	[SI]._thcounter,80h
	JNZ	C_098B
	CALL	CollisionTerrainTest
	CMP	AH,2
	JB	C_098B

	MOV	BL,AL
	XOR	BH,BH
	MOV	BL,D_00C7[BX]
	ADD	BL,[SI]._frame
	AND	BL,0Fh
	MOV	AL,D_0095[BX]
	MOV	[SI]._dir_mask,AL

	MOV	[SI]._thcounter,86h
	MOV	[SI]._accel_x,0
	MOV	[SI]._accel_y,0
C_098B:
	CALL	Deceleration_enemy
	CALL	UpdateSpeed
	CALL	UpdateFrame
	CALL	UpdatePos
	;-- --
	CMP	[SI]._thcounter,80h
	JNZ	C_09A1
	MOV	[SI]._thcounter,30
C_09A1:
	;-- --
	THINK_M

	RET
;----------------------------------------09AB
CB_REF_enemy2:
	CMP	[SI]._thcounter,0
	JNZ	C_0A05

	CALL	C_0FB8	;aim player related?
	JB	C_09C1
	CALL	AimOrbital_near
	MOV	AH,0FFh
	JB	C_09C1

	MOV	DL,3Fh
	JMP	C_0941	;(AL:dir_mask,DL:counter_mask)?
C_09C1:
	MOV	[SI]._dir_mask,AL
	AND	AH,AH
	JZ	C_0A05
	MOV	BL,AL
	XOR	BH,BH
	MOV	AL,[SI]._frame
	SHR	AL,1
	CMP	AL,D_0071[BX]
	JNZ	C_0A05
	CMP	[SI]._thcounter,0
	JNZ	C_0A05
	CALL	StartShoot
	JB	C_0A05
	MOV	AL,[SI]._frame
	AND	AL,0Eh
	MOV	AH,AL
	SHR	AL,1
	ADD	AL,AH
	MOV	[DI]._frame,AL
	ADD	AL,2
	MOV	[DI].f_1b,AL

	MOV	BX,OFFSET _DATA:D_0D71
	MOV	[DI]._p_spr,OFFSET _DATA:D_C342
	MOV	AX,(4 SHL 8) OR 0Dh
	MOV	DL,2
	CALL	MakeShoot
C_0A05:
	RET
;----------------------------------------0A06
CB_CON_enemy2:
	TEST	[SI]._thcounter,80h
	JNZ	C_0A37
	CALL	CollisionTerrainTest
	CMP	AH,2
	JB	C_0A37

	MOV	BL,AL
	XOR	BH,BH
	MOV	BL,D_00C7[BX]
	ADD	BL,[SI]._frame
	AND	BL,0Fh
	MOV	AL,D_0095[BX]
	MOV	[SI]._dir_mask,AL

	MOV	[SI]._thcounter,86h
	MOV	[SI]._accel_x,0
	MOV	[SI]._accel_y,0
C_0A37:
	CALL	Deceleration_enemy
	CALL	UpdateSpeed
	CALL	UpdateFrame
	CALL	UpdatePos
	;-- --
	CMP	[SI]._thcounter,80h
	JNZ	C_0A4D
	MOV	[SI]._thcounter,30
C_0A4D:
	;-- --
	THINK_M

	RET
;----------------------------------------0A57
CB_REF_enemy1:
	CMP	[SI]._thcounter,0
	JNZ	C_0AB2

	CALL	C_0FB8	;aim player related?
	JB	C_0A6E
	CALL	AimOrbital_near
	MOV	AH,0FFh
	JB	C_0A6E

	MOV	DL,1Fh
	JMP	C_0941	;(AL:dir_mask,DL:counter_mask)?
C_0A6E:
	MOV	[SI]._dir_mask,AL
	AND	AH,AH
	JZ	C_0AB2
	MOV	BL,AL
	XOR	BH,BH
	MOV	AL,[SI]._frame
	SHR	AL,1
	CMP	AL,D_0071[BX]
	JNZ	C_0AB2
	CMP	[SI]._thcounter,0
	JNZ	C_0AB2
	CALL	StartShoot
	JB	C_0AB2
	MOV	AL,[SI]._frame
	AND	AL,0Eh
	MOV	AH,AL
	SHR	AL,1
	ADD	AL,AH
	MOV	[DI]._frame,AL
	ADD	AL,2
	MOV	[DI].f_1b,AL

	MOV	BX,OFFSET _DATA:D_0D91
	MOV	[DI]._p_spr,OFFSET _DATA:D_C0B2
	MOV	AX,(3 SHL 8) OR 0Dh
	MOV	DL,1
	CALL	MakeShoot
C_0AB2:
	RET
;----------------------------------------0AB3
CB_CON_enemy1:
	TEST	[SI]._thcounter,80h
	JNZ	C_0AE4
	CALL	CollisionTerrainTest
	CMP	AH,2
	JB	C_0AE4

	MOV	BL,AL
	XOR	BH,BH
	MOV	BL,D_00C7[BX]
	ADD	BL,[SI]._frame
	AND	BL,0Fh
	MOV	AL,D_0095[BX]
	MOV	[SI]._dir_mask,AL

	MOV	[SI]._thcounter,86h
	MOV	[SI]._accel_x,0
	MOV	[SI]._accel_y,0
C_0AE4:
	CALL	Deceleration_enemy
	CALL	UpdateSpeed
	CALL	UpdateFrame
	CALL	UpdatePos
	;-- --
	CMP	[SI]._thcounter,80h
	JNZ	C_0AFA
	MOV	[SI]._thcounter,30
C_0AFA:
	;-- --
	THINK_M

	RET
;----------------------------------------0B04
CB_REF_enemy3:
	CMP	[SI]._thcounter,0
	JNZ	C_0B5F

	CALL	C_0FB8	;aim player related?
	JB	C_0B1B
	CALL	AimOrbital_near
	MOV	AH,0FFh
	JB	C_0B1B

	MOV	AL,1Fh
	JMP	C_0941	;(AL:dir_mask,DL:counter_mask)?
C_0B1B:
	MOV	[SI]._dir_mask,AL
	AND	AH,AH
	JZ	C_0B5F
	MOV	BL,AL
	XOR	BH,BH
	MOV	AL,[SI]._frame
	SHR	AL,1
	CMP	AL,D_0071[BX]
	JNZ	C_0B5F
	CMP	[SI]._thcounter,0
	JNZ	C_0B5F
	CALL	StartShoot
	JB	C_0B5F
	MOV	AL,[SI]._frame
	AND	AL,0Eh
	MOV	AH,AL
	SHR	AL,1
	ADD	AL,AH
	MOV	[DI]._frame,AL
	ADD	AL,2
	MOV	[DI].f_1b,AL

	MOV	BX,OFFSET _DATA:D_0DB1
	MOV	[DI]._p_spr,OFFSET _DATA:D_C5D2
	MOV	AX,(3 SHL 8) OR 0Dh
	MOV	DL,1
	CALL	MakeShoot
C_0B5F:
	RET
;----------------------------------------0B60
CB_CON_enemy3:
	TEST	[SI]._thcounter,80h
	JNZ	C_0B91
	CALL	CollisionTerrainTest
	CMP	AH,2
	JB	C_0B91

	MOV	BL,AL
	XOR	BH,BH
	MOV	BL,D_00C7[BX]
	ADD	BL,[SI]._frame
	AND	BL,0Fh
	MOV	AL,D_0095[BX]
	MOV	[SI]._dir_mask,AL

	MOV	[SI]._thcounter,86h
	MOV	[SI]._accel_x,0
	MOV	[SI]._accel_y,0
C_0B91:
	CALL	Deceleration_enemy
	CALL	UpdateSpeed
	CALL	UpdateFrame
	CALL	UpdatePos
	;-- --
	CMP	[SI]._thcounter,80h
	JNZ	C_0BA7
	MOV	[SI]._thcounter,30
C_0BA7:
	;-- --
	THINK_M

	RET
;----------------------------------------0BB1
CB_REF_enemy4:
	CMP	[SI]._thcounter,0
	JNZ	C_0C0C

	CALL	C_0FB8	;aim player related?
	JB	C_0BC8
	CALL	AimOrbital_near
	MOV	AH,0FFh
	JB	C_0BC8

	MOV	DL,1Fh
	JMP	C_0941	;(AL:dir_mask,DL:counter_mask)?
C_0BC8:
	MOV	[SI]._dir_mask,AL
	AND	AH,AH
	JZ	C_0C0C
	MOV	BL,AL
	XOR	BH,BH
	MOV	AL,[SI]._frame
	SHR	AL,1
	CMP	AL,D_0071[BX]
	JNZ	C_0C0C
	CMP	[SI]._thcounter,0
	JNZ	C_0C0C
	CALL	StartShoot
	JB	C_0C0C
	MOV	AL,[SI]._frame
	AND	AL,0Eh
	MOV	AH,AL
	SHR	AL,1
	ADD	AL,AH
	MOV	[DI]._frame,AL
	ADD	AL,2
	MOV	[DI].f_1b,AL

	MOV	BX,OFFSET _DATA:D_0DD1
	MOV	[DI]._p_spr,OFFSET _DATA:D_C862
	MOV	AX,(4 SHL 8) OR 0Dh
	MOV	DL,2
	CALL	MakeShoot
C_0C0C:
	RET
;----------------------------------------0C0D
CB_CON_enemy4:
	TEST	[SI]._thcounter,80h
	JNZ	C_0C3E
	CALL	CollisionTerrainTest
	CMP	AH,2
	JB	C_0C3E

	MOV	BL,AL
	XOR	BH,BH
	MOV	BL,D_00C7[BX]
	ADD	BL,[SI]._frame
	AND	BL,0Fh
	MOV	AL,D_0095[BX]
	MOV	[SI]._dir_mask,AL

	MOV	[SI]._thcounter,86h
	MOV	[SI]._accel_x,0
	MOV	[SI]._accel_y,0
C_0C3E:
	CALL	Deceleration_enemy
	CALL	UpdateSpeed
	CALL	UpdateFrame
	CALL	UpdatePos
	;-- --
	CMP	[SI]._thcounter,80h
	JNZ	C_0C54
	MOV	[SI]._thcounter,30
C_0C54:
	;-- --
	THINK_M

	RET
;----------------------------------------0C5E
;"big ship"
CB_REF_enemy7:
	MOV	DL,0FFh
	JMP	C_0941	;(AL:dir_mask,DL:counter_mask)?
__0C63:
	RET
;----------------------------------------0C64
;"big ship turret"
CB_REF_enemy8:
	CALL	AimRaider_near
	JB	C_0C6E
	CALL	AimOrbital_near
	JNB	C_0C80
C_0C6E:
	MOV	BL,AL
	XOR	BH,BH
	MOV	AL,D_0071[BX]
	SHL	AL,1
	CMP	AL,[SI]._frame
	JZ	C_0C81
	MOV	[SI]._frame,AL
C_0C80:
	RET
C_0C81:
	CMP	[SI]._thcounter,0
	JNZ	C_0CAB
	CALL	StartShoot
	JB	C_0CAB
	MOV	AL,[SI]._frame
	AND	AL,0Eh
	;
	SHL	AL,1
	;
	MOV	[DI]._frame,AL
	ADD	AL,3
	MOV	[DI].f_1b,AL

	MOV	BX,OFFSET _DATA:D_0E11
	MOV	[DI]._p_spr,OFFSET _DATA:D_CE84
	MOV	AX,(9 SHL 8) OR 0Dh
	MOV	DL,4
	JMP	MakeShoot
C_0CAB:
	RET
;----------------------------------------0CAC
;"big ship"
CB_CON_enemy7:
	CALL	CollisionTerrainTest
	JNB	C_0CCB
	CMP	AH,1
	JZ	C_0CCB

	MOV	BL,AL
	XOR	BH,BH
	MOV	BL,D_00C7[BX]
	ADD	BL,[SI]._frame
	AND	BL,0Fh
	MOV	AL,D_0095[BX]
	MOV	[SI]._dir_mask,AL
	
C_0CCB:
	CALL	Deceleration_enemy
	CALL	UpdateSpeed
	CALL	UpdateFrame
	CALL	UpdatePos

	THINK_M

	MOV	BL,[SI]._frame
	AND	BX,0Eh
	SHL	BX,1

	MOV	AX,D_0DF1[BX+00]
	ADD	AX,[SI]._map_x
	AND	AX,7FFh
	MOV	[SI+SizeOf_s_actor]._map_x,AX

	MOV	AX,D_0DF1[BX+02]
	ADD	AX,[SI]._map_y
	AND	AX,7FFh
	MOV	[SI+SizeOf_s_actor]._map_y,AX

	RET
;----------------------------------------0D02
;"big ship turret"
CB_CON_enemy8:
	THINK_M

	CMP	[SI-SizeOf_s_actor]._max_frame,0
	JZ	C_0D15
	MOV	[SI]._active,0
C_0D15:
	RET
;----------------------------------------0D16
;"fixed turret"
CB_REF_enemy6:
	CMP	[SI]._thcounter,0
	JNZ	C_0D49

	CALL	AimRaider_near
	JB	C_0D26
	CALL	AimOrbital_near
	JNB	C_0D49
C_0D26:
	MOV	BL,AL
	XOR	BH,BH
	MOV	AL,D_0071[BX]
	MOV	AH,[SI]._frame
	SHL	AL,1
	SUB	AL,AH
	JZ	C_0D4A
	DEC	AH
	AND	AL,0Fh
	SUB	AL,8
	JNB	C_0D43
	INC	AH
	INC	AH
C_0D43:
	AND	AH,0Fh
	MOV	[SI]._frame,AH
C_0D49:
	RET
C_0D4A:
	CALL	StartShoot
	JB	C_0D72
	MOV	AL,[SI]._frame
	AND	AL,0Eh
	MOV	AH,AL
	SHR	AL,1
	ADD	AL,AH
	MOV	[DI]._frame,AL
	ADD	AL,2
	MOV	[DI].f_1b,AL

	MOV	BX,OFFSET _DATA:D_0D31
	MOV	[DI]._p_spr,OFFSET _DATA:D_CAF2
	MOV	AX,(6 SHL 8) OR 19h
	MOV	DL,3
	JMP	MakeShoot	;(+nop)
C_0D72:
	RET
;----------------------------------------0D73
;"fixed turret"
CB_CON_enemy6:
	THINK_M

	RET
;----------------------------------------0D7D
;"mine"
CB_REF_enemy5:
	MOV	AL,[SI]._frame
	INC	AL
	CMP	AL,8
	JNZ	C_0D88
	MOV	AL,4
C_0D88:
	MOV	[SI]._frame,AL
	CALL	CollisionTerrainTest
	CMP	AH,2
	JB	C_0DB6

	MOV	BL,AL
	XOR	BH,BH
	MOV	BL,D_00C7[BX]
	ADD	BL,[SI]._frame
	AND	BL,0Fh
	MOV	AL,D_0095[BX]
	MOV	[SI]._dir_mask,AL

	MOV	[SI]._thcounter,7
	MOV	[SI]._accel_x,0
	MOV	[SI]._accel_y,0
C_0DB6:
	CALL	AimOrbital_far
	JB	C_0DBE
	JMP	C_0941	;(AL:dir_mask,DL:counter_mask)?
C_0DBE:
	MOV	[SI]._dir_mask,AL

	RET
;----------------------------------------0DC2
;"mine"
CB_CON_enemy5:
	CALL	Deceleration_enemy
	CALL	UpdateSpeed
	CALL	UpdatePos
	;-- --
	CALL	CollisionWPlayer
	JNB	C_0DD3
	JMP	DoCollision
C_0DD3:
	;-- --
	RET
;----------------------------------------0DD4
StartShoot:
	MOV	DI,OFFSET _DATA:D_091A
	MOV	CX,COUNT_0010	;(+nop)
C_0DDB:
	CMP	[DI]._active,0
	JZ	C_0DE7
	ADD	DI,SizeOf_s_actor
	LOOP	C_0DDB

	STC
C_0DE7:
	RET
;----------------------------------------0DE8
;DI: @
;SI: @
;BX: @{x,y}
;AH:
;AL:
;DL:
MakeShoot:
	MOV	[DI].f_1e,SI
	MOV	[DI].p_shootXY,BX
	MOV	[SI]._thcounter,AH
	MOV	[DI]._thcounter,AL
	MOV	[DI]._shoot_typ,DL

	XOR	AX,AX
	MOV	[DI]._speed_x,AX
	MOV	[DI]._speed_y,AX
	MOV	[DI]._max_frame,AL

	MOV	[DI]._typ4radar,10
	MOV	AL,[SI]._frame
	AND	AL,0Eh
	XOR	AH,AH
	SHL	AX,1
	ADD	BX,AX

	MOV	AX,[BX+00]	;shoot base x
	ADD	AX,[SI]._map_x
	AND	AX,7FFh
	MOV	[DI]._map_x,AX

	MOV	AX,[BX+02]	;shoot base y
	ADD	AX,[SI]._map_y
	AND	AX,7FFh
	MOV	[DI]._map_y,AX

	MOV	[DI]._p_cb_refresh,OFFSET _TEXT:CB_REF_shoot_generic
	MOV	[DI]._p_cb_control,OFFSET _TEXT:CB_CON_shoot_other
	MOV	[DI]._active,0FFh

	RET
;----------------------------------------0E35
CB_REF_shoot_generic:
	MOV	AL,[SI]._frame
	CMP	AL,[SI].f_1b
	JNZ	C_0E48
	CALL	CollisionTerrainTest
	CMP	AH,2
	JB	C_0E4B
	JMP	DoTerrainCollision
C_0E48:
	INC	[SI]._frame
C_0E4B:
	RET
;----------------------------------------0E4C
CB_CON_shoot_other:
	MOV	AL,[SI]._frame
	CMP	AL,[SI].f_1b
	JZ	C_0E90

	MOV	BX,[SI].p_shootXY
	MOV	DI,[SI].f_1e
	MOV	AL,[DI]._frame
	AND	AL,0Eh
	XOR	AH,AH
	SHL	AX,1
	ADD	BX,AX
	SHL	AX,1

	MOV	CX,[BX+00]	;shoot base x
	ADD	CX,[DI]._map_x
	AND	CX,7FFh
	MOV	[SI]._map_x,CX

	MOV	CX,[BX+02]	;shoot base y
	ADD	CX,[DI]._map_y
	AND	CX,7FFh
	MOV	[SI]._map_y,CX

	MOV	BX,OFFSET _DATA:D_1031
	ADD	BX,AX

	MOV	AX,[BX]
	MOV	[SI]._accel_x,AX

	MOV	AX,[BX+02]
	MOV	[SI]._accel_y,AX

	JMP	SHORT C_0EAD
C_0E90:
	MOV	AX,[SI]._accel_x
	ADD	[SI]._speed_x,AX

	MOV	AX,[SI]._accel_y
	ADD	[SI]._speed_y,AX

	CALL	UpdatePos

	CALL	CollisionWPlayer
	JB	C_0EAE

	DEC	[SI]._thcounter
	JNZ	C_0EAD
	;
	MOV	[SI]._active,0
C_0EAD:
	RET
	;-- --
C_0EAE:
	JMP	DoCollision
;----------------------------------------0EB1
Deceleration_enemy:
	MOV	AL,[SI]._dir_mask
	;-- x acceleration --
	TEST	AL,3
	JNZ	C_0ED7
	;-- --
	MOV	DX,[SI]._accel_x
	AND	DX,DX
	JZ	C_0ED7
	TEST	DH,80h
	JZ	C_0ECD
	ADD	DX,16
	JNB	C_0ED4

	XOR	DX,DX
	JMP	SHORT C_0ED4
C_0ECD:
	SUB	DX,16
	JNB	C_0ED4

	XOR	DX,DX
C_0ED4:
	MOV	[SI]._accel_x,DX
C_0ED7:
	;-- y acceleration --
	TEST	AL,0Ch
	JNZ	C_0EFA
	;-- --
	MOV	DX,[SI]._accel_y
	AND	DX,DX
	JZ	C_0EFA
	TEST	DH,80h
	JZ	C_0EF0
	ADD	DX,16
	JNB	C_0EF7

	XOR	DX,DX
	JMP	SHORT C_0EF7
C_0EF0:
	SUB	DX,16
	JNB	C_0EF7

	XOR	DX,DX
C_0EF7:
	MOV	[SI]._accel_y,DX
C_0EFA:
	;-- --
	RET
;----------------------------------------0EFB
;dir mask->update [_accel_x,_accel_y]/[_speed_x,_speed_y]
UpdateSpeed:
	MOV	AL,[SI]._dir_mask
	MOV	BL,[SI]._power
	XOR	BH,BH
	SHL	BX,1
	MOV	DX,[SI]._accel_x
	MOV	CX,[SI]._accel_y
	MOV	DI,BX

	MOV	BX,[SI]._max_accel
	;-- DX + --
	TEST	AL,1
	JZ	C_0F1A
	CMP	DX,BX
	JGE	C_0F1A
	ADD	DX,DI
C_0F1A:
	;-- CX + --
	TEST	AL,4
	JZ	C_0F24
	CMP	CX,BX
	JGE	C_0F24
	ADD	CX,DI
C_0F24:
	;-- --
	NEG	BX
	;-- DX - --
	TEST	AL,2
	JZ	C_0F30
	CMP	DX,BX
	JL	C_0F30
	SUB	DX,DI
C_0F30:
	;-- CX - --
	TEST	AL,8
	JZ	C_0F3A
	CMP	CX,BX
	JL	C_0F3A
	SUB	CX,DI
C_0F3A:
	;-- --
	MOV	[SI]._accel_x,DX
	ADD	[SI]._speed_x,DX

	MOV	[SI]._accel_y,CX
	ADD	[SI]._speed_y,CX

	RET
;----------------------------------------0F47
;DX: x
;CX: y
UpdateFrame:
	MOV	AX,CX
	OR	AX,DX
	AND	AX,0FFF0h
	JZ	C_0FB7	;return

	XOR	BX,BX
	TEST	DH,80h
	JZ	C_0F62
	NEG	DX
	MOV	BL,10
	TEST	CH,80h
	JZ	C_0F6A
	JMP	SHORT C_0F67
C_0F62:
	TEST	CH,80h
	JNZ	C_0F6A
C_0F67:
	ADD	BL,5
C_0F6A:

	TEST	CH,80h
	JZ	C_0F71
	NEG	CX
C_0F71:

	MOV	AX,CX
	SHR	AX,1
	SHR	AX,1
	CMP	DX,AX
	JB	C_0F9B
	INC	BL

	PUSH	CX
	SUB	CX,AX
	CMP	DX,CX
	POP	CX
	JB	C_0F9B
	INC	BL

	MOV	AX,DX
	SHR	AX,1
	SHR	AX,1
	CMP	CX,AX
	JB	C_0F9B
	INC	BL

	SUB	DX,AX
	CMP	CX,DX
	JB	C_0F9B
	INC	BL

C_0F9B:
	MOV	AL,D_0081[BX]
	MOV	AH,[SI]._frame
	SUB	AL,AH
	JZ	C_0FB7
	AND	AL,0Fh
	INC	AH
	CMP	AL,8
	JB	C_0FB1
	SUB	AH,2
C_0FB1:
	AND	AH,0Fh
	MOV	[SI]._frame,AH

C_0FB7:
	RET
;----------------------------------------
;aim player related?
C_0FB8:
	CALL	AimRaider_far
	JNB	C_0FD6
	AND	AL,AL
	JNZ	C_0FC5
	MOV	[SI].f_1b,50
C_0FC5:
	CMP	[SI].f_1b,0
	JZ	C_0FD4
	DEC	[SI].f_1b
	AND	AH,AH
	JZ	C_0FD6
	NOT	AL
C_0FD4:
	STC
	RET
C_0FD6:
	CLC
	RET
;----------------------------------------0FD8
AimRaider_far:
	MOV	DI,OFFSET _DATA:D_0430	;raider
	CMP	[DI]._active,0
	JNZ	C_0FE5
;---- ----0FE1
AimOrbital_far:
	MOV	DI,g_pUserShip
;---- ----
C_0FE5:
	;-- x --
	MOV	DX,[SI]._map_x
	ADD	DX,640
	SUB	DX,[DI]._map_x
	AND	DX,7FFh
	CMP	DX,1280
	JNB	C_103A
	MOV	AL,2
	CMP	DX,768
	JNB	C_1009
	MOV	AL,0
	CMP	DX,512
	JNB	C_1009
	MOV	AL,1
C_1009:
	;-- y --
	MOV	CX,[SI]._map_y
	ADD	CX,640
	SUB	CX,[DI]._map_y
	AND	CX,7FFh
	CMP	CX,1280
	JNB	C_103A
	MOV	AH,8
	CMP	CX,768
	JNB	C_102F
	MOV	AH,0
	CMP	CX,512
	JNB	C_102F
	MOV	AH,4
C_102F:
	;-- --
	OR	AL,AH
	MOV	AH,0
	JNZ	C_1038
	CALL	C_103C
C_1038:
	;-- --
	STC
	RET
C_103A:
	CLC
	RET
;---- ----
C_103C:
	MOV	AL,2
	CMP	DX,656
	JNB	C_104E
	MOV	AL,0
	CMP	DX,624
	JNB	C_104E
	MOV	AL,1
C_104E:
	MOV	AH,8
	CMP	CX,656
	JNB	C_1060
	MOV	AH,0
	CMP	CX,624
	JNB	C_1060
	MOV	AH,4
C_1060:
	OR	AL,AH
	MOV	D_0042,AL

	MOV	AH,0FFh

	RET
;----------------------------------------1068
AimRaider_near:
	MOV	DI,OFFSET _DATA:D_0430	;raider
	CMP	[DI]._active,0
	JNZ	C_1075
;---- ----1071
AimOrbital_near:
	MOV	DI,g_pUserShip
;---- ----
C_1075:
	;-- x --
	MOV	DX,[SI]._map_x
	ADD	DX,190
	SUB	DX,[DI]._map_x
	AND	DX,7FFh
	CMP	DX,380
	JNB	C_10C5
	MOV	AL,2
	CMP	DX,220
	JNB	C_1099
	MOV	AL,0
	CMP	DX,160
	JNB	C_1099
	MOV	AL,1
C_1099:
	;-- y --
	MOV	CX,[SI]._map_y
	ADD	CX,190
	SUB	CX,[DI]._map_y
	AND	CX,7FFh
	CMP	CX,380
	JNB	C_10C5
	MOV	AH,8
	CMP	CX,220
	JNB	C_10BF
	MOV	AH,0
	CMP	CX,160
	JNB	C_10BF
	MOV	AH,4
C_10BF:
	;-- --
	OR	AL,AH
	JZ	C_10C5
	;
	;
	;
	;-- --
	STC
	RET
C_10C5:
	CLC
	RET
;----------------------------------------10C7
DestroyShip:
	MOV	[DI]._p_cb_control,0

	CMP	DI,OFFSET _DATA:D_0430	;raider
	JNZ	C_10F0
	;-- --
	MOV	[DI]._p_cb_refresh,OFFSET _TEXT:CB_REF_destroy_raider
	MOV	[DI]._thcounter,40
	MOV	[DI]._max_frame,1

	MOV	CX,COUNT_0004	;(+nop)
	MOV	BX,OFFSET _DATA:D_0892
C_10E6:
	MOV	[BX]._active,0
	ADD	BX,SizeOf_s_actor
	LOOP	C_10E6

	RET
	;-- --
C_10F0:
	MOV	[DI]._frame,0
	MOV	[DI]._p_spr,OFFSET _DATA:D_D120
	MOV	[DI]._max_frame,9
	;-- --
	CALL	Rand
	AND	AL,4
	JZ	C_110D

	MOV	[DI]._p_spr,OFFSET _DATA:D_D1C2
	MOV	[DI]._max_frame,7
C_110D:
	;-- --
	MOV	[DI]._p_cb_refresh,OFFSET _TEXT:CB_REF_destroy_other

	CMP	DI,g_pUserShip
	JNZ	C_111D

	MOV	[DI]._p_cb_refresh,OFFSET _TEXT:CB_REF_destroy_orbital
C_111D:
	;-- --
	CMP	[DI]._shoot_typ,5
	JNZ	C_112C

	MOV	[DI]._p_spr,OFFSET _DATA:D_D244
	MOV	[DI]._max_frame,7
C_112C:
	;-- --
	RET
;----------------------------------------112D
CB_REF_destroy_other:
	INC	[SI]._frame
	
	MOV	AL,[SI]._max_frame
	CMP	AL,[SI]._frame
	JNB	C_115F
	
	MOV	[SI]._active,0
	MOV	[SI]._energy,0
	
	MOV	BL,[SI]._shoot_typ
	CMP	BL,8
	JNB	C_115F
	;-- increment "destoyed" counter --
	XOR	BH,BH
	SHL	BX,1
	INC	g_killCounts[BX]
	INC	BYTE PTR g_killTotal

	CMP	D_0430._active,0	;raider
	JNZ	C_115F
	INC	g_killCounts[BX]
	;-- --
C_115F:
	RET
;----------------------------------------1160
;SI:
CollisionWPlayer:
	MOV	DI,OFFSET _DATA:D_0430	;raider
	CALL	CollisionTest
	JB	C_116F

	MOV	DI,g_pUserShip
	CALL	CollisionTest
C_116F:
	RET
;----------------------------------------1170
;SI: @
CollisionWEnemy:
	MOV	DI,OFFSET _DATA:D_04DA
	MOV	CX,COUNT_000C	;(+nop)
	CALL	CollisionList
	JNB	C_117D

	RET
C_117D:
	MOV	DI,OFFSET _DATA:D_0210
	MOV	CX,COUNT_0010	;(+nop)
	CALL	CollisionList
	JNB	C_118A

	RET
C_118A:
	MOV	DI,OFFSET _DATA:D_0672
	MOV	CX,COUNT_0008	;(+nop)
;---- ----1191
;SI: @
;DI: @
;CX: # elements in DI
CollisionList:
C_1191:
	CALL	CollisionTest
	JB	C_119C

	ADD	DI,SizeOf_s_actor
	LOOP	C_1191

	CLC
C_119C:
	RET
;----------------------------------------119D
;SI:
;DI:
CollisionTest:
	CMP	[DI]._active,0
	JNZ	C_11A6
	JMP	C_1228
C_11A6:
	CMP	[DI]._max_frame,0
	JNZ	C_1228

	PUSH	CX
	;-- check on x --
	MOV	CX,[SI]._map_x
	MOV	DX,[DI]._map_x

	CALL	C_122D	;get sprite info(SI)?
	MOV	AL,[BX]._spr_x
	ADD	CX,AX
	MOV	AL,[BX]._box1_left
	CBW
	ADD	CX,AX

	CALL	C_1247	;get sprite info(DI)?
	MOV	AL,[BX]._spr_x
	ADD	DX,AX
	MOV	AL,[BX]._box1_left
	CBW
	ADD	DX,AX

	SUB	CX,DX
	AND	CX,7FFh
	TEST	CH,4
	JZ	C_11E0
	MOV	BX,BP
	NEG	CX
	AND	CX,7FFh
C_11E0:
	MOV	AL,[BX]._spr_w
	XOR	AH,AH
	CMP	CX,AX
	JA	C_1227
	;-- check on y --
	MOV	CX,[SI]._map_y
	MOV	DX,[DI]._map_y

	CALL	C_122D	;get sprite info(SI)?
	MOV	AL,[BX]._spr_y
	ADD	CX,AX
	MOV	AL,[BX]._box1_top
	CBW
	ADD	CX,AX

	CALL	C_1247	;get sprite info(DI)?
	MOV	AL,[BX]._spr_y
	ADD	DX,AX
	MOV	AL,[BX]._box1_top
	CBW
	ADD	DX,AX

	SUB	CX,DX
	AND	CX,7FFh
	TEST	CH,4
	JZ	C_121E
	MOV	BX,BP
	NEG	CX
	AND	CX,7FFh
C_121E:
	MOV	AL,[BX]._spr_h
	XOR	AH,AH
	CMP	CX,AX
	JBE	C_122A
	;-- --
C_1227:
	POP	CX
C_1228:
	CLC
	RET
C_122A:
	POP	CX
	STC
	RET
;----------------------------------------122D
;get sprite info(SI)?
C_122D:
	MOV	BX,[SI]._p_spr
	ADD	BX,2
	MOV	AL,[SI]._frame
	XOR	AH,AH
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	ADD	BX,AX
	XOR	AH,AH
	MOV	BP,BX

	RET
;----------------------------------------1247
;get sprite info(DI)?
C_1247:
	MOV	BX,[DI]._p_spr
	ADD	BX,2
	MOV	AL,[DI]._frame
	XOR	AH,AH
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	ADD	BX,AX
	XOR	AH,AH
	;

	RET
;----------------------------------------125F
;SI: @
CollisionTerrainTest:
	CALL	C_122D	;get sprite info(SI)?
	MOV	DI,BX
	;-- right/bottom[upper part] --
	MOV	AL,[DI]._box1_right
	CBW
	MOV	DX,AX

	MOV	AL,[DI]._box1_bottom
	CBW
	MOV	CX,AX

	XOR	BX,BX

	CALL	C_12A7	;(CX,DX)
	RCL	BL,1
	OR	BH,AL
	;-- left/top[lower part] --
	MOV	AL,[DI]._box2_left
	CBW
	MOV	DX,AX

	MOV	AL,[DI]._box2_top
	CBW
	MOV	CX,AX

	CALL	C_12A7	;(CX,DX)
	RCL	BL,1
	OR	BH,AL
	;-- right/bottom[lower part] --
	MOV	AL,[DI]._box2_right
	CBW
	MOV	DX,AX

	MOV	AL,[DI]._box2_bottom
	CBW
	MOV	CX,AX

	CALL	C_12A7	;(CX,DX)
	RCL	BL,1
	OR	BH,AL
	;-- --
	MOV	AX,BX
	AND	AL,AL
	JZ	C_12A6
	STC
C_12A6:
	RET
;---- ----
;CX: x
;DX: y
C_12A7:
	ADD	DX,[SI]._map_x
	ADD	CX,[SI]._map_y
	PUSH	BX

	PUSH	CX
	PUSH	DX
	AND	CX,7C0h
	AND	DX,7C0h
	MOV	BX,DX
	SHR	BX,1
	SHR	BX,1
	SHR	BX,1
	SHR	BX,1
	SHR	BX,1
	ADD	BX,CX
	SHR	BX,1
	MOV	BL,g_tilemap[BX]
	XOR	BH,BH
	SHL	BX,1
	SHL	BX,1
	SHL	BX,1
	SHL	BX,1
	ADD	BX,OFFSET _DATA:D_241B
	POP	DX
	POP	CX
	AND	DL,3Fh
	AND	CL,3Fh
	MOV	AL,DL
	MOV	AH,CL

	CMP	[BX].ffff_0e,0
	JZ	C_1305
	;-- lower part? --
	SUB	DL,[BX]._box2_left
	JB	C_1305
	CMP	DL,[BX]._box2_right
	JNB	C_1305
	SUB	CL,[BX]._box2_top
	JB	C_1305
	CMP	CL,[BX]._box2_bottom
	JNB	C_1305

	MOV	AL,[BX].ffff_0e
	POP	BX
	STC
	RET
C_1305:
	;-- upper part? --
	SUB	AL,[BX]._box1_left
	JB	C_131E
	CMP	AL,[BX]._box1_right
	JNB	C_131E
	SUB	AH,[BX]._box1_top
	JB	C_131E
	CMP	AH,[BX]._box1_bottom
	JNB	C_131E

	POP	BX
	XOR	AL,AL
	STC
	RET
C_131E:
	POP	BX
	XOR	AL,AL
	CLC
	RET
;----------------------------------------1323
;update [_map_x/_map_y][_speed_x/_speed_y]?
UpdatePos:
	CMP	[SI]._active,0
	JZ	C_134F

	MOV	DX,[SI]._speed_x
	MOV	AL,DH
	XOR	DH,DH
	MOV	[SI]._speed_x,DX
	CBW
	ADD	AX,[SI]._map_x
	AND	AX,7FFh
	MOV	[SI]._map_x,AX

	MOV	DX,[SI]._speed_y
	MOV	AL,DH
	XOR	DH,DH
	MOV	[SI]._speed_y,DX
	CBW
	ADD	AX,[SI]._map_y
	AND	AX,7FFh
	MOV	[SI]._map_y,AX
C_134F:
	RET
;----------------------------------------1350
CheckGems:
	;-- has enough gems? --
	MOV	AX,g_gems
	CMP	AX,46
	JNB	C_13A2	;level cleared
	;-- --
	MOV	SI,OFFSET _DATA:D_0430	;raider
	MOV	DX,[SI]._map_x
	MOV	BX,[SI]._map_y
	SUB	DX,20
	SUB	BX,20
	AND	BX,7FFh
	AND	DX,7FFh
	MOV	CL,3
	SHR	DX,CL
	SHR	BX,CL
	MOV	SI,DX
	SHR	SI,1
	SHR	SI,1
	MOV	CL,6
	SHL	BX,CL
	ADD	SI,BX
	ADD	SI,OFFSET _DATA:D_4ADB
	AND	DX,3
	XOR	DX,3
	MOV	CX,6
C_138D:
	CALL	C_13A8
	XOR	AH,AH
	ADD	SI,40h
	CMP	SI,OFFSET _DATA:D_8ADB
	JB	C_139F
	SUB	SI,4000h
C_139F:
	LOOP	C_138D

	RET
	;-- level clear --
C_13A2:
	MOV	BYTE PTR g_level_clear,0FFh

	RET
;---- ----
C_13A8:
	PUSH	DX
	PUSH	CX
	PUSH	SI

	MOV	CX,DX
	MOV	DX,3
	MOV	AX,[SI]
	AND	AX,AX
	JZ	C_13E4

	XCHG	AH,AL
	JCXZ	C_13C4
C_13BA:
	ROR	AX,1
	ROR	AX,1
	ROL	DX,1
	ROL	DX,1
	LOOP	C_13BA
C_13C4:
	MOV	CL,6
C_13C6:
	MOV	BL,AH
	AND	BL,3
	JZ	C_13DA
	
	CALL	C_13E8	;score += ...?
	INC	g_gems
	
	NOT	DX
	AND	[SI],DX
	NOT	DX
C_13DA:
	ROL	AX,1
	ROL	AX,1
	ROR	DX,1
	ROR	DX,1
	LOOP	C_13C6
C_13E4:
	POP	SI
	POP	CX
	POP	DX
	RET
;---- ----
;score += ...?
C_13E8:
	PUSH	BX

	XOR	BH,BH
	SHL	BX,1
	MOV	BX,D_0039[BX]
	ADD	g_score[0],BX
	JNB	C_13FB
	INC	g_score[2]
C_13FB:
	POP	BX
	RET
;----------------------------------------13FD
UpdateScrollInfo:
	;-- (g_scroll_y & 0x3f) * 0x30 --
	MOV	AX,g_scroll_y
	AND	AX,3Fh
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	MOV	DX,AX
	SHL	AX,1
	ADD	DX,AX
	;-- (g_scroll_x >> 3) & 7 --
	MOV	AX,g_scroll_x
	SHR	AX,1
	SHR	AX,1
	SHR	AX,1
	AND	AX,7
	ADD	AX,DX

	MOV	SI,g_pbkbuffer_front
	MOV	[SI]._vscroll,AX

	RET
;----------------------------------------1427
;load "blocks.dat" in VRAM
LoadBlocks:
	MOV	AX,3D00h	;open file
	MOV	DX,OFFSET _DATA:D_0000	;"blocks.dat"
	INT	21h
	JB	C_146F

	MOV	BX,AX
	PUSH	BX
	MOV	CX,8C5Ch
	MOV	DX,OFFSET _DATA:D_26DB
	MOV	AH,3Fh	;read file
	INT	21h
	POP	BX
	JB	C_146F

	MOV	AH,3Eh	;close file
	INT	21h

	MOV	AX,SEG_A000
	MOV	ES,AX
	CLD

	MOV	AL,0	;write mode 0
	CALL	C_278D	;set EGA register state?

	MOV	DX,PORT_3C4
	MOV	AL,2	;map mask register
	OUT	DX,AL

	MOV	SI,OFFSET _DATA:D_26DB
	XOR	DL,DL

	MOV	AL,1
	CALL	C_1470	;deflate "blocks.dat" to vram plane
	MOV	AL,2
	CALL	C_1470	;deflate "blocks.dat" to vram plane
	MOV	AL,4
	CALL	C_1470	;deflate "blocks.dat" to vram plane
	MOV	AL,8
	CALL	C_1470	;deflate "blocks.dat" to vram plane
	;-- --
C_146F:
	RET
;---- ----
;deflate "blocks.dat" to vram plane
;(some LRE)
C_1470:
	;-- PORT_3C4[2] := AL -- "Map Mask Register"
	PUSH	DX
	MOV	DX,PORT_3C4 + 1
	OUT	DX,AL
	POP	DX
	;-- --
	MOV	DI,9040h
	MOV	CX,3AE0h
C_147C:
	TEST	DL,DL
	JNZ	C_1488
	LODSB
	TEST	AL,AL
	JNZ	C_148C
	LODSB
	MOV	DL,AL
C_1488:
	XOR	AL,AL
	DEC	DL
C_148C:
	STOSB
	LOOP	C_147C
	;-- --
	RET
;----------------------------------------
C_1490:
	XOR	AH,AH

	CALL	InitTileMap
	CALL	C_156E	;init "fixed turets"
	CALL	C_15B0	;init "generator" tile pointers
	CALL	C_15FE

	RET
;----------------------------------------149F
;load "map.dat"
LoadMap:
	MOV	AX,3D00h	;open file
	MOV	DX,OFFSET _DATA:D_000B	;"map.dat"
	INT	21h
	JB	C_14B9

	MOV	BX,AX
	MOV	CX,2000h
	MOV	DX,OFFSET _DATA:D_26DB
	MOV	AH,3Fh	;read file
	INT	21h

	MOV	AH,3Eh	;close file
	INT	21h
C_14B9:
	RET
;----------------------------------------
;save "map.dat"?
__14BA:
	MOV	AX,3C00h	;create file
	MOV	DX,OFFSET _DATA:D_000B	;"map.dat"
	MOV	CX,0
	INT	21h
	MOV	BX,AX

	MOV	CX,2000h
	MOV	DX,OFFSET _DATA:D_26DB
	MOV	AH,40h	;write file
	INT	21h

	MOV	AH,3Eh	;close file
	INT	21h

	RET
;----------------------------------------14D6
InitTileMap:
	MOV	AL,g_map
	MOV	DI,OFFSET _DATA:g_tilemap
	MOV	BH,AL
	XOR	BL,BL
	SHL	BX,1
	SHL	BX,1
	ADD	BX,OFFSET _DATA:D_26DB
	MOV	SI,BX
	TEST	AH,0FFh
	JZ	C_14F1
	XCHG	SI,DI
C_14F1:
	MOV	AX,DS
	MOV	ES,AX
	CLD
	MOV	CX,400h	;20h * 20h
	REPZ	MOVSB

	RET
;----------------------------------------14FC
;load "hiscores.dat"
LoadHiscores:
	MOV	AX,3D00h	;open file
	MOV	DX,OFFSET _DATA:D_001D	;"hiscores.dat"
	INT	21h
	JB	C_1516

	MOV	BX,AX
	MOV	CX,60h
	MOV	DX,OFFSET _DATA:D_1ADB
	MOV	AH,3Fh	;read file
	INT	21h

	MOV	AH,3Eh	;close file
	INT	21h
C_1516:
	RET
;----------------------------------------1517
;save "hiscores.dat"
SaveHiscores:
	MOV	AX,3C00h	;create file
	MOV	DX,OFFSET _DATA:D_001D	;"hiscores.dat"
	MOV	CX,0
	INT	21h
	JB	C_1534

	MOV	BX,AX
	MOV	CX,60h
	MOV	DX,OFFSET _DATA:D_1ADB
	MOV	AH,40h	;write file
	INT	21h

	MOV	AH,3Eh	;close file
	INT	21h
C_1534:
	RET
;----------------------------------------1535
;load "keys.dat"
LoadKeys:
	MOV	AX,3D00h	;open file
	MOV	DX,OFFSET _DATA:D_002A	;"keys.dat"
	INT	21h
	JB	C_154F

	MOV	BX,AX
	MOV	CX,0Ch
	MOV	DX,OFFSET _DATA:D_B810
	MOV	AH,3Fh	;read file
	INT	21h

	MOV	AH,3Eh	;close file
	INT	21h
C_154F:
	RET
;----------------------------------------1550
;save "keys.dat"
SaveKeys:
	MOV	AX,3C00h	;create file
	MOV	DX,OFFSET _DATA:D_002A	;"keys.dat"
	MOV	CX,0
	INT	21h
	JB	C_156D

	MOV	BX,AX
	MOV	CX,0Ch
	MOV	DX,OFFSET _DATA:D_B810
	MOV	AH,40h	;write file
	INT	21h

	MOV	AH,3Eh	;close file
	INT	21h
C_156D:
	RET
;----------------------------------------
;init "fixed turets"
C_156E:
	MOV	BX,OFFSET _DATA:g_tilemap
	;-- --
	MOV	CH,20h
	XOR	DH,DH
C_1575:
	;-- --
	MOV	CL,20h
	XOR	DL,DL
C_1579:
	;-- --
	CMP	BYTE PTR [BX],2Bh
	JNZ	C_15A2
	;-- --
	MOV	SI,OFFSET _DATA:D_0C4A	;enemy[6] "fixed turret"
	;-- find available actor --
	MOV	DI,OFFSET _DATA:D_0210
	MOV	AH,COUNT_0010	;(+nop x 2)
C_1588:
	CMP	[DI]._active,0
	JZ	C_1597
	ADD	DI,SizeOf_s_actor
	DEC	AH
	JNZ	C_1588
	JMP	SHORT C_15AF
C_1597:
	;-- --
	CALL	SetShipInfos
	CALL	Rand
	AND	AL,0Eh
	MOV	[DI]._frame,AL
	;-- --
C_15A2:
	;-- --
	INC	DL
	INC	BX
	DEC	CL
	JNZ	C_1579
	;-- --
	INC	DH
	DEC	CH
	JNZ	C_1575
	;-- --
C_15AF:
	RET
;----------------------------------------
;init "generator" tile pointers
C_15B0:
	MOV	BX,OFFSET _DATA:g_tilemap - 1
	MOV	SI,OFFSET _DATA:D_0067
	MOV	DL,4
	MOV	CX,400h
C_15BB:
	MOV	Word Ptr [SI],-1
	INC	BX
	MOV	AL,[BX]
	SUB	AL,5
	CMP	AL,3
	JNB	C_15D1
	MOV	[SI],BX
	ADD	SI,2
	DEC	DL
	JZ	C_15D3
C_15D1:
	LOOP	C_15BB
C_15D3:
	RET
;----------------------------------------15D4
;SI:@src
;DI:@dst
;DH,DL:map position
SetShipInfos:
	PUSH	CX
	PUSH	DX
	PUSH	SI
	PUSH	DI

	MOV	AL,DH
	XOR	AH,AH
	MOV	CL,6
	SHL	AX,CL
	ADD	AX,33
	MOV	[SI]._map_y,AX

	XOR	DH,DH
	SHL	DX,CL
	ADD	DX,32
	MOV	[SI]._map_x,DX

	MOV	AX,DS
	MOV	ES,AX
	CLD
	MOV	CX,SizeOf_s_actor
	REPZ	MOVSB

	POP	DI
	POP	SI
	POP	DX
	POP	CX
	RET
;----------------------------------------
C_15FE:
	;-- clear buffer --
	MOV	CX,4000h
	MOV	SI,OFFSET _DATA:D_4ADB
	XOR	AL,AL
C_1606:
	MOV	[SI],AL
	INC	SI
	LOOP	C_1606
	;-- difficulty level --
	MOV	BL,g_map
	XOR	BH,BH
	SHL	BX,1
	ADD	BX,OFFSET _DATA:D_0057
	MOV	CH,[BX]
	MOV	CL,[BX+01]
	MOV	D_0044,CX
	;-- --
	MOV	AL,g_map
	MOV	AH,50
	MUL	AH
	MOV	CX,500
	SUB	CX,AX
C_162C:
	CALL	Rand
	AND	AX,1Fh
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	MOV	DX,AX
	CALL	Rand
	XOR	DL,AL
	CALL	Rand
	AND	AX,1Fh
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	MOV	BX,AX
	CALL	Rand
	XOR	BL,AL
	CALL	C_169F
	CMP	AH,5
	JNB	C_162C

	PUSH	CX

	MOV	SI,DX
	SHR	SI,1
	SHR	SI,1
	MOV	CL,6
	SHL	BX,CL
	ADD	SI,BX
	ADD	SI,OFFSET _DATA:D_4ADB
	CALL	Rand
	MOV	CX,D_0044
	MOV	AH,0C0h
	CMP	AL,CH
	JB	C_1680
	MOV	AH,80h
	CMP	AL,CL
	JB	C_1680
	MOV	AH,40h
C_1680:
	MOV	AL,AH
	MOV	CX,DX
	AND	CX,3
	MOV	DH,0C0h
	JCXZ	C_1695
C_168B:
	SHR	DH,1
	SHR	DH,1
	SHR	AL,1
	SHR	AL,1
	LOOP	C_168B
C_1695:
	NOT	DH
	AND	[SI],DH
	OR	[SI],AL

	POP	CX
	LOOP	C_162C
	;-- --
	RET
;---- ----
;BX:
;DX:
C_169F:
	PUSH	DX
	PUSH	BX
	PUSH	CX

	SHR	DX,1
	SHR	DX,1
	AND	DX,NOT 1	;0FEh
	MOV	SI,DX
	MOV	DI,SI
	SHR	DI,1
	AND	BX,NOT 7	;0F8h
	MOV	CL,6
	SHL	BX,CL
	ADD	SI,BX
	MOV	CL,4
	SHR	BX,CL
	ADD	DI,BX
	MOV	AH,5

	CMP	BYTE PTR g_tilemap[DI],0
	JNZ	C_16DE

	MOV	AH,0
	MOV	BX,OFFSET _DATA:D_1071
	CLD
	MOV	CX,8
C_16D0:
	LODSB
	XLAT	;AL <- BX[AL]
	ADD	AH,AL
	MOV	AL,[SI]
	XLAT	;AL <- BX[AL]
	ADD	AH,AL
	ADD	SI,3Fh
	LOOP	C_16D0
	;-- --
C_16DE:
	POP	CX
	POP	BX
	POP	DX
	RET
;----------------------------------------
C_16E2:
	;-- --
	MOV	SI,OFFSET _DATA:D_0782
	MOV	CX,COUNT_0008	;(+nop)
	CALL	C_171B
	;-- --
	MOV	SI,OFFSET _DATA:D_091A
	MOV	CX,COUNT_0010	;(+nop)
	CALL	C_171B
	;-- --
	MOV	SI,OFFSET _DATA:D_0210
	MOV	CX,COUNT_0010	;(+nop)
	CALL	C_171B
	;-- --
	MOV	SI,OFFSET _DATA:D_04DA
	MOV	CX,COUNT_000C	;(+nop)
	CALL	C_171B
	;-- --
	MOV	SI,OFFSET _DATA:D_0672
	MOV	CX,COUNT_0008	;(+nop)
	CALL	C_171B
	;-- --
	MOV	SI,OFFSET _DATA:D_0892
	MOV	CX,COUNT_0004	;(+nop)
;----
C_171B:
X_171B:
	MOV	[SI]._active,0
	ADD	SI,SizeOf_s_actor
	LOOP	X_171B

	RET
;----------------------------------------
__1725	db 0Bh dup(0)	;padding
;########################################
;
;----------------------------------------1730
MainRenderer:
	CALL	C_2B1F	;restore vram(sprites)?
	CALL	C_1B55	;restore vram(radar frame)
	CALL	C_1828
	;-- display all actors --
	MOV	CX,45h
	MOV	DI,OFFSET _DATA:X_0210
C_173F:
	CMP	[DI]._active,0
	JZ	C_174C
	PUSH	DI
	PUSH	CX
	CALL	C_177F	;render 1 ship(DI)?
	POP	CX
	POP	DI
C_174C:
	ADD	DI,SizeOf_s_actor
	LOOP	C_173F
	;-- request "DOCK" message --
	MOV	AL,g_level_clear
	AND	AL,AL
	JZ	C_1779

	CMP	D_0430._active,0	;raider
	JZ	C_1779

	MOV	AL,g_int8_cnt
	AND	AL,7Fh
	CMP	AL,40h
	JNB	C_1779
	
	MOV	AX,SEG_3807
	MOV	ES,AX
	MOV	DX,0C6h
	MOV	BX,114
	MOV	SI,OFFSET _DATA:D_DB00	;"DOCK"
	CALL	DrawSprite
C_1779:
	;-- --
	CALL	DrawRadar

	JMP	RenderUI
;----------------------------------------
;render 1 ship(DI)?
C_177F:
	MOV	AL,[DI]._frame
	MOV	SI,[DI]._p_spr
	MOV	DX,[DI]._map_x
	MOV	BX,[DI]._map_y
	;-- --
	CMP	[DI]._active,0
	JZ	C_17D5
	;-- --
	CALL	RadarAddInfo

	XOR	AH,AH
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	MOV	ES,[SI]
	ADD	SI,2
	ADD	SI,AX

	MOV	AL,[SI]._box1_left
	CBW
	ADD	DX,AX
	SUB	DX,g_scroll_x
	AND	DX,7FFh
	CMP	DX,383
	JNB	C_17D5

	MOV	AL,[SI]._box1_top
	CBW
	ADD	BX,AX
	SUB	BX,g_scroll_y
	AND	BX,7FFh
	CMP	BX,256
	JNB	C_17D5

	CMP	[SI].ffff_0e,0B1h
	JNZ	C_17D5
	;-- --
	JMP	DrawSprite
	;-- --
C_17D5:
	RET
;----------------------------------------17D6
RadarAddInfo:
	PUSH	AX
	PUSH	BX
	PUSH	DX
	;-- --
	CMP	[DI]._typ4radar,10
	JNB	C_1824
	;-- --
	MOV	AX,[DI]._map_x
	SUB	AX,D_0430._map_x	;raider
	ADD	AX,832
	AND	AX,7FFh
	CMP	AX,1664
	JNB	C_1824
	
	MOV	DX,[DI]._map_y
	SUB	DX,D_0430._map_y	;raider
	ADD	DX,416
	AND	DX,7FFh
	CMP	DX,896
	JNB	C_1824
	
	MOV	BL,g_radarCnt
	XOR	BH,BH
	ADD	BX,BX
	ADD	BX,BX
	ADD	BX,BX
	ADD	BX,OFFSET _DATA:D_231B
	MOV	[BX]._radar_x,AX
	MOV	[BX]._radar_y,DX
	MOV	AL,[DI]._typ4radar
	MOV	[BX]._radar_type,AL

	INC	BYTE PTR g_radarCnt
	;-- --
C_1824:
	POP	DX
	POP	BX
	POP	AX
	RET
;----------------------------------------
C_1828:
	CALL	C_1A23	;restore vram(tilemap)?
	CALL	C_19D2	;restore vram(gems)?

	MOV	AL,1	;write mode 1
	CALL	C_278D	;set EGA register state?

	MOV	AX,g_scroll_x
	MOV	CL,6
	SHR	AX,CL
	INC	AX
	AND	AX,1Fh
	MOV	DH,AL

	MOV	AX,g_scroll_y
	SHR	AX,CL
	INC	AX
	AND	AX,1Fh
	MOV	DL,AL

	MOV	BX,g_pbkbuffer_front
	MOV	DI,[BX]._voffset
	MOV	CX,4
C_1854:
	PUSH	CX
	PUSH	DI
	PUSH	DX

	MOV	CX,6
C_185A:
	CALL	C_1878
	ADD	DI,8
	INC	DH
	LOOP	C_185A

	POP	DX
	POP	DI
	POP	CX
	ADD	DI,0C00h
	INC	DL
	LOOP	C_1854
	;-- --
	MOV	BX,g_pbkbuffer_front
	MOV	[BX]._render_flag,0FFh
	;-- --
	RET
;---- ----
C_1878:
	PUSH	DI
	PUSH	CX
	PUSH	DX
	;-- --
	MOV	BX,g_pbkbuffer_front
	CMP	[BX]._render_flag,0
	JNZ	C_18A1
	;-- --
	MOV	CX,(40h SHL 8) OR 8
	MOV	SI,9040h	;src offset
	PUSH	DI
	PUSH	DI
	CALL	C_19B8
	POP	DI
	SUB	DI,[BX]._voffset
	ADD	DI,6030h
	MOV	CX,(40h SHL 8) OR 8
	MOV	SI,9040h	;src offset
	CALL	C_19B8
	POP	DI
	;-- --
C_18A1:
	MOV	AL,DH
	AND	AX,1Fh
	MOV	SI,AX
	MOV	AL,DL
	AND	AL,1Fh
	MOV	CL,5
	SHL	AX,CL
	ADD	SI,AX
	MOV	BL,g_tilemap[SI]
	AND	BL,BL
	JZ	C_1912

	XOR	BH,BH
	SHL	BX,1
	SHL	BX,1
	SHL	BX,1
	SHL	BX,1
	ADD	BX,OFFSET _DATA:D_241B
	MOV	SI,[BX]._p_data_spr

	MOV	AL,[BX]._spr_x
	XOR	AH,AH
	ADD	DI,AX
	MOV	AL,[BX]._spr_y
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	ADD	DI,AX
	SHL	AX,1
	ADD	DI,AX

	MOV	CL,[BX]._spr_w
	MOV	CH,[BX]._spr_h

	MOV	BX,g_pbkbuffer_front
	MOV	DX,[BX]._voffset
	MOV	BX,[BX].fff_04
	MOV	AL,[BX]	;count
	INC	BYTE PTR [BX]	;count
	INC	BX
	XOR	AH,AH
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	ADD	BX,AX
	MOV	[BX]._dst_offset,DI
	MOV	[BX]._src_offset,DX
	MOV	[BX]._bytes_per_line,CL
	MOV	[BX]._line_count,CH
	CALL	C_19B8

	POP	DX
	POP	CX
	POP	DI
	RET
C_1912:
	MOV	AL,DH
	AND	AX,1Fh
	SHL	AX,1
	MOV	SI,AX
	MOV	AL,DL
	AND	AX,1Fh
	MOV	CL,9
	SHL	AX,CL
	ADD	SI,AX
	ADD	SI,OFFSET _DATA:D_4ADB
	MOV	BX,g_pbkbuffer_front
	MOV	BP,[BX].fff_08
	MOV	BL,DS:[BP]
	XOR	BH,BH
	ADD	BX,BX
	ADD	BX,BX
	ADD	BX,BP
	INC	BX
	MOV	DX,9040h
	CLD
	MOV	CX,8
C_1945:
	LODSW
	AND	AX,AX
	JZ	C_1966
	XCHG	AL,AH
	PUSH	DI
	PUSH	SI
	PUSH	CX
	PUSH	DX
	MOV	CX,8
C_1953:
	ROL	AX,1
	ROL	AX,1
	AND	AL,3
	JZ	C_195E
	CALL	C_1976
C_195E:
	INC	DX
	INC	DI
	LOOP	C_1953
	POP	DX
	POP	CX
	POP	SI
	POP	DI
C_1966:
	ADD	SI,3Eh
	ADD	DI,180h
	ADD	DX,40h
	LOOP	C_1945

	POP	DX
	POP	CX
	POP	DI
	RET
;---- ----
C_1976:
	PUSH	DS
	PUSH	DI
	PUSH	AX

	MOV	[BX],DI
	ADD	BX,2
	MOV	[BX],DX
	ADD	BX,2
	INC	BYTE PTR DS:[BP]
	XOR	AH,AH
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	MOV	SI,0CAF8h	;-3508h?
	ADD	SI,AX

	MOV	AX,SEG_A000
	MOV	ES,AX
	MOV	DS,AX

	MOV	AX,2Fh
	MOVSB
	ADD	DI,AX
	MOVSB
	ADD	DI,AX
	MOVSB
	ADD	DI,AX
	MOVSB
	ADD	DI,AX
	MOVSB
	ADD	DI,AX
	MOVSB
	ADD	DI,AX
	MOVSB
	ADD	DI,AX
	MOVSB

	POP	AX
	POP	DI
	POP	DS
	RET
;---- ----
;CL: bytes per line
;CH: line count
;SI: src offset
;DI: dst offset
C_19B8:
	CLD
	PUSH	DS

	MOV	AX,SEG_A000
	MOV	DS,AX
	MOV	ES,AX
C_19C1:
	PUSH	CX
	PUSH	DI
	XOR	CH,CH
	REPZ	MOVSB
	POP	DI
	POP	CX
	ADD	DI,30h
	DEC	CH
	JNZ	C_19C1

	POP	DS
	RET
;----------------------------------------
;restore vram(gems)?
C_19D2:
	MOV	BX,g_pbkbuffer_front
	MOV	BX,[BX].fff_08
	MOV	CL,[BX]	;count
	XOR	CH,CH
	MOV	[BX],CH
	INC	BX
	JCXZ	C_1A22
	CLD
C_19E3:
	PUSH	DS

	MOV	DI,[BX]
	ADD	BX,2
	MOV	SI,[BX]
	ADD	BX,2

	MOV	AX,SEG_A000
	MOV	ES,AX
	MOV	DS,AX

	MOV	AX,2Fh
	MOV	DX,7
	MOVSB
	ADD	DI,AX
	ADD	SI,DX
	MOVSB
	ADD	DI,AX
	ADD	SI,DX
	MOVSB
	ADD	DI,AX
	ADD	SI,DX
	MOVSB
	ADD	DI,AX
	ADD	SI,DX
	MOVSB
	ADD	DI,AX
	ADD	SI,DX
	MOVSB
	ADD	DI,AX
	ADD	SI,DX
	MOVSB
	ADD	DI,AX
	ADD	SI,DX
	MOVSB

	POP	DS
	LOOP	C_19E3
C_1A22:
	RET
;----------------------------------------
;restore vram(tilemap)?
C_1A23:
	MOV	SI,g_pbkbuffer_front
	MOV	BX,[SI].fff_04
	MOV	CL,[BX]	;count
	XOR	CH,CH
	JCXZ	C_1A71
	MOV	[BX],CH	;count

	MOV	AL,1	;write mode 1
	CALL	C_278D	;set EGA register state?

	INC	BX
C_1A38:
	MOV	DI,[BX]._dst_offset
	MOV	SI,DI
	SUB	SI,[BX]._src_offset
	ADD	SI,6030h
	PUSH	CX
	MOV	CL,[BX]._line_count
	MOV	CH,[BX]._bytes_per_line
	PUSH	DS
	MOV	AX,SEG_A000
	MOV	ES,AX
	MOV	DS,AX
	CLD
	MOV	AX,30h
C_1A56:
	PUSH	CX
	PUSH	SI
	PUSH	DI
	MOV	CL,CH
	XOR	CH,CH
	REPZ	MOVSB
	POP	DI
	POP	SI
	POP	CX
	ADD	SI,AX
	ADD	DI,AX
	DEC	CL
	JNZ	C_1A56

	POP	DS
	POP	CX
	ADD	BX,8
	LOOP	C_1A38
C_1A71:
	RET
;----------------------------------------1A72
DrawRadar:
	TEST	BYTE PTR g_radarOn,0FFh
	JZ	C_1AD0

	CMP	D_0430._active,0	;raider
	JZ	C_1AD0
	;-- --
	CALL	DrawShipsRadar

	MOV	DI,0306h
	MOV	BX,g_pbkbuffer_front
	ADD	DI,[BX]._vscroll
	MOV	[BX].fff_0a,DI
	ADD	DI,[BX]._voffset

	MOV	CL,BYTE PTR g_scroll_x
	AND	CL,7
	XOR	CL,7

	XOR	AL,AL	;write mode 0
	CALL	C_278D	;set EGA register state?
	;-- PORT_3CE[1] = 0Fh --
	MOV	DX,PORT_3CE
	MOV	AL,1	;enable set/reset register
	OUT	DX,AL
	INC	DX
	MOV	AL,0Fh
	OUT	DX,AL
	;-- PORT_3CE[0] = 0Ah --
	MOV	DX,PORT_3CE
	XOR	AL,AL	;set/reset register
	OUT	DX,AL
	INC	DX
	MOV	AL,0Ah
	OUT	DX,AL
	;-- PORT_3CE[8] = ... --
	MOV	DX,PORT_3CE
	MOV	AL,8	;bit mask register
	OUT	DX,AL
	INC	DX

	MOV	AX,SEG_A000
	MOV	ES,AX

	PUSH	DI
	CALL	C_1AD6	;horizontal line
	ADD	DI,1680h
	CALL	C_1AD6	;horizontal line
	POP	DI
	CALL	C_1AFA	;2 vertical lines
	;-- --
C_1AD0:
	MOV	BYTE PTR g_radarCnt,0

	RET
;---- ----
C_1AD6:
	PUSH	DS
	PUSH	CX
	PUSH	DI

	MOV	BH,0FFh
	SHL	BH,CL
	MOV	BL,BH
	NOT	BH
	MOV	CX,1Ah
	PUSH	ES
	POP	DS
	MOV	SI,DI
	CLD

	MOV	AL,BH
	OUT	DX,AL
	MOVSB

	MOV	AL,0FFh
	OUT	DX,AL
	REPZ	MOVSB

	MOV	AL,BL
	OUT	DX,AL
	MOVSB

	POP	DI
	POP	CX
	POP	DS
	RET
;---- ----
;2 vertical lines
C_1AFA:
	PUSH	DS

	MOV	AL,1
	SHL	AL,CL

	MOV	SI,DI
	ADD	SI,1Bh
	MOV	BX,30h

	OUT	DX,AL

	MOV	CX,79h
C_1B0B:
	OR	ES:[DI],AL
	OR	ES:[SI],AL
	ADD	DI,BX
	ADD	SI,BX
	LOOP	C_1B0B

	POP	DS
	RET
;---- ----1B19
;display ships on radar
DrawShipsRadar:
	MOV	CL,g_radarCnt
	XOR	CH,CH
	JCXZ	C_1B54
	;-- --
	MOV	BX,OFFSET _DATA:D_231B
C_1B24:
	PUSH	CX
	PUSH	BX

	MOV	AL,[BX]._radar_type
	XOR	AH,AH
	MOV	CL,4
	SHL	AX,CL
	MOV	SI,OFFSET _DATA:D_D3C0
	MOV	ES,[SI]
	ADD	SI,2
	ADD	SI,AX
	MOV	CL,3
	MOV	DX,[BX]._radar_x
	SHR	DX,CL
	MOV	BX,[BX]._radar_y
	SHR	BX,CL
	ADD	DX,112
	ADD	BX,80
	CALL	DrawSprite

	POP	BX
	POP	CX
	ADD	BX,8
	LOOP	C_1B24
	;-- --
C_1B54:
	RET
;----------------------------------------
;restore vram(radar frame)
C_1B55:
	MOV	BX,g_pbkbuffer_front
	MOV	DI,[BX].fff_0a
	MOV	[BX].fff_0a,0
	CMP	DI,0
	JZ	C_1B8D

	MOV	SI,DI
	ADD	DI,[BX]._voffset
	ADD	SI,6030h

	MOV	AL,1	;write mode 1
	CALL	C_278D	;set EGA register state?

	MOV	AX,SEG_A000
	MOV	ES,AX

	PUSH	SI
	PUSH	DI
	CALL	C_1B8E	;horizontal line
	ADD	SI,1680h
	ADD	DI,1680h
	CALL	C_1B8E	;horizontal line
	POP	DI
	POP	SI

	CALL	C_1B9D	;2 vertical lines
C_1B8D:
	RET
;---- ----
;horizontal line
C_1B8E:
	PUSH	DS
	PUSH	DI
	PUSH	SI

	MOV	CX,1Ch
	PUSH	ES
	POP	DS
	CLD
	REPZ	MOVSB

	POP	SI
	POP	DI
	POP	DS
	RET
;---- ----
;2 vertical lines
C_1B9D:
	PUSH	DS

	MOV	BX,2Fh
	MOV	CX,79h
	PUSH	ES
	POP	DS
C_1BA6:
	MOV	AL,[SI+1Bh]
	MOV	ES:[DI+1Bh],AL
	MOVSB
	ADD	DI,BX
	ADD	SI,BX
	LOOP	C_1BA6

	POP	DS
	RET
;----------------------------------------1BB6
InsideRaider:
	;-- controlling raider or orbital? --
	MOV	AX,g_pUserShip
	CMP	AX,OFFSET _DATA:D_0430	;raider
	JZ	C_1BC5

	MOV	BYTE PTR D_1B93,0

	JMP	SHORT C_1BCA
C_1BC5:
	MOV	BYTE PTR D_1B93,2
C_1BCA:
	;-- --
	MOV	D_1F0D._map_y,262
	;-- --
	CLD
	MOV	AX,DS
	MOV	ES,AX
	MOV	SI,OFFSET _DATA:D_1C21
	MOV	DI,OFFSET _DATA:D_1CA9
	MOV	CX,4 * SizeOf_s_actor
	REPZ	MOVSB
	;-- --
	MOV	DI,OFFSET _DATA:D_1C1D
	MOV	SI,OFFSET _DATA:D_004D
	MOV	BP,OFFSET _DATA:D_1CA9
	XOR	AH,AH
	MOV	CX,4
C_1BEE:
	MOV	BX,[SI]
	ADD	SI,2
	XOR	AL,AL
	CMP	[BX]._energy,0
	JZ	C_1C07
	INC	AL
	INC	AH	;orbital left ++
	CMP	[BX]._active,0
	JZ	C_1C07
	INC	AL
C_1C07:
	MOV	[DI],AL
	INC	DI
	CMP	AL,1
	JNZ	C_1C13
	MOV	DS:[BP]._active,0FFh
C_1C13:
	ADD	BP,SizeOf_s_actor
	MOV	[BX]._active,0
	LOOP	C_1BEE
	;-- no orbital left? --
	AND	AH,AH
	JNZ	C_1C26

	MOV	SI,OFFSET _DATA:D_0430	;raider
	JMP	C_1D14
C_1C26:
	;-- --
	XOR	AX,AX
	MOV	g_scroll_x,AX
	MOV	g_scroll_y,AX
	MOV	D_1BAF[0],AL
	MOV	D_1BE0[0],AL
	MOV	D_1F2F._active,AL
	MOV	D_1F51._active,AL

	CALL	C_1FDD	;"inside raider":related(4)?
	
	CMP	BYTE PTR D_1B93,0
	JZ	C_1C47
	CALL	C_1DA6	;"inside raider":related(3)?
	;%%%%%%%%%%%%%%%%%%%%%%%%%%
	;%% "inside raider" LOOP %%
	;%%%%%%%%%%%%%%%%%%%%%%%%%%
C_1C47:
	CMP	BYTE PTR D_1B93,2
	JNZ	C_1C7D

	CALL	C_1D3C	;"inside raider":manage input?
	TEST	AL,10h
	JZ	C_1C7D

	MOV	BL,D_1C14
	CMP	BL,0FFh
	JZ	C_1CAD

	XOR	BH,BH
	CMP	BYTE PTR D_1C1D[BX],1
	JNZ	C_1C6E

	MOV	BYTE PTR D_1B93,6

	JMP	SHORT C_1C7D
C_1C6E:
	INC	BYTE PTR D_1B93
	MOV	BYTE PTR D_1B94,13

	MOV	BX,OFFSET _DATA:D_1B87
	CALL	SND_play
C_1C7D:
	;-- --
	MOV	BX,g_pbkbuffer_front
	CMP	[BX]._render_flag,0
	JNZ	C_1C91

	CALL	UpdateScrollInfo
	CALL	C_1D1E	;[6030] to front copy?
	MOV	[BX]._render_flag,0FFh
C_1C91:
	;-- --
	CALL	C_2B1F	;restore vram(sprites)?
	CALL	C_1E3B	;"inside raider":related(2)?
	CALL	C_1DEF	;"inside raider":related(1)?
	CALL	RenderUI
	CALL	DoFlip

	CALL	C_1A23	;restore vram(tilemap)?
	CALL	Synchro_x4

	CMP	BYTE PTR D_1B93,5
	JNZ	C_1C47
	;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	;%% END "inside raider" LOOP %%
	;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
C_1CAD:
	XOR	AX,AX
	MOV	g_bkbuffer_0._render_flag,AL
	MOV	g_bkbuffer_1._render_flag,AL
	MOV	D_1433,AL
	MOV	D_11B2,AL
	MOV	D_2207,AL
	MOV	D_20F6,AL

	MOV	BL,D_1C14
	MOV	SI,OFFSET _DATA:D_0430	;raider
	CMP	BL,0FFh
	JZ	C_1D14

	XOR	BH,BH
	SHL	BX,1
	MOV	DI,SI
	MOV	SI,D_004D[BX]
	MOV	[SI]._accel_x,AX
	MOV	[SI]._accel_y,AX
	MOV	[SI]._speed_x,AX
	MOV	[SI]._speed_y,AX

	MOV	BL,[DI]._frame
	ADD	BL,8
	AND	BL,0Fh
	MOV	[SI]._frame,BL

	MOV	BL,[DI]._frame
	XOR	BH,BH
	SHL	BX,1
	SHL	BX,1

	MOV	AX,D_1F95[BX+00]
	ADD	AX,[DI]._map_x
	AND	AX,7FFh
	MOV	[SI]._map_x,AX

	MOV	AX,D_1F95[BX+02]
	ADD	AX,[DI]._map_y
	AND	AX,7FFh
	MOV	[SI]._map_y,AX

	MOV	[SI]._active,0FFh
	;-- --
C_1D14:
	MOV	BYTE PTR g_docking,10	;some delay before check
	MOV	g_pUserShip,SI

	RET
;----------------------------------------
;[6030] to front copy?
C_1D1E:
	MOV	AL,1	;write mode 1
	CALL	C_278D	;set EGA register state?

	CLD
	PUSH	DS
	MOV	SI,6030h
	MOV	DI,g_pbkbuffer_front
	MOV	DI,[DI]._voffset
	MOV	AX,SEG_A000
	MOV	ES,AX
	MOV	DS,AX
	MOV	CX,2400h
	REPZ	MOVSB
	POP	DS

	RET
;----------------------------------------
;"inside raider":manage input?
C_1D3C:
	PUSH	SI
	PUSH	CX
	PUSH	BX
	;-- --
	CALL	C_2B90	;make input mask[for pick orbital]?

	MOV	AH,D_1C14
	PUSH	AX

	MOV	BL,D_1C14
	MOV	AH,BL

	TEST	AL,3
	JZ	C_1D54
	XOR	BL,1
C_1D54:

	TEST	AL,0Ch
	JZ	C_1D5B
	XOR	BL,2
C_1D5B:

	XOR	BH,BH
	MOV	CX,4
C_1D60:
	AND	BL,3
	MOV	AL,D_1C1D[BX]
	AND	AL,AL
	JNZ	C_1D73
	INC	AH
	MOV	BL,AH
	LOOP	C_1D60
	MOV	BL,0FFh
C_1D73:
	MOV	D_1C14,BL

	POP	AX
	CMP	AH,D_1C14
	JZ	C_1D86

	PUSH	AX
	CALL	C_1FDD	;"inside raider":related(4)?
	CALL	C_1DA6	;"inside raider":related(3)?
	POP	AX
C_1D86:

	TEST	AL,10h
	JNZ	C_1D8D
	CALL	C_1D91	;"inside raider":manage "control raider"?
C_1D8D:
	;-- --
	POP	BX
	POP	CX
	POP	SI
	RET
;----------------------------------------
;"inside raider":manage "control raider"?
C_1D91:
	CALL	GetKBDScancode
	CMP	AL,D_B810[0Bh]	;"control raider"
	JNZ	C_1DA3

	MOV	D_1C14,0FFh	;(+nop)

	MOV	AL,10h
	RET
C_1DA3:
	XOR	AL,AL
	RET
;----------------------------------------
;"inside raider":related(3)?
C_1DA6:
	MOV	D_1F0D._active,0	;(+nop)

	CMP	BYTE PTR D_1C14,4
	JNB	C_1DDC

	XOR	AL,AL
	CALL	C_1DDD
	MOV	SI,BX
	MOV	DI,OFFSET _DATA:D_1F0D
	CALL	C_1FD2	;"inside raider":copy actor info?

	MOV	BL,D_1C14
	XOR	BH,BH
	CMP	BYTE PTR D_1C1D[BX],2
	JNZ	C_1DD6

	MOV	SI,OFFSET _DATA:D_1F73
	MOV	DI,OFFSET _DATA:D_1F0D
	CALL	C_1FD2	;"inside raider":copy actor info?
C_1DD6:
	MOV	D_1F0D._active,0FFh	;(+nop)
C_1DDC:
	RET
;---- ----
C_1DDD:
	PUSH	AX
	MOV	AL,D_1C14
	MOV	AH,SizeOf_s_actor
	MUL	AH
	MOV	BX,OFFSET _DATA:D_1CA9
	ADD	BX,AX
	POP	AX
	MOV	[BX]._active,AL

	RET
;----------------------------------------
;"inside raider":related(1)?
C_1DEF:
	MOV	CX,COUNT_0011
	MOV	DI,OFFSET _DATA:D_1D31
C_1DF6:
	CMP	[DI]._active,0
	JZ	C_1DFF
	CALL	C_1E15	;"inside raider":draw obj[DI]'s sprite?
C_1DFF:
	ADD	DI,SizeOf_s_actor
	LOOP	C_1DF6

	MOV	BL,D_1C14
	XOR	BH,BH
	SHL	BX,1
	MOV	BX,D_004D[BX]
	MOV	g_pUserShip,BX

	RET
;----------------------------------------
;"inside raider":draw obj[DI]'s sprite?
C_1E15:
	PUSH	DI
	PUSH	CX
	PUSH	BX

	MOV	AL,[DI]._frame
	MOV	SI,[DI]._p_spr
	MOV	DX,[DI]._map_x
	MOV	BX,[DI]._map_y
	XOR	AH,AH
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	MOV	ES,[SI]
	ADD	SI,2
	ADD	SI,AX
	CALL	DrawSprite

	POP	BX
	POP	CX
	POP	DI
	RET
;----------------------------------------
;"inside raider":related(2)?
C_1E3B:
	;-- --
	MOV	SI,OFFSET _DATA:D_1E41
	MOV	CX,4
	CALL	C_1FC6	;de-activate actor list?
	;-- --
	MOV	AL,D_1C14
	CMP	AL,0FFh
	JZ	C_1E64
	MOV	AH,SizeOf_s_actor
	MUL	AH
	ADD	SI,AX

	MOV	[SI]._active,0FFh
	MOV	BX,OFFSET _DATA:D_1C16
	MOV	AL,D_1C15
	CALL	C_1FB7
	MOV	D_1C15,AL
	MOV	[SI]._frame,AH
C_1E64:
	;-- --
	MOV	SI,OFFSET _DATA:D_1D31
	MOV	CX,8
	CALL	C_1FC6	;de-activate actor list?
	;-- --
	MOV	AL,D_1C13
	INC	AL
	AND	AL,7
	MOV	D_1C13,AL
	AND	AL,6
	MOV	AH,SizeOf_s_actor
	MUL	AH
	ADD	SI,AX
	MOV	[SI]._active,0FFh
	MOV	[SI+SizeOf_s_actor]._active,0FFh

	MOV	SI,OFFSET _DATA:D_1EC9
	MOV	AL,D_1B93
	MOV	[SI]._active,0
	MOV	[SI+SizeOf_s_actor]._active,0
	CMP	AL,2
	JZ	C_1EB3
	MOV	[SI]._active,0FFh
	MOV	[SI+SizeOf_s_actor]._active,0FFh

	MOV	[SI]._frame,19
	MOV	[SI+SizeOf_s_actor]._frame,19
	JB	C_1EB3
	MOV	[SI]._frame,18
	MOV	[SI+SizeOf_s_actor]._frame,18
C_1EB3:
	MOV	AL,D_1B93
	MOV	BX,OFFSET _DATA:D_1BAF
	MOV	AH,0Bh
	AND	AL,AL
	JZ	C_1ED6
	MOV	BX,OFFSET _DATA:D_1BE0
	MOV	AH,0Ch
	CMP	AL,4
	JZ	C_1ED6
	CMP	AL,2
	JZ	C_1F39
	CMP	AL,5
	JZ	C_1F39
	CMP	AL,6
	JZ	C_1F3A
	JMP	SHORT C_1F11
C_1ED6:
	MOV	AL,[BX]
	INC	BX
	XLAT	;AL <- BX[AL]
	CMP	AL,0FFh
	JNZ	C_1EE9
	INC	BYTE PTR D_1B93
	MOV	BYTE PTR D_1B94,0

	JMP	SHORT C_1F39
C_1EE9:
	MOV	SI,OFFSET _DATA:D_1F0D
	MOV	[SI]._frame,AH
	CBW
	ADD	[SI]._map_y,AX
	MOV	[SI]._map_x,197
	DEC	BX
	INC	BYTE PTR [BX]
	TEST	AH,80h
	JNZ	C_1F39

	XOR	D_1F2F._frame,1
	XOR	D_1F51._frame,1
	MOV	DX,-5
	MOV	CX,19
	JMP	SHORT C_1F59
C_1F11:
	MOV	SI,OFFSET _DATA:D_1F0D
	MOV	AL,D_1B94
	MOV	BX,OFFSET _DATA:D_1B95
	XLAT	;AL <- BX[AL]
	CMP	AL,0FFh
	JNZ	C_1F25
	INC	BYTE PTR D_1B93
	JMP	SHORT C_1F39
C_1F25:
	INC	BYTE PTR D_1B94
	MOV	[SI]._frame,AL
	MOV	[SI]._map_x,193
	MOV	[SI]._map_y,96
	MOV	[SI]._active,0FFh
C_1F39:
	RET
C_1F3A:
	MOV	SI,OFFSET _DATA:D_1F0D
	CALL	C_1FA7
	JZ	C_1F8B
	CALL	C_1FA7
	JZ	C_1F8B
	MOV	DX,-3
	MOV	CX,20

	MOV	D_1F2F._frame,23	;(+nop)
	MOV	D_1F51._frame,23	;(+nop)
C_1F59:
	MOV	BX,OFFSET _DATA:D_1F2F

	MOV	AX,[SI]._map_x
	ADD	AX,CX
	MOV	[BX]._map_x,AX

	MOV	AX,[SI]._map_y
	ADD	AX,DX
	MOV	[BX]._map_y,AX

	MOV	BX,OFFSET _DATA:D_1F51

	MOV	AX,[SI]._map_x
	ADD	AX,CX
	ADD	AX,10
	MOV	[BX]._map_x,AX

	MOV	AX,[SI]._map_y
	ADD	AX,DX
	MOV	[BX]._map_y,AX

	MOV	D_1F2F._active,0FFh	;(+nop)
	MOV	D_1F51._active,0FFh	;(+nop)

	RET
C_1F8B:
	MOV	D_1F2F._frame,24	;(+nop)
	MOV	D_1F51._frame,24	;(+nop)
	MOV	BYTE PTR D_1B94,13
	MOV	BYTE PTR D_1B93,4
	MOV	BYTE PTR D_1BE0[0],1

	RET
;---- ----
C_1FA7:
	MOV	AX,[SI]._map_x
	CMP	AX,197
	JZ	C_1FB6
	JB	C_1FB4
	DEC	[SI]._map_x
	JMP	SHORT C_1FB6
C_1FB4:
	INC	[SI]._map_x
C_1FB6:
	RET
;---- ----
;BX: @
;AL:
C_1FB7:
	MOV	AH,AL
	INC	AH
	XLAT	;AL <- BX[AL]
	CMP	AL,0FFh
	JNZ	C_1FC3
	XOR	AX,AX
	XLAT	;AL <- BX[AL]
C_1FC3:
	XCHG	AL,AH
	RET
;---- ----
;de-activate actor list?
;SI: @
;CX: count
C_1FC6:
	PUSH	SI

C_1FC7:
	MOV	[SI]._active,0
	ADD	SI,SizeOf_s_actor
	LOOP	C_1FC7

	POP	SI
	RET
;----------------------------------------
;"inside raider":copy actor info?
C_1FD2:
	CLD
	MOV	AX,DS
	MOV	ES,AX
	MOV	CX,SizeOf_s_actor
	REPZ	MOVSB

	RET
;----------------------------------------
;"inside raider":related(4)?
C_1FDD:
	MOV	SI,0000
	MOV	AX,SEG_4E03	;"inside raider BG" bitmap
	MOV	ES,AX
	MOV	DI,6030h
	CALL	BM2VRAM

	CALL	C_2003

	XOR	AL,AL
	MOV	D_1433,AL
	MOV	D_11B2,AL
	MOV	D_2207,AL
	MOV	D_20F6,AL
	MOV	g_bkbuffer_0._render_flag,AL
	MOV	g_bkbuffer_1._render_flag,AL

	RET
;---- ----
C_2003:
	PUSH	g_pbkbuffer_front

	MOV	g_pbkbuffer_front,OFFSET _DATA:g_bkbuffer_2
	MOV	DI,OFFSET _DATA:D_1CA9
	MOV	SI,OFFSET _DATA:D_1C1D
	MOV	CX,4
	XOR	AH,AH
C_2018:
	CMP	AH,D_1C14
	JZ	C_2039
	MOV	AL,[SI]
	AND	AL,AL
	JZ	C_2039
	DEC	AL
	JZ	C_202E
	PUSH	DI
	MOV	DI,OFFSET _DATA:D_1F73
	JMP	SHORT C_202F
C_202E:
	PUSH	DI
C_202F:
	PUSH	AX
	PUSH	SI
	PUSH	CX
	CALL	C_1E15	;"inside raider":draw obj[DI]'s sprite?
	POP	CX
	POP	SI
	POP	AX
	POP	DI
C_2039:
	INC	AH
	ADD	DI,SizeOf_s_actor
	INC	SI
	LOOP	C_2018

	MOV	D_16B4,0	;(+nop)

	POP	g_pbkbuffer_front
	RET
;----------------------------------------204C
SplashImage:
	;-- set palette 0 --
	MOV	DX,OFFSET _DATA:D_00DF
	MOV	AX,DS
	MOV	ES,AX
	MOV	AX,(10h SHL 8) OR 2
	INT	10h
	;-- --
	MOV	SI,0000
	MOV	AX,SEG_5583	;"splash" bitmap
	MOV	ES,AX
	MOV	DI,6030h
	CALL	BM2VRAM

	XOR	AX,AX
	MOV	g_scroll_x,AX
	MOV	g_scroll_y,AX
	MOV	g_bkbuffer_0._render_flag,AL
	MOV	g_bkbuffer_1._render_flag,AL

	CALL	UpdateScrollInfo
	CALL	C_1D1E	;[6030] to front copy?
	JMP	DoFlip
;----------------------------------------207D
;display credits
Credits:
	CALL	BG_hellraider

	MOV	SI,OFFSET _DATA:D_17FA
	MOV	CX,6
	MOV	DI,6030h
	CALL	DrawStringArray

	CALL	UpdateScrollInfo
	CALL	C_1D1E	;[6030] to front copy?
	JMP	DoFlip
;----------------------------------------2095
;display hiscores
HighScores:
	CALL	C_21AE	;convert hiscore data to strings
	CALL	BG_hellraider

	MOV	SI,OFFSET _DATA:D_186B
	MOV	CX,8
	MOV	DI,6030h
	CALL	DrawStringArray

	CALL	UpdateScrollInfo

	PUSH	g_pbkbuffer_front
	MOV	g_pbkbuffer_front,OFFSET _DATA:g_bkbuffer_2
	MOV	AX,SEG_3807
	MOV	ES,AX
	MOV	SI,OFFSET _DATA:D_DAE0	;"HIGH SCORE"
	MOV	DX,168
	MOV	BX,100
	CALL	DrawSprite
	MOV	BYTE PTR D_16B4,0
	POP	g_pbkbuffer_front

	CALL	C_1D1E	;[6030] to front copy?
	JMP	DoFlip
;----------------------------------------20D4
DrawStringArray:
C_20D4:
	MOV	DL,[SI]
	XOR	DH,DH
	INC	SI
	MOV	BL,[SI]
	XOR	BH,BH
	INC	SI
	MOV	AL,[SI]
	INC	SI
	PUSH	CX
	PUSH	DI
	CALL	DrawStringAt
	POP	DI
	POP	CX
	LOOP	C_20D4

	RET
;----------------------------------------
C_20EB:
	CALL	C_20FE

	PUSHF
	PUSH	SI
	CALL	HighScores
	POP	SI
	POPF	

	JNB	C_20FD
	CALL	C_214A	;hiscore input screen?
	CALL	SaveHiscores
C_20FD:
	RET
;---- ----
C_20FE:
	MOV	CX,DS
	MOV	ES,CX
	MOV	SI,OFFSET _DATA:D_1ADB
	MOV	CX,8
C_2108:
	CMP	DX,[SI+0Ah]
	JA	C_211B
	JB	C_2114
	CMP	AX,[SI+08]
	JA	C_211B
C_2114:
	ADD	SI,0Ch
	LOOP	C_2108
	CLC
	RET
C_211B:
	DEC	CX
	JZ	C_2133
	PUSH	SI
	PUSH	AX
	MOV	DI,OFFSET _DATA:D_1ADB + 7 * 0Ch + 0Bh	;1B3A
	MOV	SI,DI
	SUB	SI,0Ch
	MOV	AL,0Ch
	MUL	CL
	MOV	CX,AX
	STD	
	REPZ	MOVSB
	POP	AX
	POP	SI
C_2133:
	MOV	[SI+08],AX
	MOV	[SI+0Ah],DX
	PUSH	SI
	MOV	DI,SI
	MOV	CX,8
	MOV	AL,2Ch
	CLD
	REPZ	STOSB
	CALL	C_21AE	;convert hiscore data to strings
	POP	SI
	STC
	RET
;---- ----
;hiscore input screen?
C_214A:
	XOR	BX,BX
C_214C:
	PUSH	SI
	PUSH	BX

	MOV	DI,g_pbkbuffer_front
	MOV	[DI]._vscroll,0

	CALL	C_1D1E	;[6030] to front copy?
	CALL	C_21AE	;convert hiscore data to strings

	MOV	DI,g_pbkbuffer_front
	MOV	DI,[DI]._voffset
	MOV	SI,OFFSET _DATA:D_186B
	MOV	CX,8
	CALL	DrawStringArray

	CALL	DoFlip

	POP	BX
	POP	SI
C_2171:
	CALL	GetKBDScancode
	JNB	C_2171
	CMP	AL,3Ah
	JNB	C_2171

	XOR	AH,AH
	MOV	DI,OFFSET _DATA:D_1B3B
	ADD	DI,AX
	MOV	AL,[DI]
	AND	AL,AL
	JZ	C_2171

	PUSH	AX
	PUSH	BX
	MOV	BX,OFFSET _DATA:D_1B7B
	CALL	SND_play
	POP	BX
	POP	AX

	CMP	AL,63h	;<RETURN>
	JZ	C_21AD

	CMP	AL,62h	;<BS>
	JNZ	C_21A3
	AND	BX,BX
	JZ	C_2171
	DEC	BX
	MOV	BYTE PTR [BX+SI],2Ch	;blank
	JMP	C_214C
C_21A3:
	CMP	BX,8
	JZ	C_2171
	MOV	[BX+SI],AL
	INC	BX
	JMP	C_214C
C_21AD:
	RET
;----------------------------------------
;convert hiscore data to strings
C_21AE:
	CLD

	MOV	AX,DS
	MOV	ES,AX

	MOV	SI,OFFSET _DATA:D_1ADB
	MOV	DI,OFFSET _DATA:D_186B + 3
	MOV	CX,8
C_21BC:
	PUSH	CX

	MOV	CX,8
	REPZ	MOVSB
	MOV	AX,[SI]
	MOV	DX,[SI+02]
	ADD	SI,4
	INC	DI
	CALL	WInt2Str

	POP	CX
	ADD	DI,4
	LOOP	C_21BC

	RET
;----------------------------------------
;"keys.dat":user input
C_21D5:
	CALL	C_2283	;control keys BG
	CALL	C_2235	;display control keys?
C_21DB:
	CALL	GetKBDScancode
	JNB	C_21DB
	CMP	AL,KBD_F1
	JZ	C_2211

	MOV	CX,0Ch
	MOV	SI,OFFSET _DATA:D_B810
C_21EA:
	MOV	BYTE PTR [SI],0
	INC	SI
	LOOP	C_21EA

	CALL	C_2235	;display control keys?

	MOV	CX,0Ch
	MOV	SI,OFFSET _DATA:D_B810
C_21F9:
	PUSH	CX
	CALL	C_2212	;read one key?
	POP	CX
	MOV	[SI],AL
	INC	SI
	CALL	C_2235	;display control keys?
	LOOP	C_21F9

	CALL	SaveKeys

	WAIT_M	25
C_2211:
	RET
;---- ----2212
;read one key?
C_2212:
	CALL	GetKBDScancode
	JNB	C_2212
	;-- excludes [0x3b,0x45[ --
	CMP	AL,KBD_F1
	JB	C_221F
	CMP	AL,45h	;<NUM>
	JB	C_2212
C_221F:
	;-- --
	MOV	BX,OFFSET _DATA:D_B810
	MOV	CX,0Ch
C_2225:
	CMP	AL,[BX]
	JZ	C_2212
	INC	BX
	LOOP	C_2225

	PUSH	AX
	MOV	BX,OFFSET _DATA:D_1B7B
	CALL	SND_play
	POP	AX

	RET
;---- ----2235
;display control keys?
C_2235:
	PUSH	SI
	PUSH	CX

	MOV	SI,OFFSET _DATA:D_B810
	MOV	DI,OFFSET _DATA:D_1988 + 3
	MOV	CX,0Ch
C_2240:
	MOV	BL,[SI]
	CMP	BL,54h
	JB	C_2249
	MOV	BL,54h
C_2249:
	INC	SI
	XOR	BH,BH
	MOV	AX,BX
	SHL	BX,1
	ADD	BX,AX
	ADD	BX,OFFSET _DATA:D_19DC
	MOV	AL,[BX]
	MOV	[DI],AL
	MOV	AL,[BX+01]
	MOV	[DI+01],AL
	MOV	AL,[BX+02]
	MOV	[DI+02],AL

	ADD	DI,7
	LOOP	C_2240

	CALL	C_1D1E	;[6030] to front copy?

	MOV	BX,g_pbkbuffer_front
	MOV	DI,[BX]._voffset
	MOV	CX,12
	MOV	SI,OFFSET _DATA:D_1988
	CALL	DrawStringArray

	CALL	DoFlip

	POP	CX
	POP	SI
	RET
;---- ----2283
;control keys BG
C_2283:
	CALL	BG_hellraider
	CALL	UpdateScrollInfo

	MOV	DI,6030h
	MOV	CX,0Eh
	MOV	SI,OFFSET _DATA:D_1903
	JMP	DrawStringArray
;----------------------------------------2295
BonusScreen:
	CALL	BG_hellraider
	CALL	UpdateScrollInfo

	PUSH	g_pbkbuffer_front
	MOV	g_pbkbuffer_front,OFFSET _DATA:g_bkbuffer_2
	MOV	AX,SEG_3807
	MOV	ES,AX
	MOV	SI,OFFSET _DATA:D_DAF0	;"BONUS"
	MOV	DX,193
	MOV	BX,105
	CALL	DrawSprite
	POP	g_pbkbuffer_front

	XOR	AX,AX
	MOV	D_16B4,AL

	MOV	SI,OFFSET _DATA:g_killCounts
	MOV	CX,8
C_22C5:
	PUSH	CX
	PUSH	SI
	MOV	CX,[SI]
	JCXZ	C_22D4

	MOV	AX,[SI+20h]	;__0180
	MOV	SI,[SI+10h]	;__0170
	CALL	C_22DE	;"BONUS"?

C_22D4:
	POP	SI
	ADD	SI,2
	POP	CX
	LOOP	C_22C5

	JMP	BuyOrbital
;---- ----
;"BONUS"?
;AX: bonus points
;CX: ship count
;SI: ship info
C_22DE:
	;-- convert bonus points to string --
	PUSH	AX
	PUSH	CX
	MOV	CL,3
	MOV	DI,OFFSET _DATA:D_1787 + 3
	CALL	Int2Str
	POP	CX
	POP	AX
	;-- --
	CALL	C_2313

	CALL	DelayForBonus
	;-- --
C_22F0:
	DEC	CX

	ADD	g_score[0],AX
	JNB	C_22FB
	INC	g_score[2]
C_22FB:

	CALL	C_2313

	PUSH	AX
	MOV	BX,OFFSET _DATA:D_1B7B
	CALL	SND_play
	POP	AX

	CALL	Synchro_x4
	CALL	Synchro_x4

	JCXZ	C_2310
	JMP	C_22F0
C_2310:
	;-- --
	JMP	DelayForBonus
;---- ----
C_2313:
	PUSH	AX
	PUSH	CX
	PUSH	SI

	PUSH	CX
	PUSH	SI
	CALL	UpdateScrollInfo
	CALL	C_1D1E	;[6030] to front copy?
	POP	SI
	CALL	C_2359
	POP	AX

	MOV	CL,2
	CMP	AX,100
	JB	C_232D
	MOV	AX,99
C_232D:
	MOV	DI,OFFSET _DATA:D_1780 + 3
	CALL	Int2Str

	MOV	AX,g_score[0]
	MOV	DX,g_score[2]
	MOV	DI,OFFSET _DATA:D_178E + 3
	CALL	WInt2Str

	MOV	DI,g_pbkbuffer_front
	MOV	DI,[DI]._voffset
	MOV	SI,OFFSET _DATA:D_1780
	MOV	CX,3
	CALL	DrawStringArray

	CALL	DoFlip

	CALL	C_2B1F	;restore vram(sprites)?

	POP	SI
	POP	CX
	POP	AX
	RET
;---- ----
C_2359:
	MOV	SI,[SI]._p_spr
	MOV	ES,[SI]
	ADD	SI,2 + 4 * 10h	;42h
	MOV	DX,228
	MOV	AL,[SI]._box1_left
	CBW
	ADD	DX,AX
	MOV	BX,154
	MOV	AL,[SI]._box1_top
	CBW
	ADD	BX,AX
	CALL	DrawSprite

	MOV	SI,OFFSET _DATA:D_DAF0	;"BONUS"
	MOV	AX,SEG_3807
	MOV	ES,AX
	MOV	DX,193
	MOV	BX,105
	JMP	DrawSprite
;---- ----2387
DelayForBonus:
	PUSH	CX

	WAIT_M	10

	POP	CX
	RET
;----------------------------------------2392
BuyOrbital:
	CMP	D_0430._active,0	;raider
	JZ	C_23F9

	MOV	BX,OFFSET _DATA:D_0452
	MOV	CX,4
C_239F:
	CMP	[BX]._energy,0
	JZ	C_23AB
	ADD	BX,SizeOf_s_actor
	LOOP	C_239F

	RET
	;-- an orbital missing --
C_23AB:
	MOV	AX,20000
	CMP	g_score[2],0
	JNZ	C_23BB
	CMP	AX,g_score[0]
	JNB	C_23F9
C_23BB:
	;-- "buy a new orbital/for 20000 pts/ y n"? --
	PUSH	BX

	MOV	SI,OFFSET _DATA:D_1798
	MOV	CX,3
	MOV	DI,6030h
	CALL	DrawStringArray

	MOV	SI,OFFSET _DATA:D_178E
	MOV	CX,1
	MOV	DI,6030h
	CALL	DrawStringArray

	CALL	C_1D1E	;[6030] to front copy?

	CALL	DoFlip

	POP	DI
C_23DB:
	CALL	GetKBDScancode
	CMP	AL,31h	;N
	JZ	C_23F9
	CMP	AL,15h	;Y
	JNZ	C_23DB
	;-- 'Y'es --

	;score -= 20000
	MOV	AX,20000
	SUB	g_score[0],AX
	JNB	C_23F3
	DEC	g_score[2]
C_23F3:

	MOV	SI,OFFSET _DATA:D_0B5C	;"orbital"
	CALL	SetShipInfos
	;-- --
C_23F9:
	RET
;----------------------------------------23FA
;"HELLRAIDER" background
BG_hellraider:
	MOV	SI,0000
	MOV	AX,SEG_6483	;"HELLRAIDER logo" bitmap
	MOV	ES,AX
	MOV	DI,6030h
	CALL	BM2VRAM_logo

	XOR	AX,AX
	MOV	g_scroll_x,AX
	MOV	g_scroll_y,AX
	MOV	g_bkbuffer_0._render_flag,AL
	MOV	g_bkbuffer_1._render_flag,AL

	RET
;----------------------------------------2417
;load bitmap in vram[320x30](for HELLRAIDER logo)
;(similar to BM2VRAM)
BM2VRAM_logo:
	XOR	AL,AL	;write mode 0
	CALL	C_278D	;set EGA register state?

	PUSH	DS

	MOV	AX,ES
	MOV	DS,AX

	MOV	AX,SEG_A000
	MOV	ES,AX

	MOV	DX,PORT_3C4
	MOV	AL,2	;map mask register
	OUT	DX,AL
	INC	DX

	CLD

	MOV	AL,1
	CALL	PLANE2VRAM_logo
	MOV	AL,2
	CALL	PLANE2VRAM_logo
	MOV	AL,4
	CALL	PLANE2VRAM_logo
	MOV	AL,8
	CALL	PLANE2VRAM_logo

	POP	DS
	RET
;---- ----2444
PLANE2VRAM_logo:
	PUSH	DI
	;-- PORT_3C4[2] := AL -- "Map Mask Register"
	OUT	DX,AL
	;-- --
	MOV	CX,30
C_2449:
	PUSH	CX
	MOV	CX,14h
	REPZ	MOVSW
	ADD	DI,8
	POP	CX
	LOOP	C_2449
	;-- --
	PUSH	SI
	;-- copy last line for the rest of the screen --
	MOV	CX,162
C_2459:
	SUB	SI,28h
	PUSH	CX
	MOV	CX,14h
	REPZ	MOVSW
	POP	CX
	ADD	DI,8
	LOOP	C_2459
	;-- --
	POP	SI

	POP	DI
	RET
;----------------------------------------246B
;"LEVEL XX" animation:landing
LevelStartAnim:
	MOV	BX,OFFSET _DATA:D_1FF9
	MOV	BYTE PTR D_185F[3],1Dh	;'L'

	MOV	DI,OFFSET _DATA:D_185F + 9
	MOV	AL,g_level
	INC	AL
	CMP	AL,100
	JB	C_2481
	MOV	AL,99
C_2481:
	XOR	AH,AH
	MOV	CL,02
	CALL	Int2Str

	JMP	SHORT C_2492
;---- ----248A
;"LEVEL XX" animation:leaving
LevelEndAnim:
	MOV	BX,OFFSET _DATA:D_204E
	MOV	BYTE PTR D_185F[3],0FFh	;EndOfString
;---- ----
C_2492:
	CALL	C_2546	;level start/end BG?

	XOR	AX,AX
	MOV	g_scroll_x,AX
	MOV	g_scroll_y,AX
	MOV	g_bkbuffer_0._render_flag,AL
	MOV	g_bkbuffer_1._render_flag,AL

	MOV	SI,OFFSET _DATA:D_1FD5
	MOV	AL,[BX]
	INC	BX
	XOR	AH,AH
	MOV	[SI]._map_y,AX
	MOV	D_1FF7,BX
	;%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	;%% "level animation" LOOP %%
	;%%%%%%%%%%%%%%%%%%%%%%%%%%%%
C_24B2:
	;-- --
	MOV	BX,g_pbkbuffer_front
	CMP	[BX]._render_flag,0
	JNZ	C_24C6

	CALL	UpdateScrollInfo
	CALL	C_1D1E	;[6030] to front copy?
	MOV	[BX]._render_flag,0FFh
C_24C6:
	;-- --
	CALL	C_2B1F	;restore vram(sprites)?
	CALL	C_24FA
	JB	C_24E5

	MOV	BX,g_pbkbuffer_front
	MOV	DI,[BX]._voffset
	MOV	CX,1
	MOV	SI,OFFSET _DATA:D_185F
	CALL	DrawStringArray

	CALL	DoFlip

	CALL	Synchro_x4

	JMP	C_24B2
	;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	;%% END "level animation" LOOP %%
	;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
C_24E5:
	XOR	AX,AX
	MOV	g_bkbuffer_0._render_flag,AL
	MOV	g_bkbuffer_1._render_flag,AL
	MOV	D_1433,AL
	MOV	D_11B2,AL
	MOV	D_2207,AL
	MOV	D_20F6,AL

	RET
;----------------------------------------
C_24FA:
	MOV	DI,OFFSET _DATA:D_1FD5

	MOV	AL,[DI]._frame
	INC	AL
	AND	AL,7
	MOV	[DI]._frame,AL

	MOV	SI,[DI]._p_spr
	XOR	AH,AH
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	MOV	ES,[SI]
	ADD	SI,2
	ADD	SI,AX
	MOV	DX,[DI]._map_x
	MOV	AL,[SI]._box1_left
	CBW
	ADD	DX,AX
	MOV	BX,D_1FF7
	MOV	AL,[BX]
	CMP	AL,0FFh
	JZ	C_2544
	INC	BX
	MOV	D_1FF7,BX
	XOR	AH,AH
	ADD	AX,40h
	MOV	BX,AX
	MOV	AL,[SI]._box1_top
	CBW
	ADD	BX,AX
	CALL	DrawSprite

	CLC
	RET
C_2544:
	STC
	RET
;----------------------------------------
;level start/end BG?
C_2546:
	MOV	SI,0000
	MOV	AX,SEG_5D03	;"level" bitmap
	MOV	ES,AX
	MOV	DI,6030h
	JMP	BM2VRAM
;----------------------------------------2554
;load bitmap in vram[320x192]
;(similar to BM2VRAM_logo)
BM2VRAM:
	XOR	AL,AL	;write mode 0
	CALL	C_278D	;set EGA register state?

	PUSH	DS

	MOV	AX,ES
	MOV	DS,AX

	MOV	AX,SEG_A000
	MOV	ES,AX

	MOV	DX,PORT_3C4
	MOV	AL,2	;map mask register
	OUT	DX,AL
	INC	DX

	CLD

	MOV	AL,1
	CALL	PLANE2VRAM
	MOV	AL,2
	CALL	PLANE2VRAM
	MOV	AL,4
	CALL	PLANE2VRAM
	MOV	AL,8
	CALL	PLANE2VRAM

	POP	DS
	RET
;---- ----2581
PLANE2VRAM:
	PUSH	DI
	;-- PORT_3C4[2] := AL -- "Map Mask Register"
	OUT	DX,AL
	;-- --
	MOV	CX,192
C_2586:
	PUSH	CX
	MOV	CX,14h
	REPZ	MOVSW
	ADD	DI,8
	POP	CX
	LOOP	C_2586
	;-- --
	POP	DI
	RET
;----------------------------------------2594
RenderUI:
	;-- score --
	MOV	AX,g_score[0]
	MOV	DX,g_score[2]
	MOV	DI,OFFSET _DATA:D_17F3
	CALL	WInt2Str
	;-- --
	MOV	SI,OFFSET _DATA:D_17C7	;"ORBITAL"
	CALL	DrawString

	MOV	SI,OFFSET _DATA:D_17D3	;"RAIDER"
	CALL	DrawString

	MOV	SI,OFFSET _DATA:D_17DE	;"HOLDS"
	CALL	DrawString

	MOV	SI,OFFSET _DATA:D_17E8	;"VALUE: 000000"
	CALL	DrawString
	;-- gauge 1 "HOLDS" --
	MOV	SI,OFFSET _DATA:D_DB10
	MOV	AX,g_gems
	MOV	DX,328
	MOV	BX,224
	CALL	DrawGauge
	;-- gauge 2 "ORBITAL" --
	MOV	SI,OFFSET _DATA:D_DE10
	MOV	BX,g_pUserShip
	XOR	AX,AX
	CMP	BX,OFFSET _DATA:D_0430	;raider
	JZ	C_25DA
	MOV	AL,[BX]._energy
C_25DA:
	MOV	DX,136
	MOV	BX,224
	CALL	DrawGauge
	;-- gauge 2 "RAIDER" --
	MOV	SI,OFFSET _DATA:D_DE10
	MOV	BX,OFFSET _DATA:D_0430	;raider
	MOV	AL,[BX]._energy
	SHR	AL,1
	MOV	DX,136
	MOV	BX,240
;---- ----25F4
DrawGauge:
	CMP	AL,30h
	JB	C_25FA
	MOV	AL,2Fh
C_25FA:
	XOR	AH,AH
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	ADD	SI,AX
	MOV	AX,SEG_467A
	MOV	ES,AX
	JMP	DrawSprite
;----------------------------------------260E
DrawStringAt:
	MOV	g_text_color,AL

	XOR	AL,AL	;write mode 0
	CALL	C_278D	;set EGA register state?

	SHL	BX,1
	SHL	BX,1
	SHL	BX,1
	SHL	BX,1
	ADD	DI,BX
	SHL	BX,1
	ADD	DI,BX
	MOV	AX,DX
	SHR	AX,1
	SHR	AX,1
	SHR	AX,1
	ADD	DI,AX
	CLD
	MOV	CX,DX

	JMP	SHORT C_266F
;---- ----2633
DrawString:
	MOV	BYTE PTR g_text_color,0Ah

	XOR	AL,AL	;write mode 0
	CALL	C_278D	;set EGA register state?

	CLD

	LODSW
	MOV	DI,g_pbkbuffer_front
	ADD	AX,[DI]._vscroll
	MOV	DX,[DI]._voffset
	ADD	AX,DX
	MOV	BX,[DI].fff_04
	MOV	DI,AX

	MOV	AL,[BX]	;count
	INC	BYTE PTR [BX]	;count
	INC	BX
	XOR	AH,AH
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	ADD	BX,AX
	MOV	[BX]._dst_offset,DI
	MOV	[BX]._src_offset,DX

	LODSB
	MOV	[BX]._bytes_per_line,AL
	LODSB
	MOV	[BX]._line_count,AL

	MOV	CX,g_scroll_x
;---- ----
C_266F:
	AND	CX,7
	MOV	BX,0FF00h
	SHR	BX,CL

	MOV	AX,SEG_A000
	MOV	ES,AX

	MOV	BP,2Eh
C_267F: ;-- next char --
	LODSB
	CMP	AL,0FFh	;EndOfString?
	JNZ	C_2685
	RET
C_2685:
	PUSH	SI

	XOR	AH,AH
	SHL	AX,1
	MOV	SI,AX
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	ADD	SI,AX
	ADD	SI,OFFSET _DATA:D_D6B0	;font data
	;******************
	;**** AND mask ****
	;-- PORT_3CE[3] := CL | 8 --
	MOV	DX,PORT_3CE
	MOV	AL,3	;data rotate/write mode
	MOV	AH,CL
	OR	AH,8
	OUT	DX,AX
	;-- PORT_3C4[2] := 0Fh -- "Map Mask Register"
	MOV	DX,PORT_3C4
	MOV	AX,(0Fh SHL 8) OR 2
	OUT	DX,AX
	;-- --
	MOV	DL,0CEh	;PORT_3CE
	MOV	AL,8	;bit mask register
	OUT	DX,AL
	INC	DX
	CALL	C_26D3
	;******************
	;**** OR image ****
	;-- PORT_3CE[3] := CL | 10h --
	DEC	DX	;PORT_3CE
	MOV	AL,3
	MOV	AH,CL
	OR	AH,10h
	OUT	DX,AX
	;-- PORT_3C4[2] := g_text_color -- "Map Mask Register"
	MOV	DX,PORT_3C4
	MOV	AH,g_text_color
	MOV	AL,2	;map mask register
	OUT	DX,AX
	;-- --
	MOV	DL,0CEh	;PORT_3CE
	MOV	AL,8	;bit mask register
	OUT	DX,AL
	INC	DX
	CALL	C_26D3
	;-- --
	INC	DI
	POP	SI
	JMP	C_267F	;next char
;---- ----
;DS:SI: src @
;ES:DI: dest @
;BP: dest vram stride?
;BH: scroll mask for byte 1
;BL: scroll mask for byte 2
;each source byte is written twice to the VRAM,
; masked according to the current horizontal
; scrolling state
C_26D3:
	PUSH	CX

	MOV	CL,9
	PUSH	DI
C_26D7:
	;-- PORT_3CE[8] := BH --
	MOV	AL,BH
	OUT	DX,AL
	;-- --
	MOV	AL,ES:[DI]	;value not used, but this seems important

	MOV	AL,[SI]
	STOSB
	;-- PORT_3CE[8] := BL --
	MOV	AL,BL
	OUT	DX,AL
	;-- --
	MOV	AL,ES:[DI]	;value not used, but this seems important

	MOVSB

	ADD	DI,BP
	LOOP	C_26D7
	POP	DI

	POP	CX
	RET
;----------------------------------------26EE
;update some EGA states(scroll,...)?
DoFlip:
	CMP	BYTE PTR g_vsync_option,0	;[F8] related option
	JNZ	C_2738
	;-- --
	;
	;-- --
	MOV	DX,PORT_3DA
C_26F8:
	IN	AL,DX
	TEST	AL,8
	JNZ	C_26F8
	;-- --
	CLI
	;-- set registers 0xc & 0xd[CRTC:start address high&low] --
	MOV	SI,g_pbkbuffer_front
	MOV	CX,[SI]._voffset
	ADD	CX,[SI]._vscroll
	MOV	DX,PORT_3D4
	MOV	AH,CH
	MOV	AL,0Ch
	OUT	DX,AX
	MOV	AH,CL
	MOV	AL,0Dh
	OUT	DX,AX
	;-- --
	MOV	DX,PORT_3DA
C_2717:
	IN	AL,DX
	TEST	AL,8
	JZ	C_2717
	;-- horizontal pixel panning[0..7] --
	MOV	DX,PORT_3C0
	MOV	AL,20h OR 13h
	OUT	DX,AL
	MOV	AX,g_scroll_x
	AND	AL,7
	OUT	DX,AL
	;-- flip? --
	MOV	AX,g_pbkbuffer_front
	MOV	DX,g_pbkbuffer_back
	MOV	g_pbkbuffer_front,DX
	MOV	g_pbkbuffer_back,AX

	STI	
	RET
	;-- --
C_2738:
	CLI	
	;-- --
	MOV	DX,PORT_3DA
C_273C:
	IN	AL,DX
	TEST	AL,8
	JZ	C_273C
	;-- --
	;
	;-- set registers 0xc & 0xd[CRTC:start address high&low] --
	MOV	SI,g_pbkbuffer_front
	MOV	CX,[SI]._voffset
	ADD	CX,[SI]._vscroll
	MOV	DX,PORT_3D4
	MOV	AH,CH
	MOV	AL,0Ch
	OUT	DX,AX
	MOV	AH,CL
	MOV	AL,0Dh
	OUT	DX,AX
	;-- --
	;
	;
	;
	;
	;
	;-- horizontal pixel panning[0..7] --
	MOV	DX,PORT_3C0
	MOV	AL,20h OR 13h
	OUT	DX,AL
	MOV	AX,g_scroll_x
	AND	AL,7
	OUT	DX,AL
	;-- flip? --
	MOV	AX,g_pbkbuffer_front
	MOV	DX,g_pbkbuffer_back
	MOV	g_pbkbuffer_front,DX
	MOV	g_pbkbuffer_back,AX

	STI	
	RET
;----------------------------------------2773
;set graphic mode
GrMode:
	;-- set video mode 320x200 16col (EGA) --
	MOV	AX,(0 SHL 8) OR 0Dh
	INT	10h
	;-- PORT_3D4[13h] := 18h --
	MOV	DX,PORT_3D4
	MOV	AL,13h	;CRTC: offset register
	OUT	DX,AL
	INC	DX
	MOV	AL,18h
	OUT	DX,AL
	;-- PORT_3D4[12h] := 0BFh --
	MOV	DX,PORT_3D4
	MOV	AL,12h	;CRTC: vertical display end register
	OUT	DX,AL
	INC	DX
	MOV	AL,0BFh
	OUT	DX,AL
	;-- --
	RET
;----------------------------------------
;set EGA register state?
C_278D:
	PUSH	DX

	PUSH	AX	;push parameter
	;-- PORT_3C4[2] := 0Fh -- "Map Mask Register"
	MOV	DX,PORT_3C4
	MOV	AL,2	;map mask register
	OUT	DX,AL
	INC	DX
	MOV	AL,0Fh
	OUT	DX,AL
	;-- PORT_3CE[8] := 0FFh --
	MOV	AX,(0FFh SHL 8) OR 8	;bit mask register
	CALL	C_27B5	;PORT_3CE[AL] := AH
	;-- PORT_3CE[3] := 0 --
	MOV	AX,(0 SHL 8) OR 3	;data rotate/write mode
	CALL	C_27B5	;PORT_3CE[AL] := AH
	;-- PORT_3CE[1] := 0 --
	MOV	AX,(0 SHL 8) OR 1	;enable set/reset register
	CALL	C_27B5	;PORT_3CE[AL] := AH
	;-- --
	POP	AX	;pop parameter
	;-- PORT_3CE[5] := param --
	MOV	AH,AL
	MOV	AL,5	;mode register
	CALL	C_27B5	;PORT_3CE[AL] := AH
	;-- --
	POP	DX
	RET
;---- ----
;PORT_3CE[AL] := AH
C_27B5:
	PUSH	DX

	MOV	DX,PORT_3CE
	OUT	DX,AL
	INC	DX
	MOV	AL,AH
	OUT	DX,AL

	POP	DX
	RET
;----------------------------------------27C0
;DS:SI: sprite data[s_sprite]
;ES: sprite segment
;DX: screen_x
;BX: screen_y (or vram y?)
DrawSprite:
	MOV	DI,0F3F8h	;-0C08h?

	MOV	SI,[SI]._p_data_spr
	MOV	D_11B0,SI
	ADD	SI,8

	MOV	AX,g_scroll_x
	AND	AL,7
	MOV	AH,DL
	AND	AH,7
	ADD	AL,AH
	TEST	AL,0F8h
	JZ	C_27DD
	INC	DI
C_27DD:
	AND	AX,7
	ADD	AX,AX
	MOV	ES:[0],AX
	MOV	AX,BX
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	ADD	DI,AX
	SHL	AX,1
	ADD	DI,AX	;+screen_y * 40h
	SHR	DX,1
	SHR	DX,1
	SHR	DX,1
	ADD	DI,DX	;+screen_x * 8
	MOV	BX,g_pbkbuffer_front
	ADD	DI,[BX]._voffset
	ADD	DI,[BX]._vscroll

	MOV	BP,[BX]._voffset
	ADD	BP,[BX]._vscroll
	SUB	BP,8

	MOV	BX,[BX].fff_06
	MOV	AL,[BX]
	INC	BX
	XOR	AH,AH
	SHL	AX,1
	ADD	BX,AX
	SHL	AX,1
	SHL	AX,1
	ADD	BX,AX
	MOV	CX,BX
	;-- --
	MOV	AL,0	;write mode 0
	CALL	C_278D	;set EGA register state?
	;-- --
	MOV	DX,PORT_3C4
	MOV	AL,2	;map mask register
	OUT	DX,AL
	;*************
	;****     ****
	;-- PORT_3CE[3] := 8 --
	MOV	DX,PORT_3CE
	MOV	AL,3	;data rotate/write mode
	OUT	DX,AL
	INC	DX
	MOV	AL,8
	OUT	DX,AL
	;-- --
	CALL	C_2993	;put sprite mask?
	;*************
	;****     ****
	;-- PORT_3CE[3] := 0 --
	MOV	DX,PORT_3CE + 1
	XOR	AL,AL
	OUT	DX,AL
	DEC	DX
	;-- --
	MOV	AL,4	;read map select
	OUT	DX,AL

	MOV	AX,(1 SHL 8) OR 0
	CALL	C_285D
	MOV	AX,(2 SHL 8) OR 1
	CALL	C_285D
	MOV	AX,(4 SHL 8) OR 2
	CALL	C_285D
	MOV	AX,(8 SHL 8) OR 3
	JMP	C_285D	;(+nop)
;---- ----
;AL: read map select
;AH: map mask
C_285D:
	PUSH	DS
	PUSH	ES
	PUSH	DI
	;-- PORT_3CE[4] := AL -- "Read Map Select Register"
	MOV	DX,PORT_3CE + 1
	OUT	DX,AL
	;-- PORT_3C4[2] := AH -- "Map Mask Register"
	MOV	AL,AH
	MOV	DX,PORT_3C4 + 1
	OUT	DX,AL
	;-- --
	MOV	SI,D_11B0
	ADD	D_11B0,2

	MOV	AX,ES
	MOV	DS,AX

	MOV	AX,SEG_A000
	MOV	ES,AX

	MOV	SI,[SI]

	ADD	DI,[SI]	;"vram skip offset"
	ADD	SI,2

	MOV	DX,BP
	ADD	DX,2400h
	XOR	AH,AH
C_288B:
	CMP	DI,DX
	JNS	C_28AB	;return
	CMP	DI,BP
	JNS	C_289F

	LODSB	;# of bytes
	ADD	SI,AX
	ADD	DI,AX
	ADD	DI,[SI]	;"vram skip offset"
	ADD	SI,2

	JMP	C_288B
C_289F:
	MOV	BX,DS:[EXTRA_0000]
	MOV	BX,DS:EXTRA_0002[BX]
	XOR	CH,CH
	CALL	BX
	;-- --
C_28AB:
	POP	DI
	POP	ES
	POP	DS
	RET
;---- ----
PUBLIC C_28AF
C_28AF:
	MOV	CL,[SI]
	INC	SI
C_28B2:
	LODSB
	;
	OR	ES:[DI],AL
	INC	DI
	LOOP	C_28B2
	ADD	DI,[SI]
	ADD	SI,2
	CMP	DI,DX
	JB	C_28AF

	RET
;---- ----
PUBLIC C_28C3
C_28C3:
	MOV	CL,[SI]
	INC	SI
C_28C6:
	MOV	AH,[SI]
	INC	SI
	MOV	AL,CH
	SHR	AX,1
	;
	XCHG	AL,AH
	OR	ES:[DI],AX
	INC	DI


	LOOP	C_28C6
	ADD	DI,[SI]
	ADD	SI,2
	CMP	DI,DX
	JB	C_28C3

	RET
;---- ----
PUBLIC C_28DF
C_28DF:
	MOV	CL,[SI]
	INC	SI
C_28E2:
	MOV	AH,[SI]
	INC	SI
	MOV	AL,CH
	SHR	AX,1
	SHR	AX,1
	;
	XCHG	AL,AH
	OR	ES:[DI],AX
	INC	DI


	LOOP	C_28E2
	ADD	DI,[SI]
	ADD	SI,2
	CMP	DI,DX
	JB	C_28DF

	RET
;---- ----
PUBLIC C_28FD
C_28FD:
	MOV	CL,[SI]
	INC	SI
C_2900:
	MOV	AH,[SI]
	INC	SI
	MOV	AL,CH
	SHR	AX,1
	SHR	AX,1
	SHR	AX,1
	XCHG	AL,AH
	;
	OR	ES:[DI],AX
	INC	DI


	LOOP	C_2900
	ADD	DI,[SI]
	ADD	SI,2
	CMP	DI,DX
	JB	C_28FD

	RET
;---- ----
PUBLIC C_291D
C_291D:
	MOV	CL,[SI]
	INC	SI
C_2920:
	MOV	AH,[SI]
	INC	SI
	MOV	AL,CH
	SHR	AX,1
	SHR	AX,1
	SHR	AX,1
	SHR	AX,1
	XCHG	AL,AH
	;
	OR	ES:[DI],AX
	INC	DI


	LOOP	C_2920
	ADD	DI,[SI]
	ADD	SI,2
	CMP	DI,DX
	JB	C_291D

	RET
;---- ----
PUBLIC C_293F
C_293F:
	MOV	CL,[SI]
	INC	SI
C_2942:
	LODSB
	MOV	AH,CH
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	;
	XCHG	AL,AH
	OR	ES:[DI],AX
	INC	DI


	LOOP	C_2942
	ADD	DI,[SI]
	ADD	SI,2
	CMP	DI,DX
	JB	C_293F

	RET
;---- ----
PUBLIC C_295D
C_295D:
	MOV	CL,[SI]
	INC	SI
C_2960:
	LODSB
	MOV	AH,CH
	SHL	AX,1
	SHL	AX,1
	;
	XCHG	AL,AH
	OR	ES:[DI],AX
	INC	DI


	LOOP	C_2960
	ADD	DI,[SI]
	ADD	SI,2
	CMP	DI,DX
	JB	C_295D

	RET
;----  ----
PUBLIC C_2979
C_2979:
	MOV	CL,[SI]
	INC	SI
C_297C:
	LODSB
	MOV	AH,CH
	SHL	AX,1
	;
	XCHG	AL,AH
	OR	ES:[DI],AX
	INC	DI


	LOOP	C_297C
	ADD	DI,[SI]
	ADD	SI,2
	CMP	DI,DX
	JB	C_2979

	RET
;----------------------------------------
;put sprite mask?
C_2993:
	PUSH	DS
	PUSH	ES
	PUSH	DI
	PUSH	BP
	;-- PORT_3C4[2] := 0Fh -- "Map Mask Register"
	MOV	DX,PORT_3C4 + 1
	MOV	AL,0Fh
	OUT	DX,AL
	;-- --
	MOV	AX,ES
	MOV	DS,AX

	MOV	AX,SEG_A000
	MOV	ES,AX



	ADD	DI,[SI]	;"vram skip offset"
	ADD	SI,2

	MOV	DX,BP
	ADD	DX,2400h
	XOR	AH,AH
C_29B3:
	CMP	DI,DX
	JNS	C_29FC	;return
	CMP	DI,BP
	JNS	C_29C7

	LODSB	;# of bytes
	ADD	SI,AX
	ADD	DI,AX
	ADD	DI,[SI]	;"vram skip offset"
	ADD	SI,2

	JMP	C_29B3
C_29C7:
	PUSH	DS
	PUSH	DS
	MOV	AX,_DATA
	MOV	DS,AX
	MOV	BX,g_pbkbuffer_front
	MOV	AX,DI
	SUB	AX,[BX]._voffset
	ADD	AX,6030h
	MOV	BX,[BX].fff_06
	INC	BYTE PTR [BX]
	MOV	BX,CX
	MOV	[BX+04],AX
	MOV	[BX],SI
	MOV	[BX+02],DI
	MOV	[BX+06],DX
	POP	AX
	MOV	[BX+08],AX
	POP	DS
	XOR	CH,CH
	MOV	BX,DS:[EXTRA_0000]
	MOV	BX,DS:EXTRA_0012[BX]
	CALL	BX
	;-- --
C_29FC:
	POP	BP
	POP	DI
	POP	ES
	POP	DS
	RET
;---- ----
PUBLIC C_2A01
C_2A01:
	MOV	CL,[SI]
	INC	SI
C_2A04:
	LODSB
	NOT	AL
	MOV	AH,ES:[DI]
	STOSB
	LOOP	C_2A04
	ADD	DI,[SI]
	ADD	SI,2
	CMP	DI,DX
	JB	C_2A01

	RET
;---- ----
PUBLIC C_2A17
C_2A17:
	MOV	CL,[SI]
	INC	SI
C_2A1A:
	MOV	AH,[SI]
	INC	SI
	MOV	AL,CH
	SHR	AX,1
	NOT	AX
	XCHG	AL,AH
	MOV	BL,ES:[DI]
	STOSB
	MOV	BL,ES:[DI]
	MOV	ES:[DI],AH
	LOOP	C_2A1A
	ADD	DI,[SI]
	ADD	SI,2
	CMP	DI,DX
	JB	C_2A17

	RET
;---- ----
PUBLIC C_2A3B
C_2A3B:
	MOV	CL,[SI]
	INC	SI
C_2A3E:
	MOV	AH,[SI]
	INC	SI
	MOV	AL,CH
	SHR	AX,1
	SHR	AX,1
	NOT	AX
	XCHG	AL,AH
	MOV	BL,ES:[DI]
	STOSB
	MOV	BL,ES:[DI]
	MOV	ES:[DI],AH
	LOOP	C_2A3E
	ADD	DI,[SI]
	ADD	SI,2
	CMP	DI,DX
	JB	C_2A3B

	RET
;---- ----
PUBLIC C_2A61
C_2A61:
	MOV	CL,[SI]
	INC	SI
C_2A64:
	MOV	AH,[SI]
	INC	SI
	MOV	AL,CH
	SHR	AX,1
	SHR	AX,1
	SHR	AX,1
	XCHG	AL,AH
	NOT	AX
	MOV	BL,ES:[DI]
	STOSB
	MOV	BL,ES:[DI]
	MOV	ES:[DI],AH
	LOOP	C_2A64
	ADD	DI,[SI]
	ADD	SI,2
	CMP	DI,DX
	JB	C_2A61

	RET
;---- ----
PUBLIC C_2A89
C_2A89:
	MOV	CL,[SI]
	INC	SI
C_2A8C:
	MOV	AH,[SI]
	INC	SI
	MOV	AL,CH
	SHR	AX,1
	SHR	AX,1
	SHR	AX,1
	SHR	AX,1
	XCHG	AL,AH
	NOT	AX
	MOV	BL,ES:[DI]
	STOSB
	MOV	BL,ES:[DI]
	MOV	ES:[DI],AH
	LOOP	C_2A8C
	ADD	DI,[SI]
	ADD	SI,2
	CMP	DI,DX
	JB	C_2A89

	RET
;---- ----
PUBLIC C_2AB3
C_2AB3:
	MOV	CL,[SI]
	INC	SI
C_2AB6:
	LODSB
	MOV	AH,CH
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	NOT	AX
	XCHG	AL,AH
	MOV	BL,ES:[DI]
	STOSB
	MOV	BL,ES:[DI]
	MOV	ES:[DI],AH
	LOOP	C_2AB6
	ADD	DI,[SI]
	ADD	SI,2
	CMP	DI,DX
	JB	C_2AB3

	RET
;---- ----
PUBLIC C_2AD9
C_2AD9:
	MOV	CL,[SI]
	INC	SI
C_2ADC:
	LODSB
	MOV	AH,CH
	SHL	AX,1
	SHL	AX,1
	NOT	AX
	XCHG	AL,AH
	MOV	BL,ES:[DI]
	STOSB
	MOV	BL,ES:[DI]
	MOV	ES:[DI],AH
	LOOP	C_2ADC
	ADD	DI,[SI]
	ADD	SI,2
	CMP	DI,DX
	JB	C_2AD9

	RET
;---- ----
PUBLIC C_2AFD
C_2AFD:
	MOV	CL,[SI]
	INC	SI
C_2B00:
	LODSB
	MOV	AH,CH
	SHL	AX,1
	NOT	AX
	XCHG	AL,AH
	MOV	BL,ES:[DI]
	STOSB
	MOV	BL,ES:[DI]
	MOV	ES:[DI],AH
	LOOP	C_2B00
	ADD	DI,[SI]
	ADD	SI,2
	CMP	DI,DX
	JB	C_2AFD

	RET
;----------------------------------------
;restore vram(sprites)?
C_2B1F:
	MOV	AL,1	;write mode 1
	CALL	C_278D	;set EGA register state?

	MOV	AX,SEG_A000
	MOV	ES,AX

	MOV	BX,g_pbkbuffer_front
	MOV	BX,[BX].fff_06
	MOV	CL,[BX]
	XOR	CH,CH
	MOV	BYTE PTR [BX],0
	INC	BX
	JCXZ	C_2B61
	;-- --
	CLD
C_2B3B:
	PUSH	BX
	MOV	AX,CX
	DEC	AX
	SHL	AX,1
	ADD	BX,AX
	SHL	AX,1
	SHL	AX,1
	ADD	BX,AX
	MOV	DX,[BX+08]	;segment
	MOV	DI,[BX+02]	;dst
	MOV	SI,[BX+04]	;src
	MOV	BP,[BX+06]
	MOV	BX,[BX]	;offset

	PUSH	CX
	PUSH	DS
	CALL	C_2B62
	POP	DS
	POP	CX

	POP	BX
	LOOP	C_2B3B
	;-- --
C_2B61:
	RET
;---- ----
;DX:BX: @
;SI: src
;DI: dst
;BP
C_2B62:
	PUSH	DS

	MOV	DS,DX
	XOR	CH,CH
C_2B67:
	MOV	CL,[BX]
	INC	CX
	ADD	BX,CX

	MOV	AX,ES
	MOV	DS,AX

	REPZ	MOVSB

	MOV	DS,DX
	MOV	AX,[BX]
	ADD	BX,2
	DEC	AX
	ADD	SI,AX
	ADD	DI,AX
	CMP	DI,BP
	JB	C_2B67

	POP	DS
	RET
;----------------------------------------
__2B84	db 0Ch dup(0)	;padding
;########################################
;
;----------------------------------------2B90
;make input mask[for pick orbital]?
C_2B90:
	CALL	GetJoystickMask
	OR	AL,g_kbdmsk_orb
	;-- --
	MOV	AH,AL
	AND	AL,D_B81D
	NOT	AH
	MOV	D_B81D,AH
	;-- --
	RET
;----------------------------------------2BA4
;[orbital only]
GetInputMask_orbital:
	MOV	AH,0Fh	;trigger mask:direction

	CALL	GetJoystickMask
	OR	AL,g_kbdmsk_orb
	CMP	AL,g_prevkbdmsk_orb
	JZ	C_2BB8
	MOV	g_prevkbdmsk_orb,AL
	XOR	AL,AL
C_2BB8:
	JMP	SHORT C_2BBC
;---- ----2BBA
;[raider+orbital]
GetInputMask_both:
	MOV	AH,10h	;trigger mask:shoot
;---- ----
C_2BBC:
	CALL	GetJoystickMask
	OR	AL,g_kbdmsk_orb
	;-- --
	AND	AH,AL
	AND	AL,D_B81F
	NOT	AH
	MOV	D_B81F,AH
	;-- orbital --
	PUSH	SI
	MOV	SI,OFFSET _DATA:D_B810 + 1
	CALL	C_2BEF	;remove direction keys?
	POP	SI
	;-- --
	RET
;----------------------------------------2BD8
;[raider only]
GetInputMask_raider:
	MOV	AL,g_kbdmsk_raid
	CMP	AL,g_prevkbdmsk_raid
	JZ	C_2BEE
	MOV	g_prevkbdmsk_raid,AL
	XOR	AL,AL
	;-- raider --
	PUSH	SI
	MOV	SI,OFFSET _DATA:D_B810 + 6
	CALL	C_2BEF	;remove direction keys?
	POP	SI
	;-- --
C_2BEE:
	RET
;----------------------------------------
;remove direction keys?
C_2BEF:
	PUSH	BX

	XOR	BH,BH
	;-- up --
	TEST	AL,4
	JZ	C_2BFD
	MOV	BL,[SI]
	MOV	BYTE PTR D_B790[BX],0
C_2BFD:
	;-- down --
	TEST	AL,8
	JZ	C_2C09
	MOV	BL,[SI+01]
	MOV	BYTE PTR D_B790[BX],0
C_2C09:
	;-- left --
	TEST	AL,1
	JZ	C_2C15
	MOV	BL,[SI+02]
	MOV	BYTE PTR D_B790[BX],0
C_2C15:
	;-- right --
	TEST	AL,2
	JZ	C_2C21
	MOV	BL,[SI+03]
	MOV	BYTE PTR D_B790[BX],0
C_2C21:
	;-- --
	POP	BX
	RET
;----------------------------------------2C23
;parallel port joystick
GetJoystickMask:
	PUSH	DX

	MOV	DX,PORT_378
	;-- --
	XOR	AL,AL	;0
	OUT	DX,AL	;378h
	INC	DX
	IN	AL,DX	;379h
;expecting:
;+---+---+---+---+---+---+---+---+
;| 1 | 0 | 0 | 0 | 0 | x | x | x |
;+---+---+---+---+---+---+---+---+
	XOR	AL,80h
	AND	AL,NOT 7	;0F8h
	JNZ	C_2C46	;no joypad
	;-- --
	DEC	DX
	INC	AL	;1
	OUT	DX,AL	;378h
	INC	DX
	IN	AL,DX	;379h
;+---+---+---+---+---+---+---+---+
;|fir| ^ | v | < | > | x | x | x |
;+---+---+---+---+---+---+---+---+
	SHR	AL,1
	SHR	AL,1
	SHR	AL,1
	XOR	AL,0Fh	;flip direction flags
	CMP	AL,1Fh	;all set is not good
	JZ	C_2C46	;no joypad
	;-- --
	POP	DX
	RET
C_2C46:
	POP	DX
	XOR	AL,AL
	RET
;----------------------------------------2C4A
GetKBDScancode:
	MOV	AL,g_kbd_cur_scan
	CMP	AL,g_kbd_prev_scan
	JZ	C_2C5C
	MOV	g_kbd_prev_scan,AL
	AND	AL,AL
	JZ	C_2C5C
	STC
	RET
C_2C5C:
	XOR	AL,AL
	RET
;----------------------------------------2C5F
;AX to string
Int2Str:
	PUSH	DX
	PUSH	BX

	MOV	BX,10
	MOV	CH,CL
C_2C66:
	XOR	DX,DX
	DIV	BX
	PUSH	DX
	DEC	CH
	JNZ	C_2C66
C_2C6F:
	POP	DX
	MOV	[DI],DL
	INC	DI
	LOOP	C_2C6F

	POP	BX
	POP	DX
	RET
;----------------------------------------2C78
;AX:DX to string
WInt2Str:
	PUSH	BX

	MOV	BX,1000
	DIV	BX
	MOV	CL,3
	CALL	Int2Str
	MOV	AX,DX
	MOV	CL,3
	CALL	Int2Str

	POP	BX
	RET
;----------------------------------------2C8C
Rand:
	PUSH	DX
	PUSH	CX
	PUSH	BX

	MOV	BX,OFFSET _DATA:D_B832
	MOV	AX,[BX]
	ADD	AX,[BX+04]
	ADD	AX,[BX+06]
	ADD	AX,[BX+0Ah]
	INC	AX
	MOV	CX,COUNT_000E
C_2CA2:
	MOV	DX,[BX+02]
	MOV	[BX],DX
	ADD	BX,2
	LOOP	C_2CA2

	MOV	[BX],AX

	POP	BX
	POP	CX
	POP	DX
	RET
;----------------------------------------2CB2
;backup & set new int 9[bugged]
SetInt9:
	;-- backup --
ifdef FIX_BUGS
	MOV	AL,9
else
	MOV	AL,8	;bug?should be 9!!!
endif
	MOV	AH,35h
	INT	21h
ifdef FIX_BUGS
	MOV	D_B82B[2],ES
	MOV	D_B82B[0],BX
else
	MOV	D_B824[2 - 1],ES	;bug?B825
	MOV	D_B824[0 - 1],BX	;bug?B823
endif
	;-- set new --
	PUSH	DS
	MOV	AX,CS
	MOV	DS,AX
	MOV	DX,OFFSET _TEXT:INT_2D83
	MOV	AL,9
	MOV	AH,25h
	INT	21h
	POP	DS

	MOV	BYTE PTR g_kbdmsk_orb,0

	RET
;----------------------------------------2CD5
;backup & set new int 8
SetInt8:
	;-- backup --
	MOV	AL,8
	MOV	AH,35h
	INT	21h
	MOV	D_B824[2],ES
	MOV	D_B824[0],BX
	;-- set new --
	PUSH	DS
	MOV	AX,CS
	MOV	DS,AX
	MOV	DX,OFFSET _TEXT:INT_2D12
	MOV	AL,8
	MOV	AH,25h
	INT	21h
	POP	DS
	;-- --
	MOV	AL,36h
	OUT	43h,AL
	MOV	AL,3
	OUT	40h,AL
	MOV	AL,5Dh
	OUT	40h,AL
	;-- --
	RET
;----------------------------------------2CFF
;set new int 24h
SetInt24h:
	PUSH	DS

	MOV	AX,CS
	MOV	DS,AX

	MOV	DX,OFFSET _TEXT:INT_2D0F
	MOV	AL,24h
	MOV	AH,25h
	INT	21h

	POP	DS
	RET
;----------------------------------------
;new int 24h
INT_2D0F:
	MOV	AL,0
	IRET
;----------------------------------------
;new int 8
INT_2D12:
	PUSH	ES
	PUSH	DS
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX

	MOV	AX,_DATA
	MOV	DS,AX

	INC	BYTE PTR D_B828

	CMP	BYTE PTR D_B828,1
	JNZ	C_2D2F
	CALL	C_03D1	;timer refresh[called by int 8]
	INC	BYTE PTR g_int8_cnt
C_2D2F:
	;-- increment counter if under 4 --
	MOV	AL,D_B829
	CMP	AL,4
	JNB	C_2D3B
	INC	AL
	MOV	D_B829,AL
C_2D3B:
	;-- --
	CALL	SND_refresh

	DEC	BYTE PTR D_B828

	POP	DX
	POP	CX
	POP	BX
	POP	AX
	POP	DS
	POP	ES
	;-- jmp to original int 8 --
	JMP	DWORD PTR CS:D_B824	;E744
;----------------------------------------
__2D4D:
	PUSH	AX
	
	MOV	AL,4
	CALL	Synchro
	
	POP	AX
	RET
;---- ----2D55
Synchro_x4:
	PUSH	AX

	MOV	AL,4
	CALL	Synchro

	POP	AX
	RET
;---- ----2D5D
Synchro:
	PUSH	DS

	PUSH	AX
	MOV	AX,_DATA
	MOV	DS,AX
	POP	AX
C_2D65:
	CMP	D_B829,AL
	JB	C_2D65
	SUB	D_B829,AL

	POP	DS
	RET
;----------------------------------------
;wait vsync?
__2D71:
	PUSH	AX
	PUSH	DX

	MOV	DX,PORT_3DA
C_2D76:
	IN	AL,DX
	TEST	AL,8
	JZ	C_2D76
C_2D7B:
	IN	AL,DX
	TEST	AL,8
	JNZ	C_2D7B

	POP	DX
	POP	AX
	RET
;----------------------------------------
;new int 9
INT_2D83:
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	SI
	PUSH	DS

	MOV	AX,_DATA
	MOV	DS,AX

	IN	AL,60h
	PUSH	AX	;push scancode
	PUSH	AX	;push scancode

	IN	AL,61h
	OR	AL,80h
	OUT	61h,AL
	AND	AL,7Fh
	OUT	61h,AL

	POP	BX	;pop scancode
	AND	BX,7Fh
	ADD	BX,OFFSET _DATA:D_B790
	XOR	AL,AL
	MOV	[BX],AL
	MOV	g_kbd_cur_scan,AL
	POP	AX	;pop scancode
	TEST	AL,80h
	JNZ	C_2DB5
	MOV	BYTE PTR [BX],0FFh
	MOV	g_kbd_cur_scan,AL
C_2DB5:
	;-- make input masks --
	MOV	SI,OFFSET _DATA:D_B810
	MOV	CX,5
	CALL	MkKBDInputMask
	MOV	g_kbdmsk_orb,AL

	MOV	SI,OFFSET _DATA:D_B810 + 5
	MOV	CX,5
	CALL	MkKBDInputMask
	MOV	g_kbdmsk_raid,AL
	;-- radar on/off? --
	MOV	BL,D_B810[0Ah]
	MOV	AL,D_B790[BX]
	AND	AL,AL
	JZ	C_2DE3
	CMP	AL,D_2319
	JZ	C_2DE3
	XOR	g_radarOn,AL
C_2DE3:
	MOV	BYTE PTR D_2319,0
	;-- sound on/off --
	MOV	AL,D_B790[3Ch]	;<F2>
	AND	AL,AL
	JZ	C_2DF9
	CMP	AL,D_B876
	JZ	C_2DF9
	XOR	g_soundOff,AL
C_2DF9:
	MOV	BYTE PTR D_B876,0
	;-- vsync on/off --
	MOV	AL,D_B790[42h]	;<F8>
	AND	AL,AL
	JZ	C_2E0F
	CMP	AL,D_177F
	JZ	C_2E0F
	XOR	g_vsync_option,AL
C_2E0F:
	MOV	BYTE PTR D_177F,0
	;-- --
	CALL	Rand

	MOV	AL,20h
	OUT	20h,AL
	;-- <CTRL>+<ALT>+<DEL>? --
	MOV	AL,D_B790[1Dh]	;L.CONTROL
	AND	AL,D_B790[38h]	;L.ALT
	AND	AL,D_B790[53h]	;DEL
	JNZ	C_2E40	;to reboot
	;-- --
	POP	DS
	POP	SI
	POP	CX
	POP	BX
	POP	AX
if 0	;for debug
	jmp	dword ptr CS:D_B82B
else
	IRET
endif
;---- ----2E2E
;make keyboard input mask
;SI:@
;CX:count
MkKBDInputMask:
	XOR	BH,BH
	MOV	AL,BH
C_2E32:
	MOV	BL,[SI]
	MOV	AH,D_B790[BX]
	RCR	AH,1
	RCL	AL,1
	INC	SI
	LOOP	C_2E32

	RET
;---- ----
C_2E40:	;-- reboot --
	db 0EAh
	dw 0000,0FFFFh	;JMP	FFFF:0000
;----------------------------------------
__2E45	db 0Bh dup(0)	;padding
;########################################
;
;----------------------------------------2E50
SND_play:
	CMP	BYTE PTR g_soundOff,0
	JNZ	C_2E95
	;-- --
	CMP	BYTE PTR D_B874,0
	JNZ	C_2E95
	;-- --
	MOV	AX,[BX]
	MOV	D_B861,AX

	MOV	AX,[BX+02]
	MOV	D_B865,AX

	MOV	AX,[BX+04]
	MOV	D_B867,AX

	MOV	AX,[BX+06]
	MOV	D_B86B,AX
	MOV	D_B86D,AX

	MOV	AX,[BX+08]
	MOV	D_B869,AX

	MOV	AX,[BX+0Ah]
	MOV	D_B86F,AX

	MOV	D_B871,0
	MOV	D_B863,0
	MOV	BYTE PTR g_playSnd,1
	;-- --
C_2E95:
	RET
;----------------------------------------2E96
SND_refresh:
	CMP	BYTE PTR g_playSnd,0
	JZ	C_2F0E
	;-- sound on --
	IN	AL,61h
	OR	AL,3
	OUT	61h,AL
	;-- --
	MOV	CX,D_B871
	MOV	AX,D_B861
	ADD	AX,CX
	CMP	AX,D_B863
	JZ	C_2EC7

	MOV	AL,0B6h
	OUT	43h,AL
	MOV	AX,D_B861
	ADD	AX,CX
	MOV	D_B863,AX
	OUT	42h,AL
	MOV	AL,AH
	OUT	42h,AL
	MOV	D_B863,AX
C_2EC7:
	DEC	D_B865
	JZ	C_2F0E

	MOV	DX,D_B86F
	MOV	AX,D_B861
	AND	DX,DX
	JNZ	C_2EDC
	ADD	AX,D_B867
C_2EDC:
	ADD	AX,D_B869
	MOV	D_B861,AX

	CMP	D_B86B,0
	JZ	C_2F19
	DEC	D_B86D
	JNZ	C_2F19

	MOV	AX,D_B86B
	MOV	D_B86D,AX
	AND	DX,DX
	JZ	C_2F05

	CALL	Rand

	AND	AX,D_B867
	MOV	D_B871,AX

	RET
C_2F05:
	MOV	AX,D_B867
	NEG	AX
	MOV	D_B867,AX

	RET
C_2F0E:
	MOV	BYTE PTR g_playSnd,0
	;-- sound off --
	IN	AL,61h
	AND	AL,NOT 3	;0FCh
	OUT	61h,AL
	;-- --
C_2F19:
	RET
;----------------------------------------
;__2F1A	db 6 dup(0)	;padding
;----------------------------------------
_TEXT	ENDS
;########################################
;Those constants MUST be defined AFTER the code
;(in order to generate NOPs)
;----
EXTRA_0000	EQU 0
EXTRA_0002	EQU 2
EXTRA_0012	EQU 12h

COUNT_0004	EQU 4
COUNT_0008	EQU 8
COUNT_000C	EQU 0Ch
COUNT_000E	EQU 0Eh
COUNT_0010	EQU 10h
COUNT_0011	EQU 11h

;########################################0DA9
_DATA	SEGMENT PUBLIC PARA
;----------------------------------------
D_0000	db "blocks.dat",0
D_000B	db "map.dat",0
__0013	db "title.dat",0
D_001D	db "hiscores.dat",0
D_002A	db "keys.dat",0

g_gems	dw 0	;0033
g_score	dw 0,0	;0035
D_0039	dw 0,500,1000,1500	;gems scores
g_level_clear	db 0	;0041
D_0042	db 0	;raider automatic shooting direction mask?
g_map	db 0	;0043
D_0044	dw 0	;difficulty related?
g_level	db 0	;0046
g_killTotal	db 0	;0047

g_stop_int8	db 0	;0048
g_docking	db 0	;0049
g_int8_triggered	db 0	;004A

g_pUserShip	dw OFFSET _DATA:D_0452	;004B
D_004D	dw OFFSET _DATA:D_0452	;orbital #1
__004F	dw OFFSET _DATA:D_0474	;orbital #2
__0051	dw OFFSET _DATA:D_0496	;orbital #3
__0053	dw OFFSET _DATA:D_04B8	;orbital #4
__0055	dw OFFSET _DATA:D_0430	;raider

;difficulty related?
D_0057	db 0Dh,40h	;[for map 0]
	db 19h,59h	;[for map 1]
	db 33h,7Fh	;[for map 2]
	db 4Ch,0A5h	;[for map 3]
	db 66h,0B2h	;[for map 4]
	db 7Fh,0BFh	;[for map 5]
	db 99h,0CCh	;[for map 6]
	db 0BFh,0F2h	;[for map 7]
D_0067	dw 5 dup(-1)	;pointers to g_tilemap
D_0071	db 0,2,6,0,4,3,5,0,0,1,7,0,0,0,0,0
D_0081	db 0,1,4,3,2,8,7,4,5,6,8,9,12,11,10,0
__0091	db 15,12,13,14
;direction masks (indexed by D_00C7[] + ...)
D_0095	db 8,8,9,1
	db 1,1,5,4
	db 4,4,6,2
	db 2,2,10,8
D_00A5	db 0FFh,2,6,0FFh,4,3,5,0FFh,0,1,7,0FFh,0FFh,0FFh,0FFh,0FFh
D_00B5	db -1,-1	;left up
	db  1, 0	;right
	db  1, 0	;right
	db  0, 1	;down
	db  0, 1	;down
	db -1, 0	;left
	db -1, 0	;left
	db  0,-1	;up
	db  1, 0	;right
D_00C7	db 0,12,4,8,8,10,6,8
D_00CF	db 2,3,4,5,6,7,8,8
D_00D7	db 2,4,6,8,8,8,8,8
;-- palettes --
D_00DF	db 00h,01h,02h,03h,04h,05h,06h,07h,10h,11h,12h,13h,14h,15h,16h,17h
	db 00h,01h,02h,03h,05h,05h,06h,07h,10h,11h,12h,13h,15h,15h,13h,17h
	db 00h,01h,02h,03h,01h,05h,06h,07h,10h,11h,12h,13h,11h,15h,13h,17h
	db 00h,01h,02h,03h,03h,05h,06h,07h,10h,11h,12h,13h,13h,15h,17h,17h
	db 00h,01h,02h,03h,02h,05h,06h,07h,10h,11h,12h,13h,12h,15h,16h,17h
	db 00h,01h,02h,03h,10h,05h,06h,07h,10h,11h,12h,13h,07h,15h,17h,17h
	db 00h,01h,02h,03h,04h,05h,06h,07h,10h,11h,12h,13h,14h,15h,16h,17h
	db 00h,01h,02h,03h,01h,05h,06h,07h,10h,11h,12h,13h,11h,15h,13h,17h
__015F	db 0	;padding
;-- --
g_killCounts	dw 8 dup(0)	;0160
;__0170
	dw OFFSET _DATA:D_0B7E	;enemy[0]
	dw OFFSET _DATA:D_0BA0	;enemy[1]
	dw OFFSET _DATA:D_0BC2	;enemy[2]
	dw OFFSET _DATA:D_0BE4	;enemy[3]
	dw OFFSET _DATA:D_0C06	;enemy[4]
	dw OFFSET _DATA:D_0C28	;enemy[5] "mine"
	dw OFFSET _DATA:D_0C4A	;enemy[6] "fixed turret"
	dw OFFSET _DATA:D_0C6C	;enemy[7] "big ship"
;__0180	;bonus points
	dw 281
	dw 181
	dw 253
	dw 146
	dw 247
	dw 313
	dw 522
	dw 889
;-- --
D_0190	dw OFFSET _DATA:D_0B7E	;enemy[0]	;[for map 0]
	dw OFFSET _DATA:D_0BC2	;enemy[2]
	dw OFFSET _DATA:D_0B7E	;enemy[0]
	dw OFFSET _DATA:D_0BC2	;enemy[2]
	dw 0
	dw 0
	dw 0
	dw 0
;__01A0	;[for map 1]
	dw OFFSET _DATA:D_0B7E	;enemy[0]
	dw OFFSET _DATA:D_0BC2	;enemy[2]
	dw OFFSET _DATA:D_0BA0	;enemy[1]
	dw OFFSET _DATA:D_0B7E	;enemy[0]
	dw OFFSET _DATA:D_0BC2	;enemy[2]
	dw OFFSET _DATA:D_0BA0	;enemy[1]
	dw 0
	dw 0
;__01B0	;[for map 2]
	dw OFFSET _DATA:D_0B7E	;enemy[0]
	dw OFFSET _DATA:D_0BC2	;enemy[2]
	dw OFFSET _DATA:D_0BA0	;enemy[1]
	dw OFFSET _DATA:D_0BE4	;enemy[3]
	dw OFFSET _DATA:D_0C06	;enemy[4]
	dw OFFSET _DATA:D_0B7E	;enemy[0]
	dw OFFSET _DATA:D_0BC2	;enemy[2]
	dw OFFSET _DATA:D_0BE4	;enemy[3]
;__01C0	;[for map 3]
	dw OFFSET _DATA:D_0B7E	;enemy[0]
	dw OFFSET _DATA:D_0BC2	;enemy[2]
	dw OFFSET _DATA:D_0BA0	;enemy[1]
	dw OFFSET _DATA:D_0BE4	;enemy[3]
	dw OFFSET _DATA:D_0C06	;enemy[4]
	dw OFFSET _DATA:D_0BC2	;enemy[2]
	dw OFFSET _DATA:D_0BA0	;enemy[1]
	dw OFFSET _DATA:D_0BE4	;enemy[3]
;__01D0	;[for map 4]
	dw OFFSET _DATA:D_0B7E	;enemy[0]
	dw OFFSET _DATA:D_0BC2	;enemy[2]
	dw OFFSET _DATA:D_0BA0	;enemy[1]
	dw OFFSET _DATA:D_0C06	;enemy[4]
	dw OFFSET _DATA:D_0BE4	;enemy[3]
	dw OFFSET _DATA:D_0BA0	;enemy[1]
	dw OFFSET _DATA:D_0C06	;enemy[4]
	dw OFFSET _DATA:D_0BE4	;enemy[3]
;__01E0	;[for map 5]
	dw OFFSET _DATA:D_0B7E	;enemy[0]
	dw OFFSET _DATA:D_0BC2	;enemy[2]
	dw OFFSET _DATA:D_0BA0	;enemy[1]
	dw OFFSET _DATA:D_0BE4	;enemy[3]
	dw OFFSET _DATA:D_0C06	;enemy[4]
	dw OFFSET _DATA:D_0BE4	;enemy[3]
	dw OFFSET _DATA:D_0C06	;enemy[4]
	dw OFFSET _DATA:D_0BA0	;enemy[1]
;__01F0	;[for map 6]
	dw OFFSET _DATA:D_0B7E	;enemy[0]
	dw OFFSET _DATA:D_0BC2	;enemy[2]
	dw OFFSET _DATA:D_0BA0	;enemy[1]
	dw OFFSET _DATA:D_0BE4	;enemy[3]
	dw OFFSET _DATA:D_0C06	;enemy[4]
	dw OFFSET _DATA:D_0BA0	;enemy[1]
	dw OFFSET _DATA:D_0C06	;enemy[4]
	dw OFFSET _DATA:D_0BA0	;enemy[1]
;__0200	;[for map 7]
	dw OFFSET _DATA:D_0BA0	;enemy[1]
	dw OFFSET _DATA:D_0C06	;enemy[4]
	dw OFFSET _DATA:D_0BA0	;enemy[1]
	dw OFFSET _DATA:D_0C06	;enemy[4]
	dw OFFSET _DATA:D_0BA0	;enemy[1]
	dw OFFSET _DATA:D_0C06	;enemy[4]
	dw OFFSET _DATA:D_0BE4	;enemy[3]
	dw OFFSET _DATA:D_0B7E	;enemy[0]
;-- 45h objects --
X_0210	EQU THIS BYTE

D_0210	s_actor COUNT_0010 dup(<>)
D_0430	s_actor <>	;raider
D_0452	s_actor <>	;orbital #1
D_0474	s_actor <>	;orbital #2
D_0496	s_actor <>	;orbital #3
D_04B8	s_actor <>	;orbital #4
D_04DA	s_actor 8 dup(<>)
D_05EA	s_actor 4 dup(<>)
D_0672	s_actor COUNT_0008 dup(<>)
D_0782	s_actor COUNT_0008 dup(<>)
D_0892	s_actor COUNT_0004 dup(<>)
D_091A	s_actor COUNT_0010 dup(<>)	;for shoot?

X_0B3A	EQU THIS BYTE
;-- init data --
D_0B3A	s_actor <0,0,200h,10h,-1,60h,OFFSET _DATA:D_BA90, 0,OFFSET _TEXT:CB_REF_raider, OFFSET _TEXT:CB_CON_raider, -1>	;"raider"
D_0B5C	s_actor <0,0,800h,80h, 0,30h,OFFSET _DATA:D_B880, 8,OFFSET _TEXT:CB_REF_orbital,OFFSET _TEXT:CB_CON_orbital,-1>	;"orbital"
D_0B7E	s_actor <0,0,480h,20h,-1,04h,OFFSET _DATA:D_BCA0, 9,OFFSET _TEXT:CB_REF_enemy0, OFFSET _TEXT:CB_CON_enemy0,  0>	;enemy[0]
D_0BA0	s_actor <0,0,800h,40h,-1,02h,OFFSET _DATA:D_BFB0, 9,OFFSET _TEXT:CB_REF_enemy1, OFFSET _TEXT:CB_CON_enemy1,  1>	;enemy[1]
D_0BC2	s_actor <0,0,600h,20h,-1,03h,OFFSET _DATA:D_C240, 9,OFFSET _TEXT:CB_REF_enemy2, OFFSET _TEXT:CB_CON_enemy2,  2>	;enemy[2]
D_0BE4	s_actor <0,0,680h,20h,-1,03h,OFFSET _DATA:D_C4D0, 9,OFFSET _TEXT:CB_REF_enemy3, OFFSET _TEXT:CB_CON_enemy3,  3>	;enemy[3]
D_0C06	s_actor <0,0,800h,20h,-1,02h,OFFSET _DATA:D_C760, 9,OFFSET _TEXT:CB_REF_enemy4, OFFSET _TEXT:CB_CON_enemy4,  4>	;enemy[4]
D_0C28	s_actor <0,0,220h,10h,-1,02h,OFFSET _DATA:D_D090,-1,OFFSET _TEXT:CB_REF_enemy5, OFFSET _TEXT:CB_CON_enemy5,  5>	;enemy[5] "mine"
D_0C4A	s_actor <0,0,  0 , 0 ,-1,0Ah,OFFSET _DATA:D_C9F0,-1,OFFSET _TEXT:CB_REF_enemy6, OFFSET _TEXT:CB_CON_enemy6,  6>	;enemy[6] "fixed turret"
D_0C6C	s_actor <0,0,200h,10h,-1,28h,OFFSET _DATA:D_CC80, 9,OFFSET _TEXT:CB_REF_enemy7, OFFSET _TEXT:CB_CON_enemy7,  7>	;enemy[7] "big ship"
__0C8E	s_actor <0,0,  0 , 0 ,-1,50h,OFFSET _DATA:D_CD82,-1,OFFSET _TEXT:CB_REF_enemy8, OFFSET _TEXT:CB_CON_enemy8, -1>	;enemy[8] "big ship turret"
;---- shoot base L/R x,y[orbital] --
D_0CB0	dw  -9, -9,	  9, -9
	dw  -2,-12,	 13, -6
	dw   2,-12,	 13, -1
	dw   6,-11,	 14,  2
	dw  11, -7,	 11,  7
	dw  12, -3,	  4, 10
	dw  13,  2,	  2, 13
	dw  12,  4,	 -3, 11
	dw   9, 10,	 -9, 10
	dw   3, 13,	-12,  6
	dw   0, 12,	-11,  1
	dw  -4, 11,	-12, -2
	dw -10,  7,	-10, -7
	dw -13,  2,	 -5,-11
	dw -12, -1,	 -1,-12
	dw -12, -5,	  3,-12

D_0D30	db 0	;orbital shoot L/R flag
;---- shoot base x,y[enemies] ----
;-- for enemy6 --
D_0D31	dw 0,-33
	dw 25,-24
	dw 36,0
	dw 25,23
	dw 0,33
	dw -25,23
	dw -37,0
	dw -25,-23
;-- for enemy0 --
D_0D51	dw 0,-13
	dw 11,-10
	dw 17,0
	dw 11,10
	dw 0,14
	dw -11,10
	dw -15,0
	dw -11,-10
;-- for enemy2 --
D_0D71	dw 0,-14
	dw 11,-10
	dw 16,0
	dw 11,10
	dw 0,15
	dw -12,10
	dw -15,0
	dw -11,-10
;-- for enemy1 --
D_0D91	dw 0,-8
	dw 6,-6
	dw 10,0
	dw 6,6
	dw 0,8
	dw -6,6
	dw -8,0
	dw -6,-6
;-- for enemy3 --
D_0DB1	dw 0,-11
	dw 8,-8
	dw 12,0
	dw 8,8
	dw 0,11
	dw -8,8
	dw -11,0
	dw -8,-8
;-- for enemy4 --
D_0DD1	dw 0,-12
	dw 11,-10
	dw 14,0
	dw 11,11
	dw 0,13
	dw -10,11
	dw -14,0
	dw -10,-10
;-- for enemy7 --
D_0DF1	dw 0,-4
	dw 4,-3
	dw 5,0
	dw 4,4
	dw 0,5
	dw -4,4
	dw -5,0
	dw -4,-3
;-- for enemy8 --
D_0E11	dw 0,-14
	dw 11,-11
	dw 15,0
	dw 11,11
	dw 0,14
	dw -11,11
	dw -15,0
	dw -11,-11
;-- raider shoot related --
D_0E31	s_raiderShoot <  0,-25,OFFSET _DATA:D_C342,00,02>
	s_raiderShoot < 25,-18,OFFSET _DATA:D_C0B2,01,01>
	s_raiderShoot < 32,  4,OFFSET _DATA:D_C5D2,02,02>
	s_raiderShoot < 25, 25,OFFSET _DATA:D_C0B2,03,01>

	s_raiderShoot <  0,  0,OFFSET _DATA:D_C5D2,09,00>
	s_raiderShoot <-25, 25,OFFSET _DATA:D_C0B2,05,01>
	s_raiderShoot <-32,  4,OFFSET _DATA:D_C5D2,06,02>
	s_raiderShoot <-25,-18,OFFSET _DATA:D_C0B2,07,01>

	s_raiderShoot <  1,-29,OFFSET _DATA:D_C0B2,00,01>
	s_raiderShoot < 24,-19,OFFSET _DATA:D_C342,01,02>
	s_raiderShoot < 34,  1,OFFSET _DATA:D_C0B2,02,01>
	s_raiderShoot < 25, 20,OFFSET _DATA:D_C5D2,03,02>

	s_raiderShoot <  4, 30,OFFSET _DATA:D_C0B2,04,01>
	s_raiderShoot <  0,  0,OFFSET _DATA:D_C5D2,09,00>
	s_raiderShoot <-33, -2,OFFSET _DATA:D_C0B2,06,01>
	s_raiderShoot <-21,-20,OFFSET _DATA:D_C5D2,07,02>

	s_raiderShoot < -4,-27,OFFSET _DATA:D_C5D2,00,02>
	s_raiderShoot < 20,-23,OFFSET _DATA:D_C0B2,01,01>
	s_raiderShoot < 29,  0,OFFSET _DATA:D_C342,02,02>
	s_raiderShoot < 20, 24,OFFSET _DATA:D_C0B2,03,01>

	s_raiderShoot < -4, 28,OFFSET _DATA:D_C5D2,04,02>
	s_raiderShoot <-28, 24,OFFSET _DATA:D_C0B2,05,01>
	s_raiderShoot <  0,  0,OFFSET _DATA:D_C5D2,09,02>
	s_raiderShoot <-28,-23,OFFSET _DATA:D_C0B2,07,01>

	s_raiderShoot <  3,-29,OFFSET _DATA:D_C0B2,00,01>
	s_raiderShoot < 24,-19,OFFSET _DATA:D_C5D2,01,02>
	s_raiderShoot < 34,  0,OFFSET _DATA:D_C0B2,02,01>
	s_raiderShoot < 23, 20,OFFSET _DATA:D_C342,03,02>

	s_raiderShoot <  0, 30,OFFSET _DATA:D_C0B2,04,01>
	s_raiderShoot <-22, 21,OFFSET _DATA:D_C5D2,05,02>
	s_raiderShoot <-34,  2,OFFSET _DATA:D_C0B2,06,01>
	s_raiderShoot <  0,  0,OFFSET _DATA:D_C5D2,09,00>

	s_raiderShoot <  0,  0,OFFSET _DATA:D_C5D2,09,00>
	s_raiderShoot < 25,-24,OFFSET _DATA:D_C0B2,01,01>
	s_raiderShoot < 32, -3,OFFSET _DATA:D_C5D2,02,02>
	s_raiderShoot < 25, 19,OFFSET _DATA:D_C0B2,03,01>

	s_raiderShoot <  0, 26,OFFSET _DATA:D_C342,04,02>
	s_raiderShoot <-25, 19,OFFSET _DATA:D_C0B2,05,01>
	s_raiderShoot <-32, -3,OFFSET _DATA:D_C5D2,06,02>
	s_raiderShoot <-25,-24,OFFSET _DATA:D_C0B2,07,01>

	s_raiderShoot < -2,-29,OFFSET _DATA:D_C0B2,00,01>
	s_raiderShoot <  0,  0,OFFSET _DATA:D_C5D2,09,00>
	s_raiderShoot < 34,  3,OFFSET _DATA:D_C0B2,02,01>
	s_raiderShoot < 23, 21,OFFSET _DATA:D_C5D2,03,02>

	s_raiderShoot <  1, 30,OFFSET _DATA:D_C0B2,04,01>
	s_raiderShoot <-22, 20,OFFSET _DATA:D_C342,05,02>
	s_raiderShoot <-33,  0,OFFSET _DATA:D_C0B2,06,01>
	s_raiderShoot <-23,-19,OFFSET _DATA:D_C5D2,07,02>

	s_raiderShoot <  4,-27,OFFSET _DATA:D_C5D2,00,02>
	s_raiderShoot < 28,-23,OFFSET _DATA:D_C0B2,01,01>
	s_raiderShoot <  0,  0,OFFSET _DATA:D_C5D2,09,00>
	s_raiderShoot < 28, 24,OFFSET _DATA:D_C0B2,03,01>

	s_raiderShoot <  4, 28,OFFSET _DATA:D_C5D2,04,02>
	s_raiderShoot <-20, 24,OFFSET _DATA:D_C0B2,05,01>
	s_raiderShoot <-28,  0,OFFSET _DATA:D_C342,06,02>
	s_raiderShoot <-20,-23,OFFSET _DATA:D_C0B2,07,01>

	s_raiderShoot <  0,-29,OFFSET _DATA:D_C0B2,00,01>
	s_raiderShoot < 22,-20,OFFSET _DATA:D_C5D2,01,02>
	s_raiderShoot < 33, -2,OFFSET _DATA:D_C0B2,02,01>
	s_raiderShoot <  0,  0,OFFSET _DATA:D_C5D2,09,00>

	s_raiderShoot < -3, 30,OFFSET _DATA:D_C0B2,04,01>
	s_raiderShoot <-24, 20,OFFSET _DATA:D_C5D2,05,02>
	s_raiderShoot <-34,  1,OFFSET _DATA:D_C0B2,06,01>
	s_raiderShoot <-23,-19,OFFSET _DATA:D_C342,07,02>
;-- {x,y} acceleration for players's shoot --
D_1031	dw     0, -1000h
	dw   800h,-1000h
	dw  1000h,-1000h
	dw  1000h, -800h
	dw  1000h,    0
	dw  1000h,  800h
	dw  1000h, 1000h
	dw   800h, 1000h
	dw    0,   1000h
	dw  -800h, 1000h
	dw -1000h, 1000h
	dw -1000h,  800h
	dw -1000h,    0
	dw -1000h, -800h
	dw -1000h,-1000h
	dw  -800h,-1000h
;-- --
D_1071	db 0,1,1,1,1,2,2,2,1,2,2,2,1,2,2,2
	db 1,2,2,2,2,3,3,3,2,3,3,3,2,3,3,3
	db 1,2,2,2,2,3,3,3,2,3,3,3,2,3,3,3
	db 1,2,2,2,2,3,3,3,2,3,3,3,2,3,3,3
	db 1,2,2,2,2,3,3,3,2,3,3,3,2,3,3,3
	db 2,3,3,3,3,4,4,4,3,4,4,4,3,4,4,4
	db 2,3,3,3,3,4,4,4,3,4,4,4,3,4,4,4
	db 2,3,3,3,3,4,4,4,3,4,4,4,3,4,4,4
	db 1,2,2,2,2,3,3,3,2,3,3,3,2,3,3,3
	db 2,3,3,3,3,4,4,4,3,4,4,4,3,4,4,4
	db 2,3,3,3,3,4,4,4,3,4,4,4,3,4,4,4
	db 2,3,3,3,3,4,4,4,3,4,4,4,3,4,4,4
	db 1,2,2,2,2,3,3,3,2,3,3,3,2,3,3,3
	db 2,3,3,3,3,4,4,4,3,4,4,4,3,4,4,4
	db 2,3,3,3,3,4,4,4,3,4,4,4,3,4,4,4
	db 2,3,3,3,3,4,4,4,3,4,4,4,3,4,4,4
;-- sound info --
D_1171	dw   800,16, 100 , 3, 300,0	;orbital shoot
D_117D	dw  2000,20, 110 ,16, -41,0	;raider shoot
__1189	dw 20000,16,4000h, 1,2000,0FFFFh
D_1195	dw   100, 7, 200 , 2,  50,0	;enemy spawn

__11A1	db 0Fh dup(0)	;padding?
;-- --
D_11B0	dw 0
D_11B2	db 0	;for g_bkbuffer_0
__11B3	db 280h dup(0)
D_1433	db 0	;for g_bkbuffer_1
__1434	db 280h dup(0)
D_16B4	db 0	;for g_bkbuffer_2
__16B5	db 0C8h dup(0)

g_text_color	db 0Ah	;177D
g_vsync_option	db 0	;177E
D_177F	db 0	;"vsync flag" related?
;-- --
D_1780	db 97h,79h,0Ah, 00h,00h,2Dh,0FFh	;"00x"
D_1787	db 97h,89h,0Ch, 00h,00h,00h,0FFh	;"000"
D_178E	db 8Ch,99h,0Bh, 00h,00h,00h,00h,00h,00h,0FFh	;"000000"
;-- --
D_1798	db 60h,57h,0Fh, 13h,26h,2Ah,2Ch,12h,2Ch,1Fh,16h,28h,2Ch,20h,23h,13h,1Ah,25h,12h,1Dh,0FFh	;"BUY A NEW ORBITAL"
__17AD	db 70h,62h,0Fh, 17h,20h,23h,2Ch,02h,00h,00h,00h,00h,2Ch,21h,25h,24h,0FFh	;"FOR 20000 PTS"
__17BE	db 90h,6Dh,0Bh, 0Dh,2Ah,0Bh,1Fh,0Eh,0FFh	;? "Y/N" ?
;-- --
D_17C7	db 01h,1Eh,08h,09h, 20h,23h,13h,1Ah,25h,12h,1Dh,0FFh	;"ORBITAL"
D_17D3	db 01h,21h,07h,09h, 23h,12h,1Ah,15h,16h,23h,0FFh	;"RAIDER"
D_17DE	db 1Ah,1Eh,06h,09h, 19h,20h,1Dh,15h,24h,0FFh	;"HOLDS"
D_17E8	db 1Ah,21h,0Eh,09h, 27h,12h,1Dh,26h,16h,10h,2Ch	;"VALUE: 000000"
D_17F3	db 00h,00h,00h,00h,00h,00h,0FFh
;-- --
D_17FA	db 76h,34h,0Ah, 18h,12h,1Eh,16h,2Ch,15h,16h,24h,1Ah,18h,1Fh,0FFh	;"GAME DESIGNER"
	db 76h,44h,0Bh, 24h,25h,16h,27h,16h,1Fh,2Ch,14h,12h,1Ah,1Fh,0FFh	;"STEVEN CAIN"
	db 6Bh,5Eh,0Ah, 18h,23h,12h,21h,19h,1Ah,14h,2Ch,15h,16h,24h,1Ah,18h,1Fh,0FFh	;"GRAPHIC DESIGN"
	db 6Bh,6Eh,0Bh, 1Eh,12h,23h,25h,1Ah,1Fh,2Ch,14h,12h,1Dh,27h,16h,23h,25h,0FFh	;"MARTIN CALVERT"
	db 67h,8Bh,0Ah, 24h,20h,17h,25h,28h,12h,23h,16h,2Ch,15h,16h,24h,1Ah,18h,1Fh,0FFh	;"SOFTWARE DESIGN"
	db 74h,9Bh,0Bh, 24h,25h,16h,21h,19h,16h,1Fh,2Ch,28h,12h,23h,15h,0FFh	;"STEPHEN WARD"
;-- --
D_185F	db 80h,28h,0Fh, 1Dh,16h,27h,16h,1Dh,2Ch,00h,00h,0FFh	;"LEVEL 00"
;-- --
D_186B	db 68h,38h,0Ah, 17h,23h,12h,1Eh,16h,24h,2Ch,2Ch,2Ch,01h,00h,00h,00h,00h,00h,0FFh	;"FRAMES    100000"
	db 68h,48h,0Ah, 17h,23h,12h,1Eh,16h,24h,2Ch,2Ch,2Ch,2Ch,08h,00h,00h,00h,00h,0FFh	;"FRAMES    80000"
	db 68h,58h,0Ah, 17h,23h,12h,1Eh,16h,24h,2Ch,2Ch,2Ch,2Ch,06h,00h,00h,00h,00h,0FFh	;"FRAMES    60000"
	db 68h,68h,0Bh, 12h,25h,12h,23h,1Ah,2Ch,2Ch,2Ch,2Ch,2Ch,04h,00h,00h,00h,00h,0FFh	;"ATARI     40000"
	db 68h,78h,0Bh, 12h,25h,12h,23h,1Ah,2Ch,2Ch,2Ch,2Ch,2Ch,02h,00h,00h,00h,00h,0FFh	;"ATARI     20000"
	db 68h,88h,0Bh, 12h,25h,12h,23h,1Ah,2Ch,2Ch,2Ch,2Ch,2Ch,01h,00h,00h,00h,00h,0FFh	;"ATARI     10000"
	db 68h,98h,0Bh, 12h,25h,12h,23h,1Ah,2Ch,2Ch,2Ch,2Ch,2Ch,2Ch,05h,00h,00h,00h,0FFh	;"ATARI      5000"
	db 68h,0A8h,0Bh, 12h,25h,12h,23h,1Ah,2Ch,2Ch,2Ch,2Ch,2Ch,2Ch,01h,00h,00h,00h,0FFh	;"ATARI      1000"
;-- --
D_1903	db 5Fh,2Ah,0Fh, 20h,23h,13h,1Ah,25h,12h,1Dh,0FFh	;"ORBITAL"
	db 9Fh,2Ah,0Ah, 17h,1Ah,23h,16h,0FFh	;"FIRE"
	db 9Fh,35h,0Ah, 26h,21h,0FFh	;"UP"
	db 9Fh,40h,0Ah, 15h,20h,28h,1Fh,0FFh	;"DOWN"
	db 9Fh,4Bh,0Ah, 1Dh,16h,17h,25h,0FFh	;"LEFT"
	db 9Fh,56h,0Ah, 23h,1Ah,18h,19h,25h,0FFh	;"RIGHT"
	db 5Fh,61h,0Fh, 23h,12h,1Ah,15h,16h,23h,0FFh	;"RAIDER"
	db 9Fh,61h,0Ah, 24h,25h,20h,21h,0FFh	;"STOP"
	db 9Fh,6Ch,0Ah, 26h,21h,0FFh	;"UP"
	db 9Fh,77h,0Ah, 15h,20h,28h,1Fh,0FFh	;"DOWN"
	db 9Fh,82h,0Ah, 1Dh,16h,17h,25h,0FFh	;"LEFT"
	db 9Fh,8Dh,0Ah, 23h,1Ah,18h,19h,25h,0FFh	;"RIGHT"
	db 5Fh,98h,0Fh, 23h,12h,15h,12h,23h,2Ch,25h,20h,18h,18h,1Dh,16h,0FFh	;"RADAR TOGGLE"
	db 5Fh,0A3h,0Fh, 14h,20h,1Fh,25h,23h,20h,1Dh,2Ch,23h,12h,1Ah,15h,16h,23h,0FFh	;"CONTROL RAIDER"
;-- control keys --
D_1988	db 0D0h,2Ah,7, 2Ch,2Ch,2Ch,0FFh	;"   "
	db 0D0h,35h,7, 2Ch,2Ch,2Ch,0FFh	;"   "
	db 0D0h,40h,7, 2Ch,2Ch,2Ch,0FFh	;"   "
	db 0D0h,4Bh,7, 2Ch,2Ch,2Ch,0FFh	;"   "
	db 0D0h,56h,7, 2Ch,2Ch,2Ch,0FFh	;"   "
	db 0D0h,61h,7, 2Ch,2Ch,2Ch,0FFh	;"   "
	db 0D0h,6Ch,7, 2Ch,2Ch,2Ch,0FFh	;"   "
	db 0D0h,77h,7, 2Ch,2Ch,2Ch,0FFh	;"   "
	db 0D0h,82h,7, 2Ch,2Ch,2Ch,0FFh	;"   "
	db 0D0h,8Dh,7, 2Ch,2Ch,2Ch,0FFh	;"   "
	db 0D0h,98h,7, 2Ch,2Ch,2Ch,0FFh	;"   "
	db 0D0h,0A3h,7, 2Ch,2Ch,2Ch,0FFh	;"   "
;-- --
D_19DC	db 2Ch,2Ch,2Ch	;[00]"   "
	db 16h,24h,14h	;[01]"ESC"
	db 2Ch,01h,2Ch	;[02]" 1 "
	db 2Ch,02h,2Ch	;[03]" 2 "
	db 2Ch,03h,2Ch	;[04]" 3 "
	db 2Ch,04h,2Ch	;[05]" 4 "
	db 2Ch,05h,2Ch	;[06]" 5 "
	db 2Ch,06h,2Ch	;[07]" 6 "
	db 2Ch,07h,2Ch	;[08]" 7 "
	db 2Ch,08h,2Ch	;[09]" 8 "
	db 2Ch,09h,2Ch	;[0a]" 9 "
	db 2Ch,00h,2Ch	;[0b]" 0 "
	db 2Ch,2Eh,2Ch	;[0c]" - "
	db 2Ch,2Fh,2Ch	;[0d]" = "
	db 2Ch,38h,2Ch	;[0e]<ARROW LEFT>
	db 25h,12h,13h	;[0f]"TAB"
	db 2Ch,22h,2Ch	;[10]" Q "
	db 2Ch,28h,2Ch	;[11]" W "
	db 2Ch,16h,2Ch	;[12]" E "
	db 2Ch,23h,2Ch	;[13]" R "
	db 2Ch,25h,2Ch	;[14]" T "
	db 2Ch,2Ah,2Ch	;[15]" Y "
	db 2Ch,26h,2Ch	;[16]" U "
	db 2Ch,1Ah,2Ch	;[17]" I "
	db 2Ch,20h,2Ch	;[18]" O "
	db 2Ch,21h,2Ch	;[19]" P "
	db 2Ch,30h,2Ch	;[1a]" [ "
	db 2Ch,31h,2Ch	;[1b]" ] "
	db 14h,23h,2Ch	;[1c]"CR "
	db 14h,25h,1Dh	;[1d]"CTL"
	db 2Ch,12h,2Ch	;[1e]" A "
	db 2Ch,24h,2Ch	;[1f]" S "
	db 2Ch,15h,2Ch	;[20]" D "
	db 2Ch,17h,2Ch	;[21]" F "
	db 2Ch,18h,2Ch	;[22]" G "
	db 2Ch,19h,2Ch	;[23]" H "
	db 2Ch,1Bh,2Ch	;[24]" J "
	db 2Ch,1Ch,2Ch	;[25]" K "
	db 2Ch,1Dh,2Ch	;[26]" L "
	db 2Ch,0Fh,2Ch	;[27]" ; "
	db 2Ch,32h,2Ch	;[28]" / "
	db 2Ch,33h,2Ch	;[29]" \ "
	db 24h,17h,25h	;[2a]"SFT"
	db 2Ch,33h,2Ch	;[2b]" / "
	db 2Ch,2Bh,2Ch	;[2c]" Z "
	db 2Ch,29h,2Ch	;[2d]" X "
	db 2Ch,14h,2Ch	;[2e]" C "
	db 2Ch,27h,2Ch	;[2f]" V "
	db 2Ch,13h,2Ch	;[30]" B "
	db 2Ch,1Fh,2Ch	;[31]" N "
	db 2Ch,1Eh,2Ch	;[32]" M "
	db 2Ch,0Ah,2Ch	;[33]" . "
	db 2Ch,0Bh,2Ch	;[34]" , "
	db 2Ch,32h,2Ch	;[35]" / "
	db 24h,17h,25h	;[36]"SFT"
	db 2Ch,34h,2Ch	;[37]" * "
	db 12h,1Dh,25h	;[38]"ALT"
	db 24h,21h,14h	;[39]"SPC"
	db 14h,12h,21h	;[3a]"CAP"
	db 2Ch,2Ch,2Ch	;[3b]"   " <F1>
	db 2Ch,2Ch,2Ch	;[3c]"   " <F2>
	db 2Ch,2Ch,2Ch	;[3d]"   " <F3>
	db 2Ch,2Ch,2Ch	;[3e]"   " <F4>
	db 2Ch,2Ch,2Ch	;[3f]"   " <F5>
	db 2Ch,2Ch,2Ch	;[40]"   " <F6>
	db 2Ch,2Ch,2Ch	;[41]"   " <F7>
	db 2Ch,2Ch,2Ch	;[42]"   " <F8>
	db 2Ch,2Ch,2Ch	;[43]"   " <F9>
	db 2Ch,2Ch,2Ch	;[44]"   " <F10>
	db 1Fh,26h,1Eh	;[45]"NUM"
	db 24h,14h,23h	;[46]"SCR"
	db 19h,1Eh,16h	;[47]"HME"
	db 2Ch,35h,2Ch	;[48]<ARROW UP>
	db 21h,18h,26h	;[49]"PGU"
	db 2Ch,2Eh,2Ch	;[4a]" - "
	db 2Ch,38h,2Ch	;[4b]<ARROW LEFT>
	db 2Ch,05h,2Ch	;[4c]" 5 "
	db 2Ch,36h,2Ch	;[4d]<ARROW RIGHT>
	db 2Ch,39h,2Ch	;[4e]" + "
	db 16h,1Fh,15h	;[4f]"END"
	db 2Ch,37h,2Ch	;[50]<ARROW DOWN>
	db 21h,18h,15h	;[51]"PGD"
	db 1Ah,1Fh,24h	;[52]"INS"
	db 15h,16h,1Dh	;[53]"DEL"
	db 2Ch,3Ah,2Ch	;[54]" ? "
;-- hiscores --
D_1ADB	db 17h,23h,12h,1Eh,16h,24h,2Ch,2Ch, 0A0h,86h,1,0	;"FRAMES  "/100000
	db 17h,23h,12h,1Eh,16h,24h,2Ch,2Ch, 80h,38h,01h,0	;"FRAMES  "/80000
	db 17h,23h,12h,1Eh,16h,24h,2Ch,2Ch, 60h,0EAh,0,0	;"FRAMES  "/60000
	db 12h,25h,12h,23h,1Ah,2Ch,2Ch,2Ch, 40h,9Ch,0,0	;"ATARI   "/40000
	db 12h,25h,12h,23h,1Ah,2Ch,2Ch,2Ch, 20h,4Eh,0,0	;"ATARI   "/20000
	db 12h,25h,12h,23h,1Ah,2Ch,2Ch,2Ch, 10h,27h,0,0	;"ATARI   "/10000
	db 12h,25h,12h,23h,1Ah,2Ch,2Ch,2Ch, 88h,13h,0,0	;"ATARI   "/5000
	db 12h,25h,12h,23h,1Ah,2Ch,2Ch,2Ch, 0E8h,03h,0,0	;"ATARI   "/1000
;-- scancodes to char[for hiscores] --
D_1B3B	db 0	;[00]
	db 0	;[01]
	db 0	;[02]
	db 0	;[03]
	db 0	;[04]
	db 0	;[05]
	db 0	;[06]
	db 0	;[07]
	db 0	;[08]
	db 0	;[09]
	db 0	;[0a]
	db 0	;[0b]
	db 0	;[0c]
	db 0	;[0d]
	db 62h	;[0e]<BS>
	db 0	;[0f]
	db 22h	;[10]'Q'
	db 28h	;[11]'W'
	db 16h	;[12]'E'
	db 23h	;[13]'R'
	db 25h	;[14]'T'
	db 2Ah	;[15]'Y'
	db 26h	;[16]'U'
	db 1Ah	;[17]'I'
	db 20h	;[18]'O'
	db 21h	;[19]'P'
	db 0	;[1a]
	db 0	;[1b]
	db 63h	;[1c]<RETURN>
	db 0	;[1d]
	db 12h	;[1e]'A'
	db 24h	;[1f]'S'
	db 15h	;[20]'D'
	db 17h	;[21]'F'
	db 18h	;[22]'G'
	db 19h	;[23]'H'
	db 1Bh	;[24]'J'
	db 1Ch	;[25]'K'
	db 1Dh	;[26]'L'
	db 0	;[27]
	db 0	;[28]
	db 0	;[29]
	db 0	;[2a]
	db 0	;[2b]
	db 2Bh	;[2c]'Z'
	db 29h	;[2d]'X'
	db 14h	;[2e]'C'
	db 27h	;[2f]'V'
	db 13h	;[30]'B'
	db 1Fh	;[31]'N'
	db 1Eh	;[32]'M'
	db 0	;[33]
	db 0	;[34]
	db 0	;[35]
	db 0	;[36]
	db 0	;[37]
	db 0	;[38]
	db 2Ch	;[39]' '
	db 0	;[3A]
	db 0	;[3B]
	db 0	;[3C]
	db 0	;[3D]
	db 0	;[3E]
	db 0	;[3F]
;-- sound info --
D_1B7B	dw   600, 2,  0,0,  1,0	;key pressed/bonus
D_1B87	dw 20000,75,600,4,100,0	;pick raider
;-- --
D_1B93	db 0
D_1B94	db 0	;index in D_1B95
D_1B95	db 0,0,1,1,2,2,3,3,4,4,5,5,0FFh
	db 5,5,6,6,7,7,8,8,9,9,10,10,0FFh
D_1BAF	db 0
__1BB0	db 0F8h,0F8h,0F9h,0F9h,0F9h,0F9h,0F9h,0FAh
	db 0FAh,0FAh,0FAh,0FAh,0FBh,0FBh,0FBh,0FBh
	db 0FBh,0FCh,0FCh,0FCh,0FCh,0FCh,0FDh,0FDh
	db 0FDh,0FDh,0FDh,0FEh,0FEh,0FEh,0FEh,0FEh
	db 0FFh,0FFh,0FFh,0FFh,0FFh,0,0
	db 0,0,0,0,0,0,0,0
	db 0FFh
D_1BE0	db 0
__1BE1	db 0Bh
	db 1,1,1,1,1,1,2,2
	db 2,2,2,3,3,3,3,3
	db 4,4,4,4,4,5,5,5
	db 5,5,6,6,6,6,6,7
	db 7,7,7,7,8,8,8,8
	db 0,0,0,0,0,0,0,0
	db 0FFh
D_1C13	db 0
D_1C14	db 0FFh	;user ship index?
D_1C15	db 0	;counter for some anim in "inside raider"
D_1C16	db 0Dh,0Eh,0Fh,0Fh,0Eh,0Dh,0FFh
D_1C1D	db 0,0,0,0	;orbitals state?
;-- "inside raider" actors --
D_1C21	s_actor <127, 88,0,0, 0,0,OFFSET _DATA:D_D470,0,0,0,0,0,12>
	s_actor <267, 88,0,0, 0,0,OFFSET _DATA:D_D470,0,0,0,0,0,12>
	s_actor <116,143,0,0, 0,0,OFFSET _DATA:D_D470,0,0,0,0,0,12>
	s_actor <278,143,0,0, 0,0,OFFSET _DATA:D_D470,0,0,0,0,0,12>
D_1CA9	s_actor <127,88,0,0,-1,0,OFFSET _DATA:D_D470,0,0,0,0,0,12>
	s_actor <267, 88,0,0,-1,0,OFFSET _DATA:D_D470,0,0,0,0,0,12>
	s_actor <116,143,0,0,-1,0,OFFSET _DATA:D_D470,0,0,0,0,0,12>
	s_actor <278,143,0,0,-1,0,OFFSET _DATA:D_D470,0,0,0,0,0,12>
D_1D31	s_actor <176,135,0,0, 0,0,OFFSET _DATA:D_D470,0,0,0,0,0,16>
	s_actor <262,135,0,0, 0,0,OFFSET _DATA:D_D470,0,0,0,0,0,17>
	s_actor <176,150,0,0, 0,0,OFFSET _DATA:D_D470,0,0,0,0,0,16>
	s_actor <262,150,0,0, 0,0,OFFSET _DATA:D_D470,0,0,0,0,0,17>
	s_actor <176,165,0,0, 0,0,OFFSET _DATA:D_D470,0,0,0,0,0,16>
	s_actor <262,165,0,0, 0,0,OFFSET _DATA:D_D470,0,0,0,0,0,17>
	s_actor <176,181,0,0, 0,0,OFFSET _DATA:D_D470,0,0,0,0,0,16>
	s_actor <262,181,0,0, 0,0,OFFSET _DATA:D_D470,0,0,0,0,0,17>
D_1E41	s_actor <125, 87,0,0, 0,0,OFFSET _DATA:D_D470,0,0,0,0,0,13>
	s_actor <312, 87,0,0, 0,0,OFFSET _DATA:D_D470,0,0,0,0,0,13>
	s_actor <114,142,0,0, 0,0,OFFSET _DATA:D_D470,0,0,0,0,0,13>
	s_actor <323,142,0,0, 0,0,OFFSET _DATA:D_D470,0,0,0,0,0,13>
D_1EC9	s_actor <190,217,0,0,-1,0,OFFSET _DATA:D_D470,0,0,0,0,0,19>
	s_actor <247,217,0,0,-1,0,OFFSET _DATA:D_D470,0,0,0,0,0,19>
D_1F0D	s_actor <193, 96,0,0,-1,0,OFFSET _DATA:D_D470,0,0,0,0,0,5>
D_1F2F	s_actor <  0,  0,0,0, 0,0,OFFSET _DATA:D_D470,0,0,0,0,0,0>
D_1F51	s_actor <  0,  0,0,0, 0,0,OFFSET _DATA:D_D470,0,0,0,0,0,0>
D_1F73	s_actor <193, 96,0,0,-1,0,OFFSET _DATA:D_D470,0,0,0,0,0,5>
;-- --
D_1F95	dw 0,20
	dw -6,14
	dw -12,12
	dw -19,7
	dw -22,0
	dw -18,-8
	dw -14,-14
	dw -7,-16
	dw 0,-17
	dw 8,-16
	dw 14,-13
	dw 18,-6
	dw 20,0
	dw 17,6
	dw 12,12
	dw 7,13
;-- raider object for level animation --
D_1FD5	s_actor <224,0,0,0,0,0,OFFSET _DATA:D_D620>

D_1FF7	dw 0	;@ ptr to D_1FF9 or D_204E
;landing
D_1FF9	db 17h,1Bh,1Fh,23h,27h,2Bh,2Fh,33h,37h,3Ah,3Dh,40h,43h,46h,49h,4Ch
	db 4Fh,52h,55h,58h,5Ah,5Ch,5Eh,60h,62h,64h,66h,68h,6Ah,6Ch,6Eh,70h
	db 72h,74h,76h,78h,79h,7Ah,7Bh,7Ch,7Dh,7Eh,7Fh,80h,81h,82h,83h,84h
	db 85h,86h,87h,88h,89h,8Ah,8Bh,8Ch,8Dh,8Eh,8Fh,90h,91h,92h,93h,94h
	db 95h,96h,97h,98h,98h,98h,98h,98h,98h,98h,98h,98h,98h,98h,98h,98h
	db 98h,98h,98h,98h
	db 0FFh
;leaving
D_204E	db 98h,98h,98h,98h,98h,98h,98h,98h,98h,98h,98h,98h,98h,98h,98h,98h
	db 98h,97h,96h,95h,94h,93h,92h,91h,90h,8Fh,8Eh,8Dh,8Ch,8Bh,8Ah,89h
	db 88h,87h,86h,85h,84h,83h,82h,81h,80h,7Fh,7Eh,7Dh,7Ch,7Bh,7Ah,79h
	db 78h,76h,74h,72h,70h,6Eh,6Ch,6Ah,68h,66h,64h,62h,60h,5Eh,5Ch,5Ah
	db 58h,55h,52h,4Fh,4Ch,49h,46h,43h,40h,3Dh,3Ah,37h,33h,2Fh,2Bh,27h
	db 23h,1Fh,1Bh,17h
	db 0FFh
;-- --
g_scroll_x	dw 0	;20A3
__20A5	db 0,0
g_scroll_y	dw 0	;20A7
__20A9	db 0,0,0,0,0,0,0
__20B0	db 0,0,0
__20B3	db 00h,80h,0C0h,0E0h,0F0h,0F8h,0FCh,0FEh
__20CB	db 00h,01h,03h,07h,0Fh,1Fh,3Fh,7Fh
__20C3	db 00h,01h,02h,04h,08h,10h,20h,40h
;-- backbuffers info --
g_pbkbuffer_front	dw OFFSET _DATA:g_bkbuffer_1	;20CB
g_pbkbuffer_back	dw OFFSET _DATA:g_bkbuffer_0	;20CD
g_bkbuffer_0	s_surface <0010h,0,OFFSET _DATA:D_20F6,OFFSET _DATA:D_11B2,OFFSET _DATA:D_B39B,0,0>	;20CF
g_bkbuffer_1	s_surface <3020h,0,OFFSET _DATA:D_2207,OFFSET _DATA:D_1433,OFFSET _DATA:D_B590,0,0>	;20DC
g_bkbuffer_2	s_surface <6030h,0,                  0,OFFSET _DATA:D_16B4,                  0,0,0>	;20E9
D_20F6	db 0	;for g_bkbuffer_0
__20F7	db 110h dup(0)
D_2207	db 0	;for g_bkbuffer_1
__2208	db 110h dup(0)

g_radarOn	db 0	;2318
D_2319	db 0	;"g_radarOn" related
g_radarCnt	db 0	;231A
D_231B	s_radarObject 20h dup(<>)	;display info for radar?
;-- map elements? --
D_241B	s_sprite < 9040h, 000h,000h,008h,040h, 000h,000h,000h,000h, 000h,000h,000h,000h, 0>
	s_sprite < 9240h, 000h,008h,008h,038h, 000h,000h,000h,000h, 000h,000h,000h,000h, 0>
	s_sprite < 9400h, 001h,008h,007h,030h, 000h,000h,000h,000h, 000h,000h,000h,000h, 0>
	s_sprite < 9550h, 000h,000h,008h,038h, 000h,000h,000h,000h, 000h,000h,000h,000h, 0>
	s_sprite < 9710h, 000h,000h,008h,038h, 000h,000h,000h,000h, 000h,000h,000h,000h, 0>
	s_sprite < 98D0h, 000h,000h,008h,040h, 000h,000h,000h,000h, 000h,000h,000h,000h, 0>
	s_sprite < 9AD0h, 000h,000h,008h,040h, 000h,000h,000h,000h, 000h,000h,000h,000h, 0>
	s_sprite < 9CD0h, 000h,000h,008h,040h, 000h,000h,000h,000h, 000h,000h,000h,000h, 0>
	s_sprite < 9ED0h, 001h,000h,006h,040h, 000h,000h,000h,000h, 017h,00Ah,012h,02Bh, 1>
	s_sprite <0A050h, 001h,000h,006h,038h, 000h,000h,000h,000h, 016h,00Fh,017h,019h, 1>
	s_sprite <0A1A0h, 000h,000h,008h,040h, 000h,000h,000h,000h, 00Fh,010h,023h,01Ch, 1>
	s_sprite <0A3A0h, 000h,000h,008h,040h, 000h,000h,000h,000h, 014h,012h,016h,020h, 1>
	s_sprite <0A5A0h, 000h,000h,008h,040h, 005h,008h,038h,033h, 011h,013h,01Eh,01Bh, 2>
	s_sprite <0A7A0h, 001h,000h,006h,028h, 011h,010h,023h,020h, 01Bh,019h,00Dh,00Ch, 2>
	s_sprite <0A890h, 000h,000h,008h,040h, 013h,005h,025h,026h, 01Eh,010h,010h,010h, 2>
	s_sprite <0AA90h, 000h,000h,008h,040h, 000h,000h,000h,000h, 011h,011h,01Eh,020h, 1>
	s_sprite <0AC90h, 000h,008h,008h,030h, 000h,000h,000h,000h, 011h,016h,021h,011h, 1>
	s_sprite <0AE10h, 002h,018h,003h,010h, 000h,000h,000h,000h, 000h,000h,000h,000h, 0>
	s_sprite <0AE40h, 003h,008h,005h,030h, 000h,000h,000h,000h, 000h,000h,000h,000h, 0>
	s_sprite <0AF30h, 000h,008h,008h,030h, 004h,006h,037h,035h, 012h,012h,01Ch,01Ch, 2>
	s_sprite <0B0B0h, 001h,008h,006h,030h, 00Bh,00Ch,02Dh,029h, 015h,015h,017h,015h, 2>
	s_sprite <0B1D0h, 000h,000h,008h,040h, 000h,000h,000h,000h, 012h,015h,01Ah,01Ah, 1>
	s_sprite <0B3D0h, 002h,000h,006h,030h, 013h,006h,02Ah,028h, 01Dh,00Fh,016h,016h, 2>
	s_sprite <0B4F0h, 003h,020h,004h,020h, 017h,01Eh,01Eh,01Dh, 01Eh,024h,00Fh,010h, 2>
	s_sprite <0B570h, 001h,010h,005h,030h, 000h,000h,000h,000h, 000h,000h,000h,000h, 0>
	s_sprite <0B660h, 002h,008h,005h,020h, 014h,007h,026h,021h, 01Dh,00Dh,014h,013h, 2>
	s_sprite <0B700h, 001h,008h,006h,030h, 007h,008h,035h,02Fh, 013h,010h,01Dh,01Ch, 2>
	s_sprite <0B820h, 002h,010h,004h,020h, 000h,000h,000h,000h, 000h,000h,000h,000h, 0>
	s_sprite <0B8A0h, 002h,018h,004h,020h, 000h,000h,000h,000h, 016h,01Ah,014h,013h, 1>
	s_sprite <0B920h, 001h,000h,006h,040h, 006h,005h,01Fh,01Dh, 00Eh,00Ch,00Eh,00Dh, 2>
	s_sprite <0BAA0h, 000h,000h,008h,040h, 00Ch,011h,034h,02Fh, 01Ch,01Dh,019h,016h, 2>
	s_sprite <0BCA0h, 001h,010h,006h,028h, 00Dh,010h,029h,026h, 016h,018h,016h,015h, 2>
	s_sprite <0BD90h, 003h,020h,005h,020h, 000h,000h,000h,000h, 000h,000h,000h,000h, 0>
	s_sprite <0BE30h, 001h,010h,005h,028h, 000h,000h,000h,000h, 000h,000h,000h,000h, 0>
	s_sprite <0BEF8h, 002h,010h,005h,020h, 000h,000h,000h,000h, 000h,000h,000h,000h, 0>
	s_sprite <0BF98h, 001h,008h,004h,010h, 000h,000h,000h,000h, 000h,000h,000h,000h, 0>
	s_sprite <0BFD8h, 002h,000h,006h,038h, 00Ah,017h,024h,020h, 014h,020h,00Fh,00Dh, 2>
	s_sprite <0C128h, 001h,010h,007h,028h, 000h,000h,000h,000h, 018h,019h,016h,018h, 1>
	s_sprite <0C240h, 000h,008h,004h,028h, 000h,00Ch,023h,022h, 009h,016h,00Fh,00Dh, 2>
	s_sprite <0C2E0h, 000h,000h,008h,040h, 004h,004h,03Ch,03Bh, 012h,013h,01Fh,01Dh, 2>
	s_sprite <0C4E0h, 000h,000h,008h,040h, 000h,00Bh,040h,03Ah, 010h,013h,020h,01Eh, 2>
	s_sprite <0C6E0h, 000h,000h,008h,040h, 000h,000h,000h,000h, 018h,012h,014h,016h, 1>
	s_sprite <0C8E0h, 002h,010h,004h,028h, 000h,000h,000h,000h, 000h,000h,000h,000h, 0>
	s_sprite <0C980h, 000h,008h,008h,030h, 000h,000h,000h,000h, 000h,000h,000h,000h, 0>
;-- "map.dat" (or temporary buffer) --
D_26DB	db 2000h dup(0)
;-- current map --
g_tilemap	db 400h dup(0)	;46DB
D_4ADB	db 4000h dup(0)
D_8ADB	db 28C0h dup(0)

D_B39B	db 1F5h dup(0)	;for g_bkbuffer_0
D_B590	db 200h dup(0)	;for g_bkbuffer_1
;-- keymap --
D_B790	db 80h dup(0)
;-- "keys.dat" --
D_B810	db 2Ah	;<L.SHIFT>:"fire"
	db 48h	;<UP>
	db 50h	;<DOWN>
	db 4Bh	;<LEFT>
	db 4Dh	;<RIGHT>
	db 1Fh	;S:"stop raider"
	db 11h	;W:"raider up"
	db 2Dh	;X:"raider down"
	db 1Eh	;A:"raider left"
	db 20h	;D:"raider right"
	db 39h	;<SPACE>:"radar on/off"
	db 13h	;R:"control raider"
;-- --
g_kbdmsk_orb	db 0	;B81C
D_B81D	db 0FFh	;!(g_kbdmsk_orb trigger mask)(1)
g_kbdmsk_raid	db 0	;B81E
D_B81F	db 0FFh	;!(g_kbdmsk_orb trigger mask)(2)
g_prevkbdmsk_raid	db 0	;B820
g_prevkbdmsk_orb	db 0	;B821
g_kbd_cur_scan	db 0	;B822
g_kbd_prev_scan	db 0	;B823
D_B824	dw 0,0	;original int 8 vector
D_B828	db 0	;int 8 "semaphore/counter"
D_B829	db 0
g_int8_cnt	db 0	;B82A
ifdef FIX_BUGS
D_B82B	dw ?,?	;original int 9 vector
__B82F	db 0
else
__B82B	db 5 dup(0)
endif
__B830	db 0,0
;-- random seeds --
D_B832	dw 10h dup(38h)
__B852	db 0Eh dup(0)	;padding?
;-- --
g_playSnd	db 0	;B860
D_B861	dw 0	;sound counter increment
D_B863	dw 0
D_B865	dw 0	;sound length
D_B867	dw 0
D_B869	dw 0
D_B86B	dw 0
D_B86D	dw 0
D_B86F	dw 0
D_B871	dw 0	;sound counter
__B873	db 0
D_B874	db 0	;another sound inhibit flag[always 0]?
g_soundOff	db 0	;B875
D_B876	db 0	;"sound inhibit flag" related?

__B877	db 9 dup(0);padding?
;----------------------------------------"orbital"
D_B880	dw SEG_1BDA
	s_sprite <0030h, 5,9,0Fh,08h, 0F5h,0FAh,000h,0FBh, 0F5h,0FEh,00Bh,0FEh, 0B1h>
	s_sprite <0117h, 5,7,0Eh,0Bh, 0F6h,0F8h,004h,0FDh, 0F6h,0FBh,00Ah,007h, 0B1h>
	s_sprite <022Ah, 6,8,0Ch,0Bh, 0F7h,0F7h,004h,0FDh, 0FAh,0F9h,008h,007h, 0B1h>
	s_sprite <0353h, 6,7,0Dh,0Ch, 0F7h,0F7h,004h,0FDh, 0FBh,0F7h,007h,008h, 0B1h>
	s_sprite <0463h, 7,6,0Ah,0Dh, 0F8h,0F7h,006h,000h, 003h,0F7h,003h,009h, 0B1h>
	s_sprite <056Ah, 6,6,0Dh,0Ch, 0F7h,0F7h,004h,003h, 007h,0F8h,0FBh,009h, 0B1h>
	s_sprite <067Bh, 6,6,0Bh,0Bh, 0F7h,0F7h,004h,004h, 008h,0FAh,0FAh,008h, 0B1h>
	s_sprite <07A2h, 5,6,0Eh,0Bh, 0F6h,0F8h,004h,004h, 00Bh,0FCh,0F7h,006h, 0B1h>
	s_sprite <08AEh, 5,8,0Fh,08h, 0F5h,0FAh,000h,006h, 00Bh,003h,0F5h,003h, 0B1h>
	s_sprite <09A0h, 6,7,0Eh,0Bh, 0F6h,0F8h,0FDh,004h, 009h,006h,0F7h,0FAh, 0B1h>
	s_sprite <0AB4h, 8,6,0Bh,0Bh, 0F7h,0F7h,0FDh,004h, 007h,008h,0F9h,0FAh, 0B1h>
	s_sprite <0BEEh, 6,6,0Dh,0Ch, 0F7h,0F7h,0FEh,003h, 007h,009h,0FBh,0F8h, 0B1h>
	s_sprite <0D15h, 8,6,0Ah,0Dh, 0F8h,0F7h,0FAh,000h, 0FDh,009h,0FDh,0F6h, 0B1h>
	s_sprite <0E2Dh, 6,7,0Dh,0Ch, 0F7h,0F7h,0FDh,0FDh, 0FAh,008h,006h,0F7h, 0B1h>
	s_sprite <0F54h, 8,8,0Bh,0Bh, 0F7h,0F7h,0FDh,0FDh, 0F9h,007h,007h,0F9h, 0B1h>
	s_sprite <1090h, 6,7,0Eh,0Bh, 0F6h,0F8h,0FDh,0FDh, 0F6h,005h,009h,0FBh, 0B1h>

D_B982	dw SEG_1BDA
	s_sprite <11A3h, 0,1,3,3, 0FFh,0FDh,0,0, 0,0,0,0, 0B1h>
	s_sprite <1235h, 2,0,3,3, 0FEh,0FFh,0,0, 0,0,0,0, 0B1h>
	s_sprite <12C7h, 3,0,3,3, 0FCh,0FFh,0,0, 0,0,0,0, 0B1h>
	s_sprite <1335h, 5,0,3,3, 0FAh,0FFh,0,0, 0,0,0,0, 0B1h>
	s_sprite <139Bh, 4,0,3,3, 0FBh,0FFh,0,0, 0,0,0,0, 0B1h>
	s_sprite <13E1h, 4,1,3,3, 0FBh,0FEh,0,0, 0,0,0,0, 0B1h>
	s_sprite <143Bh, 3,3,3,3, 0FCh,0FCh,0,0, 0,0,0,0, 0B1h>
	s_sprite <14A9h, 1,4,3,3, 0FEh,0FCh,0,0, 0,0,0,0, 0B1h>
	s_sprite <152Fh, 0,4,3,3, 0FFh,0FBh,0,0, 0,0,0,0, 0B1h>
	s_sprite <15C1h, 0,5,3,3, 0FFh,0FAh,0,0, 0,0,0,0, 0B1h>
	s_sprite <1653h, 0,3,3,3, 0FFh,0FCh,0,0, 0,0,0,0, 0B1h>
	s_sprite <16C1h, 0,2,3,3, 0FFh,0FDh,0,0, 0,0,0,0, 0B1h>
	s_sprite <1727h, 1,0,3,3, 0FEh,0FFh,0,0, 0,0,0,0, 0B1h>
	s_sprite <176Dh, 0,0,3,3, 0FFh,0FFh,0,0, 0,0,0,0, 0B1h>
	s_sprite <17D3h, 0,0,3,3, 0FFh,0FFh,0,0, 0,0,0,0, 0B1h>
	s_sprite <1841h, 0,0,3,3, 0FFh,0FFh,0,0, 0,0,0,0, 0B1h>

__BA84	db 0Ch dup(0)	;padding
;----------------------------------------"raider"
D_BA90	dw SEG_1BDA
	s_sprite <18E0h, 0Bh,09h,27h,1Fh, 0E2h,0EAh,000h,0EBh, 0E9h,0F0h,017h,0F0h, 0B1h>
	s_sprite <1DD4h, 0Bh,0Ah,25h,1Dh, 0E3h,0E6h,00Ch,0E8h, 0F4h,0E6h,01Dh,0F4h, 0B1h>
	s_sprite <230Fh, 12h,0Ah,24h,20h, 0E1h,0E5h,016h,0EFh, 000h,0E5h,020h,002h, 0B1h>
	s_sprite <2876h, 0Fh,0Ch,26h,1Ch, 0E3h,0E7h,01Ch,0F6h, 00Ch,0E7h,01Dh,00Ch, 0B1h>
	s_sprite <2DD3h, 07h,09h,23h,22h, 0E6h,0E7h,019h,001h, 012h,0EBh,012h,016h, 0B1h>
	s_sprite <32F8h, 0Fh,08h,21h,23h, 0E3h,0E6h,01Ch,00Ah, 01Eh,0F4h,00Dh,01Ah, 0B1h>
	s_sprite <3860h, 12h,0Eh,24h,20h, 0E0h,0E5h,015h,012h, 020h,0FFh,0FFh,01Ch, 0B1h>
	s_sprite <3DBCh, 0Eh,0Dh,23h,1Eh, 0E3h,0E6h,00Ch,017h, 01Eh,00Ah,0F4h,01Ah, 0B1h>
	s_sprite <42ECh, 0Ch,05h,25h,1Fh, 0E2h,0EAh,000h,016h, 017h,011h,0E9h,011h, 0B1h>
	s_sprite <47B6h, 0Dh,0Eh,21h,1Eh, 0E3h,0E6h,0F5h,018h, 00Dh,01Ah,0E3h,00Ah, 0B1h>
	s_sprite <4CF2h, 0Bh,0Eh,24h,20h, 0E1h,0E5h,0ECh,012h, 002h,01Ch,0E1h,0FFh, 0B1h>
	s_sprite <525Fh, 0Ah,0Bh,22h,1Eh, 0E3h,0E7h,0E5h,00Bh, 0F5h,01Bh,0E3h,0F5h, 0B1h>
	s_sprite <57B9h, 0Ch,09h,23h,22h, 0E6h,0E7h,0E7h,001h, 0EEh,016h,0EEh,0EBh, 0B1h>
	s_sprite <5CF8h, 0Bh,0Ch,20h,1Dh, 0E3h,0E6h,0E4h,0F5h, 0E3h,00Bh,0F3h,0E6h, 0B1h>
	s_sprite <6256h, 0Bh,0Ah,23h,1Fh, 0E0h,0E5h,0EBh,0EFh, 0E0h,002h,001h,0E5h, 0B1h>
	s_sprite <67A9h, 0Dh,09h,21h,1Fh, 0E3h,0E6h,0F5h,0E8h, 0E3h,0F6h,00Dh,0E6h, 0B1h>
	s_sprite <18E0h, 18h,1Eh,0Dh,0Ah, 0E2h,0EAh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <1DD4h, 11h,1Dh,10h,0Ah, 0E3h,0E6h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <230Fh, 12h,1Dh,0Eh,0Dh, 0E1h,0E5h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <2876h, 0Fh,18h,0Eh,10h, 0E3h,0E7h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <2DD3h, 07h,13h,0Eh,0Eh, 0E6h,0E7h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <32F8h, 0Fh,0Ch,0Fh,11h, 0E3h,0E6h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <3860h, 12h,0Eh,0Fh,0Eh, 0E0h,0E5h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <3DBCh, 0Eh,0Dh,14h,0Ch, 0E3h,0E6h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <42ECh, 15h,05h,13h,0Dh, 0E2h,0EAh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <47B6h, 1Ah,0Eh,14h,0Dh, 0E3h,0E6h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <4CF2h, 20h,0Eh,0Fh,0Eh, 0E1h,0E5h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <525Fh, 22h,0Bh,0Bh,14h, 0E3h,0E7h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <57B9h, 21h,11h,0Eh,12h, 0E6h,0E7h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <5CF8h, 1Fh,16h,0Ch,13h, 0E3h,0E6h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <6256h, 20h,1Bh,0Eh,0Eh, 0E0h,0E5h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <67A9h, 1Ah,1Dh,14h,0Bh, 0E3h,0E6h,000h,000h, 000h,000h,000h,000h, 0B1h>

__BC92	db 0Eh dup(0)	;padding
;----------------------------------------enemy[0]
D_BCA0	dw SEG_1BDA
	s_sprite <6CF0h, 3,4,17h,19h, 0F2h,0F2h,000h,0F5h, 0F3h,0FCh,00Dh,0FCh, 0B1h>
	s_sprite <6CF0h, 3,4,17h,19h, 0F2h,0F2h,000h,0F5h, 0F3h,0FCh,00Dh,0FCh, 0B1h>
	s_sprite <6FF2h, 9,2,17h,16h, 0ECh,0F4h,009h,0F8h, 0F8h,0F6h,00Ch,007h, 0B1h>
	s_sprite <6FF2h, 9,2,17h,16h, 0ECh,0F4h,009h,0F8h, 0F8h,0F6h,00Ch,007h, 0B1h>
	s_sprite <7315h, 1,3,1Ch,13h, 0F0h,0F4h,00Eh,000h, 006h,0F5h,006h,00Bh, 0B1h>
	s_sprite <7315h, 1,3,1Ch,13h, 0F0h,0F4h,00Eh,000h, 006h,0F5h,006h,00Bh, 0B1h>
	s_sprite <75B5h, 9,9,17h,16h, 0ECh,0ECh,009h,008h, 00Ch,0F9h,0F8h,00Ah, 0B1h>
	s_sprite <75B5h, 9,9,17h,16h, 0ECh,0ECh,009h,008h, 00Ch,0F9h,0F8h,00Ah, 0B1h>
	s_sprite <78D1h, 3,1,17h,19h, 0F2h,0F2h,000h,00Ch, 00Dh,005h,0F3h,005h, 0B1h>
	s_sprite <78D1h, 3,1,17h,19h, 0F2h,0F2h,000h,00Ch, 00Dh,005h,0F3h,005h, 0B1h>
	s_sprite <7BDBh, 3,9,17h,16h, 0F2h,0ECh,0F7h,008h, 008h,00Ah,0F4h,0F9h, 0B1h>
	s_sprite <7BDBh, 3,9,17h,16h, 0F2h,0ECh,0F7h,008h, 008h,00Ah,0F4h,0F9h, 0B1h>
	s_sprite <7F01h, 5,3,1Ch,13h, 0F0h,0F4h,0F3h,000h, 0FBh,00Bh,0FBh,0F5h, 0B1h>
	s_sprite <7F01h, 5,3,1Ch,13h, 0F0h,0F4h,0F3h,000h, 0FBh,00Bh,0FBh,0F5h, 0B1h>
	s_sprite <81ACh, 3,2,17h,16h, 0F2h,0F4h,0F7h,0F8h, 0F4h,007h,008h,0F6h, 0B1h>
	s_sprite <81ACh, 3,2,17h,16h, 0F2h,0F4h,0F7h,0F8h, 0F4h,007h,008h,0F6h, 0B1h>

D_BDA2	dw SEG_1BDA
	s_sprite < 84DEh, 2,1,09h,08h, 0FAh,0FBh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite < 85A8h, 2,1,09h,08h, 0FAh,0FBh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite < 8698h, 1,3,0Bh,08h, 0FAh,0F8h,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite < 87D7h, 1,2,09h,08h, 0FBh,0F8h,0,0, 0FCh,0FAh,004h,0FAh, 0B1h>
	s_sprite < 8879h, 1,1,08h,09h, 0FBh,0FBh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite < 8961h, 1,1,09h,09h, 0FBh,0FBh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite < 8A5Dh, 2,3,08h,08h, 0FBh,0F8h,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite < 8B89h, 2,2,08h,07h, 0FDh,0F9h,0,0, 002h,0FAh,007h,0FFh, 0B1h>
	s_sprite < 8C36h, 1,2,09h,09h, 0FCh,0FAh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite < 8D42h, 1,2,09h,09h, 0FCh,0FAh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite < 8E61h, 1,1,0Ah,0Bh, 0FCh,0FAh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite < 8F8Ah, 1,1,09h,09h, 0FEh,0FBh,0,0, 007h,0FCh,007h,004h, 0B1h>
	s_sprite < 905Ch, 2,2,08h,08h, 0FBh,0FBh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite < 9144h, 2,2,07h,07h, 0FBh,0FBh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite < 9240h, 2,2,08h,08h, 0FBh,0FBh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite < 936Ch, 3,2,08h,08h, 0FDh,0FDh,0,0, 007h,001h,002h,006h, 0B1h>
	s_sprite < 9419h, 2,1,09h,08h, 0FAh,0FCh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite < 94E3h, 2,1,09h,08h, 0FAh,0FCh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite < 95D3h, 1,1,0Bh,09h, 0FAh,0FCh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite < 970Eh, 1,1,09h,08h, 0FBh,0FEh,0,0, 004h,006h,0FCh,006h, 0B1h>
	s_sprite < 97B0h, 2,2,07h,07h, 0FBh,0FBh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite < 989Eh, 2,2,07h,07h, 0FBh,0FBh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite < 999Fh, 3,2,09h,08h, 0F8h,0FBh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite < 9AD3h, 2,2,07h,07h, 0F8h,0FDh,0,0, 0FEh,006h,0F9h,001h, 0B1h>
	s_sprite < 9B84h, 1,2,09h,09h, 0FAh,0FAh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite < 9C92h, 1,2,09h,09h, 0FAh,0FAh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite < 9DB1h, 3,1,09h,0Bh, 0F7h,0FAh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite < 9EE2h, 2,1,08h,09h, 0F7h,0FBh,0,0, 0F9h,004h,0F9h,0FCh, 0B1h>
	s_sprite < 9FB4h, 3,3,06h,06h, 0FBh,0FBh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <0A0A2h, 2,2,08h,08h, 0FBh,0FBh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <0A1A3h, 4,4,0Ah,09h, 0F8h,0F9h,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <0A2D7h, 3,3,08h,07h, 0F8h,0F9h,0,0, 0F9h,0FFh,0FEh,0FAh, 0B1h>

__BFA4	db 0Ch dup(0)	;padding
;----------------------------------------enemy[1]
D_BFB0	dw SEG_1BDA
	s_sprite <0A390h, 6,3,0Dh,0Eh, 0F4h,0F7h,000h,0FBh, 0F4h,000h,00Ch,000h, 0B1h>
	s_sprite <0A390h, 6,3,0Dh,0Eh, 0F4h,0F7h,000h,0FBh, 0F4h,000h,00Ch,000h, 0B1h>
	s_sprite <0A538h, 5,2,0Eh,0Eh, 0F4h,0F8h,004h,0FCh, 0F7h,0F8h,008h,009h, 0B1h>
	s_sprite <0A538h, 5,2,0Eh,0Eh, 0F4h,0F8h,004h,0FCh, 0F7h,0F8h,008h,009h, 0B1h>
	s_sprite <0A72Fh, 2,6,0Fh,0Dh, 0F8h,0F4h,007h,000h, 002h,0F4h,002h,00Ch, 0B1h>
	s_sprite <0A72Fh, 2,6,0Fh,0Dh, 0F8h,0F4h,007h,000h, 002h,0F4h,002h,00Ch, 0B1h>
	s_sprite <0A92Ch, 5,5,0Eh,0Eh, 0F4h,0F4h,004h,004h, 008h,0F7h,0F7h,008h, 0B1h>
	s_sprite <0A92Ch, 5,5,0Eh,0Eh, 0F4h,0F4h,004h,004h, 008h,0F7h,0F7h,008h, 0B1h>
	s_sprite <0AB0Fh, 6,1,0Dh,0Eh, 0F4h,0F7h,000h,005h, 00Ch,000h,0F4h,000h, 0B1h>
	s_sprite <0AB0Fh, 6,1,0Dh,0Eh, 0F4h,0F7h,000h,005h, 00Ch,000h,0F4h,000h, 0B1h>
	s_sprite <0ACC4h, 2,4,0Eh,0Eh, 0F8h,0F5h,0FCh,004h, 009h,008h,0F8h,0F8h, 0B1h>
	s_sprite <0ACC4h, 2,4,0Eh,0Eh, 0F8h,0F5h,0FCh,004h, 009h,008h,0F8h,0F8h, 0B1h>
	s_sprite <0AE91h, 3,6,0Fh,0Dh, 0F7h,0F4h,0FBh,000h, 000h,00Ch,000h,0F4h, 0B1h>
	s_sprite <0AE91h, 3,6,0Fh,0Dh, 0F7h,0F4h,0FBh,000h, 000h,00Ch,000h,0F4h, 0B1h>
	s_sprite <0B0A8h, 2,2,0Eh,0Eh, 0F8h,0F8h,0FCh,0FCh, 0F8h,009h,009h,0F8h, 0B1h>
	s_sprite <0B0A8h, 2,2,0Eh,0Eh, 0F8h,0F8h,0FCh,0FCh, 0F8h,009h,009h,0F8h, 0B1h>

D_C0B2	dw SEG_1BDA
	s_sprite <0B283h, 0,0,0,0, 0FFh,0FEh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B2E5h, 0,0,0,0, 0FDh,0FAh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B38Bh, 0,1,5,5, 0FEh,0FBh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B41Dh, 0,0,0,0, 0FEh,0FEh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B47Fh, 0,0,0,0, 0FEh,0FDh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B4F5h, 1,0,5,5, 0FEh,0FDh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B567h, 0,0,0,0, 0FEh,0FFh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B5ADh, 0,0,0,0, 0FEh,0FDh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B62Eh, 2,0,5,5, 0FEh,0FEh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B68Ch, 0,0,0,0, 0FEh,0FEh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B6EEh, 0,0,0,0, 0FEh,0FEh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B764h, 1,1,5,5, 0FEh,0FEh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B7D6h, 0,0,0,0, 0FFh,0FEh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B838h, 0,0,0,0, 0FDh,0FEh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B8DEh, 0,2,5,5, 0FEh,0FEh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B970h, 0,0,0,0, 0FEh,0FEh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B9D2h, 0,0,0,0, 0FDh,0FEh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0BA48h, 0,1,5,5, 0FDh,0FEh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0BABAh, 0,0,0,0, 0FEh,0FFh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0BB00h, 0,0,0,0, 0FAh,0FDh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0BB81h, 1,0,5,5, 0FBh,0FEh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0BBDFh, 0,0,0,0, 0FEh,0FEh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0BC41h, 0,0,0,0, 0FDh,0FDh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0BCB7h, 0,0,5,5, 0FDh,0FDh,0,0, 0,0,0,0, 0B1h>

__C234	db 0Ch dup(0)	;padding
;----------------------------------------enemy[2]
D_C240	dw SEG_1BDA
	s_sprite <0BD30h, 11h,11h,0Eh,0Eh, 0EFh,0F3h,000h,0F6h, 0EFh,001h,011h,001h, 0B1h>
	s_sprite <0BD30h, 11h,11h,0Eh,0Eh, 0EFh,0F3h,000h,0F6h, 0EFh,001h,011h,001h, 0B1h>
	s_sprite <0BF7Bh, 10h,11h,0Fh,0Dh, 0F1h,0F3h,008h,0F9h, 0F3h,0F6h,00Ch,00Bh, 0B1h>
	s_sprite <0BF7Bh, 10h,11h,0Fh,0Dh, 0F1h,0F3h,008h,0F9h, 0F3h,0F6h,00Ch,00Bh, 0B1h>
	s_sprite <0C1F9h, 10h,11h,10h,0Eh, 0F1h,0F1h,00Bh,000h, 000h,0F1h,000h,00Fh, 0B1h>
	s_sprite <0C1F9h, 10h,11h,10h,0Eh, 0F1h,0F1h,00Bh,000h, 000h,0F1h,000h,00Fh, 0B1h>
	s_sprite <0C477h, 10h,11h,0Fh,0Dh, 0F1h,0F3h,008h,007h, 00Ch,0F5h,0F3h,00Ah, 0B1h>
	s_sprite <0C477h, 10h,11h,0Fh,0Dh, 0F1h,0F3h,008h,007h, 00Ch,0F5h,0F3h,00Ah, 0B1h>
	s_sprite <0C70Bh, 0Dh,12h,0Eh,0Eh, 0EFh,0F3h,000h,00Ah, 011h,000h,0EFh,000h, 0B1h>
	s_sprite <0C70Bh, 0Dh,12h,0Eh,0Eh, 0EFh,0F3h,000h,00Ah, 011h,000h,0EFh,000h, 0B1h>
	s_sprite <0C960h, 0Dh,10h,0Fh,0Dh, 0F1h,0F3h,0F7h,007h, 00Ch,00Ah,0F3h,0F5h, 0B1h>
	s_sprite <0C960h, 0Dh,10h,0Fh,0Dh, 0F1h,0F3h,0F7h,007h, 00Ch,00Ah,0F3h,0F5h, 0B1h>
	s_sprite <0CBF0h, 0Ch,11h,10h,0Eh, 0F1h,0F1h,0F6h,000h, 001h,00Fh,001h,0F1h, 0B1h>
	s_sprite <0CBF0h, 0Ch,11h,10h,0Eh, 0F1h,0F1h,0F6h,000h, 001h,00Fh,001h,0F1h, 0B1h>
	s_sprite <0CE7Ah, 0Dh,12h,0Fh,0Dh, 0F1h,0F3h,0F8h,0F9h, 0F4h,00Bh,00Dh,0F6h, 0B1h>
	s_sprite <0CE7Ah, 0Dh,12h,0Fh,0Dh, 0F1h,0F3h,0F8h,0F9h, 0F4h,00Bh,00Dh,0F6h, 0B1h>

D_C342	dw SEG_1BDA
	s_sprite <0D0FAh, 0,0,00h,00h, 0FAh,0FDh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <0D1A8h, 0,0,00h,00h, 0FAh,0FDh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <0D24Bh, 0,0,0Bh,05h, 0FBh,0FEh,0,0, 0FDh,000h,003h,000h, 0B1h>
	s_sprite <0D2CBh, 0,0,00h,00h, 0FBh,0FCh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <0D39Ah, 0,0,00h,00h, 0FBh,0FCh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <0D46Eh, 1,1,07h,07h, 0FCh,0FCh,0,0, 0FEh,0FEh,002h,002h, 0B1h>
	s_sprite <0D529h, 0,0,00h,00h, 0FCh,0FAh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <0D60Bh, 0,0,00h,00h, 0FDh,0FAh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <0D6FDh, 0,0,05h,0Bh, 0FEh,0FBh,0,0, 000h,0FDh,000h,003h, 0B1h>
	s_sprite <0D7CBh, 0,0,00h,00h, 0FBh,0FBh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <0D89Ah, 0,0,00h,00h, 0FBh,0FBh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <0D96Eh, 1,1,07h,07h, 0FCh,0FCh,0,0, 002h,0FEh,0FEh,002h, 0B1h>
	s_sprite <0DA29h, 0,0,00h,00h, 0FAh,0FCh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <0DAD7h, 0,0,00h,00h, 0FAh,0FDh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <0DB7Ah, 0,0,0Bh,05h, 0FBh,0FEh,0,0, 003h,000h,0FDh,000h, 0B1h>
	s_sprite <0DBFAh, 0,0,00h,00h, 0FCh,0FBh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <0DCC3h, 0,0,00h,00h, 0FCh,0FBh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <0DD90h, 1,1,07h,07h, 0FCh,0FCh,0,0, 002h,002h,0FEh,0FEh, 0B1h>
	s_sprite <0DE4Bh, 0,0,00h,00h, 0FDh,0FAh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <0DF31h, 0,0,00h,00h, 0FDh,0FAh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <0E023h, 0,0,05h,0Bh, 0FEh,0FBh,0,0, 000h,003h,000h,0FDh, 0B1h>
	s_sprite <0E0F1h, 0,0,00h,00h, 0FCh,0FCh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <0E1BAh, 0,0,00h,00h, 0FCh,0FCh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <0E287h, 1,1,07h,07h, 0FCh,0FCh,0,0, 0FEh,002h,002h,0FEh, 0B1h>

__C4C4	db 0Ch dup(0)	;padding
;----------------------------------------enemy[3]
D_C4D0	dw SEG_2A97
	s_sprite <0030h, 2,4,11h,10h, 0F6h,0F6h,000h,0F7h, 0F6h,0FCh,00Ah,0FCh, 0B1h>
	s_sprite <0030h, 2,4,11h,10h, 0F6h,0F6h,000h,0F7h, 0F6h,0FCh,00Ah,0FCh, 0B1h>
	s_sprite <01EBh, 4,5,10h,10h, 0F4h,0F4h,007h,0F9h, 0FCh,0F6h,00Ah,004h, 0B1h>
	s_sprite <01EBh, 4,5,10h,10h, 0F4h,0F4h,007h,0F9h, 0FCh,0F6h,00Ah,004h, 0B1h>
	s_sprite <040Ah, 1,2,12h,0Fh, 0F5h,0F7h,00Ah,000h, 004h,0F6h,004h,009h, 0B1h>
	s_sprite <040Ah, 1,2,12h,0Fh, 0F5h,0F7h,00Ah,000h, 004h,0F6h,004h,009h, 0B1h>
	s_sprite <0570h, 3,3,10h,10h, 0F4h,0F4h,007h,007h, 00Ah,0FCh,0FCh,00Ah, 0B1h>
	s_sprite <0570h, 3,3,10h,10h, 0F4h,0F4h,007h,007h, 00Ah,0FCh,0FCh,00Ah, 0B1h>
	s_sprite <0773h, 2,1,11h,10h, 0F6h,0F6h,000h,009h, 00Ah,004h,0F6h,004h, 0B1h>
	s_sprite <0773h, 2,1,11h,10h, 0F6h,0F6h,000h,009h, 00Ah,004h,0F6h,004h, 0B1h>
	s_sprite <0928h, 5,4,10h,10h, 0F4h,0F4h,0F9h,007h, 004h,00Ah,0F6h,0FCh, 0B1h>
	s_sprite <0928h, 5,4,10h,10h, 0F4h,0F4h,0F9h,007h, 004h,00Ah,0F6h,0FCh, 0B1h>
	s_sprite <0B3Ah, 4,2,12h,0Fh, 0F5h,0F7h,0F7h,000h, 0FCh,009h,0FCh,0F7h, 0B1h>
	s_sprite <0B3Ah, 4,2,12h,0Fh, 0F5h,0F7h,0F7h,000h, 0FCh,009h,0FCh,0F7h, 0B1h>
	s_sprite <0CA5h, 6,6,10h,10h, 0F4h,0F4h,0F9h,0F9h, 0F6h,004h,004h,0F6h, 0B1h>
	s_sprite <0CA5h, 6,6,10h,10h, 0F4h,0F4h,0F9h,0F9h, 0F6h,004h,004h,0F6h, 0B1h>

D_C5D2	dw SEG_2A97
	s_sprite <0EBBh, 0,0,0,0, 0FDh,0FEh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <0F21h, 0,0,0,0, 0FDh,0FBh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <0FDFh, 0,1,7,7, 0FDh,0FBh,000h,0FCh, 0FDh,0FCh,003h,0FCh, 0B1h>
	s_sprite <1099h, 0,0,0,0, 0FDh,0FDh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <112Fh, 0,0,0,0, 0FCh,0FCh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <11EBh, 1,1,7,7, 0FCh,0FCh,002h,0FEh, 000h,0FCh,004h,000h, 0B1h>
	s_sprite <12A4h, 0,0,0,0, 0FEh,0FDh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <1332h, 0,0,0,0, 0FBh,0FDh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <13DCh, 3,0,7,7, 0FBh,0FDh,004h,000h, 004h,0FDh,004h,003h, 0B1h>
	s_sprite <1489h, 0,0,0,0, 0FDh,0FDh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <151Fh, 0,0,0,0, 0FCh,0FCh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <15DBh, 1,1,7,7, 0FCh,0FCh,002h,002h, 004h,000h,000h,004h, 0B1h>
	s_sprite <1694h, 0,0,0,0, 0FDh,0FEh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <16FAh, 0,0,0,0, 0FDh,0FCh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <17B8h, 0,2,7,7, 0FDh,0FCh,000h,004h, 003h,004h,0FDh,004h, 0B1h>
	s_sprite <1872h, 0,0,0,0, 0FDh,0FDh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <1908h, 0,0,0,0, 0FCh,0FCh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <19BAh, 1,1,7,7, 0FCh,0FCh,0FEh,002h, 000h,004h,0FCh,000h, 0B1h>
	s_sprite <1A75h, 0,0,0,0, 0FEh,0FDh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <1B03h, 0,0,0,0, 0FCh,0FDh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <1B9Bh, 1,0,7,7, 0FCh,0FDh,0FDh,000h, 0FDh,003h,0FDh,0FDh, 0B1h>
	s_sprite <1C32h, 0,0,0,0, 0FDh,0FDh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <1CC8h, 0,0,0,0, 0FCh,0FCh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <1D7Ah, 1,1,7,7, 0FCh,0FCh,0FEh,0FEh, 0FCh,000h,000h,0FCh, 0B1h>

__C754	db 0Ch dup(0)	;padding
;----------------------------------------enemy[4]
D_C760	dw SEG_2A97
	s_sprite <1E40h, 2,2,0Bh,10h, 0F9h,0F8h,000h,0FAh, 0F9h,0FFh,007h,0FFh, 0B1h>
	s_sprite <1E40h, 2,2,0Bh,10h, 0F9h,0F8h,000h,0FAh, 0F9h,0FFh,007h,0FFh, 0B1h>
	s_sprite <1FBCh, 4,3,0Dh,0Dh, 0F7h,0F7h,006h,0FBh, 0FCh,0FAh,007h,005h, 0B1h>
	s_sprite <1FBCh, 4,3,0Dh,0Dh, 0F7h,0F7h,006h,0FBh, 0FCh,0FAh,007h,005h, 0B1h>
	s_sprite <2142h, 0,2,13h,0Bh, 0F6h,0F9h,007h,000h, 001h,0F9h,001h,007h, 0B1h>
	s_sprite <2142h, 0,2,13h,0Bh, 0F6h,0F9h,007h,000h, 001h,0F9h,001h,007h, 0B1h>
	s_sprite <2275h, 4,4,0Dh,0Dh, 0F7h,0F7h,006h,006h, 007h,0FCh,0FCh,007h, 0B1h>
	s_sprite <2275h, 4,4,0Dh,0Dh, 0F7h,0F7h,006h,006h, 007h,0FCh,0FCh,007h, 0B1h>
	s_sprite <23FAh, 2,0,0Bh,10h, 0F9h,0F8h,000h,007h, 007h,002h,0F9h,002h, 0B1h>
	s_sprite <23FAh, 2,0,0Bh,10h, 0F9h,0F8h,000h,007h, 007h,002h,0F9h,002h, 0B1h>
	s_sprite <2569h, 3,4,0Dh,0Dh, 0F7h,0F7h,0FBh,006h, 005h,007h,0FAh,0FCh, 0B1h>
	s_sprite <2569h, 3,4,0Dh,0Dh, 0F7h,0F7h,0FBh,006h, 005h,007h,0FAh,0FCh, 0B1h>
	s_sprite <26EEh, 2,2,13h,0Bh, 0F6h,0F9h,0F9h,000h, 0FFh,007h,0FFh,0F9h, 0B1h>
	s_sprite <26EEh, 2,2,13h,0Bh, 0F6h,0F9h,0F9h,000h, 0FFh,007h,0FFh,0F9h, 0B1h>
	s_sprite <2821h, 3,3,0Dh,0Dh, 0F7h,0F7h,0FBh,0FBh, 0FAh,005h,005h,0FAh, 0B1h>
	s_sprite <2821h, 3,3,0Dh,0Dh, 0F7h,0F7h,0FBh,0FBh, 0FAh,005h,005h,0FAh, 0B1h>

D_C862	dw SEG_2A97
	s_sprite <299Eh, 0,0,00h,00h, 0FAh,000h,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <2A0Fh, 0,0,00h,00h, 0FAh,0FEh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <2AC1h, 0,0,0Bh,05h, 0FBh,0FEh,0,0, 0FDh,000h,003h,000h, 0B1h>
	s_sprite <2B41h, 0,0,00h,00h, 0FAh,0FDh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <2BFEh, 0,0,00h,00h, 0FAh,0FCh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <2CFCh, 1,1,07h,07h, 0FCh,0FCh,0,0, 0FEh,0FEh,002h,002h, 0B1h>
	s_sprite <2DB7h, 0,0,00h,00h, 0FCh,0FAh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <2E95h, 0,0,00h,00h, 0FCh,0FAh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <2F83h, 0,0,05h,0Bh, 0FEh,0FBh,0,0, 000h,0FDh,000h,003h, 0B1h>
	s_sprite <3051h, 0,0,00h,00h, 0FAh,0FAh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <310Eh, 0,0,00h,00h, 0FAh,0FAh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <320Ch, 1,1,07h,07h, 0FCh,0FCh,0,0, 002h,0FEh,0FEh,002h, 0B1h>
	s_sprite <32C7h, 0,0,00h,00h, 0FAh,0FCh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <3338h, 0,0,00h,00h, 0FAh,0FCh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <33EAh, 0,0,0Bh,05h, 0FBh,0FEh,0,0, 003h,000h,0FDh,000h, 0B1h>
	s_sprite <346Ah, 0,0,00h,00h, 0FDh,0FAh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <3532h, 0,0,00h,00h, 0FCh,0FAh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <362Bh, 1,1,07h,07h, 0FCh,0FCh,0,0, 002h,002h,0FEh,0FEh, 0B1h>
	s_sprite <36E6h, 0,0,00h,00h, 000h,0FAh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <37C4h, 0,0,00h,00h, 0FEh,0FAh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <38B2h, 0,0,05h,0Bh, 0FEh,0FBh,0,0, 000h,003h,000h,0FDh, 0B1h>
	s_sprite <3980h, 0,0,00h,00h, 0FDh,0FDh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <3A48h, 0,0,00h,00h, 0FCh,0FCh,0,0, 000h,000h,000h,000h, 0B1h>
	s_sprite <3B41h, 1,1,07h,07h, 0FCh,0FCh,0,0, 0FEh,002h,002h,0FEh, 0B1h>

__C9E4	db 0Ch dup(0)	;padding
;----------------------------------------enemy[6] "fixed turret"
D_C9F0	dw SEG_3807
	s_sprite <0030h,  3,10,15h,13h, 0F3h,0ECh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0030h,  3,10,15h,13h, 0F3h,0ECh,0,0, 0,0,0,0, 0B1h>
	s_sprite <031Ch,  3, 5,16h,12h, 0F4h,0F1h,0,0, 0,0,0,0, 0B1h>
	s_sprite <031Ch,  3, 5,16h,12h, 0F4h,0F1h,0,0, 0,0,0,0, 0B1h>
	s_sprite <060Bh,  2, 2,16h,13h, 0F5h,0F5h,0,0, 0,0,0,0, 0B1h>
	s_sprite <060Bh,  2, 2,16h,13h, 0F5h,0F5h,0,0, 0,0,0,0, 0B1h>
	s_sprite <08B6h,  3, 3,16h,13h, 0F4h,0F5h,0,0, 0,0,0,0, 0B1h>
	s_sprite <08B6h,  3, 3,16h,13h, 0F4h,0F5h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B8Dh,  3, 2,15h,13h, 0F3h,0F6h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B8Dh,  3, 2,15h,13h, 0F3h,0F6h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0E91h,  5, 3,16h,13h, 0EFh,0F5h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0E91h,  5, 3,16h,13h, 0EFh,0F5h,0,0, 0,0,0,0, 0B1h>
	s_sprite <1181h, 11, 2,16h,13h, 0E8h,0F5h,0,0, 0,0,0,0, 0B1h>
	s_sprite <1181h, 11, 2,16h,13h, 0E8h,0F5h,0,0, 0,0,0,0, 0B1h>
	s_sprite <142Ah,  5, 5,16h,13h, 0EFh,0F1h,0,0, 0,0,0,0, 0B1h>
	s_sprite <142Ah,  5, 5,16h,13h, 0EFh,0F1h,0,0, 0,0,0,0, 0B1h>

D_CAF2	dw SEG_3807
	s_sprite <1721h, 0,2,05h,08h, 0FEh,003h,000h,009h, 000h,009h,000h,009h, 0B1h>
	s_sprite <17D7h, 0,0,05h,0Fh, 0FEh,0FEh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <2355h, 0,0,05h,05h, 0FEh,0FEh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <18FDh, 0,2,06h,06h, 0F7h,002h,0FAh,006h, 0FAh,006h,0FAh,006h, 0B1h>
	s_sprite <1997h, 6,0,07h,07h, 0F7h,0FDh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <2355h, 0,0,05h,05h, 0FEh,0FEh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <1AA2h, 0,0,08h,05h, 0F3h,0FEh,0F6h,000h, 0F6h,000h,0F6h,000h, 0B1h>
	s_sprite <1B0Bh, 0,0,10h,05h, 0F3h,0FEh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <2355h, 0,0,05h,05h, 0FEh,0FEh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <1B8Eh, 0,0,06h,06h, 0F7h,0F7h,0FAh,0FAh, 0FAh,0FAh,0FAh,0FAh, 0B1h>
	s_sprite <1C28h, 7,7,06h,06h, 0F7h,0F7h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <2355h, 0,0,05h,05h, 0FEh,0FEh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <1D33h, 0,0,05h,08h, 0FEh,0F4h,000h,0F7h, 000h,0F7h,000h,0F7h, 0B1h>
	s_sprite <1DE9h, 0,0,05h,0Fh, 0FEh,0F4h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <2355h, 0,0,05h,05h, 0FEh,0FEh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <1F0Fh, 2,0,06h,06h, 002h,0F7h,006h,0FAh, 006h,0FAh,006h,0FAh, 0B1h>
	s_sprite <1FA9h, 0,6,07h,07h, 0FDh,0F7h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <2355h, 0,0,05h,05h, 0FEh,0FEh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <20B4h, 2,0,08h,05h, 004h,0FEh,009h,000h, 009h,000h,009h,000h, 0B1h>
	s_sprite <212Dh, 0,0,10h,05h, 0FEh,0FEh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <2355h, 0,0,05h,05h, 0FEh,0FEh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <21B0h, 2,2,06h,06h, 002h,002h,006h,006h, 006h,006h,006h,006h, 0B1h>
	s_sprite <224Ah, 0,0,06h,06h, 0FDh,0FDh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <2355h, 0,0,05h,05h, 0FEh,0FEh,000h,000h, 000h,000h,000h,000h, 0B1h>

__CC74	db 0Ch dup(0)	;padding
;----------------------------------------enemy[7] "big ship"
D_CC80	dw SEG_2A97
	s_sprite <3C00h, 6,6,25h,2Fh, 0E8h,0E5h,000h,0E5h, 0E8h,0F6h,018h,0F6h, 0B1h>
	s_sprite <3C00h, 6,6,25h,2Fh, 0E8h,0E5h,000h,0E5h, 0E8h,0F6h,018h,0F6h, 0B1h>
	s_sprite <420Ah, 7,3,2Ah,27h, 0E6h,0E9h,016h,0ECh, 0F7h,0EAh,019h,009h, 0B1h>
	s_sprite <420Ah, 7,3,2Ah,27h, 0E6h,0E9h,016h,0ECh, 0F7h,0EAh,019h,009h, 0B1h>
	s_sprite <48A6h, 3,5,38h,21h, 0E0h,0EBh,020h,000h, 00Ch,0EBh,00Ch,015h, 0B1h>
	s_sprite <48A6h, 3,5,38h,21h, 0E0h,0EBh,020h,000h, 00Ch,0EBh,00Ch,015h, 0B1h>
	s_sprite <4E29h, 7,6,2Ah,27h, 0E6h,0E9h,016h,015h, 019h,0F8h,0F7h,017h, 0B1h>
	s_sprite <4E29h, 7,6,2Ah,27h, 0E6h,0E9h,016h,015h, 019h,0F8h,0F7h,017h, 0B1h>
	s_sprite <5490h, 7,3,23h,28h, 0E8h,0E5h,000h,01Ch, 018h,00Bh,0E8h,00Bh, 0B1h>
	s_sprite <5490h, 7,3,23h,28h, 0E8h,0E5h,000h,01Ch, 018h,00Bh,0E8h,00Bh, 0B1h>
	s_sprite <5A6Ch, 4,6,2Ah,27h, 0E6h,0E9h,0EAh,015h, 009h,017h,0E7h,0F8h, 0B1h>
	s_sprite <5A6Ch, 4,6,2Ah,27h, 0E6h,0E9h,0EAh,015h, 009h,017h,0E7h,0F8h, 0B1h>
	s_sprite <60E8h, 6,6,38h,1Fh, 0E0h,0EBh,0E0h,000h, 0F4h,015h,0F4h,0EBh, 0B1h>
	s_sprite <60E8h, 6,6,38h,1Fh, 0E0h,0EBh,0E0h,000h, 0F4h,015h,0F4h,0EBh, 0B1h>
	s_sprite <663Ah, 4,3,2Ah,27h, 0E6h,0E9h,0EAh,0ECh, 0E7h,009h,009h,0EAh, 0B1h>
	s_sprite <663Ah, 4,3,2Ah,27h, 0E6h,0E9h,0EAh,0ECh, 0E7h,009h,009h,0EAh, 0B1h>

;enemy[8] "big ship turret"
D_CD82	dw SEG_4404
	s_sprite <0030h, 0,0,0,0, 0FBh,0F8h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0030h, 0,0,0,0, 0FBh,0F8h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0109h, 0,0,0,0, 0FBh,0F7h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0109h, 0,0,0,0, 0FBh,0F7h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0212h, 0,0,0,0, 0FCh,0FBh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0212h, 0,0,0,0, 0FCh,0FBh,0,0, 0,0,0,0, 0B1h>
	s_sprite <02C4h, 0,0,0,0, 0FBh,0FBh,0,0, 0,0,0,0, 0B1h>
	s_sprite <02C4h, 0,0,0,0, 0FBh,0FBh,0,0, 0,0,0,0, 0B1h>
	s_sprite <03D8h, 0,0,0,0, 0FBh,0FCh,0,0, 0,0,0,0, 0B1h>
	s_sprite <03D8h, 0,0,0,0, 0FBh,0FCh,0,0, 0,0,0,0, 0B1h>
	s_sprite <04AEh, 0,0,0,0, 0F7h,0FBh,0,0, 0,0,0,0, 0B1h>
	s_sprite <04AEh, 0,0,0,0, 0F7h,0FBh,0,0, 0,0,0,0, 0B1h>
	s_sprite <05C3h, 0,0,0,0, 0F7h,0FBh,0,0, 0,0,0,0, 0B1h>
	s_sprite <05C3h, 0,0,0,0, 0F7h,0FBh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0681h, 0,0,0,0, 0F7h,0F7h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0681h, 0,0,0,0, 0F7h,0F7h,0,0, 0,0,0,0, 0B1h>

D_CE84	dw SEG_4404
	s_sprite <0786h, 0,0,0,0, 0FCh,001h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <080Ch, 0,0,0,0, 0FBh,0FEh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <08D2h, 0,0,0,0, 0FCh,0FDh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <099Eh, 0,1,9,4, 0FCh,0FDh,000h,0FEh, 0FCh,0FEh,004h,0FEh, 0B1h>
	s_sprite <0A3Dh, 0,0,0,0, 0F9h,000h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <0ADFh, 0,0,0,0, 0F9h,003h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <0BC2h, 0,0,0,0, 0F9h,0FCh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <0CCCh, 1,2,7,7, 0FBh,0FCh,001h,0FFh, 0FEh,0FCh,004h,002h, 0B1h>
	s_sprite <0DA5h, 0,0,0,0, 0FAh,0FCh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <0E5Bh, 0,0,0,0, 0FAh,0FBh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <0F33h, 0,0,0,0, 0FAh,0FCh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <100Bh, 4,0,4,9, 0FCh,0FCh,002h,000h, 002h,0FCh,002h,004h, 0B1h>
	s_sprite <10BDh, 0,0,0,0, 0F9h,0F9h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <115Fh, 0,0,0,0, 0F9h,0F9h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <1242h, 0,0,0,0, 0F9h,0F9h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <134Ch, 2,2,6,6, 0FBh,0FBh,001h,001h, 004h,0FEh,0FEh,004h, 0B1h>
	s_sprite <1421h, 0,0,0,0, 0FCh,0FAh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <14A7h, 0,0,0,0, 0FBh,0FAh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <156Dh, 0,0,0,0, 0FCh,0FAh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <1639h, 0,4,9,4, 0FCh,0FCh,000h,002h, 004h,002h,0FCh,002h, 0B1h>
	s_sprite <16D8h, 0,0,0,0, 000h,0F9h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <177Ah, 0,0,0,0, 0FDh,0F9h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <1861h, 0,0,0,0, 0FCh,0F9h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <1965h, 2,2,6,6, 0FCh,0FBh,0FFh,001h, 002h,004h,0FCh,0FEh, 0B1h>
	s_sprite <1A33h, 0,0,0,0, 001h,0FCh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <1AE9h, 0,0,0,0, 0FEh,0FBh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <1BEAh, 0,0,0,0, 0FDh,0FCh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <1CC3h, 1,0,4,9, 0FDh,0FCh,0FEh,000h, 0FEh,004h,0FEh,0FCh, 0B1h>
	s_sprite <1D75h, 0,0,0,0, 000h,000h,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <1E17h, 0,0,0,0, 0FDh,0FDh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <1EFEh, 0,0,0,0, 0FCh,0FCh,000h,000h, 000h,000h,000h,000h, 0B1h>
	s_sprite <2002h, 2,2,6,6, 0FCh,0FCh,0FFh,0FFh, 0FCh,002h,002h,0FCh, 0B1h>

__D086	db 0Ah dup(0)	;padding
;----------------------------------------enemy[5] "mine"
D_D090	dw SEG_4404
	s_sprite <20D0h, 2,2,0Bh,0Bh, 0F9h,0F9h,0F9h,000h, 000h,0F9h,007h,000h, 0B1h>
	s_sprite <217Bh, 1,1,0Bh,0Bh, 0FAh,0FAh,003h,0FAh, 006h,003h,0FDh,006h, 0B1h>
	s_sprite <2237h, 0,0,0Bh,0Bh, 0FBh,0FBh,000h,005h, 0FBh,000h,000h,0FBh, 0B1h>
	s_sprite <22FBh, 1,1,0Bh,0Bh, 0FAh,0FAh,0FAh,003h, 0FDh,0FAh,006h,0FDh, 0B1h>
	s_sprite <23CCh, 2,2,0Bh,0Bh, 0F9h,0F9h,0F9h,000h, 000h,0F9h,007h,000h, 0B1h>
	s_sprite <24BAh, 1,1,0Bh,0Bh, 0FAh,0FAh,003h,0FAh, 006h,003h,0FDh,006h, 0B1h>
	s_sprite <25A1h, 0,0,0Bh,0Bh, 0FBh,0FBh,000h,005h, 0FBh,000h,000h,0FBh, 0B1h>
	s_sprite <2678h, 1,1,0Bh,0Bh, 0FAh,0FAh,0FAh,003h, 0FDh,0FAh,006h,0FDh, 0B1h>

__D112	db 0Eh dup(0)	;padding
;----------------------------------------
D_D120	dw SEG_2A97
	s_sprite <6CC0h, 0,0,0,0, 0F8h,0F8h,0,0, 0,0,0,0, 0B1h>
	s_sprite <6E58h, 0,0,0,0, 0F3h,0F4h,0,0, 0,0,0,0, 0B1h>
	s_sprite <710Dh, 0,0,0,0, 0F0h,0F1h,0,0, 0,0,0,0, 0B1h>
	s_sprite <74C5h, 0,0,0,0, 0ECh,0EEh,0,0, 0,0,0,0, 0B1h>
	s_sprite <79BEh, 0,0,0,0, 0EAh,0ECh,0,0, 0,0,0,0, 0B1h>
	s_sprite <7FCBh, 0,0,0,0, 0E9h,0EBh,0,0, 0,0,0,0, 0B1h>
	s_sprite <85F0h, 0,0,0,0, 0EAh,0ECh,0,0, 0,0,0,0, 0B1h>
	s_sprite <8AC7h, 0,0,0,0, 0EBh,0EDh,0,0, 0,0,0,0, 0B1h>
	s_sprite <8EBAh, 0,0,0,0, 0F5h,0F7h,0,0, 0,0,0,0, 0B1h>
	s_sprite <904Eh, 0,0,0,0, 0F5h,0F7h,0,0, 0,0,0,0, 0B1h>

D_D1C2	dw SEG_2A97
	s_sprite < 915Fh, 0,0,0,0, 0F6h,0F6h,0,0, 0,0,0,0, 0B1h>
	s_sprite < 938Ch, 0,0,0,0, 0F2h,0F2h,0,0, 0,0,0,0, 0B1h>
	s_sprite < 96EAh, 0,0,0,0, 0EDh,0EDh,0,0, 0,0,0,0, 0B1h>
	s_sprite < 9BF5h, 0,0,0,0, 0E9h,0E9h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0A2E2h, 0,0,0,0, 0E9h,0E9h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0A998h, 0,0,0,0, 0E9h,0E9h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B032h, 0,0,0,0, 0E9h,0E9h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B514h, 0,0,0,0, 0F6h,0F6h,0,0, 0,0,0,0, 0B1h>

D_D244	dw SEG_2A97							   
	s_sprite <0B6EAh, 0,0,0,0, 0FBh,0FBh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B7C8h, 0,0,0,0, 0F9h,0F9h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B913h, 0,0,0,0, 0F5h,0F5h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0BB6Bh, 0,0,0,0, 0F1h,0F1h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0BEE1h, 0,0,0,0, 0F1h,0F1h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0C23Ah, 0,0,0,0, 0F1h,0F1h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0C52Bh, 0,0,0,0, 0F8h,0F8h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0C6B4h, 0,0,0,0, 0FCh,0FCh,0,0, 0,0,0,0, 0B1h>

D_D2C6	dw SEG_2A97
	s_sprite <0C757h, 0,0,0,0, 0FEh,0FEh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0C7B5h, 0,0,0,0, 0FDh,0FDh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0C83Bh, 0,0,0,0, 0FBh,0FBh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0C92Bh, 0,0,0,0, 0F8h,0F8h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0CAA7h, 0,0,0,0, 0F6h,0F6h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0CCBEh, 0,0,0,0, 0F5h,0F5h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0CEBCh, 0,0,0,0, 0F4h,0F4h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0D06Dh, 0,0,0,0, 0F8h,0F8h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0D1F6h, 0,0,0,0, 0FCh,0FCh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0D299h, 0,0,0,0, 0FBh,0FBh,0,0, 0,0,0,0, 0B1h>

D_D368	dw SEG_2A97
	s_sprite <0D35Bh, 0,0,0,0, 0FDh,0FDh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0D3DDh, 0,0,0,0, 0FBh,0FBh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0D4B5h, 0,0,0,0, 0FBh,0FBh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0D583h, 0,0,0,0, 0FBh,0FBh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0D641h, 0,0,0,0, 0FBh,0FBh,0,0, 0,0,0,0, 0B1h>

__D3BA	db 6 dup(0)	;padding
;----------------------------------------for radar display
D_D3C0	dw SEG_1BDA
	s_sprite <0E350h, 0,0,0,0, 0FBh,0FBh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0E438h, 0,0,0,0, 0FAh,0FAh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0E536h, 0,0,0,0, 0FAh,0FBh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0E612h, 0,0,0,0, 0FAh,0FAh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0E710h, 0,0,0,0, 0FBh,0FBh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0E7F8h, 0,0,0,0, 0FAh,0FAh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0E8EBh, 0,0,0,0, 0FAh,0FBh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0E9D4h, 0,0,0,0, 0FAh,0FAh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0EAC7h, 0,0,0,0, 0FDh,0FDh,0,0, 0,0,0,0, 0B1h>
	s_sprite <0EB3Dh, 0,0,0,0, 0FDh,0FDh,0,0, 0,0,0,0, 0B1h>

__D462	db 0Eh dup(0)	;padding
;----------------------------------------inside raider
D_D470	dw SEG_3807
	s_sprite < 23C0h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite < 2DB0h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite < 38D6h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite < 442Eh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite < 4F62h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite < 5A92h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>

	s_sprite < 6592h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite < 70BEh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite < 7BF2h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite < 874Ah, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite < 9270h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>

	s_sprite < 9C60h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <0A0C5h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <0A52Ah, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <0A5BCh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <0A656h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <0A700h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <0A7CEh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <0A8A0h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <0A8F9h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <0A952h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <0A994h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <0A9FAh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <0AA60h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <0AAA2h, 0,0,0,0, 1,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <0AB08h, 0,0,0,0, 1,0,0,0, 0,0,0,0, 0B1h>

__D612	db 0Eh dup(0)	;padding
;----------------------------------------raider level animation
D_D620	dw SEG_3807
	s_sprite <0AB70h, 0,0,0,0, 0E1h,0F9h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0ACE1h, 0,0,0,0, 0DFh,0F9h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0AE75h, 0,0,0,0, 0E5h,0F9h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0AFCBh, 0,0,0,0, 0DFh,0F9h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B176h, 0,0,0,0, 0DFh,0F9h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B305h, 0,0,0,0, 0E5h,0F9h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B455h, 0,0,0,0, 0DFh,0F9h,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B5FEh, 0,0,0,0, 0E1h,0F9h,0,0, 0,0,0,0, 0B1h>

__D6A2	db 0Eh dup(0)	;padding
;----------------------------------------
;-- font 8x9 --
D_D6B0	db 081h,000h,000h,000h,000h,000h,000h,000h,081h,000h,03Ch,046h,04Ah,052h,062h,042h,03Ch,000h	;[00]'0'
	db 0C7h,087h,087h,087h,0C7h,0C7h,001h,001h,001h,000h,010h,030h,010h,010h,010h,010h,07Ch,000h	;[01]'1'
	db 081h,000h,000h,000h,080h,001h,000h,000h,000h,000h,03Ch,042h,002h,00Ch,030h,040h,07Eh,000h	;[02]'2'
	db 081h,000h,000h,000h,0C0h,000h,000h,000h,081h,000h,03Ch,042h,002h,01Ch,002h,042h,03Ch,000h	;[03]'3'
	db 0E1h,0C1h,081h,001h,000h,000h,000h,0F1h,0F1h,000h,00Ch,014h,024h,044h,07Eh,004h,004h,000h	;[04]'4'
	db 0C0h,080h,000h,000h,000h,018h,000h,000h,081h,000h,01Eh,020h,07Ch,002h,002h,042h,03Ch,000h	;[05]'5'
	db 0C7h,087h,081h,000h,000h,018h,000h,000h,081h,000h,010h,020h,03Ch,042h,042h,042h,03Ch,000h	;[06]'6'
	db 080h,000h,000h,000h,080h,080h,007h,00Fh,01Fh,000h,03Eh,042h,004h,03Eh,010h,020h,040h,000h	;[07]'7'
	db 081h,000h,000h,000h,000h,000h,000h,000h,081h,000h,03Ch,042h,042h,03Ch,042h,042h,03Ch,000h	;[08]'8'
	db 081h,000h,000h,000h,000h,000h,000h,000h,081h,000h,03Ch,042h,042h,03Eh,002h,042h,03Ch,000h	;[09]'9'
	db 0FFh,0FFh,0FFh,0FFh,0FFh,01Fh,01Fh,01Fh,0FFh,000h,000h,000h,000h,000h,000h,040h,000h,000h	;[0a]'.'
	db 0FFh,0FFh,0FFh,0FFh,0FFh,08Fh,00Fh,00Fh,01Fh,000h,000h,000h,000h,000h,000h,020h,040h,000h	;[0b]','
	db 08Fh,08Fh,08Fh,08Fh,08Fh,08Fh,08Fh,08Fh,08Fh,000h,020h,020h,020h,020h,020h,000h,020h,000h	;[0c]
	db 0C7h,087h,007h,00Fh,01Fh,00Fh,007h,087h,0C7h,000h,010h,020h,040h,040h,040h,020h,010h,000h	;[0d]
	db 0C7h,0C3h,0C1h,0E1h,0F1h,0E1h,0C1h,0C3h,0C7h,000h,010h,008h,004h,004h,004h,008h,010h,000h	;[0e]')'
	db 0FFh,0FFh,0E3h,0E3h,0E3h,0E3h,0C3h,0C3h,0C7h,000h,000h,000h,008h,000h,000h,008h,010h,000h	;[0f]';'
	db 0FFh,0FFh,0E3h,0E3h,0E3h,0E3h,0E3h,0E3h,0FFh,000h,000h,000h,008h,000h,000h,008h,000h,000h	;[10]
	db 0C1h,081h,081h,083h,0FFh,0FFh,0FFh,0FFh,0FFh,000h,014h,028h,000h,000h,000h,000h,000h,000h	;[11]'"'
	db 0F8h,0F0h,0E0h,0C0h,080h,000h,000h,018h,018h,000h,002h,006h,00Ah,012h,02Eh,042h,042h,000h	;[12]'A'
	db 007h,003h,003h,001h,000h,000h,000h,000h,001h,000h,070h,048h,070h,04Ch,042h,042h,07Ch,000h	;[13]'B'
	db 081h,000h,000h,018h,01Fh,018h,000h,000h,081h,000h,03Ch,042h,040h,040h,040h,042h,03Ch,000h	;[14]'C'
	db 001h,000h,000h,018h,018h,018h,000h,000h,001h,000h,07Ch,042h,042h,042h,042h,042h,07Ch,000h	;[15]'D'
	db 003h,003h,003h,007h,007h,007h,000h,000h,000h,000h,078h,040h,040h,070h,040h,040h,07Eh,000h	;[16]'E'
	db 000h,000h,000h,003h,003h,003h,01Fh,01Fh,01Fh,000h,07Eh,040h,040h,078h,040h,040h,040h,000h	;[17]'F'
	db 081h,000h,000h,018h,010h,010h,000h,000h,080h,000h,03Ch,042h,040h,040h,046h,042h,03Eh,000h	;[18]'G'
	db 018h,018h,018h,000h,000h,000h,018h,018h,018h,000h,042h,042h,042h,07Eh,042h,042h,042h,000h	;[19]'H'
	db 080h,080h,080h,0E3h,0E3h,0E3h,080h,080h,080h,000h,03Eh,008h,008h,008h,008h,008h,03Eh,000h	;[1a]'I'
	db 000h,000h,000h,0F8h,0F8h,018h,000h,000h,081h,000h,07Eh,002h,002h,002h,002h,042h,03Ch,000h	;[1b]'J'
	db 003h,003h,003h,007h,003h,001h,000h,010h,018h,000h,048h,050h,060h,050h,048h,044h,042h,000h	;[1c]'K'
	db 01Fh,01Fh,01Fh,01Fh,01Fh,01Fh,000h,000h,000h,000h,040h,040h,040h,040h,040h,040h,07Eh,000h	;[1d]'L'
	db 018h,000h,000h,000h,000h,018h,018h,018h,018h,000h,042h,066h,05Ah,042h,042h,042h,042h,000h	;[1e]'M'
	db 018h,008h,000h,000h,000h,000h,010h,018h,018h,000h,042h,062h,052h,04Ah,046h,042h,042h,000h	;[1f]'N'
	db 081h,000h,000h,018h,018h,018h,000h,000h,081h,000h,03Ch,042h,042h,042h,042h,042h,03Ch,000h	;[20]'O'
	db 001h,000h,000h,000h,000h,001h,01Fh,01Fh,01Fh,000h,07Ch,042h,042h,07Ch,040h,040h,040h,000h	;[21]'P'
	db 081h,000h,000h,018h,000h,000h,000h,000h,080h,000h,03Ch,042h,042h,042h,04Ah,044h,03Ah,000h	;[22]'Q'
	db 001h,000h,000h,000h,000h,001h,000h,010h,018h,000h,07Ch,042h,042h,07Ch,048h,044h,042h,000h	;[23]'R'
	db 081h,000h,000h,000h,000h,000h,000h,000h,081h,000h,03Ch,042h,040h,03Ch,002h,042h,03Ch,000h	;[24]'S'
	db 080h,080h,080h,0E3h,0E3h,0E3h,0E3h,0E3h,0E3h,000h,03Eh,008h,008h,008h,008h,008h,008h,000h	;[25]'T'
	db 018h,018h,018h,018h,018h,018h,000h,000h,081h,000h,042h,042h,042h,042h,042h,042h,03Ch,000h	;[26]'U'
	db 018h,018h,010h,000h,001h,003h,007h,00Fh,01Fh,000h,042h,042h,044h,048h,050h,060h,040h,000h	;[27]'V'
	db 003h,000h,000h,000h,000h,000h,000h,001h,003h,000h,048h,04Ah,04Ch,048h,05Ah,06Ch,048h,000h	;[28]'W'
	db 018h,000h,000h,081h,081h,000h,000h,018h,018h,000h,042h,024h,018h,018h,024h,042h,042h,000h	;[29]'X'
	db 018h,018h,018h,000h,000h,000h,000h,000h,081h,000h,042h,042h,042h,03Eh,002h,042h,03Ch,000h	;[2a]'Y'
	db 000h,000h,000h,0C1h,083h,007h,000h,000h,000h,000h,07Eh,004h,008h,010h,020h,040h,07Eh,000h	;[2b]'Z'
	db 0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,000h,000h,000h,000h,000h,000h,000h,000h,000h	;[2c]' '
	db 0FFh,018h,018h,000h,081h,081h,000h,018h,018h,000h,000h,042h,024h,018h,018h,024h,042h,000h	;[2d]'x' cross/multiplication
	db 0FFh,0FFh,0FFh,080h,080h,080h,0FFh,0FFh,0FFh,000h,000h,000h,000h,03Eh,000h,000h,000h,000h	;[2e]'-'
	db 0FFh,0FFh,080h,080h,080h,080h,080h,080h,0FFh,000h,000h,000h,03Eh,000h,000h,03Eh,000h,000h	;[2f]'='
	db 081h,081h,081h,08Fh,08Fh,08Fh,081h,081h,081h,000h,03Ch,020h,020h,020h,020h,020h,03Ch,000h	;[30]'['
	db 081h,081h,081h,0F1h,0F1h,0F1h,081h,081h,081h,000h,03Ch,004h,004h,004h,004h,004h,03Ch,000h	;[31]']'
	db 0FFh,0F8h,0F0h,0E0h,0C1h,083h,007h,00Fh,01Fh,000h,000h,002h,004h,008h,010h,020h,040h,000h	;[32]'/'
	db 0FFh,01Fh,00Fh,007h,083h,0C1h,0E0h,0F0h,0F8h,000h,000h,040h,020h,010h,008h,004h,002h,000h	;[33]'\' backslash
	db 0FFh,018h,000h,000h,000h,000h,000h,018h,0FFh,000h,000h,042h,018h,07Eh,018h,042h,000h,000h	;[34]'*'
	db 0E3h,0C1h,080h,080h,080h,0E3h,0E3h,0E3h,0FFh,000h,008h,01Ch,02Ah,008h,008h,008h,000h,000h	;[35]<ARROW UP>
	db 0FFh,0E3h,0E1h,000h,000h,000h,0E1h,0E3h,0FFh,000h,000h,008h,004h,07Eh,004h,008h,000h,000h	;[36]<ARROW RIGHT>
	db 0E3h,0E3h,0E3h,080h,080h,080h,0C1h,0E3h,0FFh,000h,008h,008h,008h,02Ah,01Ch,008h,000h,000h	;[37]<ARROW DOWN>
	db 0FFh,0C7h,087h,000h,000h,000h,087h,0C7h,0FFh,000h,000h,010h,020h,07Eh,020h,010h,000h,000h	;[38]<ARROW LEFT>
	db 0FFh,0E3h,0E3h,080h,080h,080h,0E3h,0E3h,0FFh,000h,000h,008h,008h,03Eh,008h,008h,000h,000h	;[39]'+'
	db 0C1h,080h,080h,080h,0E0h,0E1h,0E3h,0E3h,0E3h,000h,01Ch,022h,002h,004h,008h,000h,008h,000h	;[3a]'?'

__DAD6	db 0Ah dup(0)	;padding
;----------------------------------------
;-- strings --SEG_3807
D_DAE0	s_sprite <0B790h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>	;"HIGH SCORE"
D_DAF0	s_sprite <0BB59h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>	;"BONUS"
D_DB00	s_sprite <0BDBFh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>	;"DOCK"
;----------------------------------------
;-- gauge 1 --SEG_467A
D_DB10	s_sprite <0030h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <0135h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <026Eh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <03ABh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <04E8h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <0625h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <0762h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <089Fh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <09DCh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <0B26h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <0C71h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <0DBCh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <0F07h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <1052h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <119Dh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <12E8h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <1433h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <158Bh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <16E4h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <183Dh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <1996h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <1AEFh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <1C48h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <1DA1h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <1EFAh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <2060h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <21C7h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <232Eh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <2495h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <25FCh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <2763h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <28CAh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <2A31h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <2BA5h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <2D1Ah, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <2E8Fh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <3004h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <3179h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <32EEh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <3463h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <35D8h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <375Ah, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <38DDh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <3A60h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <3BE3h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <3D66h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <3EE9h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <3EE9h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
;-- gauge 2 --SEG_467A
D_DE10	s_sprite <4070h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <4175h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <4296h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <43B7h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <44D8h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <45F9h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <471Ah, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <483Bh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <495Ch, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <4A84h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <4BACh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <4CD4h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <4DFCh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <4F24h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <504Ch, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <5174h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <529Ch, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <53CBh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <54FAh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <5629h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <5758h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <5887h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <59B6h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <5AE5h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <5C14h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <5D4Ah, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <5E80h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <5FB6h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <60ECh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <6222h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <6358h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <648Eh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <65C4h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <6701h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <683Eh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <697Bh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <6AB8h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <6BF5h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <6D32h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <6E6Fh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <6FACh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <70F0h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <7234h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <7378h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <74BCh, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <7600h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <7744h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
	s_sprite <7744h, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0B1h>
;----------------------------------------
_DATA	ENDS
;########################################

;########################################1BBA
_STACK	SEGMENT	STACK
;----------------------------------------
	db 200h dup(?)
;----------------------------------------
_STACK	ENDS
;########################################

END	Start
