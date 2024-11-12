*-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------
    ORG    $1000
    
    INCLUDE "file_shell.x68"
    INCLUDE "memory_shell.x68"
    INCLUDE "bitmap.x68"
    
TASK_PRINT    EQU 13

HEAP_BYTES    EQU $500000

IMG_MAX_BYTES EQU $400000

SENTINEL      EQU $deaddead
    
START:                  ; first instruction of program
.initializeHeap:
    lea StartOfMem, a1
    move.l #HEAP_BYTES, d1
    bsr mem_InitHeap
    tst.b d0
    bne .error
    
.load_Image:
    move.l #IMG_MAX_BYTES, d1
    lea BMP_32_Bit, a1
    bsr bmp_Load
    tst d0
    bne .error
    
    move.l a1, a5   ; Caching the allocation address in a5
    
.test_Endianness:
    lea TestAddress, a1
    move.l #$36000000, (a1)
    move.l #4, d7
    bsr bmp_Convert_Endian
    cmp.l #$00000036, (a1)
    bne .error
    
.verify_Image:
    move.l a5, a1
    bsr bmp_Verify  ; After return, d7 will have the bytes per pixel
    tst d0
    bne .error
    
    ; Printing an image(640*980) that can't fit on the screen at the screen origin
    move.l #0, -(sp)
    move.l #0, -(sp)
    move.l #480, -(sp)
    move.l #640, -(sp)
    move.l #0, -(sp)
    move.l #0, -(sp)
    
.update_Image:  
    lea TestAddress, a4  
    bsr bmp_Update_Format
    tst d0
    beq .error
   
.draw_Image:
    bsr bmp_Draw
    bra .complete_32_Bit
        
.error
    moveq   #TASK_PRINT, d0
    lea     ErrorLabel, a1
    trap    #15  
    
    SIMHALT

.complete_32_Bit
    move.l a5, a1
    bsr bmp_Unload
    tst d0
    bne .error
    
*---
* Static Variables
*---
ErrorLabel  dc.b 'An error was encountered',0
BMP_32_Bit  dc.b 'Background_640x480.bmp',0
            * longword aligned memory buffer
            ds.l    0
StartOfMem
            dcb.b   HEAP_BYTES,0
EndOfMem
            dc.l    SENTINEL
TestAddress ds.l 0

    END    START        ; last line of source




*~Font name~Courier New~
*~Font size~12~
*~Tab type~1~
*~Tab size~4~
