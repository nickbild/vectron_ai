;;;;
; Machine learning image classification for the Vectron 64.
; Nick Bild - nick.bild@gmail.com
; https://github.com/nickbild/6502_ai
;
; Reserved memory:
; $0000 - LCD enable
; $0001 - Unused -- read it to disable any IC (except RAM).
; $0002 - Offset into memory for current image pixel data.
; $0003 - Minimum difference found between current image
;					and all known images.
; $0004 - The running total of pixel differences for a
;					single image comparison.
; $0005 - The predicted class of the current image.
; $0006-$0069 - Current image pixel data.
; $0100-$01FF - 6502 stack
; $7FBE-$7FBF - Temporary location for LCD data manipulation.
; $7FC0-$7FFF - Data to write to LCD.
;               Each character (16 x 2 lines) is represented by
;               2 consecutive bytes (4-bit mode).
;               Most sig. 4 bits are for LCD data.
;               Least sig. 4 bits - only bit 3 used (tied to RS pin).
;
; $FFF4 - Send up arrow command to 2600 emulator.
; $FFF5 - Send down arrow command to 2600 emulator.
; $FFF6 - Send left arrow command to 2600 emulator.
; $FFF7 - Send right arrow command to 2600 emulator.
;
; $FFF8 - Send low signal to OE on shift register containing image pixel data.
; $FFF9 - Send an interrput clear to the Raspberry Pi.
;
; $FFFA - NMI IRQ Vector
; $FFFB - NMI IRQ Vector
; $FFFC - Reset Vector - Stores start address of this ROM.
; $FFFD - Reset Vector
; $FFFE - IRQ Vector - Keyboard ISR address.
; $FFFF - IRQ Vector
;;;;

		processor 6502

; Named variables in RAM.
		ORG $0002

ImageOffset
		.byte #$00
MinValue
		.byte #$00
RunningTotal
		.byte #$00
Class             ; 0=up; 1=down; 2=left, 3=right; 4=nothing
		.byte #$00

; Start at beginning of ROM.
StartExe	ORG $8000
		sei

		cld

		jsr InitLcd
		jsr ZeroLCDRam

    lda #$00
    sta ImageOffset
    sta RunningTotal
    sta Class

    lda #$FF
    sta MinValue

    ; 1 - line 1, position 1; Status indicator.
    lda #$38
    sta $7FC0
    lda #$18
    sta $7FC1
    jsr WriteLCD

		; Temporary
		lda #$88
		sta $7FC6
		sta $7FC7

		cli

MainLoop
		jmp MainLoop

;;;
; Long Delay
;;;

Delay		ldx #$FF
DelayLoop1	ldy #$FF
DelayLoop2	dey
		bne DelayLoop2
		dex
		bne DelayLoop1
		rts

;;;
; Short Delay
;;;

DelayShort	ldx #$80
DelayShortLoop1	dex
		bne DelayShortLoop1
		rts

;;;
; Send high pulse to LCD enable pin.
;;;

LcdCePulse	sta $01
		jsr DelayShort
		sta $00
		jsr DelayShort
		sta $01
		jsr DelayShort
		rts

;;;
; LCD initialization sequence.
;;;

InitLcd		jsr Delay

		lda #$30			; 00110000 - data 0011, RS 0
		jsr LcdCePulse
		jsr Delay
		lda #$30
		jsr LcdCePulse
		jsr Delay
		lda #$30
		jsr LcdCePulse
		lda #$20
		jsr LcdCePulse
		jsr DelayShort

; Set 8 bit, 2 line, 5x8.
		lda #$20
		jsr LcdCePulse
		lda #$80
		jsr LcdCePulse

; Display on.
		lda #$00
		jsr LcdCePulse
		lda #$C0
		jsr LcdCePulse

; Clear display.
		lda #$00
		jsr LcdCePulse
		lda #$10
		jsr LcdCePulse
		jsr Delay

; Entry mode.
		lda #$00
		jsr LcdCePulse
		lda #$60
		jsr LcdCePulse

		rts

;;;
; Write LCD-reserved RAM addresses to LCD.
;;;

WriteLCD	lda #$80		; Line 1 : 1000 (line1) 0000 (RS 0)
 		jsr LcdCePulse
		lda #$00		; Position 0 : 0000 (position 0) 0000 (RS 0)
		jsr LcdCePulse

		ldy #$00
Line1Loop	lda $7FC0,y
		jsr LcdCePulse
		iny
		cpy #$20
		bcc Line1Loop

		lda #$C0		; Line 2 : 1100 (line2) 0000 (RS 0)
 		jsr LcdCePulse
		lda #$00		; Position 0 : 0000 (position 0) 0000 (RS 0)
		jsr LcdCePulse

		ldy #$00
Line2Loop	lda $7FE0,y
		jsr LcdCePulse
		iny
		cpy #$20
		bcc Line2Loop

		rts

;;;
; Zero out LCD reserved RAM (set all positions to space character).
;;;

ZeroLCDRam	ldx #$00
ZeroLoop	lda #$28
		sta $7FC0,x
		inx
		lda #$08
		sta $7FC0,x
		inx
		cpx #$40
		bcc ZeroLoop

		rts

;;;
; Interrupt Service Routine.
;;;

ClassifierIsr
    lda $FFF8  ; Read the shift register.
		ldx ImageOffset
    sta $06,x
    inc ImageOffset

    ; If data is in for all 100 pixels...
    lda #$64   ; 100
    cmp ImageOffset
    bne INCOMPLETE
    jsr FindNearestNeighbor
		; Done with this image. Reset variables for next.
		lda #$00
    sta ImageOffset
		lda #$FF
    sta MinValue

		; else...
INCOMPLETE

		; Send an interrupt clear.
    lda $FFF9

		rti

;;;
; Find nearest known image to current image data and store it's class.
;;;

FindNearestNeighbor

  ;;;
  ; UP
  ;;;

  ldy #$00
  sty RunningTotal
Image0_up_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image0_up,y
  cmp $06,y
  bcc Image0_up_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
	sbc $06,y
  jmp Image0_up_skip2
Image0_up_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
	sbc Image0_up,y
Image0_up_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image0_up_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image0_up_skip3 ; if RunningTotal >= MinValue, branch
  ; RunningTotal < MinValue at this point
  sta MinValue
  lda #$00
  sta Class
Image0_up_skip3


  ldy #$00
  sty RunningTotal
Image1_up_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image1_up,y
  cmp $06,y
  bcc Image1_up_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
	sbc $06,y
  jmp Image1_up_skip2
Image1_up_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image1_up,y
Image1_up_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image1_up_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image1_up_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$00
  sta Class
Image1_up_skip3


  ldy #$00
  sty RunningTotal
Image2_up_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image2_up,y
  cmp $06,y
  bcc Image2_up_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image2_up_skip2
Image2_up_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image2_up,y
Image2_up_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image2_up_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image2_up_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$00
  sta Class
Image2_up_skip3


  ldy #$00
  sty RunningTotal
Image3_up_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image3_up,y
  cmp $06,y
  bcc Image3_up_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image3_up_skip2
Image3_up_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image3_up,y
Image3_up_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image3_up_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image3_up_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$00
  sta Class
Image3_up_skip3


  ldy #$00
  sty RunningTotal
Image4_up_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image4_up,y
  cmp $06,y
  bcc Image4_up_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image4_up_skip2
Image4_up_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image4_up,y
Image4_up_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image4_up_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image4_up_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$00
  sta Class
Image4_up_skip3


  ldy #$00
  sty RunningTotal
Image5_up_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image5_up,y
  cmp $06,y
  bcc Image5_up_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image5_up_skip2
Image5_up_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image5_up,y
Image5_up_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image5_up_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image5_up_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$00
  sta Class
Image5_up_skip3


  ldy #$00
  sty RunningTotal
Image6_up_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image6_up,y
  cmp $06,y
  bcc Image6_up_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image6_up_skip2
Image6_up_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image6_up,y
Image6_up_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image6_up_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image6_up_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$00
  sta Class
Image6_up_skip3


  ldy #$00
  sty RunningTotal
Image7_up_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image7_up,y
  cmp $06,y
  bcc Image7_up_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image7_up_skip2
Image7_up_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image7_up,y
Image7_up_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image7_up_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image7_up_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$00
  sta Class
Image7_up_skip3


  ldy #$00
  sty RunningTotal
Image8_up_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image8_up,y
  cmp $06,y
  bcc Image8_up_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image8_up_skip2
Image8_up_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image8_up,y
Image8_up_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image8_up_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image8_up_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$00
  sta Class
Image8_up_skip3


  ldy #$00
  sty RunningTotal
Image9_up_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image9_up,y
  cmp $06,y
  bcc Image9_up_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image9_up_skip2
Image9_up_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image9_up,y
Image9_up_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image9_up_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image9_up_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$00
  sta Class
Image9_up_skip3


  ;;;
  ; DOWN
  ;;;

  ldy #$00
  sty RunningTotal
Image0_down_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image0_down,y
  cmp $06,y
  bcc Image0_down_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image0_down_skip2
Image0_down_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image0_down,y
Image0_down_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image0_down_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image0_down_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$01
  sta Class
Image0_down_skip3


  ldy #$00
  sty RunningTotal
Image1_down_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image1_down,y
  cmp $06,y
  bcc Image1_down_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image1_down_skip2
Image1_down_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image1_down,y
Image1_down_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image1_down_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image1_down_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$01
  sta Class
Image1_down_skip3


  ldy #$00
  sty RunningTotal
Image2_down_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image2_down,y
  cmp $06,y
  bcc Image2_down_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image2_down_skip2
Image2_down_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image2_down,y
Image2_down_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image2_down_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image2_down_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$01
  sta Class
Image2_down_skip3


  ldy #$00
  sty RunningTotal
Image3_down_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image3_down,y
  cmp $06,y
  bcc Image3_down_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image3_down_skip2
Image3_down_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image3_down,y
Image3_down_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image3_down_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image3_down_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$01
  sta Class
Image3_down_skip3


  ldy #$00
  sty RunningTotal
Image4_down_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image4_down,y
  cmp $06,y
  bcc Image4_down_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image4_down_skip2
Image4_down_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image4_down,y
Image4_down_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image4_down_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image4_down_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$01
  sta Class
Image4_down_skip3


  ldy #$00
  sty RunningTotal
Image5_down_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image5_down,y
  cmp $06,y
  bcc Image5_down_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image5_down_skip2
Image5_down_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image5_down,y
Image5_down_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image5_down_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image5_down_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$01
  sta Class
Image5_down_skip3


  ldy #$00
  sty RunningTotal
Image6_down_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image6_down,y
  cmp $06,y
  bcc Image6_down_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image6_down_skip2
Image6_down_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image6_down,y
Image6_down_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image6_down_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image6_down_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$01
  sta Class
Image6_down_skip3


  ldy #$00
  sty RunningTotal
Image7_down_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image7_down,y
  cmp $06,y
  bcc Image7_down_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image7_down_skip2
Image7_down_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image7_down,y
Image7_down_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image7_down_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image7_down_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$01
  sta Class
Image7_down_skip3


  ldy #$00
  sty RunningTotal
Image8_down_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image8_down,y
  cmp $06,y
  bcc Image8_down_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image8_down_skip2
Image8_down_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image8_down,y
Image8_down_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image8_down_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image8_down_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$01
  sta Class
Image8_down_skip3


  ldy #$00
  sty RunningTotal
Image9_down_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image9_down,y
  cmp $06,y
  bcc Image9_down_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image9_down_skip2
Image9_down_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image9_down,y
Image9_down_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image9_down_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image9_down_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$01
  sta Class
Image9_down_skip3


  ;;;
  ; LEFT
  ;;;

  ldy #$00
  sty RunningTotal
Image0_left_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image0_left,y
  cmp $06,y
  bcc Image0_left_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image0_left_skip2
Image0_left_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image0_left,y
Image0_left_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image0_left_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image0_left_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$02
  sta Class
Image0_left_skip3


  ldy #$00
  sty RunningTotal
Image1_left_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image1_left,y
  cmp $06,y
  bcc Image1_left_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image1_left_skip2
Image1_left_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image1_left,y
Image1_left_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image1_left_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image1_left_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$02
  sta Class
Image1_left_skip3


  ldy #$00
  sty RunningTotal
Image2_left_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image2_left,y
  cmp $06,y
  bcc Image2_left_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image2_left_skip2
Image2_left_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image2_left,y
Image2_left_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image2_left_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image2_left_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$02
  sta Class
Image2_left_skip3


  ldy #$00
  sty RunningTotal
Image3_left_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image3_left,y
  cmp $06,y
  bcc Image3_left_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image3_left_skip2
Image3_left_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image3_left,y
Image3_left_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image3_left_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image3_left_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$02
  sta Class
Image3_left_skip3


  ldy #$00
  sty RunningTotal
Image4_left_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image4_left,y
  cmp $06,y
  bcc Image4_left_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image4_left_skip2
Image4_left_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image4_left,y
Image4_left_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image4_left_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image4_left_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$02
  sta Class
Image4_left_skip3


  ldy #$00
  sty RunningTotal
Image5_left_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image5_left,y
  cmp $06,y
  bcc Image5_left_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image5_left_skip2
Image5_left_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image5_left,y
Image5_left_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image5_left_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image5_left_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$02
  sta Class
Image5_left_skip3


  ldy #$00
  sty RunningTotal
Image6_left_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image6_left,y
  cmp $06,y
  bcc Image6_left_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image6_left_skip2
Image6_left_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image6_left,y
Image6_left_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image6_left_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image6_left_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$02
  sta Class
Image6_left_skip3


  ldy #$00
  sty RunningTotal
Image7_left_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image7_left,y
  cmp $06,y
  bcc Image7_left_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image7_left_skip2
Image7_left_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image7_left,y
Image7_left_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image7_left_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image7_left_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$02
  sta Class
Image7_left_skip3


  ldy #$00
  sty RunningTotal
Image8_left_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image8_left,y
  cmp $06,y
  bcc Image8_left_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image8_left_skip2
Image8_left_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image8_left,y
Image8_left_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image8_left_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image8_left_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$02
  sta Class
Image8_left_skip3


  ldy #$00
  sty RunningTotal
Image9_left_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image9_left,y
  cmp $06,y
  bcc Image9_left_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image9_left_skip2
Image9_left_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image9_left,y
Image9_left_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image9_left_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image9_left_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$02
  sta Class
Image9_left_skip3


  ;;;
  ; RIGHT
  ;;;

  ldy #$00
  sty RunningTotal
Image0_right_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image0_right,y
  cmp $06,y
  bcc Image0_right_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image0_right_skip2
Image0_right_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image0_right,y
Image0_right_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image0_right_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image0_right_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$03
  sta Class
Image0_right_skip3


  ldy #$00
  sty RunningTotal
Image1_right_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image1_right,y
  cmp $06,y
  bcc Image1_right_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image1_right_skip2
Image1_right_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image1_right,y
Image1_right_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image1_right_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image1_right_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$03
  sta Class
Image1_right_skip3


  ldy #$00
  sty RunningTotal
Image2_right_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image2_right,y
  cmp $06,y
  bcc Image2_right_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image2_right_skip2
Image2_right_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image2_right,y
Image2_right_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image2_right_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image2_right_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$03
  sta Class
Image2_right_skip3


  ldy #$00
  sty RunningTotal
Image3_right_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image3_right,y
  cmp $06,y
  bcc Image3_right_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image3_right_skip2
Image3_right_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image3_right,y
Image3_right_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image3_right_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image3_right_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$03
  sta Class
Image3_right_skip3


  ldy #$00
  sty RunningTotal
Image4_right_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image4_right,y
  cmp $06,y
  bcc Image4_right_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image4_right_skip2
Image4_right_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image4_right,y
Image4_right_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image4_right_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image4_right_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$03
  sta Class
Image4_right_skip3


  ldy #$00
  sty RunningTotal
Image5_right_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image5_right,y
  cmp $06,y
  bcc Image5_right_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image5_right_skip2
Image5_right_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image5_right,y
Image5_right_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image5_right_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image5_right_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$03
  sta Class
Image5_right_skip3


  ldy #$00
  sty RunningTotal
Image6_right_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image6_right,y
  cmp $06,y
  bcc Image6_right_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image6_right_skip2
Image6_right_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image6_right,y
Image6_right_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image6_right_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image6_right_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$03
  sta Class
Image6_right_skip3


  ldy #$00
  sty RunningTotal
Image7_right_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image7_right,y
  cmp $06,y
  bcc Image7_right_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image7_right_skip2
Image7_right_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image7_right,y
Image7_right_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image7_right_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image7_right_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$03
  sta Class
Image7_right_skip3


  ldy #$00
  sty RunningTotal
Image8_right_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image8_right,y
  cmp $06,y
  bcc Image8_right_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image8_right_skip2
Image8_right_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image8_right,y
Image8_right_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image8_right_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image8_right_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$03
  sta Class
Image8_right_skip3


  ldy #$00
  sty RunningTotal
Image9_right_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image9_right,y
  cmp $06,y
  bcc Image9_right_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image9_right_skip2
Image9_right_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image9_right,y
Image9_right_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image9_right_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image9_right_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$03
  sta Class
Image9_right_skip3


  ;;;
  ; NOTHING
  ;;;

  ldy #$00
  sty RunningTotal
Image0_nothing_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image0_nothing,y
  cmp $06,y
  bcc Image0_nothing_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image0_nothing_skip2
Image0_nothing_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image0_nothing,y
Image0_nothing_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image0_nothing_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image0_nothing_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$04
  sta Class
Image0_nothing_skip3


  ldy #$00
  sty RunningTotal
Image1_nothing_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image1_nothing,y
  cmp $06,y
  bcc Image1_nothing_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image1_nothing_skip2
Image1_nothing_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image1_nothing,y
Image1_nothing_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image1_nothing_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image1_nothing_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$04
  sta Class
Image1_nothing_skip3


  ldy #$00
  sty RunningTotal
Image2_nothing_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image2_nothing,y
  cmp $06,y
  bcc Image2_nothing_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image2_nothing_skip2
Image2_nothing_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image2_nothing,y
Image2_nothing_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image2_nothing_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image2_nothing_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$04
  sta Class
Image2_nothing_skip3


  ldy #$00
  sty RunningTotal
Image3_nothing_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image3_nothing,y
  cmp $06,y
  bcc Image3_nothing_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image3_nothing_skip2
Image3_nothing_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image3_nothing,y
Image3_nothing_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image3_nothing_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image3_nothing_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$04
  sta Class
Image3_nothing_skip3


  ldy #$00
  sty RunningTotal
Image4_nothing_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image4_nothing,y
  cmp $06,y
  bcc Image4_nothing_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image4_nothing_skip2
Image4_nothing_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image4_nothing,y
Image4_nothing_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image4_nothing_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image4_nothing_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$04
  sta Class
Image4_nothing_skip3


  ldy #$00
  sty RunningTotal
Image5_nothing_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image5_nothing,y
  cmp $06,y
  bcc Image5_nothing_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image5_nothing_skip2
Image5_nothing_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image5_nothing,y
Image5_nothing_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image5_nothing_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image5_nothing_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$04
  sta Class
Image5_nothing_skip3


  ldy #$00
  sty RunningTotal
Image6_nothing_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image6_nothing,y
  cmp $06,y
  bcc Image6_nothing_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image6_nothing_skip2
Image6_nothing_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image6_nothing,y
Image6_nothing_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image6_nothing_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image6_nothing_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$04
  sta Class
Image6_nothing_skip3


  ldy #$00
  sty RunningTotal
Image7_nothing_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image7_nothing,y
  cmp $06,y
  bcc Image7_nothing_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image7_nothing_skip2
Image7_nothing_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image7_nothing,y
Image7_nothing_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image7_nothing_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image7_nothing_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$04
  sta Class
Image7_nothing_skip3


  ldy #$00
  sty RunningTotal
Image8_nothing_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image8_nothing,y
  cmp $06,y
  bcc Image8_nothing_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image8_nothing_skip2
Image8_nothing_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image8_nothing,y
Image8_nothing_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image8_nothing_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image8_nothing_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$04
  sta Class
Image8_nothing_skip3


  ldy #$00
  sty RunningTotal
Image9_nothing_loop
  ; Determine order of values (max first) and do subtraction.
  lda Image9_nothing,y
  cmp $06,y
  bcc Image9_nothing_skip1 ; if A < cmp value
  ; A >= cmp value at this point
  sec
  sbc $06,y
  jmp Image9_nothing_skip2
Image9_nothing_skip1
  ; A < cmp value at this point
  lda $06,y
  sec
  sbc Image9_nothing,y
Image9_nothing_skip2

  ; Add current pixel difference to running total
  ; for this image.
  clc
	adc RunningTotal
  sta RunningTotal

  iny
  cpy #$64
  bne Image9_nothing_loop

  ; If RunningTotal < MinValue:
  ; MinValue = RunningTotal
  ; Class = current class
  lda RunningTotal
  cmp MinValue
  bcs Image9_nothing_skip3 ; if A >= cmp value
  ; MinValue < RunningTotal at this point
  sta MinValue
  lda #$04
  sta Class
Image9_nothing_skip3

	; Display class.

	; $FFF4 - Send up arrow command to 2600 emulator.
	; $FFF5 - Send down arrow command to 2600 emulator.
	; $FFF6 - Send left arrow command to 2600 emulator.
	; $FFF7 - Send right arrow command to 2600 emulator.

  lda Class
  cmp #$00
  bne next1

  ; 0
	lda $FFF4 ; Send up arrow.

  lda #$38
  sta $7FC2
  lda #$08
  sta $7FC3
  jsr WriteLCD
  jmp ALLDONE

next1
  lda Class
  cmp #$01
  bne next2

  ; 1
	lda $FFF5 ; Send down arrow.

  lda #$38
  sta $7FC2
  lda #$18
  sta $7FC3
  jsr WriteLCD
  jmp ALLDONE

next2
  lda Class
  cmp #$02
  bne next3

  ; 2
	lda $FFF6 ; Send left arrow.

  lda #$38
  sta $7FC2
  lda #$28
  sta $7FC3
  jsr WriteLCD
  jmp ALLDONE

next3
  lda Class
  cmp #$03
  bne next4

  ; 3
	lda $FFF7 ; Send right arrow.

  lda #$38
  sta $7FC2
  lda #$38
  sta $7FC3
  jsr WriteLCD
  jmp ALLDONE

next4
  lda Class
  cmp #$04
  bne next5

  ; 4
  lda #$38
  sta $7FC2
  lda #$48
  sta $7FC3
  jsr WriteLCD
  jmp ALLDONE

next5
ALLDONE

  rts

;;;
; Training data lookup tables.
;;;

Image0_up
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$01
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$00
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image1_up
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$00
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05

Image2_up
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$00
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05

Image3_up
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$01
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image4_up
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$03
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$05
    .byte #$01
    .byte #$01
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$00
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image5_up
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$02
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$01
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05

Image6_up
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$02
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$01
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image7_up
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$01
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$01
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image8_up
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$05
    .byte #$02
    .byte #$02
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$01
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image9_up
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$02
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05


Image0_down
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05

Image1_down
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05

Image2_down
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05

Image3_down
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05

Image4_down
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$01
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05

Image5_down
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05

Image6_down
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05

Image7_down
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$00
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05

Image8_down
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$01
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05

Image9_down
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$00
    .byte #$00
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05


Image0_left
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$00
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$01
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image1_left
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$01
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$03
    .byte #$00
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image2_left
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$00
    .byte #$00
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$03
    .byte #$00
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image3_left
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$00
    .byte #$00
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$01
    .byte #$00
    .byte #$01
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image4_left
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$01
    .byte #$00
    .byte #$00
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$01
    .byte #$01
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image5_left
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$00
    .byte #$00
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$01
    .byte #$02
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image6_left
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$00
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$01
    .byte #$02
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image7_left
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$00
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$01
    .byte #$01
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image8_left
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$01
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image9_left
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$01
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05


Image0_right
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$00
    .byte #$00
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$01
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$03
    .byte #$01
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$01
    .byte #$00
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04

Image1_right
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$00
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$01
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$01
    .byte #$00
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image2_right
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$00
    .byte #$00
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$01
    .byte #$01
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$01
    .byte #$01
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$01
    .byte #$01
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04

Image3_right
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$02
    .byte #$02
    .byte #$01
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$03
    .byte #$00
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$01
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image4_right
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$01
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$00
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$05
    .byte #$02
    .byte #$00
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image5_right
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$01
    .byte #$02
    .byte #$02
    .byte #$00
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$01
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$01
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03

Image6_right
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$00
    .byte #$01
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$02
    .byte #$01
    .byte #$02
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$01
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$00
    .byte #$02
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$01
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03

Image7_right
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$04
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$01
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$02
    .byte #$00
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$05
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04

Image8_right
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$00
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$01
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$05
    .byte #$01
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image9_right
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$00
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$01
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$04
    .byte #$02
    .byte #$02
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$01
    .byte #$01
    .byte #$03
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$03
    .byte #$02
    .byte #$01
    .byte #$00
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$01
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$02
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05


Image0_nothing
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image1_nothing
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image2_nothing
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image3_nothing
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image4_nothing
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image5_nothing
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image6_nothing
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image7_nothing
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image8_nothing
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05

Image9_nothing
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05
    .byte #$05


; Store the location of key program sections.
		ORG $FFFC
ResetVector
		.word StartExe		        ; Start of execution.
IrqVector
		.word ClassifierIsr				; Interrupt service routine.
