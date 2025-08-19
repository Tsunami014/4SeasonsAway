; X is current Y pos (PLEASE NOTE THIS; IT'S VERY IMPORTANT)
; tmpPtr is the current object pointer
; tmp1 is the output (0 if not handled, tile id (that isn't 0) if succeeded)
; tmp2 is the input column idx as it could be either

MACRO HandleTile  ; Handle drawing a tile. Is a macro as this is only used once and repeated a lot, so a subroutine is too expensive.
  LDY #$00
  LDA (tmpPtr),Y
  TAY
  BMI +
  AND #%00000001
  BEQ Horiz
  JMP Vert
+ AND #%00000001
  BNE Struct

Single:  ; A single block
  JMP Aft
Struct:  ; A structure of blocks
  JMP Aft
Horiz:  ; A horizontal row of blocks
  TYA
  AND #%00111110
  CMP tmp2
  BPL Aft  ; Skip if x < tile x
  LDY #$01
  LDA (tmpPtr),Y
  AND #%00001111
  STA tmp3
  TXA
  AND #%00011110  ; Get top 4 bits of Y
  LSR
  CMP tmp3
  BNE Aft  ; Skip if not the right Y pos
  LDA #$01  ; TODO: Fill with the correct tile value
  STA tmp1
  JMP Aft
Vert:  ; A vertical row of blocks
  
Aft:
ENDM

HorizTiles:  ; Tiles used for horizontal objects. The horizontal object is entirely just one block, and that block id is listed below.
  .db $01

