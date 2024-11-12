*-----------------------------------------------------------
* Title      : Duel At Dusk
* Written by : Aditya Sinha
* Date       : 10/02/2024
* Description: Projectile turn based 2P game. Use the right power and angle to shoot down your opponent 
*-----------------------------------------------------------
    ORG    $1000
    
    INCLUDE "file_shell.x68"
    INCLUDE "memory_shell.x68"
    INCLUDE "bitmap.x68"

ALL_REG         REG     D0-D7/A0-A6

*Memory and Image Properties    
HEAP_BYTES              EQU $850000

IMG_MAX_BYTES           EQU $200000

CHAR_MAX_BYTES          EQU $C800

WIN_BANNER_MAX_BYTES    EQU $4B000

SENTINEL                EQU $deaddead

NUM_PROPERTIES          EQU 5

*Trap Commands
TASK_PRINT              EQU     13
SET_PEN_COLOR_COMMAND   EQU     80
SET_FILL_COLOR_COMMAND  EQU     81
SET_PEN_WIDTH_COMMAND   EQU     93
DRAW_LINE_COMMAND       EQU     84
DRAW_CIRCLE_COMMAND     EQU     88
GET_TIME_COMMAND        EQU     8
GET_USER_INPUT_COMMAND  EQU     19
DELAY_FRAME	             EQU 	  23
FRAME_DELAY_TIME        EQU     1
GAME_OVER_FRAME_DELAY   EQU     300
LOAD_AUDIO_COMMAND      EQU     74
PLAY_AUDIO_COMMAND      EQU     75
CONTROL_AUDIO_COMMAND   EQU     77

*Color
GREEN   EQU $0000FF00
RED  EQU $000000FF

*Key Input Commands
KEY_A           EQU $41
KEY_D           EQU $44
KEY_SPACE       EQU $20
KEY_R           EQU $52

KEY_ARROW_LEFT  EQU $25
KEY_ARROW_RIGHT EQU $27
KEY_ARROW_CTRL  EQU $11

*Fractional Bits - Using 8.8 Convention
FRAC_BITS   EQU 8

*Initial Setup
PROJECTILE_INITIAL_ANGLE    EQU 45<<FRAC_BITS  
PROJECTILE_ANGLE_INCREMENT  EQU 400 
PROJECTILE_MIN_ANGLE        EQU 30<<FRAC_BITS
PROJECTILE_MAX_ANGLE        EQU 90<<FRAC_BITS
PROJECTILE_LINE_SIZE        EQU 60<<FRAC_BITS         
GRAVITY                     EQU 40     

*Stone properties        
STONE_SIZE                  EQU 15<<FRAC_BITS
STONE_VELOCITY              EQU 12<<FRAC_BITS
STONE_OUTLINE_COLOR         EQU $00000000
STONE_FILLED_COLOR          EQU $0000a0e6

*Power Meter
POWER_METER_MIN             EQU 0   
POWER_METER_MAX             EQU 1<<FRAC_BITS
POWER_METER_INCREMENT       EQU 12
POWER_METER_TOP             EQU 100
POWER_METER_BOTTOM          EQU 250
POWER_METER_LEFT            EQU 20
POWER_METER_RIGHT           EQU 40
POWER_METER_LEFT_P2         EQU 600
POWER_METER_RIGHT_P2        EQU 620
POWER_METER_THICKNESS       EQU 2
POWER_METER_COLOR           EQU $00FFFF00
POWER_METER_UNFILLED_COLOR  EQU $00FFFFFF
POWER_METER_FILLED_COLOR    EQU $000000FF

*7 segment display for health
SEG_LINE_LENGTH             EQU 20
SEG_THICKNESS               EQU 3
SEG_COLOR                   EQU $000000FF
SEG_TOP                     EQU 20
SEG_P1_LEFT                 EQU 20
SEG_P2_LEFT                 EQU 600 

*7 segment display for wind speed
WS_LINE_LENGTH              EQU 6
WS_THICKNESS                EQU 2
WS_COLOR                    EQU $00000000
WS_TOP                      EQU 10
WS_LEFT                     EQU 325

*Wind properties
WIND_HORIZONTAL_STRENGTH    EQU 450
WIND_VERTICAL_STRENGTH      EQU 30
    
*Character hitbox properties
CHAR_HEADSHOT_Y           EQU 350
CHAR_BODYSHOT_Y           EQU 400
CHAR_LEGSHOT_Y            EQU 425

*Stone damage properties
HEADSHOT_DAMAGE           EQU 3
BODYSHOT_DAMAGE           EQU 2
LEGSHOT_DAMAGE            EQU 1
    
START:               
    
; Load background and player images and draw them to the screen
SetupGame:
   
.initializeHeap:
    lea StartOfMem, a1
    move.l #HEAP_BYTES, d1
    bsr mem_InitHeap
    tst.b d0
    bne error
    
**BITMAP**
.load_Bgm_Img:
    move.l #IMG_MAX_BYTES, d1
    lea BackgroundImg, a1
    bsr bmp_Load
    tst.b d0
    bne error
    
    move.l a1, a5   ; Caching the allocation address in a5
    
.set_BGM_Img_Bounds
    move.l #0, -(sp)
    move.l #0, -(sp)
    move.l #480, -(sp)
    move.l #640, -(sp)
    move.l #0, -(sp)
    move.l #0, -(sp)
    
.update_Image: 
    move.l a5, a1 
    lea Updated_BGM_Img, a4  
    bsr bmp_Update_Format
    tst.b d0
    beq error
    
.draw_BGM_Image:
    bsr bmp_Draw
    add.l #24, sp
    
.bgm_Projectile_Preview
    lea Updated_BGM_Img, a1
    lea Left_Bgm_Redraw_Rect, a4
    move.l #54, d3
    move.l #268, d2
    move.l #86, d4
    move.l #86, d5
    bsr bmp_BGM_Cutout
    
    lea Right_Bgm_Redraw_Rect, a4
    move.l #505, d3
    move.l #266, d2
    move.l #86, d4
    move.l #86, d5
    bsr bmp_BGM_Cutout
    
.bgm_Power_Meter:
    lea Updated_BGM_Img, a1
    lea Pow_Meter_Left_Redraw, a4
    move.l #(POWER_METER_LEFT-5), d3
    move.l #(POWER_METER_TOP-5), d2
    move.l #26, d4
    move.l #170, d5
    bsr bmp_BGM_Cutout
    
    lea Updated_BGM_Img, a1
    lea Pow_Meter_Right_Redraw, a4
    move.l #(POWER_METER_LEFT_P2-5), d3
    move.l #(POWER_METER_TOP-5), d2
    move.l #26, d4
    move.l #170, d5
    bsr bmp_BGM_Cutout
    
.bgm_P1_Health:
    lea Updated_BGM_Img, a1
    lea P1_Health_Redraw_Rect, a4
    move.l #(SEG_P1_LEFT-5), d3
    move.l #(SEG_TOP-5), d2
    move.l #31, d4
    move.l #56, d5
    bsr bmp_BGM_Cutout
    
.bgm_P2_Health:
    lea Updated_BGM_Img, a1
    lea P2_Health_Redraw_Rect, a4
    move.l #(SEG_P2_LEFT-5), d3
    move.l #(SEG_TOP-5), d2
    move.l #31, d4
    move.l #56, d5
    bsr bmp_BGM_Cutout
    
.bgm_Horizontal_Wind:
    lea Updated_BGM_Img, a1
    lea Horizontal_Wind_Redraw, a4
    move.l #(255), d3
    move.l #(WS_TOP-5), d2
    move.l #61, d4
    move.l #25, d5
    bsr bmp_BGM_Cutout
    
.bgm_Vertical_Wind:
    lea Updated_BGM_Img, a1
    lea Vertical_Wind_Redraw, a4
    move.l #(295), d3
    move.l #(WS_TOP-5), d2
    move.l #25, d4
    move.l #62, d5
    bsr bmp_BGM_Cutout
    
.bgm_Wind_Properties:
    lea Updated_BGM_Img, a1
    lea Wind_Prop_Redraw, a4
    move.l #(WS_LEFT-5), d3
    move.l #(WS_TOP-5), d2
    move.l #81, d4
    move.l #25, d5
    bsr bmp_BGM_Cutout
    
.bgm_Player_Win:
    lea Updated_BGM_Img, a1
    lea Player_Win_Redraw, a4
    move.l #170, d3
    move.l #90, d2
    move.l #311, d4
    move.l #211, d5
    bsr bmp_BGM_Cutout
    
.bgm_Start_Screen:
    lea Updated_BGM_Img, a1
    lea Start_Screen_Redraw, a4
    move.l #115, d3
    move.l #145, d2
    move.l #445, d4
    move.l #125, d5
    bsr bmp_BGM_Cutout
    
.bgm_P1:
    lea Updated_BGM_Img, a1
    lea P1_Redraw, a4
    move.l #15, d3
    move.l #345, d2
    move.l #70, d4
    move.l #110, d5
    bsr bmp_BGM_Cutout

.bgm_P2:
    lea Updated_BGM_Img, a1
    lea P2_Redraw, a4
    move.l #575, d3
    move.l #345, d2
    move.l #70, d4
    move.l #110, d5
    bsr bmp_BGM_Cutout    
    
*Load Start Screen
.set_SS_Bounds
    move.l #150, -(sp)
    move.l #120, -(sp)
    move.l #100, -(sp)
    move.l #425, -(sp)
    move.l #0, -(sp)
    move.l #0, -(sp)
    
.update_SS: 
    lea StartScreen, a1 
    lea Start_Screen_Img, a4  
    bsr bmp_Upd_Alpha
    tst.b d0
    beq error
    
    add.l #24, sp
    
.load_Player1_Img:
    move.l #CHAR_MAX_BYTES, d1
    lea Player1Img, a1
    bsr bmp_Load
    tst.b d0
    bne error
    
    move.l a1, a5
    
; Rect coordinates - Top Left: (20,350) Width: 60 Height: 100
.set_Player1_Img_Bounds
    move.l #350, -(sp)
    move.l #20, -(sp)
    move.l #99, -(sp)
    move.l #60, -(sp)
    move.l #0, -(sp)
    move.l #0, -(sp)
    
    ; Init projectile preview
    lea Player1_Fire_XCoordinate, a0
    move.l #(20+40)<<FRAC_BITS, (a0)
    lea Player1_Fire_YCoordinate, a0
    move.l #(340)<<FRAC_BITS, (a0)
    
    ; Init stone
    lea P1_Stone_XCoordinate, a0
    move.l #(20+40)<<FRAC_BITS, (a0)
    lea Stone_YCoordinate, a0
    move.l #(350)<<FRAC_BITS, (a0)
    
.update_Player1_Image: 
    move.l a5, a1 
    lea Updated_Player1_Img, a4  
    bsr bmp_Upd_Alpha
    tst.b d0
    beq error
    lea Player_1_Img_Prop, a1
    move.l a4, (a1)+ 
    move.l d4, (a1)+
    move.l d5, (a1)+
    move.l d3, (a1)+
    move.l d2, (a1)
    
.draw_Player1_Image:
    ;bsr bmp_Draw
    sub.l #10, 4(a1)
    sub.l #5, 8(a1)
    add.l #10, 12(a1)
    add.l #5, 16(a1)
    add.l #24, sp 
.load_Player2_Img:
    move.l #CHAR_MAX_BYTES, d1
    lea Player2Img, a1
    bsr bmp_Load
    tst.b d0
    bne error
    
    move.l a1, a5
    
; Rect coordinates - Top Left: (350,580) Width: 60 Height: 100    
.set_Player2_Img_Bounds
    move.l #350, -(sp)
    move.l #570, -(sp)
    move.l #99, -(sp)
    move.l #60, -(sp)
    move.l #0, -(sp)
    move.l #0, -(sp)
    
    ; Init projectile preview
    lea Player2_Fire_XCoordinate, a0
    move.l #(570)<<FRAC_BITS, (a0)
    lea Player2_Fire_YCoordinate, a0
    move.l #(340)<<FRAC_BITS, (a0)
    
    ; Init stone
    lea P2_Stone_XCoordinate, a0
    move.l #(570<<FRAC_BITS-STONE_SIZE), (a0)
    lea Stone_YCoordinate, a0
    move.l #(350)<<FRAC_BITS, (a0)
    
.update_Player2_Image: 
    move.l a5, a1 
    lea Updated_Player2_Img, a4  
    bsr bmp_Upd_Alpha
    tst.b d0
    beq error
    lea Player_2_Img_Prop, a1
    move.l a4, (a1)+
    move.l d4, (a1)+
    move.l d5, (a1)+
    move.l d3, (a1)+
    move.l d2, (a1)
    
.draw_Player2_Image:
    ;bsr bmp_Draw
    sub.l #10, 4(a1)
    sub.l #5, 8(a1)
    add.l #10, 12(a1)
    add.l #5, 16(a1)
    add.l #24, sp    
      
.upd_P1_Throw2_Img:
    move.l #350, -(sp)
    move.l #20, -(sp)
    move.l #99, -(sp)
    move.l #60, -(sp)
    move.l #0, -(sp)
    move.l #0, -(sp)
    
    lea P1Throw2, a1 
    lea P1_Throw2Img, a4  
    bsr bmp_Upd_Alpha
    add.l #24, sp
    
.upd_P1_Throw3_Img:
    move.l #350, -(sp)
    move.l #20, -(sp)
    move.l #99, -(sp)
    move.l #60, -(sp)
    move.l #0, -(sp)
    move.l #0, -(sp)
    
    lea P1Throw3, a1 
    lea P1_Throw3Img, a4  
    bsr bmp_Upd_Alpha
    add.l #24, sp
    
.upd_P2_Throw2_Img:
    move.l #350, -(sp)
    move.l #580, -(sp)
    move.l #99, -(sp)
    move.l #60, -(sp)
    move.l #0, -(sp)
    move.l #0, -(sp)
    
    lea P2Throw2, a1 
    lea P2_Throw2Img, a4  
    bsr bmp_Upd_Alpha
    add.l #24, sp
    
.upd_P2_Throw3_Img:
    move.l #350, -(sp)
    move.l #580, -(sp)
    move.l #99, -(sp)
    move.l #60, -(sp)
    move.l #0, -(sp)
    move.l #0, -(sp)
    
    lea P2Throw3, a1 
    lea P2_Throw3Img, a4  
    bsr bmp_Upd_Alpha
    add.l #24, sp
    
.upd_P1_Hurt1:
    move.l #350, -(sp)
    move.l #20, -(sp)
    move.l #99, -(sp)
    move.l #60, -(sp)
    move.l #0, -(sp)
    move.l #0, -(sp)
    
    lea P1Hurt1, a1 
    lea P1_Hurt1, a4  
    bsr bmp_Upd_Alpha
    add.l #24, sp
    
.upd_P1_Hurt2:
    move.l #350, -(sp)
    move.l #20, -(sp)
    move.l #99, -(sp)
    move.l #60, -(sp)
    move.l #0, -(sp)
    move.l #0, -(sp)
    
    lea P1Hurt2, a1 
    lea P1_Hurt2, a4  
    bsr bmp_Upd_Alpha
    add.l #24, sp
    
.upd_P2_Hurt1:
    move.l #350, -(sp)
    move.l #580, -(sp)
    move.l #99, -(sp)
    move.l #60, -(sp)
    move.l #0, -(sp)
    move.l #0, -(sp)
    
    lea P2Hurt1, a1 
    lea P2_Hurt1, a4  
    bsr bmp_Upd_Alpha
    add.l #24, sp
    
.upd_P2_Hurt2:
    move.l #350, -(sp)
    move.l #580, -(sp)
    move.l #99, -(sp)
    move.l #60, -(sp)
    move.l #0, -(sp)
    move.l #0, -(sp)
    
    lea P2Hurt2, a1 
    lea P2_Hurt2, a4  
    bsr bmp_Upd_Alpha
    add.l #24, sp
    
.init_Projectile:
    lea PROJECTILE_ANGLE, a0
    move.l #PROJECTILE_INITIAL_ANGLE, (a0)   
    
    lea POWER_PERCENT, a0
    move.l #0, (a0)
    
    lea Stone_XVelocity, a0
    move.l #0, (a0)
    lea Stone_YVelocity, a0
    move.l #0, (a0)
    
.load_WindRight_Img:
    move.l #CHAR_MAX_BYTES, d1
    lea WindRightImg, a1
    bsr bmp_Load
    tst.b d0
    bne error
    
    move.l a1, a5
    
.set_WindRight_Bounds
    move.l #10, -(sp)
    move.l #260, -(sp)
    move.l #20, -(sp)
    move.l #60, -(sp)
    move.l #0, -(sp)
    move.l #0, -(sp)
    
.update_WindRight_Img: 
    move.l a5, a1 
    lea Wind_Right_Img, a4  
    bsr bmp_Upd_Alpha
    tst.b d0
    beq error
    
    add.l #24, sp
    
.load_WindLeft_Img:
    move.l #CHAR_MAX_BYTES, d1
    lea WindLeftImg, a1
    bsr bmp_Load
    tst.b d0
    bne error
    
    move.l a1, a5
    
.set_WindLeft_Bounds
    move.l #10, -(sp)
    move.l #260, -(sp)
    move.l #20, -(sp)
    move.l #60, -(sp)
    move.l #0, -(sp)
    move.l #0, -(sp)
    
.update_WindLeft_Img: 
    move.l a5, a1 
    lea Wind_Left_Img, a4  
    bsr bmp_Upd_Alpha
    tst.b d0
    beq error
    
    add.l #24, sp
    
.load_WindUp_Img:
    move.l #CHAR_MAX_BYTES, d1
    lea WindUpImg, a1
    bsr bmp_Load
    tst.b d0
    bne error
    
    move.l a1, a5
    
.set_WindUp_Bounds
    move.l #10, -(sp)
    move.l #300, -(sp)
    move.l #60, -(sp)
    move.l #20, -(sp)
    move.l #0, -(sp)
    move.l #0, -(sp)
    
.update_WindUp_Img: 
    move.l a5, a1 
    lea Wind_Up_Img, a4  
    bsr bmp_Upd_Alpha
    tst.b d0
    beq error
    
    add.l #24, sp
    
.load_WindDown_Img:
    move.l #CHAR_MAX_BYTES, d1
    lea WindDownImg, a1
    bsr bmp_Load
    tst.b d0
    bne error
    
    move.l a1, a5
    
.set_WindDown_Bounds
    move.l #10, -(sp)
    move.l #300, -(sp)
    move.l #60, -(sp)
    move.l #20, -(sp)
    move.l #0, -(sp)
    move.l #0, -(sp)
    
.update_WindDown_Img: 
    move.l a5, a1 
    lea Wind_Down_Img, a4  
    bsr bmp_Upd_Alpha
    tst.b d0
    beq error
    
    add.l #24, sp
    
.load_Mph_Img:
    move.l #CHAR_MAX_BYTES, d1
    lea MphImg, a1
    bsr bmp_Load
    tst.b d0
    bne error
    
    move.l a1, a5
    
.set_Mph_Bounds
    move.l #10, -(sp)
    move.l #370, -(sp)
    move.l #20, -(sp)
    move.l #35, -(sp)
    move.l #0, -(sp)
    move.l #0, -(sp)
    
.update_Mph_Img: 
    move.l a5, a1 
    lea Mph_Img, a4  
    bsr bmp_Upd_Alpha
    tst.b d0
    beq error
    
    add.l #24, sp
    
draw_Start_Screen:
.xCoord EQU 120
.yCoord EQU 150
.width  EQU 424
.height EQU 99
    lea Start_Screen_Img, a4
    move.l #.yCoord, d2
    move.l #.xCoord, d3
    move.l #.height, d5
    move.l #.width, d4
    
    bsr bmp_Draw
    
******************************************************************************************    
StartLoop:
    move.l #KEY_SPACE, d1
    move.b #GET_USER_INPUT_COMMAND,d0
    trap #15
    
    move.l d1, d2
    andi.l #$000000FF, d2
    beq StartLoop   
******************************************************************************************  
   
redraw_Start:
.xCoord EQU 115
.yCoord EQU 145
.width  EQU 444
.height EQU 124
    lea Start_Screen_Redraw, a4
    move.l #.xCoord, d3
    move.l #.yCoord, d2
    move.l #.width, d4
    move.l #.height, d5
    
    bsr bmp_Draw
   
.draw_Power_Meter:   
    bsr Draw_Power_Meter 

.draw_Initial_Health:
    bsr P1_SetHealth 
    bsr P2_SetHealth 
  
.drawWind:
    bsr SetWindSpeed
    bsr DrawWS  
    
*Load P1 Win
.set_P1Win_Bounds
    move.l #100, -(sp)
    move.l #180, -(sp)
    move.l #200, -(sp)
    move.l #300, -(sp)
    move.l #0, -(sp)
    move.l #0, -(sp)
    
.update_P1Win: 
    lea P1WinImg, a1 
    lea Player1_Win_Img, a4  
    bsr bmp_Upd_Alpha
    tst.b d0
    beq error
    
    add.l #24, sp
    
*Load P2 Win
.set_P2Win_Bounds
    move.l #100, -(sp)
    move.l #180, -(sp)
    move.l #200, -(sp)
    move.l #300, -(sp)
    move.l #0, -(sp)
    move.l #0, -(sp)
    
.update_P2Win: 
    lea P2WinImg, a1 
    lea Player2_Win_Img, a4  
    bsr bmp_Upd_Alpha
    tst.b d0
    beq error
    
    add.l #24, sp
    
    lea Updated_Player1_Img, a4
    move.l #350, d2
    move.l #20, d3
    move.l #98, d5
    move.l #59, d4
    bsr bmp_Draw
    
    lea Updated_Player2_Img, a4
    move.l #350, d2
    move.l #570, d3
    move.l #98, d5
    move.l #59, d4
    bsr bmp_Draw
    
*Set double buffered mode
    move.l  #92,d0
    move.l  #17,d1
    trap    #15
    
*Load all sounds & play background music
    lea BackgroundMusic, a1
    clr.l d1
    move.b #0, d1
    move.b #LOAD_AUDIO_COMMAND, d0
    trap #15
    
    lea P1Laugh, a1
    move.b #1, d1
    move.b #LOAD_AUDIO_COMMAND, d0
    trap #15
    
    lea P2Laugh, a1
    move.b #2, d1
    move.b #LOAD_AUDIO_COMMAND, d0
    trap #15
    
    lea Throw, a1
    move.b #3, d1
    move.b #LOAD_AUDIO_COMMAND, d0
    trap #15
    
    lea Applause, a1
    move.b #4, d1
    move.b #LOAD_AUDIO_COMMAND, d0
    trap #15
    
    lea P1Wins, a1
    move.b #5, d1
    move.b #LOAD_AUDIO_COMMAND, d0
    trap #15
    
    lea P2Wins, a1
    move.b #6, d1
    move.b #LOAD_AUDIO_COMMAND, d0
    trap #15
    
    move.b #0, d1
    move.l #1, d2
    move.b #CONTROL_AUDIO_COMMAND, d0
    trap #15
   
******************************************************************************************    
GameLoop:
    * Check if game over
    tst.b GAME_OVER
    bne GameOver
    
    * Read Input
    move.b #8, d0
    trap #15
    move.l d1, d7
    
    bsr GetUserInput
    cmp.b #1, CURRENT_PLAYER
    beq P1_Loop
    
    bsr UpdateStone
    bsr Draw_P2_Projectile_Line
    bsr DrawStone
    bsr CheckCollOnP1
    ;bsr delayFrame
    
    move.b  #94,d0
    trap    #15
    
    bra gameLoop
    
P1_Loop:
    bsr UpdateStone
    bsr Draw_P1_Projectile_Line
    bsr DrawStone
    bsr CheckCollOnP2
    ;bsr DelayFrame
    
    move.b  #94,d0
    trap    #15
    
    move.b #8, d0
    trap #15
    sub.l d7, d1
    
    bra gameLoop 
    
GameOver:    
    ; Stop background audio
    move.b #0, d1
    move.l #2, d2
    move.b #CONTROL_AUDIO_COMMAND, d0
    trap #15
    
    ; Delay by 3 sec
    move.l  #DELAY_FRAME, d0
    move.l  #GAME_OVER_FRAME_DELAY, d1
    trap    #15
    
    ; Play crowd cheer audio
    move.b #4, d1
    move.l #1, d2
    move.b #CONTROL_AUDIO_COMMAND, d0
    trap #15
    
    cmp.b #1, GAME_WINNER
    beq .p1Win
    
    ; Display P2 win banner
    lea Player2_Win_Img, a4
    move.l #180, d3
    move.l #100, d2
    move.l #299, d4
    move.l #199, d5
    bsr bmp_Draw
    
    ; Play P2 win audio
    move.b #6, d1
    move.b #PLAY_AUDIO_COMMAND, d0
    trap #15 
    
    move.b  #94,d0
    trap    #15

    bra checkRestartInp   
    
.p1Win:
    ; Play P1 win audio
    move.b #5, d1
    move.b #PLAY_AUDIO_COMMAND, d0
    trap #15
    
    ; Display P1 win banner
    lea Player1_Win_Img, a4
    move.l #180, d3
    move.l #100, d2
    move.l #299, d4
    move.l #199, d5
    bsr bmp_Draw
    
    move.b  #94,d0
    trap    #15
    
checkRestartInp:
    move.l #KEY_R, d1
    move.b #GET_USER_INPUT_COMMAND,d0
    trap #15
    
    move.l d1, d2
    andi.l #$000000FF, d2
    beq checkRestartInp
    
    bsr ResetGame
    
    SIMHALT
    
******************************************************************************************
DelayFrame:
    move.l  #DELAY_FRAME, d0
    move.l  #FRAME_DELAY_TIME, d1
    trap    #15
    rts
    
; Resets game state after one player shoots
ResetState:
    lea PROJECTILE_ANGLE, a0
    move.l #PROJECTILE_INITIAL_ANGLE, (a0)   
    
    lea POWER_PERCENT, a0
    move.l #0, (a0)
    
    lea Stone_XVelocity, a0
    move.l #0, (a0)
    lea Stone_YVelocity, a0
    move.l #0, (a0)
    
    move.l #0, WS_X
    move.l #0, WS_Y
    
    move.b #0, PROJECTILE_ACTIVE
    move.b #0, POWER_ACTIVE
    move.b #0, Stone_X_Initialized
    
    sub.b #1, TURNS_LEFT
    tst.b TURNS_LEFT
    beq .changeWind
    
    bsr Redraw_WS_Symbol
    bsr DrawWS
    bra .resetChar
    
.changeWind:
    bsr Redraw_WS_Symbol
    bsr SetWindSpeed
    bsr DrawWS
    move.b #2, TURNS_LEFT
    
.resetChar:
    cmp.b #1, CURRENT_PLAYER
    beq .resetP1
    
    ; Erase the P2 power meter
    lea Pow_Meter_Right_Redraw, a4
    move.l #(POWER_METER_LEFT_P2-5), d3
    move.l #(POWER_METER_TOP-5), d2
    move.l #25, d4
    move.l #169, d5
    bsr bmp_Draw
    
    ; Reset P2
    lea Player2_Fire_XCoordinate, a0
    move.l #(570)<<FRAC_BITS, (a0)
    lea Player2_Fire_YCoordinate, a0
    move.l #(350)<<FRAC_BITS, (a0)
    
    lea P2_Stone_XCoordinate, a0
    move.l #(570<<FRAC_BITS-STONE_SIZE), (a0)
    lea Stone_YCoordinate, a0
    move.l #(350)<<FRAC_BITS, (a0)
    
    move.b #1, CURRENT_PLAYER
    
    rts
    
.resetP1:
    ; Erase the P1 power meter
    lea Pow_Meter_Left_Redraw, a4
    move.l #(POWER_METER_LEFT-5), d3
    move.l #(POWER_METER_TOP-5), d2
    move.l #25, d4
    move.l #169, d5
    bsr bmp_Draw
    
    lea Player1_Fire_XCoordinate, a0
    move.l #(20+40)<<FRAC_BITS, (a0)
    lea Player1_Fire_YCoordinate, a0
    move.l #(340)<<FRAC_BITS, (a0)

    lea P1_Stone_XCoordinate, a0
    move.l #(20+40)<<FRAC_BITS, (a0)
    lea Stone_YCoordinate, a0
    move.l #(350)<<FRAC_BITS, (a0)
    
    move.b #2, CURRENT_PLAYER
    
    rts

; Resets the game state and gives the first shot to the player who went second this game 
ResetGame:
    lea PROJECTILE_ANGLE, a0
    move.l #PROJECTILE_INITIAL_ANGLE, (a0)   
    
    lea POWER_PERCENT, a0
    move.l #0, (a0)
    
    lea Stone_XVelocity, a0
    move.l #0, (a0)
    lea Stone_YVelocity, a0
    move.l #0, (a0)
    
    move.l #0, WS_X
    move.l #0, WS_Y
    
    move.b #0, PROJECTILE_ACTIVE
    move.b #0, POWER_ACTIVE
    move.b #0, Stone_X_Initialized
    
    move.b #2, TURNS_LEFT
    
    ; Reset P1
    lea Pow_Meter_Left_Redraw, a4
    move.l #(POWER_METER_LEFT-5), d3
    move.l #(POWER_METER_TOP-5), d2
    move.l #25, d4
    move.l #169, d5
    bsr bmp_Draw
    
    lea Player1_Fire_XCoordinate, a0
    move.l #(20+40)<<FRAC_BITS, (a0)
    lea Player1_Fire_YCoordinate, a0
    move.l #(340)<<FRAC_BITS, (a0)

    lea P1_Stone_XCoordinate, a0
    move.l #(20+40)<<FRAC_BITS, (a0)
    lea Stone_YCoordinate, a0
    move.l #(350)<<FRAC_BITS, (a0)
    
    ; Redraw P1
    lea Updated_Player1_Img, a4
    move.l #350, d2
    move.l #20, d3
    move.l #98, d5
    move.l #59, d4
    bsr bmp_Draw
    
    ; Reset P2
    lea Pow_Meter_Right_Redraw, a4
    move.l #(POWER_METER_LEFT_P2-5), d3
    move.l #(POWER_METER_TOP-5), d2
    move.l #25, d4
    move.l #169, d5
    bsr bmp_Draw
    
    lea Player2_Fire_XCoordinate, a0
    move.l #(570)<<FRAC_BITS, (a0)
    lea Player2_Fire_YCoordinate, a0
    move.l #(350)<<FRAC_BITS, (a0)
    
    lea P2_Stone_XCoordinate, a0
    move.l #(570<<FRAC_BITS-STONE_SIZE), (a0)
    lea Stone_YCoordinate, a0
    move.l #(350)<<FRAC_BITS, (a0)
    
    ; Redraw P2
    lea Updated_Player2_Img, a4
    move.l #350, d2
    move.l #570, d3
    move.l #98, d5
    move.l #59, d4
    bsr bmp_Draw
    
    bsr Redraw_WS_Symbol
    bsr SetWindSpeed
    bsr DrawWS
    
    lea Player_Win_Redraw, a4
    move.l #170, d3
    move.l #90, d2
    move.l #310, d4
    move.l #210, d5
    bsr bmp_Draw
    
    ; Reset game state variables
    cmp.b #1, CURRENT_GAMESTART_PLAYER
    beq .updPlayer
    
    move.b #1, CURRENT_PLAYER
    move.b #1, CURRENT_GAMESTART_PLAYER
    bra .contReset
    
.updPlayer:
    move.b #2, CURRENT_PLAYER
    move.b #2, CURRENT_GAMESTART_PLAYER

.contReset:
    move.b #0, GAME_OVER
    move.b P1_MaxHealth, P1_Health
    move.b P2_MaxHealth, P2_Health
    bsr P1_SetHealth
    bsr P2_SetHealth
    bsr Draw_Power_Meter
    
    ; Reset sounds
    move.b #4, d1
    move.l #2, d2
    move.b #CONTROL_AUDIO_COMMAND, d0
    trap #15
    
    move.b #0, d1
    move.l #1, d2
    move.b #CONTROL_AUDIO_COMMAND, d0
    trap #15
    
    move.b  #94,d0
    trap    #15
    
    bra GameLoop

**INPUT**
GetUserInput:
    movem.l ALL_REG, -(sp)
    cmp.b #1, PROJECTILE_ACTIVE
    beq .noInput
    cmp.b #1, CURRENT_PLAYER
    beq .GetP1Input
    bra .GetP2Input
    
.noInput:
    movem.l (sp)+, ALL_REG
    rts
    
.GetP1Input:
    move.l #(KEY_A<<16 + KEY_D<<8 + KEY_SPACE), d1
    move.b #GET_USER_INPUT_COMMAND,d0
    trap #15
    
    move.l d1, d2
    andi.l #$000000FF, d2
    bne .P1Fire
        
    move.l d1, d2
    andi.l #$00FF0000, d2
    bne .P1IncAngle
    
    move.l d1, d2
    andi.l #$0000FF00, d2
    bne .P1DecAngle
    
    bra .DoneP1Input
    
.P1Fire:
    bsr UpdatePowerMeter
    bsr ThrowStone

    movem.l (sp)+, ALL_REG
    rts
    
.P1IncAngle:
    lea PROJECTILE_ANGLE, a0
    move.l (a0), d0
    move.l #PROJECTILE_ANGLE_INCREMENT, d1
    add.l d1, d0
    cmp.l #PROJECTILE_MAX_ANGLE, d0
    bge .clampMaxAngle
    
    move.l d0, (a0)
    
    bsr ClearP1Projectile
    
    movem.l (sp)+, ALL_REG
    rts
    
.clampMaxAngle:
    move.l #PROJECTILE_MAX_ANGLE, (a0)
    
    movem.l (sp)+, ALL_REG
    rts
    
.P1DecAngle:
    lea PROJECTILE_ANGLE, a0
    move.l (a0), d0
    move.l #PROJECTILE_ANGLE_INCREMENT, d1
    sub.l d1, d0
    cmp.l #PROJECTILE_MIN_ANGLE, d0
    ble .clampMinAngle
    
    move.l d0, (a0)
    
    bsr ClearP1Projectile

    movem.l (sp)+, ALL_REG
    rts  

.clampMinAngle:
    move.l #PROJECTILE_MIN_ANGLE, (a0)

    movem.l (sp)+, ALL_REG
    rts 
    
.DoneP1Input:
    movem.l (sp)+, ALL_REG
    rts
    
.GetP2Input:
    move.l #(KEY_ARROW_RIGHT<<16 + KEY_ARROW_LEFT<<8 + KEY_ARROW_CTRL), d1
    move.b #GET_USER_INPUT_COMMAND,d0
    trap #15
    
    move.l d1, d2
    andi.l #$000000FF, d2
    bne .P2Fire
        
    move.l d1, d2
    andi.l #$00FF0000, d2
    bne .P2IncAngle
    
    move.l d1, d2
    andi.l #$0000FF00, d2
    bne .P2DecAngle
    
    bra .DoneP2Input
    
.P2Fire:
    bsr UpdatePowerMeter
    bsr ThrowStone

    movem.l (sp)+, ALL_REG
    rts
    
.P2IncAngle:
    lea PROJECTILE_ANGLE, a0
    move.l (a0), d0
    move.l #PROJECTILE_ANGLE_INCREMENT, d1
    add.l d1, d0
    cmp.l #PROJECTILE_MAX_ANGLE, d0
    bge .clampMaxAngle2
    
    move.l d0, (a0)
    
    bsr ClearP2Projectile
    
    movem.l (sp)+, ALL_REG
    rts
    
.clampMaxAngle2:
    move.l #PROJECTILE_MAX_ANGLE, (a0)
    
    movem.l (sp)+, ALL_REG
    rts
    
.P2DecAngle:
    lea PROJECTILE_ANGLE, a0
    move.l (a0), d0
    move.l #PROJECTILE_ANGLE_INCREMENT, d1
    sub.l d1, d0
    cmp.l #PROJECTILE_MIN_ANGLE, d0
    ble .clampMinAngle2
    
    move.l d0, (a0)
    
    bsr ClearP2Projectile

    movem.l (sp)+, ALL_REG
    rts  

.clampMinAngle2:
    move.l #PROJECTILE_MIN_ANGLE, (a0)

    movem.l (sp)+, ALL_REG
    rts 
    
.DoneP2Input:
    movem.l (sp)+, ALL_REG
    rts
    
ClearP1Projectile:
    lea Left_Bgm_Redraw_Rect, a4
    move.l #54, d3
    move.l #268, d2
    move.l #85, d4
    move.l #85, d5
    bsr bmp_Draw
    rts
    
ClearP2Projectile:
    lea Right_Bgm_Redraw_Rect, a4
    move.l #505, d3
    move.l #266, d2
    move.l #85, d4
    move.l #85, d5
    bsr bmp_Draw
    rts
    
Draw_P1_Projectile_Line:
    movem.l ALL_REG, -(sp)
    
    move.l #PROJECTILE_LINE_SIZE, d0
    lea PROJECTILE_ANGLE, a1
    move.l (a1), d1
    asr.l #8, d1
    move.l d1, d2
    asl.l #1, d2
    lea cosTable, a1
    move.w (a1,d2), d3
    mulu.w d0, d3
    asr.l #8, d3
    
    lea Player1_Fire_XCoordinate, a0
    move.l (a0), d0
    add.l d0, d3
    asr.l #8, d3
    
    lea sinTable, a1
    move.w (a1, d2), d4
    move.l #PROJECTILE_LINE_SIZE, d0
    mulu.w d0, d4
    asr.l #8, d4
    
    lea Player1_Fire_YCoordinate, a0
    move.l (a0), d0
    sub.l d4, d0
    move.l d0, d4
    asr.l #8, d4
    
    ; Draw projectile preview line
    move.b #4, d1
    move.b #SET_PEN_WIDTH_COMMAND, d0
    trap #15
    
    move.l #GREEN, d1
    move.b #SET_PEN_COLOR_COMMAND, d0
    trap #15
    
    lea Player1_Fire_XCoordinate, a0
    move.l (a0), d1
    asr.l #8, d1
    lea Player1_Fire_YCoordinate, a0
    move.l (a0), d2
    asr.l #8, d2
    move.b #DRAW_LINE_COMMAND, d0
    trap #15
    
    move.b #2, d1
    move.b #SET_PEN_WIDTH_COMMAND, d0
    trap #15
    
    move.l #RED, d1
    move.b #SET_PEN_COLOR_COMMAND, d0
    trap #15
    
    move.l #RED, d1
    move.b #SET_FILL_COLOR_COMMAND,d0
    trap #15
    
    move.l d3, d1
    move.l d4, d2
    sub.l #5, d1
    add.l #5, d4
    
    add.l #5, d3
    sub.l #5, d2
    move.b #88, d0
    trap #15
    
    movem.l (sp)+, ALL_REG
    rts
    
Draw_P2_Projectile_Line:
    movem.l ALL_REG, -(sp)
    
    move.l #PROJECTILE_LINE_SIZE, d0
    lea PROJECTILE_ANGLE, a1
    move.l (a1), d1
    asr.l #8, d1
    move.l d1, d2
    asl.l #1, d2
    lea cosTable, a1
    move.w (a1,d2), d3
    mulu.w d0, d3
    asr.l #8, d3
    
    lea Player2_Fire_XCoordinate, a0
    move.l (a0), d0
    sub.l d3, d0
    move.l d0, d3
    asr.l #8, d3
    
    lea sinTable, a1
    move.w (a1, d2), d4
    move.l #PROJECTILE_LINE_SIZE, d0
    mulu.w d0, d4
    asr.l #8, d4
    
    lea Player2_Fire_YCoordinate, a0
    move.l (a0), d0
    sub.l d4, d0
    move.l d0, d4
    asr.l #8, d4
    
    ; Draw projectile preview line
    move.b #4, d1
    move.b #SET_PEN_WIDTH_COMMAND, d0
    trap #15
    
    move.l #GREEN, d1
    move.b #SET_PEN_COLOR_COMMAND, d0
    trap #15
    
    lea Player2_Fire_XCoordinate, a0
    move.l (a0), d1
    asr.l #8, d1
    lea Player2_Fire_YCoordinate, a0
    move.l (a0), d2
    asr.l #8, d2
    move.b #DRAW_LINE_COMMAND, d0
    trap #15
    
    move.b #2, d1
    move.b #SET_PEN_WIDTH_COMMAND, d0
    trap #15
    
    move.l #RED, d1
    move.b #SET_PEN_COLOR_COMMAND, d0
    trap #15
    
    move.l #RED, d1
    move.b #SET_FILL_COLOR_COMMAND,d0
    trap #15
    
    move.l d3, d1
    move.l d4, d2
    sub.l #5, d1
    add.l #5, d4
    
    add.l #5, d3
    sub.l #5, d2
    move.b #88, d0
    trap #15
    
    movem.l (sp)+, ALL_REG
    rts

; Update power meter based on the time the player holds the shoot key    
UpdatePowerMeter:
    movem.l ALL_REG, -(sp)
.loop: 
    move.b #1, POWER_ACTIVE
    bsr SetShootKey
    move.b #GET_USER_INPUT_COMMAND,d0
    trap #15

    andi.l #$000000FF, d1
    beq .completeUpdate

    lea POWER_PERCENT, a0
    move.l (a0), d0
    add.l #POWER_METER_INCREMENT, d0
    cmp.l #POWER_METER_MAX, d0
    bgt .clampPower
    move.l d0, (a0)
    
    bsr Draw_Power_Meter
    
    ; Copy buffer
    move.b  #94,d0
    trap    #15
    
    move.l  #DELAY_FRAME, d0
    move.l  #FRAME_DELAY_TIME, d1
    trap    #15
        
    bra .loop
    
.clampPower:
    move.l #POWER_METER_MAX, (a0)
    
    bsr Draw_Power_Meter
    
    ; Copy buffer
    move.b  #94,d0
    trap    #15

    ;move.b #0, POWER_ACTIVE
    ;movem.l (sp)+, ALL_REG
    ;rts
    bra .loop
    
.completeUpdate:
    ; Play throw animation
    bsr PlayThrowAnim

    ; Play throw sound
    move.b #3, d1
    move.b #PLAY_AUDIO_COMMAND, d0
    trap #15
    
    move.b #0, POWER_ACTIVE
    movem.l (sp)+, ALL_REG
    rts
    
SetShootKey:
    cmp.b #1, CURRENT_PLAYER
    beq .p1ShootKey
    move.l #KEY_ARROW_CTRL, d1
    rts
      
.p1ShootKey:
    move.l #KEY_SPACE, d1
    rts
       
PlayThrowAnim:
    movem.l ALL_REG, -(sp)
    
    cmp.b #1, CURRENT_PLAYER
    beq .p1Anim
    
    lea P2_Throw2Img, a5
    bsr P2DrawFrame
    
    lea P2_Throw3Img, a5
    bsr P2DrawFrame
    
    lea Updated_Player2_Img, a5
    bsr P2DrawFrame
    
    movem.l (sp)+, ALL_REG
    rts
    
.p1Anim:
    lea P1_Throw2Img, a5
    bsr P1DrawFrame
    
    lea P1_Throw3Img, a5
    bsr P1DrawFrame
    
    lea Updated_Player1_Img, a5
    bsr P1DrawFrame
    
    movem.l (sp)+, ALL_REG
    rts
   
* a5 - address of frame to draw 
P1DrawFrame:
    lea P1_Redraw, a4
    move.l #15, d3
    move.l #345, d2
    move.l #69, d4
    move.l #109, d5
    bsr bmp_Draw
    
    move.l a5, a4
    move.l #20, d3
    move.l #350, d2
    move.l #59, d4
    move.l #98, d5
    bsr bmp_Draw
    
    ; Copy buffer
    move.b  #94,d0
    trap    #15
    
    move.l  #DELAY_FRAME, d0
    move.l  #2, d1
    trap    #15
    
    rts
    
* a5 - address of frame to draw 
P2DrawFrame:
    lea P2_Redraw, a4
    move.l #575, d3
    move.l #345, d2
    move.l #69, d4
    move.l #109, d5
    bsr bmp_Draw
    
    move.l a5, a4
    move.l #570, d3
    move.l #350, d2
    move.l #59, d4
    move.l #98, d5
    bsr bmp_Draw
    
    ; Copy buffer
    move.b  #94,d0
    trap    #15
    
    move.l  #DELAY_FRAME, d0
    move.l  #2, d1
    trap    #15
    
    rts

ThrowStone:
    tst.b POWER_ACTIVE
    bne .dontThrowStone
    bsr SetStoneXCoord
    bsr CalcInitStoneVelc
    rts
    
.dontThrowStone:
    rts

SetStoneXCoord:
    movem.l ALL_REG, -(sp)
    
    tst.b Stone_X_Initialized
    bne .dontSetStoneX
    move.b #1, Stone_X_Initialized
    
    cmp.b #1, CURRENT_PLAYER
    beq .p1StoneXCoord
    
    ; p2 stone x coordinate
    lea P2_Stone_XCoordinate, a0
    lea Stone_XCoordinate, a1
    move.l (a0), (a1)
    
    movem.l (sp)+, ALL_REG
    rts
    
.p1StoneXCoord:
    lea P1_Stone_XCoordinate, a0
    lea Stone_XCoordinate, a1
    move.l (a0), (a1)
    
    movem.l (sp)+, ALL_REG
    rts
    
.dontSetStoneX:
    movem.l (sp)+, ALL_REG
    rts

**PHYSICS**
; Calculate stone velocity based on the power meter and wind speed and direction    
CalcInitStoneVelc:
    movem.l ALL_REG, -(sp)
    
    move.b #1, PROJECTILE_ACTIVE
    
    lea PROJECTILE_ANGLE, a1
    move.l (a1), d0
    
    lea POWER_PERCENT, a1
    move.l (a1), d1
    
    lea sinTable, a0
    lea cosTable, a1
    
    lea Stone_XVelocity, a2
    lea Stone_YVelocity, a3
    
    ; Cosine and Sine of projectile angle
    asr.l #8, d0
    asl.l #1, d0
    move.w (a1,d0), d2
    move.w (a0,d0), d3
    
    ; Update stone's x and y velocity based on the power and angle
    move.l #STONE_VELOCITY, d4
    mulu.w d4, d2   ; Multiplying by cosine of velocity
    asr.l #8, d2
    mulu.w d1, d2   ; Multiplying by power factor
    asr.l #8, d2    
    
.XVelocity:    
    cmp.b #2, CURRENT_PLAYER
    beq .p2XVel   ; Set x velocity as negative if current player is 2
    move.l d2, (a2)
    bra .setYVel
    
.p2XVel:
    clr.l d5
    sub.l d2, d5
    move.l d5, (a2)
    
.setYVel:
    move.l #STONE_VELOCITY, d4
    mulu.w d4, d3   ; Multiplying by sine of velocity
    asr.l #8, d3
    mulu.w d1, d3   ; Multiplying by power factor
    asr.l #8, d3    
    
.YVelocity:    
    clr.l d5
    sub.l d3, d5
    move.l d5, (a3)
    
    ; Wind factor
    move.l #WIND_HORIZONTAL_STRENGTH, d4
    clr.l d7
    move.b WIND_SPEED, d7
    mulu.w d4, d7
    asr.l #8, d7 
    
    move.l #WIND_VERTICAL_STRENGTH, d4
    clr.l d6
    move.b WIND_SPEED, d6
    mulu.w d4, d6
    asr.l #8, d6

    cmp.b #0, WIND_DIRECTION
    beq .updLeft
    
    cmp.b #1, WIND_DIRECTION
    beq .updRight
    
    cmp.b #2, WIND_DIRECTION
    beq .updUp
    
    cmp.b #3, WIND_DIRECTION
    beq .updDown
    
    bra .end
    
.updLeft:
    neg.l d7
    move.l d7, WS_X
    bra .end
    
.updRight:
    move.l d7, WS_X
    bra .end

.updUp:
    neg.l d6
    move.l d6, WS_Y
    bra .end
    
.updDown:
    move.l d6, WS_Y

.end:    
    movem.l (sp)+, ALL_REG
    rts
 
; Updates the stone's X and Y coordinates velocities based on the velocities
; calculated in CalcInitStoneVelc    
UpdateStone:
    movem.l ALL_REG, -(sp)
    
    tst.b PROJECTILE_ACTIVE
    beq .dontUpdate
    
    tst.b POWER_ACTIVE
    bne .dontUpdate
    
    lea Stone_XCoordinate, a0
    move.l (a0), d0
    
    lea Stone_YCoordinate, a1
    move.l (a1), d1
    
    lea Stone_XVelocity, a2
    move.l (a2), d2
    
    lea Stone_YVelocity, a3
    move.l (a3), d3
    
    move.l #GRAVITY, d4
    
    bsr ClearStone
    
    ; Updating coordinates and velocity
    add.l d2, d0
    add.l WS_X, d0
    add.l WS_X, d2
    add.l d3, d1
    add.l WS_Y, d1
    add.l WS_Y, d3
    add.l d4, d3
    
    move.l d0, (a0)
    move.l d1, (a1)
    move.l d3, (a3)
    
    movem.l (sp)+, ALL_REG
    rts
    
.dontUpdate:
    movem.l (sp)+, ALL_REG
    rts

; Erases the stone drawn in the previous frame    
ClearStone:
    movem.l ALL_REG, -(sp)
    
    ; Erase current projectile drawing
    lea Updated_BGM_Img, a1
    lea Projectile_Redraw_Rect, a4
    move.l d0, d3
    asr.l #8, d3
    sub.l #5, d3
    move.l d1, d2
    sub.l #STONE_SIZE, d2
    asr.l #8, d2
    sub.l #5, d2
    move.l #STONE_SIZE, d4
    asr.l #8, d4
    add.l #10, d4
    move.l d4, d5
    bsr bmp_BGM_Cutout
    sub.l #1, d4
    sub.l #1, d5
    bsr bmp_Draw
    
    movem.l (sp)+, ALL_REG
    rts
 
**COLLISION** 
; Performs a collision and hitbox check on the player 2 character  
CheckCollOnP2:
    movem.l ALL_REG, -(sp)
    
    tst.b PROJECTILE_ACTIVE
    beq .dontCheckColl
    
    tst.b POWER_ACTIVE
    bne .dontCheckColl
    
    ; Bottom Left X
    lea Stone_XCoordinate, a0
    move.l (a0), d1
    asr.l #8, d1
    
    ; Bottom Left Y
    lea Stone_YCoordinate, a1
    move.l (a1), d4
    asr.l #8, d4

    ; Top Right X
    move.l (a0), d3
    add.l #STONE_SIZE, d3
    asr.l #8, d3

    ; Top Right Y
    move.l (a1), d2
    sub.l #STONE_SIZE, d2
    asr.l #8, d2
    
    lea Player_2_Img_Prop, a2
    ; 12(a2) - Top left X
    ; 16(a2) - Top left Y
    
    cmp.l #480, d4
    bge .outOfBounds
    
    cmp.l #0, d2
    ble .outOfBounds
    
    cmp.l #640, d3
    bge .outOfBounds

    cmp.l #0, d1
    ble .outOfBounds 
    
    cmp.l 16(a2), d4
    bge .yCollision
    
    movem.l (sp)+, ALL_REG
    rts 
    
.yCollision:
    move.l 16(a2), d6
    cmp.l 12(a2), d3
    blt .noYCollision
    
    move.l 12(a2), d5
    add.l 4(a2), d5
    cmp.l d5, d1
    bgt .noYCollision
    
    ; Play P1 battle laugh audio
    move.l #1, d1
    move.b #PLAY_AUDIO_COMMAND, d0
    trap #15
    
    ; Play hurt animation
    bsr PlayHurtAnim
    
    ; Check hitboxes
    cmp.l #CHAR_BODYSHOT_Y, d4
    blt .headShotDmg
    
    cmp.l #CHAR_LEGSHOT_Y, d4
    blt .bodyShotDmg
    
    sub.b #LEGSHOT_DAMAGE, P2_Health
    bmi .clampHealth
    beq .clampHealth
    bsr P2_SetHealth
    bra .stateReset
    
.headShotDmg:
    sub.b #HEADSHOT_DAMAGE, P2_Health
    bmi .clampHealth
    beq .clampHealth
    bsr P2_SetHealth
    bra .stateReset
    
.bodyShotDmg:
    sub.b #BODYSHOT_DAMAGE, P2_Health
    bmi .clampHealth
    beq .clampHealth
    bsr P2_SetHealth
    bra .stateReset
    
.clampHealth:
    move.b #0, P2_HEALTH
    bsr P2_SetHealth
    move.b #1, GAME_OVER
    move.b #1, GAME_WINNER
    
.complete:
    move.l (a0), d0
    move.l (a1), d1
    bsr ClearStone
    
    bsr ClearP1Projectile
    bsr Draw_Power_Meter
    
    movem.l (sp)+, ALL_REG
    rts
    
.stateReset:
    move.l (a0), d0
    move.l (a1), d1
    bsr ClearStone
    
    bsr ClearP1Projectile
    bsr Draw_Power_Meter
    bsr ResetState
    
    movem.l (sp)+, ALL_REG
    rts

.noYCollision:
    movem.l (sp)+, ALL_REG
    rts
    
.dontCheckColl:
    movem.l (sp)+, ALL_REG
    rts
    
.outOfBounds:   
    move.l (a0), d0
    move.l (a1), d1
    bsr ClearStone
    
    bsr ClearP1Projectile
    bsr ResetState
    bsr Draw_Power_Meter

    movem.l (sp)+, ALL_REG
    rts

**COLLISION**  
; Performs a collision and hitbox check on the player 1 character  
CheckCollOnP1:
    movem.l ALL_REG, -(sp)
    
    tst.b PROJECTILE_ACTIVE
    beq .p1DontCheckColl
    
    tst.b POWER_ACTIVE
    bne .p1DontCheckColl
    
    ; Bottom Left X
    lea Stone_XCoordinate, a0
    move.l (a0), d1
    asr.l #8, d1
    
    ; Bottom Left Y
    lea Stone_YCoordinate, a1
    move.l (a1), d4
    asr.l #8, d4

    ; Top Right X
    move.l (a0), d3
    add.l #STONE_SIZE, d3
    asr.l #8, d3

    ; Top Right Y
    move.l (a1), d2
    sub.l #STONE_SIZE, d2
    asr.l #8, d2
    
    lea Player_1_Img_Prop, a2
    ; 12(a2) - Top left X
    ; 16(a2) - Top left Y
    
    cmp.l #480, d4
    bge .p1OutOfBounds
    
    cmp.l #0, d2
    ble .p1OutOfBounds
    
    cmp.l #640, d3
    bge .p1OutOfBounds

    cmp.l #0, d1
    ble .p1OutOfBounds 
    
    cmp.l 16(a2), d4
    bge .p1YCollision
    
    movem.l (sp)+, ALL_REG
    rts
    
.p1YCollision:
    move.l 16(a2), d6
    move.l 12(a2), d5
    add.l 4(a2), d5
    cmp.l d5, d1
    bgt .p1NoYCollision
    
    cmp.l 12(a2), d3
    blt .p1NoYCollision
    
    ; Play P2 battle laugh audio
    move.l #2, d1
    move.b #PLAY_AUDIO_COMMAND, d0
    trap #15
    
    ; Play hurt animation
    bsr PlayHurtAnim
    
    ; Check hitboxes
    cmp.l #CHAR_BODYSHOT_Y, d4
    blt .headShotDmg
    
    cmp.l #CHAR_LEGSHOT_Y, d4
    blt .bodyShotDmg
    
    sub.b #LEGSHOT_DAMAGE, P1_Health
    bmi .clampHealth
    beq .clampHealth
    bsr P1_SetHealth
    bra .stateReset
    
.headShotDmg:
    sub.b #HEADSHOT_DAMAGE, P1_Health
    bmi .clampHealth
    beq .clampHealth
    bsr P1_SetHealth
    bra .stateReset
    
.bodyShotDmg:
    sub.b #BODYSHOT_DAMAGE, P1_Health
    bmi .clampHealth
    beq .clampHealth
    bsr P1_SetHealth
    bra .stateReset
    
.clampHealth:
    move.b #0, P1_HEALTH
    bsr P1_SetHealth
    move.b #1, GAME_OVER
    move.b #2, GAME_WINNER
    
.stateReset:
    move.l (a0), d0
    move.l (a1), d1
    bsr ClearStone
    
    bsr ClearP2Projectile
    bsr ResetState
    bsr Draw_Power_Meter
    
    movem.l (sp)+, ALL_REG
    rts
    
.p1NoYCollision:
    movem.l (sp)+, ALL_REG
    rts
    
.p1DontCheckColl:
    movem.l (sp)+, ALL_REG
    rts
    
.p1OutOfBounds:   
    move.l (a0), d0
    move.l (a1), d1
    bsr ClearStone
    
    bsr ClearP2Projectile
    bsr ResetState
    bsr Draw_Power_Meter

    movem.l (sp)+, ALL_REG
    rts
    
PlayHurtAnim:
    movem.l ALL_REG, -(sp)
    
    cmp.b #1, CURRENT_PLAYER
    beq .p1Anim
    
    lea P1_Hurt1, a5
    bsr P1DrawFrame
    
    lea P1_Hurt2, a5
    bsr P1DrawFrame
    
    lea Updated_Player1_Img, a5
    bsr P1DrawFrame
    
    movem.l (sp)+, ALL_REG
    rts
    
.p1Anim:
    lea P2_Hurt1, a5
    bsr P2DrawFrame
    
    lea P2_Hurt2, a5
    bsr P2DrawFrame
    
    lea Updated_Player2_Img, a5
    bsr P2DrawFrame
    
    movem.l (sp)+, ALL_REG
    rts
  
DrawStone:
    movem.l ALL_REG, -(sp)
    
    tst.b PROJECTILE_ACTIVE
    beq .dontDrawStone
    
    tst.b POWER_ACTIVE
    bne .dontDrawStone
    
    move.b #4, d1
    move.b #SET_PEN_WIDTH_COMMAND, d0
    trap #15
    
    move.l #STONE_OUTLINE_COLOR, d1
    move.b #SET_PEN_COLOR_COMMAND, d0
    trap #15
    
    move.l  #STONE_FILLED_COLOR, d1
    move.b  #SET_FILL_COLOR_COMMAND,d0
    trap    #15
    
    ; Bottom Left X
    lea Stone_XCoordinate, a0
    move.l (a0), d1
    asr.l #8, d1
    
    ; Bottom Left Y
    lea Stone_YCoordinate, a1
    move.l (a1), d4
    asr.l #8, d4

    ; Top Right X
    move.l (a0), d3
    add.l #STONE_SIZE, d3
    asr.l #8, d3

    ; Top Right Y
    move.l (a1), d2
    sub.l #STONE_SIZE, d2
    asr.l #8, d2 
    
    move.b  #DRAW_CIRCLE_COMMAND,d0
    trap    #15
    
    movem.l (sp)+, ALL_REG
    rts
    
.dontDrawStone:
    movem.l (sp)+, ALL_REG
    rts
    
Draw_Power_Meter
    move.l #POWER_METER_COLOR, d1
    move.b #SET_PEN_COLOR_COMMAND, d0
    trap #15
    
    move.l #POWER_METER_UNFILLED_COLOR, d1
    move.b #SET_FILL_COLOR_COMMAND, d0
    trap #15
    
    move.l #POWER_METER_THICKNESS, d1
    move.b #SET_PEN_WIDTH_COMMAND, d0
    trap #15
    
    move.l #POWER_METER_BOTTOM, d4
    move.l #POWER_METER_TOP, d2
    
    cmp.b #1, CURRENT_PLAYER
    beq .meterLeft
    
    move.l #POWER_METER_LEFT_P2, d1
    move.l #POWER_METER_RIGHT_P2, d3
    bra .drawOuterMeter
    
.meterLeft:
    move.l #POWER_METER_LEFT, d1
    move.l #POWER_METER_RIGHT, d3
    
.drawOuterMeter:
    move.l d1, d7    
    move.b #87, d0
    trap #15
    
    ; Reset pen width
    move.l #1, d1
    move.b #SET_PEN_WIDTH_COMMAND, d0
    trap #15
    
    ; Set pen color to red
    move.l #POWER_METER_FILLED_COLOR, d1
    move.b #SET_PEN_COLOR_COMMAND, d0
    trap #15
    
    ; Set fill color to red
    move.l #POWER_METER_FILLED_COLOR, d1
    move.b #SET_FILL_COLOR_COMMAND, d0
    trap #15
    
    move.l d7, d1
    
    ; Adjust rectange coordinates to get the inner rectangle
    add.l #1, d1
    add.l #1, d2
    sub.l #1, d3
    sub.l #1, d4
    
    lea POWER_PERCENT, a0
    move.l (a0), d5
    move.l d4, d6
    sub.l d2, d6
    asl.l #8, d6
    mulu.w d5, d6
    asr.l #8, d6
    asr.l #8, d6
    
    move.l d4, d2
    sub.l d6, d2
    
    move.b #87, d0
    trap #15
    
    rts
 
**7SEG**   
*---
* Draw functions A-G (Draw each segment of the 7 segment display)
*
* d5 - X coordinate of where to start the 7 segment
* 
*---
Draw_7Seg_A:
    ; Set pen width to 7 segment width
    move.l #SEG_THICKNESS, d1
    move.b #SET_PEN_WIDTH_COMMAND, d0
    trap #15
    
    ; Set pen color to 7 segment color
    move.l #SEG_COLOR, d1
    move.b #SET_PEN_COLOR_COMMAND, d0
    trap #15    
     
    move.l #1, d1
    add.l d5, d1
    move.l #SEG_TOP, d2
    move.l #(SEG_LINE_LENGTH-1), d3
    add.l d5, d3
    move.l d2, d4
    move.b #DRAW_LINE_COMMAND, d0
    trap #15
    rts
    
Draw_7Seg_B:
    ; Set pen width to 7 segment width
    move.l #SEG_THICKNESS, d1
    move.b #SET_PEN_WIDTH_COMMAND, d0
    trap #15
    
    ; Set pen color to 7 segment color
    move.l #SEG_COLOR, d1
    move.b #SET_PEN_COLOR_COMMAND, d0
    trap #15    
    
    move.l #(SEG_THICKNESS+SEG_LINE_LENGTH), d1
    add.l d5, d1
    move.l #(SEG_TOP+SEG_THICKNESS), d2
    move.l #(SEG_THICKNESS+SEG_LINE_LENGTH), d3
    add.l d5, d3
    move.l #(SEG_TOP+SEG_THICKNESS+SEG_LINE_LENGTH), d4
    move.b #DRAW_LINE_COMMAND, d0
    trap #15
    rts
    
Draw_7Seg_C:
    ; Set pen width to 7 segment width
    move.l #SEG_THICKNESS, d1
    move.b #SET_PEN_WIDTH_COMMAND, d0
    trap #15
    
    ; Set pen color to 7 segment color
    move.l #SEG_COLOR, d1
    move.b #SET_PEN_COLOR_COMMAND, d0
    trap #15    
    
    move.l #(SEG_THICKNESS+SEG_LINE_LENGTH), d1
    add.l d5, d1
    move.l #(SEG_TOP+SEG_THICKNESS+SEG_LINE_LENGTH+SEG_THICKNESS), d2
    move.l #(SEG_THICKNESS+SEG_LINE_LENGTH), d3
    add.l d5, d3
    move.l #(SEG_TOP+SEG_THICKNESS+SEG_LINE_LENGTH+SEG_THICKNESS+SEG_LINE_LENGTH), d4
    move.b #DRAW_LINE_COMMAND, d0
    trap #15
    rts
    
Draw_7Seg_D:
    ; Set pen width to 7 segment width
    move.l #SEG_THICKNESS, d1
    move.b #SET_PEN_WIDTH_COMMAND, d0
    trap #15
    
    ; Set pen color to 7 segment color
    move.l #SEG_COLOR, d1
    move.b #SET_PEN_COLOR_COMMAND, d0
    trap #15    
    
    move.l #1, d1
    add.l d5, d1
    move.l #(SEG_TOP+SEG_THICKNESS+SEG_LINE_LENGTH+SEG_THICKNESS+SEG_LINE_LENGTH+SEG_THICKNESS), d2
    move.l #(SEG_LINE_LENGTH-1), d3
    add.l d5, d3
    move.l #(SEG_TOP+SEG_THICKNESS+SEG_LINE_LENGTH+SEG_THICKNESS+SEG_LINE_LENGTH+SEG_THICKNESS), d4
    move.b #DRAW_LINE_COMMAND, d0
    trap #15
    rts
    
Draw_7Seg_E:
    ; Set pen width to 7 segment width
    move.l #SEG_THICKNESS, d1
    move.b #SET_PEN_WIDTH_COMMAND, d0
    trap #15
    
    ; Set pen color to 7 segment color
    move.l #SEG_COLOR, d1
    move.b #SET_PEN_COLOR_COMMAND, d0
    trap #15    
    
    move.l d5, d1
    move.l #(SEG_TOP+SEG_THICKNESS+SEG_LINE_LENGTH+SEG_THICKNESS), d2
    move.l d5, d3
    move.l #(SEG_TOP+SEG_THICKNESS+SEG_LINE_LENGTH+SEG_THICKNESS+SEG_LINE_LENGTH), d4
    move.b #DRAW_LINE_COMMAND, d0
    trap #15
    rts
    
Draw_7Seg_F:
    ; Set pen width to 7 segment width
    move.l #SEG_THICKNESS, d1
    move.b #SET_PEN_WIDTH_COMMAND, d0
    trap #15
    
    ; Set pen color to 7 segment color
    move.l #SEG_COLOR, d1
    move.b #SET_PEN_COLOR_COMMAND, d0
    trap #15    
    
    move.l d5, d1
    move.l #(SEG_TOP+SEG_THICKNESS), d2
    move.l d5, d3
    move.l #(SEG_TOP+SEG_THICKNESS+SEG_LINE_LENGTH), d4
    move.b #DRAW_LINE_COMMAND, d0
    trap #15
    rts
    
Draw_7Seg_G:
    ; Set pen width to 7 segment width
    move.l #SEG_THICKNESS, d1
    move.b #SET_PEN_WIDTH_COMMAND, d0
    trap #15
    
    ; Set pen color to 7 segment color
    move.l #SEG_COLOR, d1
    move.b #SET_PEN_COLOR_COMMAND, d0
    trap #15    
    
    move.l #1, d1
    add.l d5, d1
    move.l #(SEG_TOP+SEG_THICKNESS+SEG_LINE_LENGTH), d2
    move.l #(SEG_LINE_LENGTH-1), d3
    add.l d5, d3
    move.l #(SEG_TOP+SEG_THICKNESS+SEG_LINE_LENGTH), d4
    move.b #DRAW_LINE_COMMAND, d0
    trap #15
    rts
    
Draw_0:
    bsr Draw_7Seg_A
    bsr Draw_7Seg_B
    bsr Draw_7Seg_C
    bsr Draw_7Seg_D
    bsr Draw_7Seg_E
    bsr Draw_7Seg_F
    rts
    
Draw_1:
    bsr Draw_7Seg_B
    bsr Draw_7Seg_C
    rts
    
Draw_2:
    bsr Draw_7Seg_A
    bsr Draw_7Seg_B
    bsr Draw_7Seg_G
    bsr Draw_7Seg_E
    bsr Draw_7Seg_D
    rts
    
Draw_3:
    bsr Draw_7Seg_A
    bsr Draw_7Seg_B
    bsr Draw_7Seg_G
    bsr Draw_7Seg_C
    bsr Draw_7Seg_D
    rts
    
Draw_4:
    bsr Draw_7Seg_F
    bsr Draw_7Seg_G
    bsr Draw_7Seg_B
    bsr Draw_7Seg_C
    rts
    
Draw_5:
    bsr Draw_7Seg_A
    bsr Draw_7Seg_F
    bsr Draw_7Seg_G
    bsr Draw_7Seg_C
    bsr Draw_7Seg_D
    rts
    
Draw_6:
    bsr Draw_7Seg_A
    bsr Draw_7Seg_F
    bsr Draw_7Seg_G
    bsr Draw_7Seg_E
    bsr Draw_7Seg_C
    bsr Draw_7Seg_D
    rts
    
Draw_7:
    bsr Draw_7Seg_A
    bsr Draw_7Seg_B
    bsr Draw_7Seg_C
    rts
    
Draw_8:
    bsr Draw_7Seg_A
    bsr Draw_7Seg_B
    bsr Draw_7Seg_C
    bsr Draw_7Seg_D
    bsr Draw_7Seg_E
    bsr Draw_7Seg_F
    bsr Draw_7Seg_G
    rts
    
Draw_9:
    bsr Draw_7Seg_A
    bsr Draw_7Seg_B
    bsr Draw_7Seg_C
    bsr Draw_7Seg_D
    bsr Draw_7Seg_F
    bsr Draw_7Seg_G
    rts
    
P1_SetHealth:
    movem.l ALL_REG, -(sp)
     
    lea P1_Health_Redraw_Rect, a4
    move.l #(SEG_P1_LEFT-5), d3
    move.l #(SEG_TOP-5), d2
    move.l #30, d4
    move.l #55, d5
    bsr bmp_Draw
  
    move.l #SEG_P1_LEFT, d5

    cmp.b #9, P1_Health
    beq .draw9
    cmp.b #8, P1_Health
    beq .draw8
    cmp.b #7, P1_Health
    beq .draw7
    cmp.b #6, P1_Health
    beq .draw6
    cmp.b #5, P1_Health
    beq .draw5
    cmp.b #4, P1_Health
    beq .draw4
    cmp.b #3, P1_Health
    beq .draw3
    cmp.b #2, P1_Health
    beq .draw2
    cmp.b #1, P1_Health
    beq .draw1
    cmp.b #0, P1_Health
    beq .draw0
    
    movem.l (sp)+, ALL_REG
    rts
    
.draw9:
    bsr Draw_9
    movem.l (sp)+, ALL_REG
    rts

.draw8:
    bsr Draw_8
    movem.l (sp)+, ALL_REG
    rts

.draw7:
    bsr Draw_7
    movem.l (sp)+, ALL_REG
    rts

.draw6:
    bsr Draw_6
    movem.l (sp)+, ALL_REG
    rts
    
.draw5:
    bsr Draw_5
    movem.l (sp)+, ALL_REG
    rts
    
.draw4:
    bsr Draw_4
    movem.l (sp)+, ALL_REG
    rts
    
.draw3:
    bsr Draw_3
    movem.l (sp)+, ALL_REG
    rts
    
.draw2:
    bsr Draw_2
    movem.l (sp)+, ALL_REG
    rts
    
.draw1:
    bsr Draw_1
    movem.l (sp)+, ALL_REG
    rts
    
.draw0:
    bsr Draw_0
    movem.l (sp)+, ALL_REG
    rts
    
P2_SetHealth:
    movem.l ALL_REG, -(sp)
     
    lea P2_Health_Redraw_Rect, a4
    move.l #(SEG_P2_LEFT-5), d3
    move.l #(SEG_TOP-5), d2
    move.l #30, d4
    move.l #55, d5
    bsr bmp_Draw
  
    move.l #SEG_P2_LEFT, d5

    cmp.b #9, P2_Health
    beq .draw9
    cmp.b #8, P2_Health
    beq .draw8
    cmp.b #7, P2_Health
    beq .draw7
    cmp.b #6, P2_Health
    beq .draw6
    cmp.b #5, P2_Health
    beq .draw5
    cmp.b #4, P2_Health
    beq .draw4
    cmp.b #3, P2_Health
    beq .draw3
    cmp.b #2, P2_Health
    beq .draw2
    cmp.b #1, P2_Health
    beq .draw1
    cmp.b #0, P2_Health
    beq .draw0
    
    movem.l (sp)+, ALL_REG
    rts
    
.draw9:
    bsr Draw_9
    movem.l (sp)+, ALL_REG
    rts

.draw8:
    bsr Draw_8
    movem.l (sp)+, ALL_REG
    rts

.draw7:
    bsr Draw_7
    movem.l (sp)+, ALL_REG
    rts

.draw6:
    bsr Draw_6
    movem.l (sp)+, ALL_REG
    rts
    
.draw5:
    bsr Draw_5
    movem.l (sp)+, ALL_REG
    rts
    
.draw4:
    bsr Draw_4
    movem.l (sp)+, ALL_REG
    rts
    
.draw3:
    bsr Draw_3
    movem.l (sp)+, ALL_REG
    rts
    
.draw2:
    bsr Draw_2
    movem.l (sp)+, ALL_REG
    rts
    
.draw1:
    bsr Draw_1
    movem.l (sp)+, ALL_REG
    rts
    
.draw0:
    bsr Draw_0
    movem.l (sp)+, ALL_REG
    rts
    
WS_Draw_7Seg_A:
    ; Set pen width to 7 segment width
    move.l #WS_THICKNESS, d1
    move.b #SET_PEN_WIDTH_COMMAND, d0
    trap #15
    
    ; Set pen color to 7 segment color
    move.l #WS_COLOR, d1
    move.b #SET_PEN_COLOR_COMMAND, d0
    trap #15    
     
    move.l #1, d1
    add.l d5, d1
    move.l #WS_TOP, d2
    move.l #(WS_LINE_LENGTH-1), d3
    add.l d5, d3
    move.l d2, d4
    move.b #DRAW_LINE_COMMAND, d0
    trap #15
    rts
    
WS_Draw_7Seg_B:
    ; Set pen width to 7 segment width
    move.l #WS_THICKNESS, d1
    move.b #SET_PEN_WIDTH_COMMAND, d0
    trap #15
    
    ; Set pen color to 7 segment color
    move.l #WS_COLOR, d1
    move.b #SET_PEN_COLOR_COMMAND, d0
    trap #15    
    
    move.l #(WS_THICKNESS+WS_LINE_LENGTH), d1
    add.l d5, d1
    move.l #(WS_TOP+WS_THICKNESS), d2
    move.l #(WS_THICKNESS+WS_LINE_LENGTH), d3
    add.l d5, d3
    move.l #(WS_TOP+WS_THICKNESS+WS_LINE_LENGTH), d4
    move.b #DRAW_LINE_COMMAND, d0
    trap #15
    rts
    
WS_Draw_7Seg_C:
    ; Set pen width to 7 segment width
    move.l #WS_THICKNESS, d1
    move.b #SET_PEN_WIDTH_COMMAND, d0
    trap #15
    
    ; Set pen color to 7 segment color
    move.l #WS_COLOR, d1
    move.b #SET_PEN_COLOR_COMMAND, d0
    trap #15    
    
    move.l #(WS_THICKNESS+WS_LINE_LENGTH), d1
    add.l d5, d1
    move.l #(WS_TOP+WS_THICKNESS+WS_LINE_LENGTH+WS_THICKNESS), d2
    move.l #(WS_THICKNESS+WS_LINE_LENGTH), d3
    add.l d5, d3
    move.l #(WS_TOP+WS_THICKNESS+WS_LINE_LENGTH+WS_THICKNESS+WS_LINE_LENGTH), d4
    move.b #DRAW_LINE_COMMAND, d0
    trap #15
    rts
    
WS_Draw_7Seg_D:
    ; Set pen width to 7 segment width
    move.l #WS_THICKNESS, d1
    move.b #SET_PEN_WIDTH_COMMAND, d0
    trap #15
    
    ; Set pen color to 7 segment color
    move.l #WS_COLOR, d1
    move.b #SET_PEN_COLOR_COMMAND, d0
    trap #15    
    
    move.l #1, d1
    add.l d5, d1
    move.l #(WS_TOP+WS_THICKNESS+WS_LINE_LENGTH+WS_THICKNESS+WS_LINE_LENGTH+WS_THICKNESS), d2
    move.l #(WS_LINE_LENGTH-1), d3
    add.l d5, d3
    move.l #(WS_TOP+WS_THICKNESS+WS_LINE_LENGTH+WS_THICKNESS+WS_LINE_LENGTH+WS_THICKNESS), d4
    move.b #DRAW_LINE_COMMAND, d0
    trap #15
    rts
    
WS_Draw_7Seg_E:
    ; Set pen width to 7 segment width
    move.l #WS_THICKNESS, d1
    move.b #SET_PEN_WIDTH_COMMAND, d0
    trap #15
    
    ; Set pen color to 7 segment color
    move.l #WS_COLOR, d1
    move.b #SET_PEN_COLOR_COMMAND, d0
    trap #15    
    
    move.l d5, d1
    move.l #(WS_TOP+WS_THICKNESS+WS_LINE_LENGTH+WS_THICKNESS), d2
    move.l d5, d3
    move.l #(WS_TOP+WS_THICKNESS+WS_LINE_LENGTH+WS_THICKNESS+WS_LINE_LENGTH), d4
    move.b #DRAW_LINE_COMMAND, d0
    trap #15
    rts
    
WS_Draw_7Seg_F:
    ; Set pen width to 7 segment width
    move.l #WS_THICKNESS, d1
    move.b #SET_PEN_WIDTH_COMMAND, d0
    trap #15
    
    ; Set pen color to 7 segment color
    move.l #WS_COLOR, d1
    move.b #SET_PEN_COLOR_COMMAND, d0
    trap #15    
    
    move.l d5, d1
    move.l #(WS_TOP+WS_THICKNESS), d2
    move.l d5, d3
    move.l #(WS_TOP+WS_THICKNESS+WS_LINE_LENGTH), d4
    move.b #DRAW_LINE_COMMAND, d0
    trap #15
    rts
    
WS_Draw_7Seg_G:
    ; Set pen width to 7 segment width
    move.l #WS_THICKNESS, d1
    move.b #SET_PEN_WIDTH_COMMAND, d0
    trap #15
    
    ; Set pen color to 7 segment color
    move.l #WS_COLOR, d1
    move.b #SET_PEN_COLOR_COMMAND, d0
    trap #15    
    
    move.l #1, d1
    add.l d5, d1
    move.l #(WS_TOP+WS_THICKNESS+WS_LINE_LENGTH), d2
    move.l #(WS_LINE_LENGTH-1), d3
    add.l d5, d3
    move.l #(WS_TOP+WS_THICKNESS+WS_LINE_LENGTH), d4
    move.b #DRAW_LINE_COMMAND, d0
    trap #15
    rts
    
WS_Draw_0:
    bsr WS_Draw_7Seg_A
    bsr WS_Draw_7Seg_B
    bsr WS_Draw_7Seg_C
    bsr WS_Draw_7Seg_D
    bsr WS_Draw_7Seg_E
    bsr WS_Draw_7Seg_F
    rts
    
WS_Draw_1:
    bsr WS_Draw_7Seg_B
    bsr WS_Draw_7Seg_C
    rts
    
WS_Draw_2:
    bsr WS_Draw_7Seg_A
    bsr WS_Draw_7Seg_B
    bsr WS_Draw_7Seg_G
    bsr WS_Draw_7Seg_E
    bsr WS_Draw_7Seg_D
    rts
    
WS_Draw_3:
    bsr WS_Draw_7Seg_A
    bsr WS_Draw_7Seg_B
    bsr WS_Draw_7Seg_G
    bsr WS_Draw_7Seg_C
    bsr WS_Draw_7Seg_D
    rts
    
WS_Draw_4:
    bsr WS_Draw_7Seg_F
    bsr WS_Draw_7Seg_G
    bsr WS_Draw_7Seg_B
    bsr WS_Draw_7Seg_C
    rts
    
WS_Draw_5:
    bsr WS_Draw_7Seg_A
    bsr WS_Draw_7Seg_F
    bsr WS_Draw_7Seg_G
    bsr WS_Draw_7Seg_C
    bsr WS_Draw_7Seg_D
    rts
    
WS_Draw_6:
    bsr WS_Draw_7Seg_A
    bsr WS_Draw_7Seg_F
    bsr WS_Draw_7Seg_G
    bsr WS_Draw_7Seg_E
    bsr WS_Draw_7Seg_C
    bsr WS_Draw_7Seg_D
    rts
    
WS_Draw_7:
    bsr WS_Draw_7Seg_A
    bsr WS_Draw_7Seg_B
    bsr WS_Draw_7Seg_C
    rts
    
WS_Draw_8:
    bsr WS_Draw_7Seg_A
    bsr WS_Draw_7Seg_B
    bsr WS_Draw_7Seg_C
    bsr WS_Draw_7Seg_D
    bsr WS_Draw_7Seg_E
    bsr WS_Draw_7Seg_F
    bsr WS_Draw_7Seg_G
    rts
    
WS_Draw_9:
    bsr WS_Draw_7Seg_A
    bsr WS_Draw_7Seg_B
    bsr WS_Draw_7Seg_C
    bsr WS_Draw_7Seg_D
    bsr WS_Draw_7Seg_F
    bsr WS_Draw_7Seg_G
    rts
    
Draw_WR:
    lea Wind_Right_Img, a4
    move.l #260, d3
    move.l #10, d2
    move.l #59, d4
    move.l #19, d5
    bsr bmp_Draw
    rts
    
Draw_WL:
    lea Wind_Left_Img, a4
    move.l #260, d3
    move.l #10, d2
    move.l #59, d4
    move.l #19, d5
    bsr bmp_Draw
    rts
    
Draw_WU:
    lea Wind_Up_Img, a4
    move.l #300, d3
    move.l #10, d2
    move.l #19, d4
    move.l #59, d5
    bsr bmp_Draw
    rts
    
Draw_WD:
    lea Wind_Down_Img, a4
    move.l #300, d3
    move.l #10, d2
    move.l #19, d4
    move.l #59, d5
    bsr bmp_Draw
    rts
    
Draw_WProp:
    lea Mph_Img, a4
    move.l #370, d3
    move.l #10, d2
    move.l #34, d4
    move.l #19, d5
    bsr bmp_Draw
    rts

**RANDOM**
; Calculates the wind direction and speed based on the last 2 bytes of current time     
SetWindSpeed:
    movem.l ALL_REG, -(sp)
    
    ; Get the last 2 bytes of time and extracts wind direction and speed 
    move.b #8, d0
    trap #15
    
    move.l d1, d3
    
    asr.l #8, d3
    and.l #%00000000000000000000000000000011, d3
    move.b d3, WIND_DIRECTION
    
    clr.l d2
    move.b d1, d2
    move.b d2, WIND_SPEED
    divu #100, d2
    move.b d2, WS_100s
    
    mulu #100, d2
    sub.b d2, d1
    move.b d1, d2
    divu #10, d2
    move.b d2, WS_10s
    
    mulu #10, d2
    sub.b d2, d1
    move.b d1, WS_1s
    
    movem.l (sp)+, ALL_REG
    rts
    
Redraw_WS_Symbol:
    movem.l ALL_REG, -(sp)
    
    cmp.b #0, WIND_DIRECTION
    beq .horRedraw
    
    cmp.b #1, WIND_DIRECTION
    beq .horRedraw
    
    cmp.b #2, WIND_DIRECTION
    beq .vertRedraw
    
    cmp.b #3, WIND_DIRECTION
    beq .vertRedraw
    
.vertRedraw:
    ; Redraw background at wind dir bmp
    lea Vertical_Wind_Redraw, a4
    move.l #(295), d3
    move.l #(WS_TOP-5), d2
    move.l #24, d4
    move.l #61, d5
    bsr bmp_Draw
    
    bra .redraw_WindProp
    
.horRedraw:
    ; Redraw background at wind dir bmp
    lea Horizontal_Wind_Redraw, a4
    move.l #(255), d3
    move.l #(WS_TOP-5), d2
    move.l #60, d4
    move.l #24, d5
    bsr bmp_Draw
    
.redraw_WindProp:
    lea Wind_Prop_Redraw, a4
    move.l #(WS_LEFT-5), d3
    move.l #(WS_TOP-5), d2
    move.l #80, d4
    move.l #24, d5
    bsr bmp_Draw
    
    movem.l (sp)+, ALL_REG
    rts
    
DrawWS:
    movem.l ALL_REG, -(sp)

.direction:    
    cmp.b #0, WIND_DIRECTION
    beq .windLeft
    
    cmp.b #1, WIND_DIRECTION
    beq .windRight
    
    cmp.b #2, WIND_DIRECTION
    beq .windUp
    
    cmp.b #3, WIND_DIRECTION
    beq .windDown
    
.windLeft:
    bsr Draw_WL
    bra .speed
    
.windRight:
    bsr Draw_WR
    bra .speed
    
.windUp:
    bsr Draw_WU
    bra .speed
    
.windDown:
    bsr Draw_WD

.speed:    
    move.l #WS_LEFT, d5
    move.b WS_100s, d2
    bsr DrawNum
    
    move.l #(WS_LEFT+14), d5
    move.b WS_10s, d2
    bsr DrawNum
    
    move.l #(WS_LEFT+28), d5
    move.b WS_1s, d2
    bsr DrawNum
    
.metric:
    bsr Draw_WProp
    
    move.b  #94,d0
    trap    #15
    
    movem.l (sp)+, ALL_REG
    rts
    
DrawNum:
    cmp.b #9, d2
    beq .wsdraw9
    cmp.b #8, d2
    beq .wsdraw8
    cmp.b #7, d2
    beq .wsdraw7
    cmp.b #6, d2
    beq .wsdraw6
    cmp.b #5, d2
    beq .wsdraw5
    cmp.b #4, d2
    beq .wsdraw4
    cmp.b #3, d2
    beq .wsdraw3
    cmp.b #2, d2
    beq .wsdraw2
    cmp.b #1, d2
    beq .wsdraw1
    cmp.b #0, d2
    beq .wsdraw0
    
    rts
    
.wsdraw9:
    bsr WS_Draw_9
    rts
    
.wsdraw8:
    bsr WS_Draw_8
    rts

.wsdraw7:
    bsr WS_Draw_7
    rts

.wsdraw6:
    bsr WS_Draw_6
    rts

.wsdraw5:
    bsr WS_Draw_5
    rts
    
.wsdraw4:
    bsr WS_Draw_4
    rts
    
.wsdraw3:
    bsr WS_Draw_3
    rts
    
.wsdraw2:
    bsr WS_Draw_2
    rts
    
.wsdraw1:
    bsr WS_Draw_1
    rts
    
.wsdraw0:
    bsr WS_Draw_0
    rts
    
error
    moveq   #TASK_PRINT, d0
    lea     ErrorLabel, a1
    trap    #15  
    SIMHALT    
    
*---
* Static Variables
*---
ErrorLabel          dc.b 'An error was encountered',0
BackgroundImg       dc.b 'Background_640x480.bmp',0
Player1Img          dc.b 'P1_Throw1.bmp',0
Player2Img          dc.b 'P2_Throw1.bmp',0
WindRightImg        dc.b 'WindRight.bmp',0
WindLeftImg         dc.b 'WindLeft.bmp',0
WindUpImg           dc.b 'WindUp.bmp',0
WindDownImg         dc.b 'WindDown.bmp',0
MphImg              dc.b 'mph.bmp',0
BackgroundMusic     dc.b 'BackgroundMusic.wav',0
P1Laugh             dc.b 'P1_Battle_Laugh.wav',0
P2Laugh             dc.b 'P2_Battle_Laugh.wav',0
Throw               dc.b 'Throw.wav',0
P1Wins              dc.b 'Player1_Wins.wav',0
P2Wins              dc.b 'Player2_Wins.wav',0
Applause            dc.b 'Applause.wav',0
                    * longword aligned memory buffer
                    ds.l    0
StartOfMem
                    dcb.b   HEAP_BYTES,0
EndOfMem
                    dc.l    SENTINEL
Updated_BGM_Img     
                    dcb.b   IMG_MAX_BYTES,0
End_Of_BGM_IMG
                    dc.l    SENTINEL   
Updated_Player1_Img     
                    dcb.b   CHAR_MAX_BYTES,0
End_Of_Player1_Img
                    dc.l    SENTINEL
P1_Throw2Img     
                    dcb.b   CHAR_MAX_BYTES,0
End_Of_P1_Throw2Img
                    dc.l    SENTINEL  
P1_Throw3Img     
                    dcb.b   CHAR_MAX_BYTES,0
End_Of_P1_Throw3Img
                    dc.l    SENTINEL 
P1_Hurt1     
                    dcb.b   CHAR_MAX_BYTES,0
End_Of_P1_Hurt1
                    dc.l    SENTINEL  
P1_Hurt2     
                    dcb.b   CHAR_MAX_BYTES,0
End_Of_P1_Hurt2
                    dc.l    SENTINEL               
Updated_Player2_Img     
                    dcb.b   CHAR_MAX_BYTES,0
End_Of_Player2_Img
                    dc.l    SENTINEL
P2_Throw2Img     
                    dcb.b   CHAR_MAX_BYTES,0
End_Of_P2_Throw2Img
                    dc.l    SENTINEL 
P2_Throw3Img     
                    dcb.b   CHAR_MAX_BYTES,0
End_Of_P2_Throw3Img
                    dc.l    SENTINEL
P2_Hurt1     
                    dcb.b   CHAR_MAX_BYTES,0
End_Of_P2_Hurt1
                    dc.l    SENTINEL 
P2_Hurt2     
                    dcb.b   CHAR_MAX_BYTES,0
End_Of_P2_Hurt2
                    dc.l    SENTINEL                   
Wind_Right_Img     
                    dcb.b   CHAR_MAX_BYTES,0
End_Of_Wind_Right_Img
                    dc.l    SENTINEL
Wind_Left_Img     
                    dcb.b   CHAR_MAX_BYTES,0
End_Of_Wind_Left_Img
                    dc.l    SENTINEL
Wind_Up_Img     
                    dcb.b   CHAR_MAX_BYTES,0
End_Of_Wind_Up_Img
                    dc.l    SENTINEL
Wind_Down_Img     
                    dcb.b   CHAR_MAX_BYTES,0
End_Of_Wind_Down_Img
                    dc.l    SENTINEL                   
Mph_Img     
                    dcb.b   CHAR_MAX_BYTES,0
End_Of_Mph_Img  
                    dc.l    SENTINEL 
P1_Redraw     
                    dcb.b   CHAR_MAX_BYTES,0
End_Of_P1_Redraw  
                    dc.l    SENTINEL 
P2_Redraw     
                    dcb.b   CHAR_MAX_BYTES,0
End_Of_P2_Redraw  
                    dc.l    SENTINEL                    
Player_Win_Redraw    
                    dcb.b   IMG_MAX_BYTES,0
End_Player_Win_Redraw
                    dc.l    SENTINEL                
Player1_Win_Img     
                    dcb.b   WIN_BANNER_MAX_BYTES,0
End_Of_Player1_Win_Img
                    dc.l    SENTINEL    
Player2_Win_Img     
                    dcb.b   WIN_BANNER_MAX_BYTES,0
End_Of_Player2_Win_Img
                    dc.l    SENTINEL 
Start_Screen_Img     
                    dcb.b   WIN_BANNER_MAX_BYTES,0
End_Of_Start_Screen_Img
                    dc.l    SENTINEL 
Start_Screen_Redraw     
                    dcb.b   WIN_BANNER_MAX_BYTES,0
End_Of_Start_Screen_Redraw
                    dc.l    SENTINEL                   
P1WinImg            incbin 'Player1_Win.bmp'
                    dc.l    SENTINEL 
P2WinImg            incbin 'Player2_Win.bmp'
                    dc.l    SENTINEL 
StartScreen         incbin 'Start_Screen.bmp'
                    dc.l    SENTINEL      
Left_Bgm_Redraw_Rect     
                    dcb.b   CHAR_MAX_BYTES,0
End_Left_Bgm_Redraw_Rect                    
                    dc.l    SENTINEL 
Right_Bgm_Redraw_Rect     
                    dcb.b   CHAR_MAX_BYTES,0
End_Right_Bgm_Redraw_Rect                    
                    dc.l    SENTINEL   
Pow_Meter_Left_Redraw     
                    dcb.b   CHAR_MAX_BYTES,0
End_Pow_Meter_Left_Redraw                    
                    dc.l    SENTINEL 
Pow_Meter_Right_Redraw    
                    dcb.b   CHAR_MAX_BYTES,0
End_Pow_Meter_Right_Redraw                    
                    dc.l    SENTINEL                                    
Projectile_Redraw_Rect     
                    dcb.b   CHAR_MAX_BYTES,0
End_Projectile_Redraw_Rect                    
                    dc.l    SENTINEL    
P1_Health_Redraw_Rect     
                    dcb.b   CHAR_MAX_BYTES,0
End_P1_Health_Redraw_Rect                    
                    dc.l    SENTINEL 
P2_Health_Redraw_Rect     
                    dcb.b   CHAR_MAX_BYTES,0
End_P2_Health_Redraw_Rect                    
                    dc.l    SENTINEL 
Horizontal_Wind_Redraw    
                    dcb.b   CHAR_MAX_BYTES,0
End_Horizontal_Wind_Redraw                    
                    dc.l    SENTINEL
Vertical_Wind_Redraw    
                    dcb.b   CHAR_MAX_BYTES,0
End_Vertical_Wind_Redraw                    
                    dc.l    SENTINEL                    
Wind_Prop_Redraw    
                    dcb.b   CHAR_MAX_BYTES,0
End_Wind_Prop_Redraw                    
                    dc.l    SENTINEL
P1Throw2            incbin 'P1_Throw2.bmp'
                    dc.l    SENTINEL
P1Throw3            incbin 'P1_Throw3.bmp'
                    dc.l    SENTINEL
P1Hurt1             incbin 'P1_Hurt_1.bmp'
                    dc.l    SENTINEL 
P1Hurt2             incbin 'P1_Hurt_2.bmp'
                    dc.l    SENTINEL                   
P2Throw2            incbin 'P2_Throw2.bmp'
                    dc.l    SENTINEL
P2Throw3            incbin 'P2_Throw3.bmp'
                    dc.l    SENTINEL
P2Hurt1             incbin 'P2_Hurt_1.bmp'
                    dc.l    SENTINEL 
P2Hurt2             incbin 'P2_Hurt_2.bmp'
                    dc.l    SENTINEL                                  
                                   
Player_1_Img_Prop   dcb.l   NUM_PROPERTIES,0  
Player_2_Img_Prop   dcb.l   NUM_PROPERTIES,0 

Player1_Fire_XCoordinate ds.l    1 
Player1_Fire_YCoordinate ds.l    1 
 
Player2_Fire_XCoordinate ds.l    1 
Player2_Fire_YCoordinate ds.l    1  

P1_Stone_XCoordinate     ds.l    1
P2_Stone_XCoordinate     ds.l    1
Stone_XCoordinate        ds.l    1
Stone_YCoordinate        ds.l    1  
Stone_XVelocity          ds.l    1
Stone_YVelocity          ds.l    1
Stone_X_Initialized      dc.b    0

PROJECTILE_ANGLE         ds.l    1 
PROJECTILE_ACTIVE        dc.b    0

POWER_PERCENT            ds.l    1
POWER_ACTIVE             dc.b    0

CURRENT_PLAYER           dc.b    1
CURRENT_GAMESTART_PLAYER dc.b    1
P1_Health                dc.b    9  
P1_MaxHealth             dc.b    9  
P2_Health                dc.b    9
P2_MaxHealth             dc.b    9 
TURNS_LEFT               dc.b    2 

WIND_DIRECTION           dc.b    0
WIND_SPEED               dc.b    0
WS_X                     dc.l    0
WS_Y                     dc.l    0
WS_100s                  dc.b    0
WS_10s                   dc.b    0
WS_1s                    dc.b    0

GAME_OVER                dc.b    0
GAME_WINNER              dc.b    1


; Sine and Cosine values
cosTable        dc.w    $FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FD,$FC
                dc.w    $FC,$FB,$FA,$F9,$F8,$F7,$F6,$F4,$F3
                dc.w    $F2,$F0,$EE,$ED,$EB,$E9,$E8,$E6,$E4
                dc.w    $E2,$DF,$DD,$DB,$D9,$D6,$D4,$D1,$CF
                dc.w    $CC,$C9,$C6,$C4,$C1,$BE,$BB,$B8,$B5
                dc.w    $B1,$AE,$AB,$A7,$A4,$A1,$9D,$9A,$96
                dc.w    $92,$8F,$8B,$87,$83,$80,$7C,$78,$74
                dc.w    $70,$6C,$68,$64,$5F,$5B,$57,$53,$4F
                dc.w    $4A,$46,$42,$3D,$39,$35,$30,$2C,$28
                dc.w    $23,$1F,$1A,$16,$11,$D,$8,$4,$0
sinTable
                dc.w    $0,$4,$8,$D,$11,$16,$1A,$1F,$23,$28,$2C
                dc.w    $30,$35,$39,$3D,$42,$46,$4A,$4F,$53
                dc.w    $57,$5B,$5F,$64,$68,$6C,$70,$74,$78
                dc.w    $7C,$7F,$83,$87,$8B,$8F,$92,$96,$9A
                dc.w    $9D,$A1,$A4,$A7,$AB,$AE,$B1,$B5,$B8
                dc.w    $BB,$BE,$C1,$C4,$C6,$C9,$CC,$CF,$D1
                dc.w    $D4,$D6,$D9,$DB,$DD,$DF,$E2,$E4,$E6
                dc.w    $E8,$E9,$EB,$ED,$EE,$F0,$F2,$F3,$F4
                dc.w    $F6,$F7,$F8,$F9,$FA,$FB,$FC,$FC,$FD
                dc.w    $FE,$FE,$FF,$FF,$FF,$FF,$FF,$FF                          

    END    START        ; last line of source








*~Font name~Courier New~
*~Font size~14~
*~Tab type~1~
*~Tab size~4~
