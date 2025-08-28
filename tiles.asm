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
  STA tmp3
  LDA tmp1
  AND #%00111110  ; So tmp1 has the lower bit masked too
  CMP tmp3
  BNE aft1
  ; Now check for the type
  TXA
  AND #%00000001
  BEQ Single
  JMP Vert
aft1:  ; For usage near here
  JMP Aft  ; Bcos this func's too big

VertTypPtrs:  ; Pointers to the functions used by the vertical tiles to specify how they should be rendered
  .dw DrawVert0, DrawVert1

Single:  ; A single block
  ; Find Y and skip if offscreen (Singles can be used as offscreen objects for blank screens if required)
  LDY #$01
  LDA (tmpPtr),Y
  TAX  ; Keep for later
  AND #$0F
  CMP #15
  BCS aft1
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
  LDA SingleTiles2,X
  STA $0300,Y
  INY  ; Draw second block
  LDA SingleTiles,X
  STA $0300,Y
  JMP Aft
Struct:  ; A structure of blocks
  JMP Aft
Horiz:  ; A horizontal row of blocks
  ; Skip if x < tile x
  TXA
  AND #%00111110
  CMP tmp1
  BEQ +  ; Continue if it's equal
  BPL aft1
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
  ; Find Y
  LDY #$01
  LDA (tmpPtr),Y
  TAX  ; Keep for later
  AND #$0F
  ;CMP #15  ; We don't need to check if Y is offscreen, as it never should be
  ;BCS Aft
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
  ; Find Y and if offscreen assume it's a floor pattern object
  LDY #$01
  LDA (tmpPtr),Y
  TAX  ; Keep for later
  AND #$0F
  CMP #15
  BCS Aft  ; If is offscreen, it's a floor pattern object; so don't draw it.
  ; Find height required
  LDY #$02
  AND #$0F
  ASL  ; So it draws 2* that many tiles
  STA tmp3  ; tmp3 is the looper
  ; Draw the tile to the right Y!
  ASL
  CLC
  ADC tmp2
  TAY  ; Now Y is the base offset to draw to plus the tile Y coord!
  TXA  ; Now find correct tile type
.REPT 4  ; Get top 4 bits
  LSR
.ENDR
  STA tmp2  ; Store it in tmp2
  TAX
  ; Now jump to the correct function!
  LDA VertType,X
  ASL
  TAX
  LDA VertTypPtrs,X
  STA jmpPtr
  LDA VertTypPtrs+1,X
  STA jmpPtr+1
  JMP (jmpPtr)
DrawVert1:
  LDA tmp1
  AND #%00000001
  BEQ Aft  ; Ensure it only draws the right column
DrawVert0:
  LDX tmp2
  LDA VertTiles2,X
  STA $0300,Y
  ; Draw other blocks
  LDA VertTiles,X
  LDX tmp3
- DEY
  STA $0300,Y
  DEX
  BNE -
Aft:
ENDM

SingleTiles:  ; Top block of tile
  ;   dirtS
  .db $04
SingleTiles2: ; Bottom block of tile
  .db $04

HorizTiles:  ; Top block of every column
  ;   grass,dirtH
  .db $02,  $04
HorizTiles2: ; Bottom block of every column
  .db $04,  $04

VertType:   ; Type of object the vertical ones are (defines what the values in VertTiles are useed for)
  ; 0 = middle,top - 1 = middle,top (only the right column)
  ;   pillar,ladder
  .db $00,   $01
VertTiles:
  ;   pillar,ladder
  .db $10,   $12
VertTiles2:
  .db $11,   $12

