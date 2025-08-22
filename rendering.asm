ScreenSze = 38  ; HACK: Please ignore this is 38, for some reason this is required to be this way.

UpdateScroll:
; TODO: Add to queue instead of calling subroutine directly
  ; Set x scroll
  LDA playerx
  ; Check x change
  AND #%11111000
  SEC
  SBC lastXpos
  BEQ ++
  ; There was a change
  BPL @plus
; If going backwards
  EOR #$FF
  CLC
  ADC #$01  ; Negate the value (get two's complement) so it always draws tiles forwards
.REPT 3
  LSR A
.ENDR
  STA tmp1  ; Store the amount of x change to fix next update
  LDA #%10000001  ; It is decreasing and is NOT initialisation
  STA tmp2
  LDA nxtCol
  SEC
  SBC #ScreenSze + Offset  ; The next column to update should now be the old index (right side of the screen) - the screen size (32 columns)
  STA nxtCol      ; This needed to be changed so it would be adding columns to the left side of the screen. Due to the decreasing bit being set, everything else is ok
  JSR DrawCol
  LDA nxtCol  ; Now increase by screen size (32) to find the new nxtCols index! (should be old index - amount of tiles drawn)
  CLC
  ADC #ScreenSze + Offset
  STA nxtCol
  JMP +aftdraw
@plus:
.REPT 3
  LSR A
.ENDR
  STA tmp1  ; Store the amount of x change to fix next update
  LDA #%00000001  ; It is not decreasing and is NOT initialisation
  STA tmp2
  JSR DrawCol
+aftdraw
  LDA playerx  ; Now we update lastXpos and x scroll
  STA $2005
  AND #%11111000
  STA lastXpos
  JMP +next

++  ; Change happened within a tile, not across multiple tiles
  LDA $2002  ; read PPU status to reset the high/low latch
  LDA playerx  ; Update x scroll
  STA $2005
+next
  ; Set y scroll to 0
  LDA #$00
  STA $2005
  ; Update bit 8 of scroll
  LDA playerscrn
  AND #%00000001   ; A = 0000000S
  ORA #PPUCTRLBASE ; A = CCCCCCCS
  STA $2000
  
  RTS


; All these macros are faster ways of separating code that will only be used in one spot
; This ust be before DrawCols as it has macros that need to be defined beforehand
  .include "tiles.asm" ;; Includes functions for drawing tiles and stuff


MACRO PointPPU colIdx  ; Writes over A
  LDA $2002  ; read PPU status to reset the high/low latch

  ; Get pointer value
  ; High byte
  LDA colIdx
  AND #%00100000
  BEQ +
  LDA #$24  ; is a 1 - use 2nd page
  JMP +next
+ LDA #$20  ; is a 0 - use 1st page
+next
  STA $2006
  ; Low byte
  LDA colIdx
  AND #%00011111
  STA $2006

  ; TODO: Can we just start 32 blocks down instead of writing a blank?
  LDA #$00
  STA $2007  ; First column is offscreen, so we write a 0 to it
ENDM


; Assumes Y=0, writes over X&tmp3&tmp4&tmpPtr
MACRO ChkIncItPtr itPtr,colIdx  ; Check and increase an item pointer (check if need to) in a loop. Continues until next item is not ok.
  LDA colIdx
  AND #%00111110
  STA tmp4  ; tmp4 = Current screen. But, only the part of the screen.
Start:
  LDA (itPtr),Y  ; Load first byte of the previous object
  AND #%00000001
  ORA #%00000010  ; Now should be a number between 2&3 - the number of bytes
  TAY
  LDA (itPtr),Y  ; Load first byte of next object
  AND #%00111110  ; Filter out for the X and screen
  CMP tmp4  ; This only works when going forwards; when going backwards, the objects would be added when they're half a block too early
  BNE End
  ; The next item is now on screen! (Exactly on the screen edge)
  ; Update itPtr to be the next obj
  STY tmp3
  LDA itPtr
  CLC
  ADC tmp3  ; Now A = itPtr + 2 + (1 if there is a data byte in the object else 0)
  STA itPtr
  BCC +
  LDA itPtr+1
  ADC #$00  ; Propagate the carry
  STA itPtr+1

+ LDY #$00  ; So the next loop will work
  JMP Start  ; Keep going until the next item is not on the screen edge

End:
  LDY #$00
ENDM


; Decrease the temp item pointer by 1 item.
; Assumes Y=0, writes over X or Y, tmp3 and tmpPtr. tmpPtr becomes the pointer to the previous item and X&tmp3 become the amount of bytes-1
UseX = 1
MACRO DecTmpItPtr
  LDA tmpPtr
  BNE +
  DEC tmpPtr+1
+ DEC tmpPtr
  ; Load last value of previous byte
  LDA (tmpPtr),Y
  AND #%11110000
  CMP #%11110000
IF UseX==1
  BEQ +
  LDX #$01
  JMP +aft
+ LDX #$02
+aft
  STX tmp3
ELSE
  BEQ +
  LDY #$01
  JMP +aft
+ LDY #$02
+aft
  STY tmp3
ENDIF
  SEC
  LDA tmpPtr
  SBC tmp3
  STA tmpPtr
  LDA tmpPtr+1
  SBC #$00
  STA tmpPtr+1
ENDM

ChkDecItPtrRout:  ; Is the routine internals for the ChkDecItPtr. This is a subroutine.
  DecTmpItPtr  ; Sets X
  INX  ; Now X is correct

  LDA tmp1
  AND #%00111110
  STA tmp3  ; tmp3 = Current screen. But, only the part of the screen. 

  LDA (tmpPtr),Y
  AND #%00111111  ; So if it ends with 1 then it won't work
  CMP tmp3
  BEQ ChkDecItPtrRout  ; Keep going while the objects are on the edge of the screen
  RTS  ; TODO: Check length; keep going down while object x + length is on the left, not just x

; Assumes Y=0, writes over X,tmp1,tmp3 and tmpPtr
MACRO ChkDecItPtr itPtr,colIdx  ; Check and decrease an item pointer (check if need to) in a loop. Continues until next item is not ok.
  ; TODO: Every loop, it decrements tmpItPtr and only if it was successful does it then update itPtr. It updates itPtr every loop. This means we don't have to un-add it later.
  LDA itPtr
  STA tmpPtr
  LDA itPtr+1
  STA tmpPtr+1

  LDA colIdx
  STA tmp1  ; Store colIdx in tmp1 for use in the routine
  JSR ChkDecItPtrRout
  ; Object is not correct, so now go back.
  STX tmp3
  LDA tmpPtr
  CLC
  ADC tmp3
  STA itPtr
  LDA tmpPtr+1
  ADC #$00  ; Propagate carry
  STA itPtr+1
ENDM


Other:

  ; Store tmp1 to the stack before running this so tmp1 is free (tmp2 is still used)
  LDA tmp1
  PHA
  ; Handle next code differently if going forwards or backwards
  LDA tmp2
  BPL +positive
;negative
  ; Decrease 1 from both pointers
  ; We do not need to check for initialisation here as in initialisation it only generates forwards
  ChkDecItPtr prevItPtr,prevCol
  ChkDecItPtr nxtItPtr,nxtCol

  JMP +nxt
+positive
  ; Check for initialisation (everything is 0) (tmp2 is still loaded)
  BEQ +  ; Skip increasing backward pointer if initialisation
  ; Add 1 to both pointers
  ; TODO: Make ChkIncItPtr not a macro. Also, for prevItPtr, do not just increase it when the next column increases but instead increase it when the next object is 1 column offscreen. Make a macro in tilles.asm for getting the tile width.
  ;ChkIncItPtr prevItPtr,prevCol  ; Increase prevItPtr if required
+ ChkIncItPtr nxtItPtr,nxtCol  ; Increase nxtItPtr if required
+nxt

  LDA tmp2  ; Now store tmp2
  PHA

  BPL +
  LDA prevCol
  JMP +aft
+ LDA nxtCol
+aft
  AND #%00111110
  STA tmp2  ; tmp2 now contains the column index



MACRO handleDrawingVBLANK
  LDX CacheDrawFrom
Loop1:
  CPX CacheDrawTo
  BEQ End
  INX
  LDA $0300,X
  STA vtmp1  ; Use vtmp1 as temp storage for the column index
  PointPPU vtmp1
  ; X is a number from 0-6 labelling which column in cache to use.
  ; Each column in cache has a column index stored at $030? where ? = X (0-6)
  ; The columns are stored in memory as a list of every byte making up the column (28 in total) starting from $0310, $0330, $0350, etc.
  ; This low byte is stored in a table below this macro for ease of use
  TXA
  PHA  ; Store X on the stack, it will be used as the loop counter below
  LDY CacheIdxToAddr,X  ; Now Y is the low byte of the address!
  LDX #28  ; Draw 28 tiles (30 (screen size) - 2 (2 offscreen tiles))
Loop2:
  LDA ($0300),Y  ; Load tile
  STA $2007  ; Store tile in PPU
  INY  ; Point to next tile
  DEX
  CPX #00
  BNE Loop2  ; Keep looping until done all tiles
  JMP Loop1
End:
  STX CacheDrawFrom  ; Now hould be equal
ENDM
; This table will end up far away from the code but oh well, doesn't affect anything
CacheIdxToAddr:
  .db $10, $30, $50, $70, $90, $B0, $D0



MACRO DrawInit
  ; A is the amount of columns to increment by
Loop:
  PHA  ; Keep A for later
  ChkIncItPtr nxtItPtr,nxtCol  ; Increase nxtItPtr if required
  PointPPU nxtCol
  LDA nxtCol
  ORA #%10000000
  STA tmp1
  JSR DrawCol  ; Draw column
  LDA nxtCol  ; Now increase column idx
  CLC
  ADC #$01
  AND #%00111111  ; And ensure it doesn't overflow
  STA nxtCol
  PLA  ; Get A back again for checking in the loop
  SEC
  SBC #$01
  BNE Loop
ENDM


MACRO drawColMain
  ; Can have a reverse loop (as opposed to the VBLANK handle drawing) as we already know there's at least 1 column to draw
Loop:
  ; TODO: Do stuff here
  INX
  CPX CacheMakeTo
  BNE Loop
ENDM


DrawCol:
  ; Only used in main
  ; Draws the current column. This uses prev and nxt ItPtrs to calculate the current column, without modifying either.
  ; It writes the column to either $2007 or $03??, specified by tmp1. If the most significant bit of tmp1 is 1, it uses $2007, else it uses $03 tmp1

  LDX #28  ; 28 visible tiles in a column (30 - 2 invisible extras)
  LDA tmp1
  AND #%00111110
  STA tmp4  ; Now tmp4 contains only the column index!
LoopTls:
  LDA #$00
  STA tmp2
  LDA nxtItPtr+1
  STA tmpPtr+1
  LDA nxtItPtr
  STA tmpPtr

  ; Check if it's equal right now to ensure nothing bad happens when 0 items are on-screen
  CMP prevItPtr
  BNE LoopIts
  LDA tmpPtr+1
  CMP prevItPtr+1
  BNE LoopIts  ; If end != start, continue
  JMP +cont  ; Because HandleTile is so big

LoopIts:  ; Loop over every item on-screenish backwards (later items override previous ones)
  HandleTile  ; Macro defined in tiles.asm
  LDA tmp2
  BNE +write
  ; If is still 0, decrease then check if temp pointer is still greater than the initial; and if so, keep looping
  LDY #$00  ; Requires Y=0
  UseX = 0  ; Go clobber Y instead of my precious X!
  DecTmpItPtr
  UseX = 1
  ; Check if tmpPtr <= prevItPtr
  LDA tmpPtr+1  ; compare high bytes
  CMP prevItPtr+1
  BCC +cont ; if tmpPtr+1 < prevItPtr+1 then tmpPtr < prevItPtr so exit loop
  BNE +loopIts ; if tmpPtr+1 != prevItPtr+1 then tmpPtr > prevItPtr so continue
  LDA tmpPtr  ; compare low bytes
  CMP prevItPtr
  BEQ +cont  ; if tmpPtr+0 == prevItPtr+0 then tmpPtr == prevItPtr so exit
  BCS +loopIts ; if tmpPtr+0 > prevItPtr+0 then tmpPtr > prevItPtr so continue
  JMP +cont
+loopIts  ; Because HandleTile is so fat
  JMP LoopIts

+cont
  LDA #$02  ; If no object wants it, draw a blank (changed for testing)
+write
  BIT tmp1
  BPL +store03
  STA $2007
  JMP +aft
+store03
  INC tmp1
  LDY tmp1
  STA ($0300),Y
+aft
  DEX
  TXA  ; Keep going until all tiles are drawn
  BEQ +end
  ; This is required as Branch instructions are relative, but this subroutine is so long it becomes out of range
  JMP LoopTls
+end
  RTS

