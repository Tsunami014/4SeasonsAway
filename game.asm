;; Main game code
  ; Set some vars
  LDA #00
  STA playerx
  STA playerxspeed
  STA playerscrn
  ; Write to the sreen and then enable it
  JSR RewriteScreen
  JSR EnableRendering
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
  ; Update scroll
  LDA playerx
  STA $2005
  LDA $00
  STA $2005 
  ; Update bit 8 of scroll
  LDA playerscrn
  AND #%00000001   ; A = 0000000S
  ORA #PPUCTRLBASE ; A = CCCCCCCS
  STA $2000
aftMvement:

  RTI  ; return from interrupt


RewriteScreen:
  ;; Write to PPU
  ; — point PPU at nametable $2000 by setting 2006 twice - first is the 20 part and the second is the 00 part
  LDA #$20
  STA $2006
  LDA #$00
  STA $2006

  LDY #$00
RowLoop:
    LDX #$00
ColLoop:
    TXA
    AND #%00000111
    STA $2007  ; push one tile

    INX
    CPX #32  ; 32 columns
    BNE ColLoop

    INY
    CPY #30  ; 30 rows
    BNE RowLoop

    RTS

