*-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------
    ORG    $1000
START:                  ; first instruction of program

ArrayStart
    dc.b A_SEG
    dc.b B_SEG
    ...

SegmentDraws
    dc.l DrawA
    dc.l DrawB
    ...
    dc.l DrawG

int GetSegment(int digit)
    switch(digit)
        case 1:
            return ONE_SEGMENT

void drawDigit(int digit, int top, int left, int size)
    for seg:0->7
        if(mast[digit] & 1 << seg)
            draw[seg]()

DrawA 
    draw line from top left to top right
DrawB
    draw line from top right to mid right    

    END    START        ; last line of source

*~Font name~Courier New~
*~Font size~12~
*~Tab type~1~
*~Tab size~4~
