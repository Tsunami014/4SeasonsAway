;; Main game code
  ; Set some vars
  LDA #00
  STA playerx
  STA playerxspeed
  STA playerscrn

  STA nxtCol
  ; Set initial pointer to base address of Tilemap label
  LDA #Tilemap & $FF  ; Low byte of Tilemap label memory location
  STA nxtItPtr
  LDA #Tilemap / 256  ; High byte
  STA nxtItPtr+1

  ; Write to the sreen and then enable it
  LDA #36  ; 32 columns per screen; draw one whole screen plus a couple extra columns after
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

HandleMovement:
  LDA #00
  STA tmp1 ; Store whether to update the scroll

  LDA buttons1  ; Check button state
  AND #BTN_RIGHT
  BEQ noR
  LDA playerxspeed
  CMP #maxxspeed  ; Ensure it doesn't go higher than the max speed
  BPL noR
  CLC
  ADC #xspeedchng
  STA playerxspeed  ; Store the new player speed
  JMP aftX2
noR:
  LDA buttons1  ; Check button state
  AND #BTN_LEFT
  BEQ noL
  LDA playerxspeed
  CMP #-maxxspeed  ; Ensure it doesn't go lower than negative max speed
  BMI noL
  CLC
  SBC #xspeedchng
  STA playerxspeed  ; Store the new player speed
  JMP aftX2
noL:
  ; Handle slowing down
  LDX playerxspeed
  TXA
  BEQ aftX2  ; If zero continue
  BMI minXspd
;posXspd:
  DEX
  JMP aftX1
minXspd:
  INX
aftX1:
  STX playerxspeed  ; Store the player x speed when changed (from slowdown)
aftX2:
  ; Check speed and whether it crosses a screen boundary; if so, update screen number
  LDA playerxspeed
  BEQ aftsetx3  ; Don't run if speed is 0
  BPL PlSpd
;MinSpd:
  LDA playerx
  BMI aftsetx1  ; If bit 7 is set, there's no way you can underflow
  CLC
  ADC playerxspeed
  BPL aftsetx2
  LDX playerscrn  ; Going down a screen
  DEX
  STX playerscrn
  JMP aftsetx2
PlSpd:
  LDA playerx
  CLC
  ADC playerxspeed
  BCC aftsetx2  ; go to aftsetx2 if adding caused an overflow
  LDX playerscrn  ; Going up a screen
  INX
  STX playerscrn
  JMP aftsetx2
aftsetx1:
  CLC
  ADC playerxspeed  ; Calculate new player speed
aftsetx2:
  STA playerx
  LDA #01  ; Remember we changed something, so update scroll later
  STA tmp1
aftsetx3:

  LDA tmp1
  BEQ aftMvement  ; Only update scroll if moved
  JSR UpdateScroll
aftMvement:

  RTI  ; return from interrupt


UpdateScroll:
  ; Set x scroll
  LDA playerx
  STA $2005
  ; Check x change
  AND #%11111000
  CLC
  SBC lastXpos
  BEQ UpdScrl3
  ; There was a change
  BPL UpdScrl2  ; If it's minus, swap the current and last x so you can increment
  ; TODO:
UpdScrl2:
  STA lastXpos
  
UpdScrl3:
  ; Set y scroll to 0
  LDA $00
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
  BEQ DC1
  LDA #$24
  JMP DC2
DC1:
  LDA #$20
DC2:
  STA $2006
  ; Low byte
  LDA nxtCol
  AND #%00011111
  STA $2006

  LDY #$00

  ; <testing>

  LDX #0
  LDA (nxtItPtr),X  ; Put the value at nxtItPtr into tmp2
  STA tmp2
  ; Add 1 to pointer
  LDA nxtItPtr
  CLC
  ADC #$01
  STA nxtItPtr
  BCC LoopTls  ; Don't add to next one if don't need to
  LDA nxtItPtr+1
  ADC #$00  ; Propagate the carry
  STA nxtItPtr+1
LoopTls:
  TYA
  CMP tmp2
  BMI TLEQ
  ; tile y pos != tmp2
  LDA #$00
  JMP TLEND
TLEQ:
  ; tile y pos == tmp2
  LDA #$01
TLEND:
  STA $2007

  ; </testing>
  
  INY
  CPY #30  ; 30 tiles in a column
  BNE LoopTls

  ; Increase next col pointer by 30 (amount of tiles in column)
  LDX nxtCol
  INX
  ; Check pointer for overflow
  CPX #64  ; 64 columns
  BNE DCPtrOvfDne
  LDX #$00
DCPtrOvfDne:
  STX nxtCol
  ; Check amount of columns remaining
  LDA tmp1
  CLC
  SBC #$01
  STA tmp1
  BNE DrawCols  ; DrawCols for each column in tmp1

  RTS

