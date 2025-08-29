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
  BNE AftS
  ; Now check for the type
  TXA
  AND #%00000001
  BEQ Single
  JMP Vert


; Pointers to the functions used by the objects to specify how they should be rendered
HorizTypPtrs:
  .dw DrawHoriz0, DrawHoriz1, DrawHoriz2, DrawHoriz3
VertTypPtrs:
  .dw DrawVert0, DrawVert1


Single:  ; A single block
  ; Find Y and skip if offscreen (Singles can be used as offscreen objects for blank screens if required)
  LDY #$01
  LDA (tmpPtr),Y
  TAX  ; Keep for later
  AND #$0F
  CMP #15
  BCS AftS
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
AftS  ; Reuse existing jmp
  JMP Aft


Struct:  ; A structure of blocks
  JMP Aft


Horiz:  ; A horizontal row of blocks
  ; Skip if x < tile x
  TXA
  AND #%00111110
  CMP tmp1
  BEQ +  ; Continue if it's equal
  BPL AftH
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
  BMI AftH
  ; Find Y
  LDY #$01
  LDA (tmpPtr),Y
  TAX  ; Keep for later
  AND #$0F
  ;CMP #15  ; We don't need to check if Y is offscreen, as it never should be
  ;BCS AftH
  ; Draw the tile to the right Y!
  ASL
  CLC
  ADC tmp2
  TAY  ; Now Y is the base offset to draw to plus the tile Y coord!
  TXA  ; Now find correct tile type
.REPT 4  ; Get top 4 bits
  LSR
.ENDR
  STA tmp3  ; Type is in tmp3

  TAX
  ; Now jump to the correct function!
  LDA HorizType,X
  ASL
  TAX
  LDA HorizTypPtrs,X
  STA jmpPtr
  LDA HorizTypPtrs+1,X
  STA jmpPtr+1
  JMP (jmpPtr)
DrawHoriz0:
  LDX tmp3
  LDA HorizTiles,X
  STA $0300,Y
  INY  ; Draw second block
  STA $0300,Y
AftH:  ; Reuse an existing jmp
  JMP Aft
DrawHoriz1:
  LDX tmp3
  LDA HorizTiles2,X
  STA $0300,Y
  INY  ; Draw second block
  LDA HorizTiles,X
  STA $0300,Y
  JMP Aft
DrawHoriz3:
  LDA tmp1
  AND #%00000001
  BEQ DHStart
  JMP DHEnd
DrawHoriz2:
  STY tmp5
  LDY #$00
  LDA (tmpPtr),Y
  AND #%00111110
  CMP tmp1
  BEQ @DHStart
  AND #%00100000  ; Store screen bit for later
  STA tmp4
  LDY #$02
  LDA (tmpPtr),Y
  AND #$0F
  ASL
  ORA tmp4
  ORA #%00000001  ; Ensure it's the last *column*
  LDY tmp5
  CMP tmp1
  BEQ DHEnd
; Regular in the middle tile
  LDX tmp3
  LDA HorizTiles,X
  STA $0300,Y
  INY  ; Draw second block
  LDA HorizTiles,X
  STA $0300,Y
  JMP Aft
@DHStart:
  LDY tmp5
DHStart:
  LDX tmp3
  LDA HorizTiles,X
  CLC
  ADC #$01
  STA $0300,Y
  INY  ; Draw second block
  LDA HorizTiles,X
  ADC #$02  ; Previous should NEVER overflow
  STA $0300,Y
  JMP Aft
DHEnd:
  LDX tmp3
  LDA HorizTiles,X
  CLC
  ADC #$04
  STA $0300,Y
  INY  ; Draw second block
  LDA HorizTiles,X
  ADC #$03  ; Previous should NEVER overflow
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
  LDA (tmpPtr),Y
  AND #$0F
  ASL  ; So it draws 2* that many tiles
  STA tmp3  ; tmp3 is the looper
  ; Draw the tile to the right Y!
  TXA
  AND #$0F
  ASL
  CLC
  ADC tmp2
  TAY  ; Now Y is the base offset to draw to plus the tile Y coord!
  TXA  ; Now find correct tile type
.REPT 4  ; Get top 4 bits
  LSR
.ENDR
  STA tmp4  ; Store it in tmp4
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
  LDX tmp4
  LDA VertTiles2,X  ; This tile is for the top; so keep it until the end
  STA tmp4
  ; Draw other blocks
  LDA VertTiles,X
  LDX tmp3
  DEX  ; Leave one out for the end
- STA $0300,Y
  INY
  DEX
  BNE -
  LDA tmp4
  STA $0300,Y


Aft:
ENDM


SingleTiles:  ; Top block of tile
  ;   dirtS
  .db $04
SingleTiles2: ; Bottom block of tile
  .db $04

; A set of 5 is a set of 5 tiles in order in the character rom: middle, bottom left, top left, top right, bottom right.
; A 'looping' set of 5 does not use the middle tile; it just loops between the left and right ones.
HorizType:  ; Type of object (defines what HorizTiles and HorizTiles2 are used for)
; 0 = all,unused - 1 = bottom,top - 2 = start tile of a set of 5,unused - 3 = start of a looping set of 5,unused
  ;   grass,dirtH,bricks,cloud,leaf
  .db $01,  $00,  $03,   $02,  $02
HorizTiles:
  .db $02,  $04,  $36,   $26,  $16
HorizTiles2:
  .db $04,  $04,  $36,   $26,  $16

VertType:   ; Type of object the vertical ones are (defines what the values in VertTiles are useed for)
; 0 = middle,top - 1 = middle,top (only the right column)
  ;   pillar,ladder,trunk
  .db $00,   $01,   $00
VertTiles:
  .db $10,   $12,   $15
VertTiles2:
  .db $11,   $12,   $15

