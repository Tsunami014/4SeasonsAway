;; Main game code
  ; Set initial pointer to base address of Tilemap label
  LDA #<Tilemap  ; Low byte of Tilemap label memory location
  STA nxtItPtr
  STA prevItPtr
  LDA #>Tilemap  ; High byte
  STA nxtItPtr+1
  STA prevItPtr+1

  ; Write to the sreen and then enable it
  LDA #32 + Offset  ; 32 columns per screen; draw one whole screen plus a couple extra columns after
  STA tmp1
  JSR DrawCols
  JSR UpdateScroll  ; Update scrolling afterwards, fixing any other issues

  ; Enable rendering
  LDA #PPUCTRLBASE
  STA $2000
  LDA #PPUMASKBASE
  STA $2001
  ; Main loop
Forever:
  JMP Forever  ;; Infinite loop


;-------------------------------------------------------------------------------------


VBLANK:

; Handle Movement
  LDA #00
  STA tmp1 ; Store whether to update the scroll

  LDA buttons1  ; Check button state
  AND #BTN_RIGHT
  BEQ @noR
  LDA playerxspeed
  CMP #maxxspeed  ; Ensure it doesn't go higher than the max speed
  BPL @noR
  CLC
  ADC #xspeedchng
  STA playerxspeed  ; Store the new player speed
  JMP @aftX2
@noR:
  LDA buttons1  ; Check button state
  AND #BTN_LEFT
  BEQ @noL
  LDA playerxspeed
  CMP #-maxxspeed  ; Ensure it doesn't go lower than negative max speed
  BMI @noL
  SEC
  SBC #xspeedchng
  STA playerxspeed  ; Store the new player speed
  JMP @aftX2
@noL
  ; Handle slowing down
  LDX playerxspeed
  TXA
  BEQ @aftX2  ; If zero continue
  BMI @negX
; Positive X speed - decrease to go down
  DEX
  JMP @aftX1
; Negative X speed - increase to slow down
@negX:
  INX
@aftX1:
  STX playerxspeed  ; Store the player x speed when changed (from slowdown)
@aftX2:
  ; Check speed and whether it crosses a screen boundary; if so, update screen number
  LDA playerxspeed
  BEQ @aftsetx3  ; Don't run if speed is 0
  BPL @posSpd
; Negative speed
  LDA playerx
  BMI @aftsetx1  ; If bit 7 is set, there's no way you can underflow
  CLC
  ADC playerxspeed
  BPL @aftsetx2
  LDX playerscrn  ; Going down a screen
  DEX
  STX playerscrn
  JMP @aftsetx2
; Positive speed
@posSpd:
  LDA playerx
  CLC
  ADC playerxspeed
  BCC @aftsetx2  ; go to aftsetx2 if adding caused an overflow
  LDX playerscrn  ; Going up a screen
  INX
  STX playerscrn
  JMP @aftsetx2
@aftsetx1:
  CLC
  ADC playerxspeed  ; Calculate new player speed
@aftsetx2:
  STA playerx
  LDA #01  ; Remember we changed something, so update scroll later
  STA tmp1
@aftsetx3:

; Check scrolling
  LDA tmp1
  BEQ +  ; Only update scroll if moved
  JSR UpdateScroll
+ ; After movement

  RTI  ; return from interrupt


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
  JSR DrawCols
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
  JSR DrawCols
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


; Assumes Y=0, writes over X&tmp3
MACRO ChkIncItPtr itPtr,colIdx  ; Check and increase an item pointer (check if need to) in a loop. Continues until next item is not ok.
Start:
  LDA colIdx
  AND #%00111110
  STA tmp3  ; tmp3 = Current screen. But, only the part of the screen.

  LDA (itPtr),Y  ; Load first byte of the previous object
  TAX  ; Required for macro
  AND #%00111110  ; Filter out for the X and screen
  CMP tmp3
  BNE End  ; This only works when going forwards; when going backwards, the objects would be added when they're half a block too early

  ; The next item is now on screen! (Exactly on the screen edge)
  TXA
  AND #%00000001
  ORA #%00000010  ; Add 2
  STA tmp3
  LDA itPtr
  CLC
  ADC tmp3  ; Now A = itPtr + 2 + (1 if there is a data byte in the object else 0)
  STA itPtr
  BCC End
  LDA itPtr+1
  ADC #$00  ; Propagate the carry
  STA itPtr+1

  JMP Start

End:
ENDM


; Decrease the temp item pointer by 1 item.
; Assumes Y=0, writes over X, tmp3 and tmpPtr. tmpPtr becomes the pointer to the previous item and X&tmp3 become the amount of bytes-1
MACRO DecTmpItPtr
  LDA tmpPtr
  BNE +
  DEC tmpPtr+1
+ DEC tmpPtr
  ; Load last value of previous byte
  LDA (tmpPtr),Y
  AND #%11110000
  CMP #%11110000
  BEQ +
  LDX #$01
  JMP +aft
+ LDX #$02
+aft
  STX tmp3
  SEC
  LDA tmpPtr
  SBC tmp3
  STA tmpPtr
  LDA tmpPtr+1
  SBC #$00
  STA tmpPtr+1
ENDM

ChkDecItPtrRout:  ; Is the routine internals for the ChkDecItPtr. This is a subroutine.
  DecTmpItPtr itPtr  ; Sets X
  INX  ; Now X is correct

  LDA tmp1
  AND #%00111110
  STA tmp3  ; tmp3 = Current screen. But, only the part of the screen. 

  LDA (tmpPtr),Y
  AND #%00111111  ; So if it ends with 1 then it won't work
  CMP tmp3
  BEQ ChkDecItPtrRout  ; Keep going while the objects are on the edge of the screen
  RTS

; Assumes Y=0, writes over X,tmp1,tmp3 and tmpPtr
MACRO ChkDecItPtr itPtr,colIdx  ; Check and decrease an item pointer (check if need to) in a loop. Continues until next item is not ok.
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


DrawCols:
  ; Draws the amount of columns as specified in the tmp1 memory location
  ; Also, tmp2 stores whether this is NOT Initialisation or not and also the Direction (D000000I) (So when initialisation, everything=0)
  ; Both are stored in the stack when looping
  LDA $2002  ; read PPU status to reset the high/low latch

  ; Get pointer value
  ; High byte
  LDA nxtCol
  AND #%00100000
  BEQ +
  LDA #$24  ; is a 1 - use 2nd page
  JMP +next
+ LDA #$20  ; is a 0 - use 1st page
+next
  STA $2006
  ; Low byte
  LDA nxtCol
  AND #%00011111
  STA $2006

  LDY #$00  ; Now Y is $00. This will be used a lot.
  STY $2007  ; First column is offscreen, so we write a 0 to it

  ; Store tmp1 to the stack before running this so tmp1 is free (tmp2 is used)
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
  LDA tmp2  ; Check for initialisation (everything is 0)
  BNE +  ; Skip increasing backward pointer
  ; Add 1 to both pointers
  ChkIncItPtr prevItPtr,prevCol  ; Increase prevItPtr if required
+ ChkIncItPtr nxtItPtr,nxtCol  ; Increase nxtItPtr if required
+nxt

  LDA tmp2  ; Now store tmp2
  PHA

  LDA tmp2
  BPL +
  LDA prevCol
  JMP +aft
+ LDA nxtCol
+aft
  STA tmp2  ; tmp2 now contains the column index
  ; Y is already 0, if you're wondering
LoopTls:
  ; Here we use tmp2 and tmp3 as a temporary pointer, as they are next to each other in memory.
  LDA #$00
  STA tmp1
  LDA nxtItPtr+1
  STA tmpPtr+1
  LDA nxtItPtr
  STA tmpPtr

  ; Check if it's equal right now to ensure nothing bad happens when 0 items are on-screen
  CMP prevItPtr
  BNE LoopIts
  LDA tmpPtr+1
  CMP prevItPtr+1
  BNE LoopIts
  ; There is nothing; skip whole loop
  JMP +cont

LoopIts:  ; Loop over every item on-screenish backwards (later items override previous ones)
  ; Decrement tmp pointer
  DecTmpItPtr
  HandleTile  ; Macro defined in tiles.asm
  LDA tmp1
  BNE +write
  ; If is still 0, check if temp pointer is still greater than the initial; and if so, keep looping
  LDA tmpPtr+1  ; compare high bytes
  CMP prevItPtr+1
  BCC +cont ; if tmpPtr+1 < prevItPtr+1 then tmpPtr < prevItPtr so exit loop
  BNE LoopIts ; if tmpPtr+1 != prevItPtr+1 then tmpPtr > prevItPtr so continue
  LDA tmpPtr  ; compare low bytes
  CMP prevItPtr
  BEQ +cont  ; if tmpPtr+0 == prevItPtr+0 then tmpPtr == prevItPtr so exit
  BCS LoopIts ; if tmpPtr+0 > prevItPtr+0 then tmpPtr > prevItPtr so continue

+cont
  LDA #$00  ; If no object wants it, draw a blank
+write
  STA $2007
 
  INY
  CPY #29  ; 30 tiles in a column
  BNE +loopTls

  PLA
  STA tmp2
  PLA
  STA tmp1

  LDA tmp2
  BMI +
  INC nxtCol  ; Increase next col pointer if going forwards
  JMP +aft
+ DEC nxtCol  ; Decrease next col pointer if going backwards
+aft
  ; Decrease tmp1 and check if need to continue
  DEC tmp1
  LDA tmp1
  BNE +loopCols  ; DrawCols for each column in tmp1
  RTS
; These are required as Branch instructions are relative, but this subroutine is so long it becomes out of range
+loopCols
  JMP DrawCols
+loopTls
  JMP LoopTls

