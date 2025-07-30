GAME:
  JSR RewriteScreen
  JSR EnableRendering
Forever:
  JMP Forever  ;; Infinite loop


;-------------------------------------------------------------------------------------


VBLANK:
  RTS   ;; Finish


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
    AND #%00000001  ; For an alternating pattern; 0, 1, 0, 1, ...
    STA $2007       ; push one tile

    INX
    CPX #32         ; 32 columns
    BNE ColLoop

    INY
    CPY #30         ; 30 rows
    BNE RowLoop

    RTS

