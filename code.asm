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
PPUMASKBASE = %00011110   ; enable sprites, enable background, no clipping on left side

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
maxxspeed  = $08

Offset     = 30;6  ; The number of tiles forwards to draw new tiles



;;;;;;;;;;;;;;;;;; Variables



; Please note these variables all default to 0
.enum $0000  ; Start variables at ram location 0
; .dsb 1 means reserve one byte of space, .dsb 2 means reserve 2 bytes (pointer)
; Temporary vars with various uses
tmp1         .dsb 1
tmp2         .dsb 1
tmp3         .dsb 1

tmpPtr       .dsb 2

; Rendering stuff
nxtCol       .dsb 1  ; Next column id JJSCCCCC (C = column num, S = screen num (yes they are separate), J = junk (can be anything, doesn't affect execution))
nxtItPtr     .dsb 2  ; Pointer to memory where the next screen rendering item is located (for the right side of the screen)
prevCol      .dsb 1  ; The previous column id, just like before; but for the left side of the screen instead of the right.
prevItPtr    .dsb 2  ; Same, but the item on the left side
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


;;;;;;;;;;;;;;;;;; Utility functions



; For later



;;;;;;;;;;;;;;;;;; Initialisation



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
  STA $0000, x
  STA $0100, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0200, x
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
- LDA palette, X    ; load data from address (palette + the value in x (which is the loop index))
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



;;;;;;;;;;;;;;;;;; Sprites and graphics



  .org $E000
palette:
  .db $22,$29,$1A,$0F,  $22,$36,$17,$0F,  $22,$30,$21,$0F,  $22,$27,$17,$0F   ;;background palette
  .db $22,$1C,$15,$14,  $22,$02,$38,$3C,  $22,$1C,$15,$14,  $22,$02,$38,$3C   ;;sprite palette

sprites:
     ;vert tile attr horiz
  .db $80, $32, $00, $80   ;sprite 0
  .db $80, $33, $00, $88   ;sprite 1
  .db $88, $34, $00, $80   ;sprite 2
  .db $88, $35, $00, $88   ;sprite 3


  .include "tilemap/tilemap.asm"  ; Includes Tilemap&PrevTilemap label



  .org $FFFA     ; Three vectors starts here
  .dw NMI        ; NMI label (once per frame) 
  .dw RESET      ; Initialisation or reset
  .dw 0          ; IRQ (isn't used)


  .incbin "tiles.chr"  ; Include the graphics file at the end
