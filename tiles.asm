; tmpPtr is the current object pointer
; tmp1 is the input column idx as it could be either
; tmp2 is the base address; $0300 + address + tile y to draw to screen!
MACRO HandleTile  ; Handle drawing a tile. Is a macro as this is only used once and repeated a lot, so a subroutine is too expensive.
  LDY #$00
  LDA (tmpPtr),Y
  TAX  ; Now the first byte is in X for ease of access later
  BMI +
  AND #%00000001
  BEQ Struct
  JMP Horiz
+ ; Skip if x != tile x
  AND #%00111110
  CMP tmp1
  BNE Aft
  ; Now check for the type
  TXA
  AND #%00000001
  BNE Vert

Single:  ; A single block
  JMP Aft
Struct:  ; A structure of blocks
  JMP Aft
Horiz:  ; A horizontal row of blocks
  ; Skip if x < tile x
  TXA
  AND #%00111110
  CMP tmp1
  BEQ +  ; Continue if it's equal
  BPL Aft
+ ; Store screen bit for later
  AND #%00100000
  STA tmp3
  ; Skip if x > tile position of x + width
  LDA tmp1
  AND #%00111110  ; Now we can mask the last bit
  TAX
  LDY #$02
  LDA (tmpPtr),Y
  AND #%00001111
  ASL
  ORA tmp3
  LDY tmp1  ; Save tmp1 for restore later
  STX tmp1
  CMP tmp1
  STY tmp1  ; Restore tmp1
  BMI Aft
  ; Find Y and also skip if Y is offscreen (>= 15)
  LDY #$01
  LDA (tmpPtr),Y
  TAX  ; Keep for later
  AND #$0F
  CMP #15
  BCS Aft
  ; Draw the tile to the right Y!
  ASL
  CLC
  ADC tmp2
  TAY  ; Now Y is the base offset to draw to plus the tile Y coord!
  TXA  ; Now find correct tile type
.REPT 4  ; Get top 4 bits
  LSR
.ENDR
  TAX
  LDA HorizTiles2,X
  STA $0300,Y
  INY  ; Draw second block
  LDA HorizTiles,X
  STA $0300,Y
  JMP Aft
Vert:  ; A vertical row of blocks
  
Aft:
ENDM

HorizTiles:  ; Tiles used for horizontal objects. The horizontal object is entirely just one block, and that block id is listed below.
  .db $02
HorizTiles2:  ; Second tiles in the horizontal object (the one under the first)
  .db $04

