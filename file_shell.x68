*-----------------------------------------------------------
* Title      : File IO module
* Written by : 
* Date       : 
* Description: 
*-----------------------------------------------------------

FILE_TASK_FOPEN      EQU     51
FILE_TASK_FCREATE    EQU     52
FILE_TASK_FREAD      EQU     53
FILE_TASK_FWRITE     EQU     54
FILE_TASK_FCLOSE     EQU     56

*---
* Write a buffer to a file
*
* a1 - start address of filename
* a2 - start address of buffer to write
* d1.l - size of buffer to write
*
* out d0.b - 0 for success, non-zero for failure
*---
file_Write:
REGS_TO_SAVE REG a1-a2/d1-d3
    movem.l REGS_TO_SAVE, -(sp)
; Create a new file
    move.l d1, d3 
    move.b #FILE_TASK_FCREATE, d0
    trap #15
    tst.w d0
    bne return_file_write
  
; Write to the file  
    move.b #FILE_TASK_FWRITE, d0
    move.l a2, a1
    move.l d3, d2
    trap #15
    
    move.b #FILE_TASK_FCLOSE, d0
    trap #15
    
return_file_write
    movem.l (sp)+, REGS_TO_SAVE
    rts

*---
* Read a buffer from a file
*
* a1 - start address of filename
* a2 - start address of buffer to read
* d1.l - size of buffer to read
*
* out d1.l - number of bytes read
* out d0.b - 0 for success, non-zero for failure
*---
file_Read:
; Opening the existing source file
    move.b #FILE_TASK_FOPEN, d0
    trap #15
    tst.w d0
    bne return_file_read
    
; Read input file
    move.l a2, a1
    move.l #$200000, d2
    move.b #FILE_TASK_FREAD, d0
    trap #15
    
return_file_read   
    rts
    






*~Font name~Courier New~
*~Font size~14~
*~Tab type~1~
*~Tab size~4~
