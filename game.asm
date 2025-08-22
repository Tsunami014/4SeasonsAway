;; Main game code
  ; Set initial pointer to base address of Tilemap label
  LDA #<Tilemap  ; Low byte of Tilemap label memory location
  STA nxtItPtr
  STA prevItPtr
  LDA #>Tilemap  ; High byte
  STA nxtItPtr+1
  STA prevItPtr+1

  ; Write to the sreen and then enable it
  LDA #32 + Offset  ; 32 columns per screen; draw one whole screen plus a couple extra columns after
  DrawInit
  JSR UpdateScroll  ; Update scrolling afterwards, fixing any other issues

  ; Enable rendering
  ; UpdateScroll sets $2000 at end
  LDA #PPUMASKBASE
  STA $2001
  ; Main loop
Loop:
  LDX CacheMakeFrom
  CPX CacheMakeTo
  BEQ Loop
  ; Need to queue more columns!
  JMP Loop


;-------------------------------------------------------------------------------------


VBLANK:
  ; Store registers to the stack
  PHA
  TXA
  PHA
  TYA
  PHA

; Handle Movement
  LDA #00
  STA vtmp1 ; Store whether to update the scroll

  LDA buttons1  ; Check button state
  AND #BTN_RIGHT
  BEQ @noR
  LDA playerxspeed
  CMP #maxxspeed  ; Ensure it doesn't go higher than the max speed
  BPL @noR
  CLC
  ADC #xspeedchng
  STA playerxspeed  ; Store the new player speed
  JMP @aftX2
@noR:
  LDA buttons1  ; Check button state
  AND #BTN_LEFT
  BEQ @noL
  LDA playerxspeed
  CMP #-maxxspeed  ; Ensure it doesn't go lower than negative max speed
  BMI @noL
  SEC
  SBC #xspeedchng
  STA playerxspeed  ; Store the new player speed
  JMP @aftX2
@noL
  ; Handle slowing down
  LDX playerxspeed
  TXA
  BEQ @aftX2  ; If zero continue
  BMI @negX
; Positive X speed - decrease to go down
  DEX
  JMP @aftX1
; Negative X speed - increase to slow down
@negX:
  INX
@aftX1:
  STX playerxspeed  ; Store the player x speed when changed (from slowdown)
@aftX2:
  ; Check speed and whether it crosses a screen boundary; if so, update screen number
  LDA playerxspeed
  BEQ @aftsetx3  ; Don't run if speed is 0
  BPL @posSpd
; Negative speed
  LDA playerx
  BMI @aftsetx1  ; If bit 7 is set, there's no way you can underflow
  CLC
  ADC playerxspeed
  BPL @aftsetx2
  LDX playerscrn  ; Going down a screen
  DEX
  STX playerscrn
  JMP @aftsetx2
; Positive speed
@posSpd:
  LDA playerx
  CLC
  ADC playerxspeed
  BCC @aftsetx2  ; go to aftsetx2 if adding caused an overflow
  LDX playerscrn  ; Going up a screen
  INX
  STX playerscrn
  JMP @aftsetx2
@aftsetx1:
  CLC
  ADC playerxspeed  ; Calculate new player speed
@aftsetx2:
  STA playerx
  LDA #01  ; Remember we changed something, so update scroll later
  STA vtmp1
@aftsetx3:

; Check scrolling
  LDA vtmp1
  BEQ +  ; Only update scroll if moved
  JSR UpdateScroll
+ ; After movement
  
  handleDrawingVBLANK  ; Draw any columns that were queued

  ; Restore registers from stack
  PLA
  TAY
  PLA
  TAX
  PLA

  RTI  ; return from interrupt

