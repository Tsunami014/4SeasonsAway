;; Main game code
  JSR RewriteScreen
  JSR EnableRendering
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
  BMI minXspd  ; If negative, increase
  DEX  ; If positive, decrease
  JMP aftX1
minXspd:
  INX
aftX1:
  STX playerxspeed  ; Store the player x speed when changed (from slowdown)
aftX2:
  LDA playerx
  CLC
  ADC playerxspeed  ; Calculate new player speed
  CMP playerx
  BEQ aftsetx  ; If nothing changed, skip
  STA playerx
  LDA #01  ; Remember we changed something, so update scroll later
  STA tmp1
aftsetx:

  LDA tmp1
  BEQ aftMvement
  ; Update scroll
  LDA playerx
  STA $2005
  LDA $00
  STA $2005 
aftMvement:

  RTI             ; return from interrupt


RewriteScreen:
  ;; Write to PPU
  ; — point PPU at nametable $2000
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
    STA $2007       ; push one tile

    INX
    CPX #32         ; 32 columns
    BNE ColLoop

    INY
    CPY #30         ; 30 rows
    BNE RowLoop

    RTS

