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

  LDA buttons1
  AND #BTN_RIGHT
  BEQ noR
  LDA playerxspeed
  CMP #maxxspeed
  BPL noR
  CLC
  ADC #xspeedchng
  STA playerxspeed
  JMP aftR2
noR:
  LDX playerxspeed
  TXA
  BEQ aftR2
  BMI minXspd
  DEX
  JMP aftR1
minXspd:
  INX
aftR1:
  STX playerxspeed
aftR2:
  LDA playerx
  CLC
  ADC playerxspeed
  CMP playerx
  BEQ aftsetx
  STA playerx
  LDA #01
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

