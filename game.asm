;; Main game code
  ; Set initial pointer to base address of Tilemap label
  LDA #<Tilemap  ; Low byte of Tilemap label memory location
  STA nxtItPtr
  LDA #>Tilemap  ; High byte
  STA nxtItPtr+1

  ; Write to the sreen and then enable it
  LDA #32 + 6  ; 32 columns per screen; draw one whole screen plus a couple extra columns after
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


UpdateScroll:
  ; Set x scroll
  LDA playerx
  ; Check x change
  AND #%11111000
  SEC
  SBC lastXpos
  BEQ ++
  ; There was a change
  .REPT 3
  LSR A
  .ENDR
  BPL +
  ORA #%10000000
+ STA tmp1  ; Store the amount of x change to fix next update
  JSR DrawCols
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

  ; <testing>

  LDA (nxtItPtr),Y  ; Put the value at nxtItPtr into tmp2
  STA tmp2
  ; Add 1 to pointer
  LDA nxtItPtr
  CLC
  ADC #$01
  STA nxtItPtr
  BCC +  ; Don't add to next one if don't need to
  LDA nxtItPtr+1
  ADC #$00  ; Propagate the carry
  STA nxtItPtr+1
+ LDY #$00
LoopTls:
  CPY tmp2
  BMI +eq
  ; tile y pos != tmp2
  LDA #$00
  JMP +aft
+eq
  ; tile y pos == tmp2
  LDA #$01

+aft STA $2007

  ; </testing>
  
  INY
  CPY #30  ; 30 tiles in a column
  BNE LoopTls

  ; Increase next col pointer by 30 (amount of tiles in column)
  LDX nxtCol
  INX
  ; Check pointer for overflow
  CPX #64  ; 64 columns
  BNE +
  LDX #$00
+
  STX nxtCol
  ; Check amount of columns remaining
  LDA tmp1
  SEC
  SBC #$01
  STA tmp1
  BNE DrawCols  ; DrawCols for each column in tmp1

  RTS

