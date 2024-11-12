*-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------

*---
* Read an image from a file
*
* a1 - start address of filename
*
* d1 - number of bytes to read
* out a1 - start address of loaded image file
* out d0.b - 0 for success, non-zero for failure
*---
bmp_Load:
    bsr mem_Alloc
    tst.b d0
    bne .fail_Load
    move.l a0, a2
    bsr file_Read
    tst.b d0
    bne .fail_Load
    
    move.l a0, a1   ; Returning the starting address of the allocation
    move.l d2, d1   ; Number of bytes read
    ;bsr mem_Shrink
    
    move.b #0, d0
    rts
    
.fail_Load:
    move.b #1, d0
    rts
 
*---
* Unloads an image file
*
* a1 - start address of image file allocation
*
* out d0.b - 0 for success, non-zero for failure
*---
bmp_Unload:
    bsr mem_Free
    rts

*---
* Converts a value to big endian
*
* a1 - start address of value in litle endian format
* d7 - number of bytes containing the value
*
* out a1 - value in big endian format
* out d0.b - 0 for success, non-zero for failure
*---
bmp_Convert_Endian:
.REGS_TO_SAVE REG a1-a2/d1/d6/d7
    movem.l .REGS_TO_SAVE, -(sp)
    cmp.l #1, d7
    ble .fail_Convert 
    
    move.l a1, a2
    move.l d7, d1
    sub.l #1, d1
    add.l d1, a2    ; Moving a2 to the last bit of value
    
    asr.l #1, d7    ; Number of bytes to reverse
    
.reverseValues:    
    move.b (a1), d6
    move.b (a2), (a1)
    move.b d6, (a2)
    add.l #1, a1
    sub.l #1, a2
    
    sub.l #1, d7
    tst.b d7
    bne .reverseValues
    
    movem.l (sp)+, .REGS_TO_SAVE
    move.b #0, d0
    rts
    
.fail_Convert:
    movem.l (sp)+, .REGS_TO_SAVE
    move.b #1, d0
    rts   
    
*---
* Verifies the signature and bits per pixel of the bmp file
*
* a1 - start address of image file allocation
*
* out d7 - bits per pixel
* out d0.b - 0 for success, non-zero for failure
*--- 
bmp_Verify:
    movem.l a1, -(sp)
    cmp.w #$424D, (a1)  ; Checking the signature
    bne .wrongSignature
    
    add.l #28, a1
    move.l #2, d7
    bsr bmp_Convert_Endian
    
; Only allows 32 bits per pixel bmps    
    cmp.w #$20, (a1)
    beq .verifyComplete
    
    movem.l (sp)+, a1
    move.b #1, d0
    rts

.wrongSignature:
    movem.l (sp)+, a1
    move.b #1, d0
    rts
    
.verifyComplete:
    clr.l d7
    move.w (a1), d7
    movem.l (sp)+, a1
    move.b #0, d0
    rts
    
*---
* Gets a cutout of the image required and saves off the starting address of the 
* updated pixel data
*
* a1 - Start address of updated image format
* a4 - address of rect cutout generated
* d3 - Top left X coordinate   
* d2 - Top left Y coordinate   
* d4 - Width of the rectangle  
* d5 - Height of the rectangle  
*---
bmp_BGM_Cutout:
REG_SAVE REG d0-d7/a0-a6
    movem.l REG_SAVE, -(sp)
    move.l d4, IMAGE_WIDTH
    move.l a1, a2
    move.l d3, INITIAL_IMG_X_COORD
    
.rowLoop:
    move.l IMAGE_WIDTH, d4   ; Resetting number of cols
    move.l INITIAL_IMG_X_COORD, d3  ; Resetting initial x coordinate
    
    move.l #640, d1
    mulu.w #4, d1
    mulu.w d2, d1
    move.l d1, d7
    
.colLoop:
    move.l a2, a1
    move.l d7, d1

    move.l d3, d6
    mulu.w #4, d6
    add.l d6, d1
    add.l d1, a1
    
    move.l (a1), (a4)+
    add.l #1, d3
    sub.l #1, d4
    tst d4
    bne .colLoop
    
    add.l #1, d2
    sub.l #1, d5
    tst d5
    bne .rowLoop

    movem.l (sp)+, REG_SAVE
    rts


**************************************************************************************
*---
* Gets a cutout of the image required and saves off the starting address of the 
* updated pixel data
*
* a1 - start address of image file allocation
* a4 - address of where to store the updated image format
* (sp + 4) - Bottom left X coordinate
* (sp + 8) - Bottom left Y coordinate
* (sp + 12) - Width of the rectangle
* (sp + 16) - Height of the rectange
* (sp + 20) - X coordinate of where to start drawing the rectangle on screen
* (sp + 24) - Y coordinate of where to start drawing the rectangle on screen
*
* out d4 - Updated image width
* out d5 - Updated image height
* out d3 - Screen coordinate X
* out d2 - Screen coordinate Y
* out d0.b - 0 for success, non-zero for failure
*--- 
bmp_Update_Format:
* Imp registers -
* d1 - Image width
* d2 - Image height
* d7 - Bytes per pixel
* d6 - Padding required

    ; Verify file and get bytes per pixel in d7 
    bsr bmp_Verify
    tst.b d0
    bne .failBmpUpdate
    
    clr.l d1
    clr.l d2
    move.b #33, d0
    trap #15    ; Trap task to get the window size
    
    move.w d1, d2   ; Lower word gets the height
    lsr.l #8, d1   
    lsr.l #8, d1    ; Upper word gets the width
    
    ; Saving the screen width & height
    move.l d1, SCREEN_WIDTH 
    move.l d2, SCREEN_HEIGHT
    
    cmp.l 20(sp), d1
    ble .failBmpUpdate  ; If starting x coordinate of where to draw is out of bounds then return a failure
    
    cmp.l 24(sp), d2
    ble .failBmpUpdate  ; If starting y coordinate of where to draw is out of bounds then return a failure
    
    ; Clamp the draw start point's top left coordinates to 0s if they are negative
    sub.l #0, 20(sp)
    bmi .clampScreenX
    sub.l #0, 24(sp)
    bmi .clampScreenY
    
    bra .calcPadding
    
.clampScreenX:
    move.l #0, 20(sp)
    cmp.l #0, 24(sp)
    bpl .calcPadding
    
.clampScreenY:
    move.l #0, 24(sp)
    
.calcPadding
    asr.l #3, d7    ; Number of bytes/pixel
    move.l d7, d6
    move.l a1, a2
    
    add.l #18, a1   ; Image width
    move.l #4, d7
    bsr bmp_Convert_Endian
    move.l (a1), d1 ; Saving image width
    move.l d1, ORIGINAL_IMG_WIDTH
    
    add.l #4, a1
    move.l #4, d7
    bsr bmp_Convert_Endian
    move.l (a1), d2 ; Saving image height
    move.l d2, ORIGINAL_IMG_HEIGHT

    move.l d6, d7   ; Restoring d7 or bytes/pixel
    move.l d7, d0   ; Saving bytes/pixel
    move.l d1, d6
    mulu.w d6, d7
    divu #4, d7
    lsr.l #8, d7
    lsr.l #8, d7
    
    move.l a2, a1   ; Restoring a1 or starting address of image
    
    move.w #4, d6
    sub.w d7, d6    ; Get the padding required
    
    move.l d0, d7   ; Restoring bytes/pixel
    
    cmp.w #4, d6    ; Set padding to 0 if the row length is already divisible by 4
    bne .clampRect
    clr.l d6    
    
.clampRect
    ; Throw an error if the rectangle's width or height is 0
    cmp.l #0, 12(sp)
    beq .failBmpUpdate
    
    cmp.l #0, 16(sp)
    beq .failBmpUpdate

    cmp.l 4(sp), d1
    ble .failBmpUpdate  ; If the rectangle's top left x coordinate is out of bounds then return a failure
    
    cmp.l 8(sp), d2
    ble .failBmpUpdate  ; If the rectangle's top left y coordinate is out of bounds then return a failure
    
    ; Clamp the rectangle's top left point's coordinates to 0s if they are negative
    sub.l #0, 4(sp)
    bmi .clampRectX
    sub.l #0, 8(sp)
    bmi .clampRectY
    
    bra .checkRectDim
    
.clampRectX:
    move.l #0, 4(sp)
    cmp.l #0, 8(sp)
    bpl .checkRectDim
    
.clampRecty:
    move.l #0, 8(sp)
    
.checkRectDim:
    move.l 4(sp), d3
    add.l 12(sp), d3
    
    move.l 8(sp), d4
    add.l 16(sp), d4
    
    cmp.l d3, d1
    blt .adjustRectXDim
    
    cmp.l d4, d2
    blt .adjustRectYDim
    
    bra .screenRect
    
.adjustRectXDim:
    move.l d1, d0
    sub.l 4(sp), d0
    move.l d0, 12(sp)
    
    cmp.l d4, d2
    bge .screenRect
    
.adjustRectYDim:
    move.l d2, d0
    sub.l 8(sp), d0
    move.l d0, 16(sp)
    
.screenRect:
    move.l 20(sp), d3
    add.l 12(sp), d3
    
    move.l 24(sp), d4
    add.l 16(sp), d4
    
    move.l SCREEN_WIDTH, d5
    cmp.l d3, d5
    blt .adjustScreenX
    
    move.l SCREEN_HEIGHT, d5
    cmp.l d4, d5
    blt .adjustScreenY
    
    bra .bmp_write
    
.adjustScreenX:
    move.l SCREEN_WIDTH, d0
    sub.l 20(sp), d0
    move.l d0, 12(sp)
    
    move.l SCREEN_HEIGHT, d5
    cmp.l d4, d5
    bge .bmp_write
    
.adjustScreenY:
    move.l SCREEN_HEIGHT, d0
    sub.l 24(sp), d0
    move.l d0, 16(sp)

.bmp_write:
    ;move.l a1, a2   ; Caching off a1 - start of image allocation
    move.l a4, a5   ; Caching off a4 - start of updated pixel data
    add.l #10, a1   ;offset to pixel array
    move.l d7, d5   ; Caching d7 - bytes per pixel
    move.l #4, d7
    bsr bmp_Convert_Endian
    move.l d5, d7   ; Restoring d7
    
    add.l (a1), a2  ; Setting a2 to the start of the pixel array
    move.l a2, a3   ; Copy of starting address of pixel array
    
    move.l 12(sp), IMAGE_WIDTH   ; Getting the updated value of rectangle width
    move.l 16(sp), IMAGE_HEIGHT   ; Getting the updated value of rectangle height
    
    move.l 8(sp), d3
    sub.l d3, d2
    sub.l #1, d2    if y coordinate is 0 and height is 3, the row in the pixel table will be (3 - 0 - 1)
    move.l d2, 8(sp)    ; Moving the image y coordinate to the corresponding row in the color table
    
    move.l 4(sp), INITIAL_IMG_X_COORD
    move.l 20(sp), INITIAL_SCREEN_X_COORD
    move.l 24(sp), INITIAL_SCREEN_Y_COORD
    
.rowLoop:
    ; Getting the row position in the pixel array
    
    move.l 12(sp), IMAGE_WIDTH  ; Reset number of columns with each row iteration
    move.l ORIGINAL_IMG_WIDTH, d1  ; Resetting d1
    move.l INITIAL_IMG_X_COORD, 4(sp)    ; Restoring the initial image x coordinate for the next row iteration
    move.l INITIAL_SCREEN_X_COORD, 20(sp)   ; Restoring the inital screen x coordinate for the next row iteration
    
    move.l 8(sp), d3
    mulu.w d7, d3
    mulu.w d1, d3
    
    move.l 8(sp), d5
    mulu.w d6, d5
    
    add.l d5, d3
    move.l d3, d4   ; Copy of d3
    
    move.l a3, a2   ; Reset a2 to the start of pixel array
    
.columnLoop:
    move.l a3, a2
    
    ; Getting the column position in the pixel array
    move.l 4(sp), d5
    mulu.w d7, d5
    
    move.l d4, d3   ; Restoring d3 after a column iteration
    
    add.l d5, d3    
    add.l d3, a2
    ;move.l a2, a1
    
    ; Set pen color to the pixel color
    ;bsr read_Color
    ;move.l (a1), d1
    ;lsr.l #8, d1
    ;move.b #80, d0
    ;trap #15 
    
    ; Save off required data to a4
    bsr .setImgColor
    ;move.l (a2), d1
    ;lsr.l #8, d1
    ;move.l d1, (a4)+
    
    ; Draw pixel at screen coordinate
    ;move.l 20(sp), d1
    ;move.l 24(sp), d2
    ;move.b #82, d0
    ;trap #15
    
    sub.l #1, IMAGE_WIDTH
    add.l #1, 4(sp)
    add.l #1, 20(sp)
    
    tst.l IMAGE_WIDTH
    bne .columnLoop
    
    sub.l #1, IMAGE_HEIGHT
    sub.l #1, 8(sp)
    add.l #1, 24(sp) 
    tst.l IMAGE_HEIGHT
    beq .exitRowLoop
    bne .rowLoop
    
.exitRowLoop
    ; Returning address of updated pixel data, image width and height and initial screen coordinates
    move.l a5, a4
    
    move.l 12(sp), d4
    move.l 16(sp), d5
    ;Subtracting 1 from d3 and d4 to follow -1 indexing to use dbf
    sub.l #1, d4  
    sub.l #1, d5
    move.l INITIAL_SCREEN_X_COORD, d3
    move.l INITIAL_SCREEN_Y_COORD, d2  
    move.b #1, d0
    rts
   
.setImgColor:
    move.l a2, a1
    move.b #0, (a4)+
    move.b (a1)+, (a4)+
    move.b (a1)+, (a4)+
    move.b (a1)+, (a4)+
    rts
    
.failBmpUpdate
    move.b #1, d0
    rts
    
**************************************************************************************
*---
* Gets a cutout of the image required and saves off the starting address of the 
* updated pixel data
*
* a1 - start address of image file allocation
* a4 - address of where to store the updated image format
* (sp + 4) - Bottom left X coordinate
* (sp + 8) - Bottom left Y coordinate
* (sp + 12) - Width of the rectangle
* (sp + 16) - Height of the rectange
* (sp + 20) - X coordinate of where to start drawing the rectangle on screen
* (sp + 24) - Y coordinate of where to start drawing the rectangle on screen
*
* out d4 - Updated image width
* out d5 - Updated image height
* out d3 - Screen coordinate X
* out d2 - Screen coordinate Y
* out d0.b - 0 for success, non-zero for failure
*--- 
bmp_Upd_Alpha:
* Imp registers -
* d1 - Image width
* d2 - Image height
* d7 - Bytes per pixel
* d6 - Padding required

    ; Verify file and get bytes per pixel in d7 
    bsr bmp_Verify
    tst.b d0
    bne .failBmpUpdate
    
    clr.l d1
    clr.l d2
    move.b #33, d0
    trap #15    ; Trap task to get the window size
    
    move.w d1, d2   ; Lower word gets the height
    lsr.l #8, d1   
    lsr.l #8, d1    ; Upper word gets the width
    
    ; Saving the screen width & height
    move.l d1, SCREEN_WIDTH 
    move.l d2, SCREEN_HEIGHT
    
    cmp.l 20(sp), d1
    ble .failBmpUpdate  ; If starting x coordinate of where to draw is out of bounds then return a failure
    
    cmp.l 24(sp), d2
    ble .failBmpUpdate  ; If starting y coordinate of where to draw is out of bounds then return a failure
    
    ; Clamp the draw start point's top left coordinates to 0s if they are negative
    sub.l #0, 20(sp)
    bmi .clampScreenX
    sub.l #0, 24(sp)
    bmi .clampScreenY
    
    bra .calcPadding
    
.clampScreenX:
    move.l #0, 20(sp)
    cmp.l #0, 24(sp)
    bpl .calcPadding
    
.clampScreenY:
    move.l #0, 24(sp)
    
.calcPadding
    asr.l #3, d7    ; Number of bytes/pixel
    move.l d7, d6
    move.l a1, a2
    
    add.l #18, a1   ; Image width
    move.l #4, d7
    bsr bmp_Convert_Endian
    move.l (a1), d1 ; Saving image width
    move.l d1, ORIGINAL_IMG_WIDTH
    
    add.l #4, a1
    move.l #4, d7
    bsr bmp_Convert_Endian
    move.l (a1), d2 ; Saving image height
    move.l d2, ORIGINAL_IMG_HEIGHT

    move.l d6, d7   ; Restoring d7 or bytes/pixel
    move.l d7, d0   ; Saving bytes/pixel
    move.l d1, d6
    mulu.w d6, d7
    divu #4, d7
    lsr.l #8, d7
    lsr.l #8, d7
    
    move.l a2, a1   ; Restoring a1 or starting address of image
    
    move.w #4, d6
    sub.w d7, d6    ; Get the padding required
    
    move.l d0, d7   ; Restoring bytes/pixel
    
    cmp.w #4, d6    ; Set padding to 0 if the row length is already divisible by 4
    bne .clampRect
    clr.l d6    
    
.clampRect
    ; Throw an error if the rectangle's width or height is 0
    cmp.l #0, 12(sp)
    beq .failBmpUpdate
    
    cmp.l #0, 16(sp)
    beq .failBmpUpdate

    cmp.l 4(sp), d1
    ble .failBmpUpdate  ; If the rectangle's top left x coordinate is out of bounds then return a failure
    
    cmp.l 8(sp), d2
    ble .failBmpUpdate  ; If the rectangle's top left y coordinate is out of bounds then return a failure
    
    ; Clamp the rectangle's top left point's coordinates to 0s if they are negative
    sub.l #0, 4(sp)
    bmi .clampRectX
    sub.l #0, 8(sp)
    bmi .clampRectY
    
    bra .checkRectDim
    
.clampRectX:
    move.l #0, 4(sp)
    cmp.l #0, 8(sp)
    bpl .checkRectDim
    
.clampRecty:
    move.l #0, 8(sp)
    
.checkRectDim:
    move.l 4(sp), d3
    add.l 12(sp), d3
    
    move.l 8(sp), d4
    add.l 16(sp), d4
    
    cmp.l d3, d1
    blt .adjustRectXDim
    
    cmp.l d4, d2
    blt .adjustRectYDim
    
    bra .screenRect
    
.adjustRectXDim:
    move.l d1, d0
    sub.l 4(sp), d0
    move.l d0, 12(sp)
    
    cmp.l d4, d2
    bge .screenRect
    
.adjustRectYDim:
    move.l d2, d0
    sub.l 8(sp), d0
    move.l d0, 16(sp)
    
.screenRect:
    move.l 20(sp), d3
    add.l 12(sp), d3
    
    move.l 24(sp), d4
    add.l 16(sp), d4
    
    move.l SCREEN_WIDTH, d5
    cmp.l d3, d5
    blt .adjustScreenX
    
    move.l SCREEN_HEIGHT, d5
    cmp.l d4, d5
    blt .adjustScreenY
    
    bra .bmp_write
    
.adjustScreenX:
    move.l SCREEN_WIDTH, d0
    sub.l 20(sp), d0
    move.l d0, 12(sp)
    
    move.l SCREEN_HEIGHT, d5
    cmp.l d4, d5
    bge .bmp_write
    
.adjustScreenY:
    move.l SCREEN_HEIGHT, d0
    sub.l 24(sp), d0
    move.l d0, 16(sp)

.bmp_write:
    ;move.l a1, a2   ; Caching off a1 - start of image allocation
    move.l a4, a5   ; Caching off a4 - start of updated pixel data
    add.l #10, a1   ;offset to pixel array
    move.l d7, d5   ; Caching d7 - bytes per pixel
    move.l #4, d7
    bsr bmp_Convert_Endian
    move.l d5, d7   ; Restoring d7
    
    add.l (a1), a2  ; Setting a2 to the start of the pixel array
    move.l a2, a3   ; Copy of starting address of pixel array
    
    move.l 12(sp), IMAGE_WIDTH   ; Getting the updated value of rectangle width
    move.l 16(sp), IMAGE_HEIGHT   ; Getting the updated value of rectangle height
    
    move.l 8(sp), d3
    sub.l d3, d2
    sub.l #1, d2    if y coordinate is 0 and height is 3, the row in the pixel table will be (3 - 0 - 1)
    move.l d2, 8(sp)    ; Moving the image y coordinate to the corresponding row in the color table
    
    move.l 4(sp), INITIAL_IMG_X_COORD
    move.l 20(sp), INITIAL_SCREEN_X_COORD
    move.l 24(sp), INITIAL_SCREEN_Y_COORD
    
.rowLoop:
    ; Getting the row position in the pixel array
    
    move.l 12(sp), IMAGE_WIDTH  ; Reset number of columns with each row iteration
    move.l ORIGINAL_IMG_WIDTH, d1  ; Resetting d1
    move.l INITIAL_IMG_X_COORD, 4(sp)    ; Restoring the initial image x coordinate for the next row iteration
    move.l INITIAL_SCREEN_X_COORD, 20(sp)   ; Restoring the inital screen x coordinate for the next row iteration
    
    move.l 8(sp), d3
    mulu.w d7, d3
    mulu.w d1, d3
    
    move.l 8(sp), d5
    mulu.w d6, d5
    
    add.l d5, d3
    move.l d3, d4   ; Copy of d3
    
    move.l a3, a2   ; Reset a2 to the start of pixel array
    
.columnLoop:
    move.l a3, a2
    
    ; Getting the column position in the pixel array
    move.l 4(sp), d5
    mulu.w d7, d5
    
    move.l d4, d3   ; Restoring d3 after a column iteration
    
    add.l d5, d3    
    add.l d3, a2
    ;move.l a2, a1
    
    ; Set pen color to the pixel color
    ;bsr read_Color
    ;move.l (a1), d1
    ;lsr.l #8, d1
    ;move.b #80, d0
    ;trap #15 
    
    ; Save off required data to a4
    bsr .checkAlpha
    ;move.l (a2), d1
    ;lsr.l #8, d1
    ;move.l d1, (a4)+
    
    ; Draw pixel at screen coordinate
    ;move.l 20(sp), d1
    ;move.l 24(sp), d2
    ;move.b #82, d0
    ;trap #15
    
    sub.l #1, IMAGE_WIDTH
    add.l #1, 4(sp)
    add.l #1, 20(sp)
    
    tst.l IMAGE_WIDTH
    bne .columnLoop
    
    sub.l #1, IMAGE_HEIGHT
    sub.l #1, 8(sp)
    add.l #1, 24(sp) 
    tst.l IMAGE_HEIGHT
    beq .exitRowLoop
    bne .rowLoop
    
.exitRowLoop
    ; Returning address of updated pixel data, image width and height and initial screen coordinates
    move.l a5, a4
    
    move.l 12(sp), d4
    move.l 16(sp), d5
    ;Subtracting 1 from d3 and d4 to follow -1 indexing to use dbf
    sub.l #1, d4  
    sub.l #1, d5
    move.l INITIAL_SCREEN_X_COORD, d3
    move.l INITIAL_SCREEN_Y_COORD, d2  
    move.b #1, d0
    rts
   
.checkAlpha:
    move.l a2, a6
    add.l #3, a6
    cmp.b #0, (a6)
    beq .setBGColor

.setImgColor:
    move.l a2, a1
    move.b #0, (a4)+
    move.b (a1)+, (a4)+
    move.b (a1)+, (a4)+
    move.b (a1)+, (a4)+
    rts

.setBGColor:   
    move.l 24(sp), d1
    move.l 28(sp), d2
    move.b #83, d0
    trap #15
    move.l d0, (a4)+
    rts
    
.failBmpUpdate
    move.b #1, d0
    rts    
    
    
*---
* Draws a rectangular cutout of the image to the screen
*
* a4 - address of the updated image format
* d4 - Image width
* d5 - Image height
* d3 - Screen coordinate X
* d2 - Screen coordinate Y
*
*--- 
bmp_Draw:
    move.w d4, d6   ; Saving image width
    move.w d3, d7   ; Saving x coordinate
.rowLoop:
    move.w d6, d4
    move.w d7, d3
.colLoop:
    ; Set pen color to the pixel color
    move.l (a4)+, d1
    moveq #80, d0
    trap #15 
    
    ; Draw pixel at screen coordinate
    move.w d3, d1
    moveq #82, d0
    trap #15
    
    add.w #1, d3
    
    dbf d4, .colLoop
    
    add.w #1, d2 
    dbf d5, .rowLoop
    
.exitRowLoop
   rts
  
SCREEN_WIDTH           dc.l 0
SCREEN_HEIGHT          dc.l 0
ORIGINAL_IMG_WIDTH     dc.l 0
ORIGINAL_IMG_HEIGHT    dc.l 0
IMAGE_WIDTH            dc.l 0
IMAGE_HEIGHT           dc.l 0
INITIAL_IMG_X_COORD    dc.l 0
INITIAL_SCREEN_X_COORD dc.l 0
INITIAL_SCREEN_Y_COORD dc.l 0







*~Font name~Courier New~
*~Font size~12~
*~Tab type~1~
*~Tab size~4~
