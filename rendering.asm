ScreenSze = 38  ; HACK: Please ignore this is 38, for some reason this is required to be this way.

UpdateScroll:
  ; Set x scroll
  LDA playerx
  ; Check x change
  AND #%11111000
  SEC
  SBC lastXpos
  BEQ ++
  ; There was a change
  BPL @positive
;negative
  EOR #$FF
  CLC
  ADC #$01  ; Find two's complement to negate the value
.REPT 3  ; Shift to the right spot
  LSR A
.ENDR
  STA tmp3
  LDA CacheMake
  SEC
  SBC tmp3  ; Subtract the now positive tile count
  STA CacheMake
  JMP ++
@positive:
.REPT 3
  LSR A
.ENDR
  CLC
  ADC CacheMake  ; Add the positive tile count
  STA CacheMake

++
  LDA playerx  ; Update x scroll
  STA $2005
  ; Set y scroll to 0
  LDA #$00
  STA $2005
  ; Update bit 8 of scroll
  LDA playerscrn
  AND #%00000001   ; A = 0000000S
  ORA #PPUCTRLBASE ; A = CCCCCCCS
  STA $2000
  
  LDA playerx
  AND #%11111000
  STA lastXpos

  RTS


; All these macros are faster ways of separating code that will only be used in one spot
; This ust be before DrawCols as it has macros that need to be defined beforehand
  .include "tiles.asm" ;; Includes functions for drawing tiles and stuff


MACRO PointPPU colIdx  ; Writes over A
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

  LDA #$00
  STA $2007  ; First column is offscreen, so we write a 0 to it
ENDM


; Sets Y->0, writes over Y&tmp3&tmp4&tmpPtr
; Uses nxtCol and writes to nxtItPtr
ChkIncNxtItPtr:  ; Check and increase an item pointer (check if need to) in a loop. Continues until next item is not ok.
  LDY #$00
  LDA nxtCol
  AND #%00111110
  STA tmp4  ; tmp4 = Current screen. But, only the part of the screen.
-loop
  LDA (nxtItPtr),Y  ; Load first byte of the previous object
  AND #%00000001
  ORA #%00000010  ; Now should be a number between 2&3 - the number of bytes
  TAY
  LDA (nxtItPtr),Y  ; Load first byte of next object
  AND #%00111110  ; Filter out for the X and screen
  CMP tmp4  ; This only works when going forwards; when going backwards, the objects would be added when they're half a block too early
  BNE +End
  ; The next item is now on screen! (Exactly on the screen edge)
  ; Update nxtItPtr to be the next obj
  STY tmp3
  LDA nxtItPtr
  CLC
  ADC tmp3  ; Now A = nxtItPtr + 2 + (1 if there is a data byte in the object else 0)
  STA nxtItPtr
  BCC +
  LDA nxtItPtr+1
  ADC #$00  ; Propagate the carry
  STA nxtItPtr+1

+ LDY #$00  ; So the next loop will work
  JMP -loop  ; Keep going until the next item is not on the screen edge

+End:
  LDY #$00
  RTS

MACRO ChkIncPrevItPtr  ; Macro as it's only ever used once
Loop:
  LDY #$00
  LDA (prevItPtr),Y

  GetObjMaxX prevItPtr
  CLC
  ADC #$01
  AND #%00011111
  CMP prevCol
  BNE Aft
  ; Object is now offscreen! Increase prevItPtr
-OSLoop  ; Loop over next objects while they overshadow (or don't loop if they don't)
  LDA (prevItPtr),Y  ; Find out how many bytes this object is
  AND #%00000001
  ORA #%00000010  ; A is 2 or 3
  STA tmp2
  LDA prevItPtr
  CLC
  ADC tmp2
  STA prevItPtr
  BNE +
  INC prevItPtr+1  ; It did overflow
+ LDA (prevItPtr),Y
  AND #%01000000
  BNE -OSLoop
  JMP Loop
Aft:
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




MACRO DrawInit
  LDA #32  ; 32 columns per screen
Loop:
  PHA  ; Keep A for later
  LDX nxtCol
  STX tmp1  ; Point to correct column
  JSR ChkIncNxtItPtr  ; Increase nxtItPtr if required.
  PointPPU tmp1  ; Saves having to jump to it again after
  TXA  ; X is unchanged
  ORA #%10000000
  STA tmp1  ; Store column in addition to a 'write directly to the screen' bit
  JSR DrawCol  ; Draw column to the right memory spot
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



MACRO handleDrawingVBLANK
  LDX CacheDrawFrom
Loop1:
  CPX CacheDrawTo
  BEQ End
  INX
  CPX #$07  ; Handle overflow
  BNE +
  LDX #$00
+ LDA $0300,X
  STA vtmp1  ; Use vtmp1 as temp storage for the column index
  PointPPU vtmp1
  ; X is a number from 0-6 labelling which column in cache to use.
  ; Each column in cache has a column index stored at $030? where ? = X (0-6)
  ; The columns are stored in memory as a list of every byte making up the column (28 in total) starting from $0310, $0330, $0350, etc. (but NOTE they're backwards)
  ; This low byte is stored in a table below this macro for ease of use
  TXA
  PHA  ; Store X on the stack, it will be used as the loop counter below
  LDA CacheIdxToAddr,X  ; Now A is the low byte of the address!
  CLC
  ADC #28  ; Draw 28 tiles (30 (screen size) - 2 (2 offscreen tiles))
  TAX
  LDY #28  ; Iterate using Y
Loop2:
  DEX
  STX vtmp1
  LDA $0300,X  ; Load tile
  STA $2007  ; Store tile in PPU
  DEY  ; Point to next tile
  BNE Loop2  ; Keep looping until done all tiles
  PLA  ; Restore X
  TAX
  JMP Loop1
End:
  STX CacheDrawFrom  ; Now hould be equal
ENDM


MACRO drawColMain
  ; Can have a reverse loop (as opposed to the VBLANK handle drawing) as we already know there's at least 1 column to draw
Loop:
  ; At this point A is always the value in CacheMake
  BPL @plus1
;minus
  ; TODO: Decrease item pointers
  JMP +aft
@plus1:
  ChkIncPrevItPtr
  JSR ChkIncNxtItPtr  ; Increase nxtItPtr if required.
  LDA prevCol
  CLC
  ADC #$01
  AND #%00111111
  STA prevCol
  LDA nxtCol
  STA tmp1  ; Point to correct column
  CLC
  ADC #$01
  AND #%00111111
  STA nxtCol

+aft
  JSR DrawCol  ; Draw column to cache

  LDA CacheMake
  BPL @plus2
;minus
  CLC
  ADC #$01
  STA CacheMake
  BNE Loop
  JMP +end
@plus2:
  SEC
  SBC #$01
  STA CacheMake
  BNE Loop
+end
ENDM



DrawCol:
  ; Only used in main
  ; Draws the current column. This uses prev and nxt ItPtrs to calculate the current column, without modifying either.
  ; It writes the column to either $2007 or $03??, specified by tmp1. If the most significant bit of tmp1 is 1, it uses $2007, else it uses $03 CacheDrawTo+Tile and increments CacheDrawTo appending the column data to the cache data thing every column

  LDA tmp1
  AND #%00111110
  STA tmp4  ; Now tmp4 contains only the column index!
  LDX #28  ; 28 visible tiles in a column (30 - 2 invisible extras)
LoopTls:
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
  STA tmp2
+write
  LDA tmp1
  BPL +store03
  LDA tmp2
  STA $2007
  JMP +aft
+store03
  STX tmp3
  LDY CacheDrawTo
  INY
  CPY #$07
  BNE +
  LDY #$00
+ LDA CacheIdxToAddr,Y  ; A is the base address
  CLC
  ADC tmp3
  TAY  ; Y is now the address + the tile row num
  DEY  ; As Y is one too big
  LDA tmp2
  STA $0300,Y
+aft
  DEX
  TXA
  BEQ +end  ; Only quit when all tiles are drawn
  ; This is required as Branch instructions are relative, but this subroutine is so long it becomes out of range
  JMP LoopTls
+end
  LDA tmp1
  BMI +trueEnd
  ; Add the column to the next cache 'which column should it be' place
  LDX CacheDrawTo
  INX
  CPX #$07
  BNE +
  LDX #$00
+ STA $0300,X
  STX CacheDrawTo  ; Now there is 1 more tile to draw!
+trueEnd
  RTS

