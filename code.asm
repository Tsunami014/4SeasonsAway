  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring



;;;;;;;;;;;;;;;;;; Declarations



  .rsset $0000  ;;start variables at ram location 0

; .rs 1 means reserve one byte of space
tmp1       .rs 1  ; Some temporary variables
tmp2       .rs 1


buttons1   .rs 1  ; player 1 gamepad buttons, one bit per button


;;;;;;;;; Constants


;; Controller inputs
BTN_A      = %10000000
BTN_B      = %01000000
BTN_SELECT = %00100000
BTN_START  = %00010000
BTN_UP     = %00001000
BTN_DOWN   = %00000100
BTN_LEFT   = %00000010
BTN_RIGHT  = %00000001



;;;;;;;;;;;;;;;;;; initialisation



  .bank 0
  .org $C000 

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

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT $2002
  BPL vblankwait1

clrmem:
  LDA #$00
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
  BNE clrmem
   
vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2


LoadPalettes:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006             ; write the high byte of $3F00 address
  LDA #$00
  STA $2006             ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop:
  LDA palette, x        ; load data from address (palette + the value in x)
                          ; 1st time through loop it will load palette+0
                          ; 2nd time through loop it will load palette+1
                          ; 3rd time through loop it will load palette+2
                          ; etc
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $10, decimal 16 - copying 16 bytes = 4 sprites
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down



;;;;;;;;;  Game initialisation



  LDA #$00         ; start with no scroll (set scroll bytes to 0)
  STA $2005
  STA $2005

  JMP GAME

EnableRendering:
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000
  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA $2001
  RTS
DisableRendering:
  LDA #$00
  STA $2000
  STA $2001



;;;;;;;;;;;;;;;;;; Tick



NMI:  ; During VBLANK
  LDA #$00
  STA $2003       ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014       ; set the high byte (02) of the RAM address, start the transfer
   
  JSR ReadController  ;;get the current button data for player 1
  
  JSR VBLANK

  RTI             ; return from interrupt



  .include "game.asm" ;; Includes the labels for VBLANK and GAME



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

ReadControllerLoop:
  LDA $4016
  AND #%00000001  ; isolate bit0 (next button)
  LSR A           ; shift bit0 → Carry
  ROL buttons1    ; shift buttons1 left, carry→bit0

  DEX
  BNE ReadControllerLoop
  RTS



;;;;;;;;;;;;;;;;;; Sprites and graphics



  .bank 1
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


  .org $FFFA     ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0


;;;;;;;;; 


  .bank 2
  .org $0000
  .incbin "tiles.chr"   ;includes the graphics file

