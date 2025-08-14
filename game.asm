;; Main game code
  ; Set initial pointer to base address of Tilemap label
  LDA #<Tilemap  ; Low byte of Tilemap label memory location
  STA nxtItPtr
  LDA #>Tilemap  ; High byte
  STA nxtItPtr+1

  ; Write to the sreen and then enable it
  LDA #32 + Offset  ; 32 columns per screen; draw one whole screen plus a couple extra columns after
  STA tmp1
  JSR DrawCols
  JSR UpdateScroll  ; Update scrolling afterwards, fixing any other issues

  ; Set initial prev item pointer to base address of Tilemap label
  ; The pointer would've changed (but not actually been used, as it starts generating forwards) due to initial generation, so here we're setting it properly.
  LDA #<(Tilemap - Offset)  ; Low byte of Tilemap label memory location
  STA prevItPtr
  LDA #>(Tilemap - Offset)  ; High byte
  STA prevItPtr+1
  ; HACK: This will have a gap of `Offset` tiles behind the start, but because we will never go further back than where we started, this is ok.

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
  ORA #%10000000  ; Signal that it is decreasing
  TAX  ; Because we can't subtract the x change when the last bit is set, we store it to set again later
  LDA nxtCol
  SEC
  SBC #ScreenSze + Offset  ; The next column to update should now be the old index (right side of the screen) - the screen size (32 columns)
  STA nxtCol      ; This needed to be changed so it would be adding columns to the left side of the screen. Due to the decreasing bit being set, everything else is ok
  STX tmp1
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



DrawCols:
  ; Draws the amount of columns as specified in the tmp1 memory location
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

  LDY #$00
  STY $2007  ; First column is offscreen, so we write a 0 to it

  ; The next code is slightly testing code; it will be *similar* later.

  ; Handle next code differently if going forwards or backwards
  LDA tmp1
  BPL +positive
;negative
  ; Put the value at prevItPtr into tmp2
  LDA (prevItPtr),Y
  STA tmp2
  ; Decrease 1 from both pointers
  LDA prevItPtr+1  ; If high byte of prevItPtr is 0, don't increment as this is in the initialisation
  BEQ ++
  LDA prevItPtr
  BNE +
  DEC prevItPtr+1  ; If current value == 0 (so it will wrap around) then decrease bottom pointer by 1
+ DEC prevItPtr
++
  LDA nxtItPtr
  BNE +
  DEC nxtItPtr+1  ; Same here
+ DEC nxtItPtr

  JMP +nxt
+positive
  ; Put the value at nxtItPtr into tmp2
  LDA (nxtItPtr),Y
  STA tmp2
  ; Add 1 to both pointers
  LDA prevItPtr+1  ; Same as before; skip if initialisation.
  BEQ +
  INC prevItPtr
  BNE +
  INC prevItPtr+1  ; If updated value == 0 (so it did wrap around) then increase bottom pointer by 1
+
  INC nxtItPtr
  BNE +nxt
  INC nxtItPtr+1  ; Same here

+nxt
  LDY #$00  ; Y is already 0, if you're wondering
LoopTls:
  CPY tmp2
  BMI @eq
  ; tile y pos != tmp2
  LDA #$00
  JMP @aft
@eq:
  ; tile y pos == tmp2
  LDA #$01

@aft:
  STA $2007
 
  INY  ; TODO: Maybe just decrement???
  CPY #29  ; 30 tiles in a column
  BNE LoopTls

  LDA tmp1
  BMI +
  ; Increase next col pointer
  INC nxtCol
  ; Check amount of columns remaining
  SEC  ; If tmp1 is positive, -1
  SBC #$01
  STA tmp1
  BNE +loop  ; DrawCols for each column in tmp1
  RTS
+ ; Decrease next col pointer
  DEC nxtCol
  ; Check amount of columns remaining
  SEC  ; If tmp1 is negative, -1 still, but
  SBC #$01
  STA tmp1
  AND #%01111111  ; Then later when checking ignore the extra bit
  BNE +loop
  RTS
+loop  ; This is required as Branch instructions are relative, but this subroutine is so long it becomes out of range
  JMP DrawCols

