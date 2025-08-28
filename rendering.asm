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
  ; A is already colIdx
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


;-------------------------------------------------------------------------------------

; Sets Y->0, writes over Y&tmp1&tmp2&tmpPtr
; Uses nxtCol and writes to nxtItPtr
ChkIncNxtItPtr:  ; Check and increase an item pointer (check if need to) in a loop. Continues until next item is not ok.
  LDY #$00
  LDA nxtCol
  AND #%00111110
  STA tmp2  ; tmp2 = Current screen. But, only the part of the screen.
-loop
  LDA (nxtItPtr),Y  ; Load first byte of the previous object
  AND #%00000001
  ORA #%00000010  ; Now should be a number between 2&3 - the number of bytes
  TAY
  LDA (nxtItPtr),Y  ; Load first byte of next object
  AND #%00111110  ; Filter out for the X and screen
  CMP tmp2  ; This only works when going forwards; when going backwards, the objects would be added when they're half a block too early
  BNE +End
  ; The next item is now on screen! (Exactly on the screen edge)
  ; Update nxtItPtr to be the next obj
  STY tmp1
  LDA nxtItPtr
  CLC
  ADC tmp1  ; Now A = nxtItPtr + 2 + (1 if there is a data byte in the object else 0)
  STA nxtItPtr
  BCC +
  INC nxtItPtr+1
+ LDY #$01
  LDA (nxtItPtr),Y  ; Load Y value of object
  AND #$0F
  CMP #$0F  ; Check if it's a floor pattern
  BEQ @FP
  LDY #$00  ; So the next loop will work
  JMP -loop  ; Keep going until the next item is not on the screen edge
@FP:
  LDY #$02
  LDA (nxtItPtr),Y
  AND #$0F  ; This is the new floor pattern!
  STA nxtFP
  LDY #$00
  JMP -loop  ; Continue looping

+End:
  LDY #$00
  RTS



MACRO ChkIncPrevItPtr  ; Macro as it's only ever used once
  LDA prevCol
  AND #%00111110
  STA tmp1
Loop:
  LDY #$00
  LDA (prevItPtr),Y  ; Find out how many bytes this object is
  AND #%00000001
  ORA #%00000010  ; A is 2 or 3
  STA tmp2
  TAY
  LDA (prevItPtr),Y  ; Get next object's first byte
  TAX
  BMI @OneWide
  AND #%00000001
  BEQ @Struct
;Horizontal
  TXA
  AND #%00100000
  STA tmp3
  INY  ; Add 2 to Y to get data byte
  INY
  LDA (prevItPtr),Y
  AND #$0F  ; Lower 4 bits; the x+width
  ASL
  ORA tmp3  ; Combine with screen bit from earlier
  JMP @Aft1
@Struct:
  ; TODO: This
@OneWide:  ; Vertical or single
  INY  ; Get Y position byte
  LDA (prevItPtr),Y
  AND #$0F
  CMP #$0F  ; If y position == $F, is a floor pattern
  BNE @cont
  ; Floor patterns!
  LDA (prevItPtr),Y  ; Load the same byte again, but this time get the top 4 bits instead of the bottom 4
.REPT 4
  LSR
.ENDR
  STA prevFP
@cont:
  TXA
  AND #%00111110

@Aft1:
  CLC
  ADC #$02
  AND #%00111110
  CMP tmp1
  BNE Aft2
  ; Object is now offscreen! Increase prevItPtr
  LDY #$00
-OvSLoop  ; Loop over next objects while they overshadow (or don't loop if they don't)
  ; Increase prev item ptr first
  LDA prevItPtr
  CLC
  ADC tmp2
  STA prevItPtr
  BCC +
  INC prevItPtr+1  ; It did overflow
+ ; Check if it overshadows
  LDA (prevItPtr),Y
  AND #%01000000
  BEQ +loop  ; If it is not overshadowing, continue the main loop
  LDY #$01  ; Find if it's a floor pattern
  LDA (prevItPtr),Y
  AND #$0F
  CMP #$0F
  BNE +
  ; Floor pattern!
  LDA (prevItPtr),Y  ; Load the same byte again, but this time get the top 4 bits instead of the bottom 4
.REPT 4
  LSR
.ENDR
  STA prevFP
+ LDY #$00  ; Make Y 0 again
  LDA (prevItPtr),Y  ; Find out how many bytes this object is
  AND #%00000001
  ORA #%00000010  ; A is 2 or 3
  STA tmp2
  JMP -OvSLoop
+loop
  JMP Loop
Aft2:
ENDM


;-------------------------------------------------------------------------------------


; Decrease the temp item pointer by 1 item.
; Writes over Y, tmp3 and tmpPtr. tmpPtr becomes the pointer to the previous item and Y&tmp3 become the amount of bytes-1
MACRO DecTmpItPtr
  LDY #$00
  LDA tmpPtr
  BNE +
  DEC tmpPtr+1
+ DEC tmpPtr
  ; Load last value of previous byte
  LDA (tmpPtr),Y
  AND #%11110000
  CMP #%11110000
  BEQ +
  LDY #$01
  JMP +aft
+ LDY #$02
+aft
  STY tmp3
  LDA tmpPtr
  SEC
  SBC tmp3
  STA tmpPtr
  LDA tmpPtr+1
  SBC #$00
  STA tmpPtr+1
ENDM


; TODO: These below routines are all broken and will not work.
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


;-------------------------------------------------------------------------------------


MACRO DrawInit
  LDA #32+Offset  ; 32 columns per screen plus a couple extra
Loop:
  PHA  ; Keep A for later
  JSR ChkIncNxtItPtr  ; Increase nxtItPtr if required.
  LDA nxtCol
  STA tmp1  ; Point to correct column
  PointPPU tmp1  ; Saves having to jump to it again after
  LDA nxtFP
  STA tmp3
  JSR DrawCol  ; Draw column to cache
  ; Now draw cached column to the screen
  LDX #28  ; 28 tiles in a column
  ; Loop in reverse
  LDY #FirstCacheVal+28
- DEY
  LDA $0300,Y
  STA $2007
  DEX
  BNE -

  LDA #$00
  STA CacheDrawTo  ; Do not draw this again later, there's no need; so just pretend it's not there.

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



MACRO HandleDrawingVBLANK
--
  LDX CacheDrawFrom
  CPX CacheDrawTo
  BEQ End
  LDA $0300,X
  STA vtmp1  ; Use vtmp1 as temp storage for the column index
  PointPPU vtmp1
  ; X is a number from 0-6 labelling which column in cache to use.
  ; Each column in cache has a column index stored at $030? where ? = X (0-6)
  ; The columns are stored in memory as a list of every byte making up the column (28 in total) starting from $0310, $0330, $0350, etc. (but NOTE they're backwards)
  ; This low byte is stored in a table below this macro for ease of use
  LDA CacheIdxToAddr,X  ; Now A is the low byte of the address!
  ; After it's been used, increase by 1
  INX
  CPX #$07  ; Handle overflow
  BNE +
  LDX #$00
+ STX CacheDrawFrom
  ; Now use the low byte of the addr in A from before
  CLC
  ADC #28  ; Draw 28 tiles (30 (screen size) - 2 (2 offscreen tiles))
  TAX
  LDY #28  ; Iterate using Y
-
  DEX
  STX vtmp1
  LDA $0300,X  ; Load tile
  STA $2007  ; Store tile in PPU
  DEY  ; Point to next tile
  BNE -  ; Keep looping until done all tiles
  JMP --
End:
ENDM


MACRO CheckCacheSze  ; Checks if adding to the cache will cause an overflow
  LDA CacheDrawTo
  CLC
  ADC #$01
  CMP #$07
  BNE +
  LDA #$00
+ CMP CacheDrawFrom
  ; Next instruction to do is BNE
ENDM
MACRO DrawColMain
  CheckCacheSze
  BNE Loop
  JMP End  ; Skip if too many tiles queued
  ; Can have a reverse loop (as opposed to the VBLANK handle drawing) as we already know there's at least 1 column to draw
Loop
  ; At this point X is always the value in CacheMake
  TXA
  BPL @plus1
;minus
  ;ChkDecItPtr prevItPtr,prevCol
  ; TODO: Forwards pointer
  LDX prevCol
  STX tmp1  ; Point to correct column
  DEX
  TXA
  AND #%00111111
  STA prevCol
  LDX nxtCol
  DEX
  TXA
  AND #%00111111
  STA nxtCol
  LDA prevFP
  STA tmp3
  JMP +aft
@plus1:
  ChkIncPrevItPtr
  JSR ChkIncNxtItPtr  ; Increase nxtItPtr if required.
  LDX prevCol
  INX
  TXA
  AND #%00111111
  STA prevCol
  LDX nxtCol
  STX tmp1  ; Point to correct column
  INX
  TXA
  AND #%00111111
  STA nxtCol
  LDA nxtFP
  STA tmp3

+aft
  JSR DrawCol  ; Draw column to cache

  LDX CacheMake
  BPL @plus2
;minus
  INX
JMP +nxt
@plus2:
  DEX
+nxt
  STX CacheMake
  BEQ End
  CheckCacheSze
  BNE End  ; Skip if too many tiles queued
  JMP Loop
End:
ENDM


;-------------------------------------------------------------------------------------


DrawCol:
  ; tmp1 must be the column idx of the column to draw
  ; tmp3 must be the floor pattern to use
  ; Only used in main
  ; Draws the current column. This uses prev and nxt ItPtrs to calculate the current column, without modifying either.
  ; It writes the column to $03??; $03 CacheDrawTo+Tile and increments CacheDrawTo appending the column data to the cache data thing every column

  ; First clear the memory address we will be using
  LDY CacheDrawTo
  LDA CacheIdxToAddr,Y  ; A is the base address
  STA tmp2  ; tmp2 is now also the base address
  TAY
  ; Fill every tile with the floor pattern
  LDX tmp3
  LDA FloorPatternIdxs,X  ; Get index into floor pattern table
  STA tmp3  ; tmp3 is the max value of the loop
  SEC
  SBC #14  ; Find the initial value of the loop
  TAX
- LDA FloorPatterns,X
.REPT 4  ; Get top 4 bits down to bottom
  LSR
.ENDR
  STA $0300,Y
  INY
  LDA FloorPatterns,X
  AND #$0F
  STA $0300,Y
  INY
  INX
  CPX tmp3
  BNE -

  LDA prevItPtr+1
  STA tmpPtr+1
  LDA prevItPtr
  STA tmpPtr

  ; Check if it's equal right now to ensure nothing bad happens when 0 items are on-screen
  CMP nxtItPtr
  BNE LoopIts
  LDA tmpPtr+1
  CMP nxtItPtr+1
  BNE LoopIts  ; If end != start, continue
  JMP End  ; Because HandleTile is so big

LoopIts:  ; Loop over every item on-screenish forwards (later items override previous ones) and get them to draw to the column if they can
  ; Increase pointer
  LDY #$00
  LDA (tmpPtr),Y
  AND #%00000001
  ORA #%00000010  ; A is the number of bytes in object
  STA tmp3
  LDA tmpPtr
  CLC
  ADC tmp3
  STA tmpPtr
  BCC +
  INC tmpPtr+1
+
  HandleTile  ; Now handle the tile!

  ; Check if tmpPtr <= nxtItPtr and continue while it is!
  LDA tmpPtr+1  ; compare high bytes
  CMP nxtItPtr+1
  BCC +loop ; if tmpPtr+1 < nxtItPtr+1 then tmpPtr < nxtItPtr so continue
  BNE End ; if tmpPtr+1 != nxtItPtr+1 then tmpPtr > nxtItPtr so exit
  LDA tmpPtr  ; compare low bytes
  CMP nxtItPtr
  BCC +loop  ; if tmpPtr+0 < nxtItPtr+0 then tmpPtr < prevItPtr so continue
  BEQ +loop  ; if tmpPtr+0 == nxtItPtr+0 then tmpPtr == prevItPtr so continue
  JMP End  ; else it's >, so exit

+loop  ; Bcos HandleTile is so fat
  JMP LoopIts

End
  LDA tmp1
  ; Add the column to the next cache 'which column should it be' place
  LDX CacheDrawTo
  STA $0300,X
  ; Now increase cache draw to!
  INX
  CPX #$07
  BNE +
  LDX #$00
+ STX CacheDrawTo  ; Now there is 1 more tile to draw!
  RTS

