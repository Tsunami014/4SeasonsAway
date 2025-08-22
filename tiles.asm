; X is current Y pos (PLEASE NOTE THIS; IT'S VERY IMPORTANT)
; tmpPtr is the current object pointer
; tmp1 is the input column idx as it could be either (but NOTE the highest bit needs to be ignored in any calculation)
; tmp4 is the input column idx only (tmp1 with the correct bits masked out)
; tmp2 is the output (0 if not handled, tile id (that isn't 0) if succeeded) (This value can be used, as it's only set at the end)

MACRO HandleTile  ; Handle drawing a tile. Is a macro as this is only used once and repeated a lot, so a subroutine is too expensive.
  LDY #$00
  LDA (tmpPtr),Y
  TAY  ; Now the first byte is in Y for ease of access later
  BPL +
  AND #%00000001
  BEQ Struct
  JMP Vert
+ AND #%00000001
  BNE Horiz

Single:  ; A single block
  JMP Fail
Struct:  ; A structure of blocks
  JMP Fail
Horiz:  ; A horizontal row of blocks
  ; Skip if x < tile x
  TYA
  AND #%00111110
  CMP tmp4
  BEQ +  ; Continue if it's equal
  BPL Fail
+ ; Store screen bit for later
  AND #%00100000
  STA tmp2
  ; Skip if not the right Y pos
  LDY #$01
  LDA (tmpPtr),Y
  AND #%00001111
  STA tmp3
  TXA
  SEC
  SBC #$01  ; Subtract 1 so the Y is really correct!
  AND #%00011110  ; Get top 4 bits of Y
  LSR
  CMP tmp3
  BNE Fail
  ; Skip if x > tile position of x + width
  LDY #$02
  LDA (tmpPtr),Y
  AND #%00001111
  ASL
  ORA tmp2
  CMP tmp4
  BMI Fail
  BEQ Fail  ; Can't have it being equal either!
  LDA #$01  ; TODO: Fill with the correct tile value
  STA tmp2
  JMP Aft
Vert:  ; A vertical row of blocks
  
Fail:
  LDA #$00
  STA tmp2
Aft:
ENDM

HorizTiles:  ; Tiles used for horizontal objects. The horizontal object is entirely just one block, and that block id is listed below.
  .db $01

