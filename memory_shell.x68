*-----------------------------------------------------------
* Title      : Memory management module
* Written by : 
* Date       : 
* Description: 
*-----------------------------------------------------------

* constants for callers of mem_Audit
MEM_AUDIT_OFFS_FREE_CNT     EQU 0
MEM_AUDIT_OFFS_USED_CNT     EQU 4
MEM_AUDIT_OFFS_FREE_MEM     EQU 8
MEM_AUDIT_OFFS_USED_MEM     EQU 12
MEM_AUDIT_RETURN_SIZE       EQU 16

* constants for header struct (internal)
MEM_HEADER_SIZE EQU 8 * !!! update this value based on your header layout
MEM_OFFSET_SIZE EQU 0
MEM_NEXT        EQU 4

*---
* Initializes the start of the heap
* 
* a1 - start address of heap
* d1.l - size of heap
*
* out d0.b - 0 = success, non-zero = failure
*---
mem_InitHeap:
    cmp.l #MEM_HEADER_SIZE, d1
    ble .mem_Init_Fail

    move.l a1, START_OF_HEAP
    sub.l #MEM_HEADER_SIZE, d1
    neg.l d1
    
    move.l d1, MEM_OFFSET_SIZE(a1)
    move.l #0, MEM_NEXT(a1)
    
    move.b #0, d0
    rts
    
.mem_Init_Fail
    move.b #1, d0
    rts

*---
* Accumulates some statistics for memory usage
*
* out d0.b - 0 = success, non-zero = error
* out (sp) - count of free blocks
* out (sp+4) - count of used blocks
* out (sp+8) - total remaining free memory
* out (sp+12) - total allocated memory
mem_Audit:
; d1 - count of free blocks
; d2 - count of used blocks
; d3 - total free memory
; d4 - total allocated memory
.REGS_TO_SAVE REG a2-a3/d1-d5
    movem.l .REGS_TO_SAVE, -(sp)
    move.l START_OF_HEAP, a3
; Initializing variables
    move.l #0, d1
    move.l #0, d2
    move.l #0, d3
    move.l #0, d4
    
.mem_Loop:
    move.l (a3), d5
    asl.l #1, d5    ; Checking if block is unused
    bcc .updateUsedBlocks
    
.updateFreeBlocks:
    add.l #1, d1    ; Adding 1 to the number of free blocks
    move.l (a3), d5 
    neg.l d5
    add.l d5, d3    ; Adding the size of the block to the total free size
    bra .iterate_Mem_Loop 
    
.updateUsedBlocks:
    add.l #1, d2    ; Adding 1 to the number of used blocks
    add.l (a3), d4  ; Adding the size of the block to the total used size

.iterate_Mem_Loop:
    add.l #MEM_NEXT, a3  
    cmp.l #0, (a3)
    beq .mem_Audit_Complete
    move.l (a3), a3 ; Set a3 to the next block of the heap
    bra .mem_Loop
    
.mem_Audit_Complete:
    add.l #44, sp   ; Moving down the stack to the point where registers were saved and setting output variables
    move.l d4, (sp)
    move.l d3, -(sp)
    move.l d2, -(sp)
    move.l d1, -(sp)
    sub.l #32, sp   ; Moving back up the stack to the point where registers were saved
    movem.l (sp)+, .REGS_TO_SAVE
    move.b #0, d0
    rts
          
*---
* Allocates a chunk of memory from the heap
*
* d1.l - size
*
* out a0 - start address of allocation
* out d0.b - 0 = success, non-zero = failure
*---
mem_Alloc:
.REGS_TO_SAVE REG a2-a3/d2-d3
    movem.l .REGS_TO_SAVE, -(sp)
    ;lea START_OF_HEAP, a2
    ;move.l (a2), a3 ; START_OF_HEAP contains the address to the address of the actual start of heap
    move.l START_OF_HEAP, a3
    
.mem_Loop:
    move.l (a3), d2
    asl.l #1, d2    ; Checking if block is unused
    bcc .iterate_Mem_Loop
    
.checkAvailableSpace:
    move.l (a3), d2
    neg.l d2
    cmp.l d1, d2
    bge .initialize_Block
    blt .fail_Mem_Alloc
    bra .iterate_Mem_Loop
    
.iterate_Mem_Loop:  
    add.l #MEM_NEXT, a3
    cmp.l #0, (a3)
    beq .fail_Mem_Alloc
    move.l (a3), a3 ; Set a3 to the next block of the heap
    bra .mem_Loop
    
.initialize_Block:
    sub.l d1, d2
    cmp.l #MEM_HEADER_SIZE, d2
    ble .alloc_Rem_Block  ; If the requested block size is less than the remaining heap size - header
                          ; then we allocate only the required size, else we allocate the entire remaining block
    
; Setting up the requested block
    move.l d1, (a3) ; Setting the size of the block
    add.l #MEM_NEXT, a3
    
    move.l a3, d3
    add.l #MEM_NEXT, d3
    move.l d3, a0   ; Save off start address of allocation to return
    add.l d1, d3
    move.l d3, (a3)
    move.l d3, a3   ; Move to the next block
    
; Setting up the remaining block
    move.l d2, (a3)
    sub.l #MEM_HEADER_SIZE, (a3)    ; Subtract header size
    neg.l (a3)  ; Negate to indicate empty block
    add.l #MEM_NEXT, a3
    move.l #0, (a3)
    
    move.b #0, d0
    movem.l (sp)+, .REGS_TO_SAVE
    rts
    
.alloc_Rem_Block:
    move.l d1, (a3)
    add.l d2, (a3)  ; Allocating the entire remaining block
                    ; Not subtracting the header size since we're using the original header
    
    add.l #MEM_NEXT, a3
    move.l #0, (a3)
    
    add.l #MEM_NEXT, a3
    move.l a3, a0   ; Save off start address of allocation to return
    
    move.b #0, d0
    movem.l (sp)+, .REGS_TO_SAVE
    rts
    
.fail_Mem_Alloc:
    move.b #1, d0
    movem.l (sp)+, .REGS_TO_SAVE
    rts
    
*---
* Retrieves the size of the allocation
*
* a0 - starting address of allocation
*
* out d1 - size of allocation
* out d0.b - 0 = success, non-zero = failure
*---
mem_GetSize:
    sub.l #MEM_NEXT, a0
    sub.l #MEM_NEXT, a0
    move.l (a0), d1
    
    move.l #0, d0
    rts 
    
*---
* Frees a chunk of memory from the heap
*
* a1 - start address of allocation
*
* out d0.b - 0 = success, non-zero = failure
*---
mem_Free:
    sub.l #MEM_HEADER_SIZE, a1
    
    move.l (a1), d1
    asl.l #1, d1
    bcs .fail_Mem_Free  ; If the block is already free, then return an error
    
    neg.l (a1)
    
    move.l START_OF_HEAP, a1
    add.l #MEM_HEADER_SIZE, a1
    bsr mem_Coalesce
    
    move.b #0, d0
    rts
    
.fail_Mem_Free:
    move.b #1, d0
    rts
    
*---
* Reduces a current memory allocation to a smaller number of bytes
*
* a1 - start address of allocation
* d1.l - new size
* 
* out a0 - address of newly created free memory
* out d0.b - 0 = success, non-zero = failure
mem_Shrink:
.REGS_TO_SAVE REG a1-a2/d1-d3
    movem.l .REGS_TO_SAVE, -(sp)
    sub.l #MEM_HEADER_SIZE, a1
    move.l (a1), d2
    sub.l d1, d2
    cmp.l #MEM_HEADER_SIZE, d2  ; If the remaining size after splitting the block is less than or equal to the header size, then return a failure
    ble .fail_Mem_Shrink
    
; Allocate the smaller block    
    move.l d1, (a1)
    add.l #MEM_NEXT, a1
    move.l (a1), a2   ; Saving off the original next pointer 
    move.l a1, d3
    add.l #MEM_NEXT, d3
    add.l d1, d3
    move.l d3, (a1)
    move.l d3, a1   ; Move to the next block
    
; Setup the free block
    move.l d2, (a1)
    sub.l #MEM_HEADER_SIZE, (a1)
    neg.l (a1)
    add.l #MEM_NEXT, a1
    move.l a2, (a1)
    add.l #MEM_NEXT, a1
    move.l a1, a0   ; Return value of the address of the new free block
    
    move.l START_OF_HEAP, a1
    add.l #MEM_HEADER_SIZE, a1
    bsr mem_Coalesce
    
    move.b #0, d0
    movem.l (sp)+, .REGS_TO_SAVE
    rts
    
.fail_Mem_Shrink:
    move.b #1, d0
    movem.l (sp)+, .REGS_TO_SAVE
    rts
    
*---
* Coalesces free memory blocks
*
* a1 - address of first allocation to consider
*
* out d0.b - 0 = success, non-zero = failure
*---    
mem_Coalesce:
    movem.l a1-a2/d1-d4, -(sp)
    sub.l #MEM_HEADER_SIZE, a1
    
.mem_Loop:
    move.l (a1), d2
    asl.l #1, d2    ; Checking if block is free
    bcc .iterate_Mem_Loop  

.initialize_Loop:    
    move.l (a1), d2
    neg.l d2
    move.l a1, a2   ; Caching the address of the first free block found
    move.l #1, d3   ; Current number of free blocks
    
.free_Block_Loop:
    add.l #MEM_NEXT, a2 
    cmp.l #0, (a2)
    beq .lastBlock
    move.l (a2), a2
    move.l (a2), d4
    asl.l #1, d4 
    bcs .updateFreeBlocks
    bra .check_If_Needed
    
.updateFreeBlocks:
    add.l #1, d3
    move.l (a2), d4
    neg.l d4
    add.l d4, d2
    add.l #MEM_HEADER_SIZE, d2
    bra .free_Block_Loop
    
.lastBlock:
    sub.l #MEM_NEXT, a2
    cmp.l #1, d3
    bgt .coalesce_Blocks   
    
.check_If_Needed:
    cmp.l #1, d3 
    bgt .coalesce_Blocks
    add.l #MEM_NEXT, a2
    move.l (a2), a1
    add.l #MEM_NEXT, a1
    bra .iterate_Mem_Loop
 
.coalesce_Blocks:
    move.l d2, (a1)
    neg.l (a1)    
    add.l #MEM_NEXT, a2
    add.l #MEM_NEXT, a1
    move.l (a2), (a1)

.iterate_Mem_Loop: 
    cmp.l #0, (a1)
    beq .return_Mem_Coalesce
    move.l (a1), a1 ; Set a1 to the next block of the heap
    bra .mem_Loop 
 
.return_Mem_Coalesce:
    movem.l (sp)+, a1-a2/d1-d4
    move.b #0, d0
    rts    
    
START_OF_HEAP   ds.l 1




*~Font name~Courier New~
*~Font size~14~
*~Tab type~1~
*~Tab size~4~
