PRG_COUNT = 2 ;1 = 16KB, 2 = 32KB
CHR_COUNT = 1 ;1 = 8KB, 2 = 16KB, 4 = 32KB
MIRRORING = %0001 ;%0000 = horizontal, %0001 = vertical, %1000 = four-screen

; NES Header
	.db "NES", $1a ;identification of the iNES header
	.db PRG_COUNT ;number of 16KB PRG-ROM pages
	.db CHR_COUNT ;number of 8KB CHR-ROM pages
	.db $00|MIRRORING ;mapper 0 and mirroring
	.dsb 9, $00 ;clear the remaining bytes



;;;;;;;;;;;;;;;;;; Constants



PPUCTRLBASE = %10010100   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
PPUMASKBASE = %00011110   ; enable sprites, enable background, no clipping on left side, increment by 32

;; Controller inputs
BTN_A      = %10000000
BTN_B      = %01000000
BTN_SELECT = %00100000
BTN_START  = %00010000
BTN_UP     = %00001000
BTN_DOWN   = %00000100
BTN_LEFT   = %00000010
BTN_RIGHT  = %00000001

xspeedchng = $01
maxxspeed  = $07  ; So you can never load more than 1 tile too much every frame

Offset     = 5  ; The number of tiles forwards to draw new tiles
; 16 - Offset is the maximum number of tiles an object can be wide before it starts looping around

; Memory addresses for cache
CacheColumns = $0300
; Cache memory location of the column (0-6)
CacheDrawFrom  = $030D
CacheDrawTo    = $030E
; Amount of tiles to cache forwards or backwards (signed)
CacheMake      = $030F



;;;;;;;;;;;;;;;;;; Variables



; Please note these variables all default to 0
.enum $0000  ; Start variables at ram location 0
; .dsb 1 means reserve one byte of space, .dsb 2 means reserve 2 bytes (pointer)
; Temporary vars with various uses OUTSIDE VBLANK
tmp1         .dsb 1
tmp2         .dsb 1
tmp3         .dsb 1
tmp4         .dsb 1
tmp5         .dsb 1

jmpPtr       .dsb 2  ; A pointer used for jump table stuff
tmpPtr       .dsb 2
; Temporary variables FOR VBLANK
vtmp1        .dsb 1

; Rendering stuff
nxtCol       .dsb 1  ; Next column id JJSCCCCC (C = column num, S = screen num (yes they are separate), J = junk (can be anything, doesn't affect execution))
nxtItPtr     .dsb 2  ; Pointer to memory where the next screen rendering item is located (for the right side of the screen)
nxtFP        .dsb 1  ; Which floor pattern to use for the right side of the screen
prevCol      .dsb 1  ; The previous column id, just like before; but for the left side of the screen instead of the right.
prevItPtr    .dsb 2  ; Same, but the item on the left side
prevFP       .dsb 1  ; Which floor pattern to use for the left side of the screen
; VERY IMPORTANT: prevItPtr is NOT rendered. The rendered objects are prevItPtr < item <= nxtItPtr. But when nxtItPtr == prevItPtr nothing should be rendered.

; Player stuff
playerx      .dsb 1
playerxspeed .dsb 1
playerscrn   .dsb 1
lastXpos     .dsb 1
playery      .dsb 1
playeryspeed .dsb 1
buttons1     .dsb 1  ; player 1 gamepad buttons, one bit per button

.ende




.org $8000  ; Program ROM ($8000 for 2 banks, $C000 for 1)



;;;;;;;;;;;;;;;;;; Initialisation



  .include "rendering.asm"  ;; Includes UpdateScroll, DrawCols, etc.
RESET:
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX $4017    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX $2000    ; disable NMI
  STX $2001    ; disable rendering
  STX $4010    ; disable DMC IRQs

; Wait for vblank to make sure PPU is ready
- BIT $2002
  BPL -

; Clear all memory
- LDA #$00
  STA $0000,X
  STA $0100,X
  STA $0300,X
  STA $0400,X
  STA $0500,X
  STA $0600,X
  STA $0700,X
  LDA #$FE
  STA $0200,X
  INX
  BNE -
  
; Second wait for vblank, PPU is ready after this
- BIT $2002
  BPL -


; Load palettes
  LDA $2002         ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006         ; write the high byte of $3F00 address
  LDA #$00
  STA $2006         ; write the low byte of $3F00 address
  LDX #$00          ; start out at 0
; Load pallete loop
- LDA palette,X     ; load data from address (palette + the value in x (which is the loop index))
  STA $2007         ; write to PPU
  INX
  CPX #$20          ; Only copy until hex $10, decimal 16 - copying 16 bytes = 4 sprites
  BNE -



;;;;;;;;;  Game initialisation



  LDA #$00         ; start with no scroll (set scroll bytes to 0)
  STA $2005
  STA $2005

  LDA #%00000100
  STA $2000

  .include "game.asm" ;; Includes the labels for VBLANK and continues this function



;;;;;;;;;;;;;;;;;; Tick



NMI:  ; During VBLANK
  ; Store registers to the stack for recovery inside VBLANK routine
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA #$00
  STA $2003       ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014       ; set the high byte (02) of the RAM address, start the transfer
   
  JSR ReadController  ;;get the current button data for player 1
  
  JMP VBLANK  ; Returning from interrupt should occur here



;;;;;;;;;;;;;;;;;; Reading controllers



;; The reason this is required is as to read from controller inputs, you need to read from a memory address multiple times in a row.
;; This code reads from the addresses for player 1 buttons and pushes them into a variable.
ReadController:
  ;; Latch the controllers
  LDA #$01
  STA $4016       ; strobe on
  LDA #$00
  STA $4016       ; strobe off

  ;;Prepare for 8 reads
  LDX #$08
  LDA #$00
  STA buttons1    ; clear previous frame’s bits

; Read controller loop
- LDA $4016
  AND #%00000001  ; isolate bit0 (next button)
  LSR A           ; shift bit0 → Carry
  ROL buttons1    ; shift buttons1 left, carry→bit0

  DEX
  BNE -
  RTS



;;;;;;;;;;;;;;;;;; Data



  .org $D000
palette:
  ;   Spring,           Summer,           Automn,           Winter
  .db $21,$19,$27,$2D,  $21,$28,$27,$2D,  $21,$17,$27,$00,  $21,$1B,$27,$2D   ;;background palette
  .db $21,$1C,$15,$14,  $21,$02,$38,$3C,  $21,$1C,$15,$14,  $21,$02,$38,$3C   ;;sprite palette

FirstCacheVal = $10  ; For init usage
CacheIdxToAddr:  ; Exactly what it sounds like.
  .db FirstCacheVal, $30, $50, $70, $90, $B0, $D0

FloorPatterns:
  ; Each one is 14 bytes; each set of 4 bits is a tile
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; 0 - empty
  .db $44,$42,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; 1 - Grass until 2
  .db $44,$44,$44,$44,$42,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; 2 - Grass until 5
  .db $DD,$DD,$DD,$DD,$DD,$DD,$DD,$DD,$DD,$DD,$DD,$DD,$DD,$DD  ; 3 - Cave entirely filled
  .db $DD,$DD,$11,$11,$11,$11,$11,$11,$11,$11,$11,$DD,$DD,$DD  ; 4 - Cave until 2, and ceiling from 12
  .db $DD,$DD,$11,$11,$11,$11,$11,$11,$11,$DD,$DD,$DD,$DD,$DD  ; 5 - Cave until 2, and ceiling from 10
  .db $DD,$DD,$DD,$DD,$DD,$DD,$11,$11,$11,$11,$11,$DD,$DD,$DD  ; 6 - Cave until 6, and ceiling from 12
  .db $DD,$DD,$11,$11,$11,$DD,$DD,$DD,$11,$11,$11,$DD,$DD,$DD  ; 7 - Cave until 2, middle section from 6-8, and ceiling from 12
  .db $44,$44,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; 8 - Sand until 2
  .db $88,$87,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; 9 - Water until 2
  .db $88,$87,$00,$00,$05,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; A - Water until 2, bridge at 5

FloorPatternIdxs:  ; Indexes into the FloorPatterns table - basically, multiples of 14. This is offset by 1.
  .db $0E,$1C,$2A,$38,$46,$54,$62,$70,$7E,$8C,$9A,$A8


  .include "tilemap/tilemap.asm"  ; Includes Tilemap&PrevTilemap label



  .org $FFFA     ; Three vectors starts here
  .dw NMI        ; NMI label (once per frame) 
  .dw RESET      ; Initialisation or reset
  .dw 0          ; IRQ (isn't used)


  .incbin "tiles.chr"  ; Include the graphics file at the end
