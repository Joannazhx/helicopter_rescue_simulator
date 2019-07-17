.include "m2560def.inc"

.equ LCD_CTRL_PORT = PORTA
.equ LCD_CTRL_DDR = DDRA
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4	

.equ LCD_DATA_PORT = PORTF
.equ LCD_DATA_DDR = DDRF
.equ LCD_DATA_PIN = PINF

.def row = r24 //row
.def col = r17 //column
.def rmask = r18 //mask for current row during scan
.def cmask = r19 //mask for current column during scan
.def temp1 = r20
.def temp2 = r16

.equ PORTFDIR =0xF0  //PORTf 4-7BIT SET FOR OUTPUT
.equ INITCOLMASK = 0xEF //11101111 SCAN colum from the left  C3 c2 c1 c0 r3 r2 r1 r0
.equ INITROWMASK = 0x01 //
.equ ROWMASK = 0x0F // for get input from PortF

.equ pattern = 0b11111111
.equ pattern1 = 0b00000000

.cseg

	jmp Reset
.org INT0addr
	jmp Ext_int0
.org INT1addr 
	jmp EXT_INT1

.macro STORE
.if @0 > 63 //I/O adress or not
sts @0, @1
.else
out @0, @1
.endif
.endmacro

.macro LOAD
.if @1 > 63 //I/O adress or not
lds @0, @1
.else
in @0, @1
.endif
.endmacro

.macro do_lcd_command
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro
.macro do_lcd_data
	ldi r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

Ext_int0:
	sbrs r26,0
	reti
	sbrc r26,1
	reti
	push temp1 //save register
	in temp1,SREG //save SREG
	push temp1	
	//out PortC,output //display pattern now
	pop temp1
	out SREG,temp1
	pop temp1
	ldi temp1,0b00001111
	sts PORTL,temp1
delay1s_1:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ldi r18,1
	add r19,r18
	ldi r18,255
	cp r18,r19
	brne delay1s_1
	ldi temp1,0b11110000
	sts PORTL,temp1
delay1s_2:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ldi r18,1
	add r19,r18
	ldi r18,255
	cp r18,r19
	brne delay1s_2
	ldi temp1,0b11111111
	sts PORTL,temp1
delay1s_3:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ldi r18,1
	add r19,r18
	ldi r18,255
	cp r18,r19
	brne delay1s_3
	ldi temp1,0b00000000
	sts PORTL,temp1
	do_lcd_command 0b11000000
	do_lcd_data's'
	do_lcd_data't'
	do_lcd_data'a'
	do_lcd_data't'
	do_lcd_data'u'
	do_lcd_data's'
	do_lcd_data':'
	do_lcd_data'B'
	do_lcd_data'E'
	ldi temp1,0b00000010
	or r26,temp1
	reti
EXT_INT1:
	sbrs r26,0
	reti
	sbrs r26,1
	reti
	push temp1 //save register
	in temp1,SREG //save SREG
	push temp1	
	//out PortC,output //display pattern now
	pop temp1
	out SREG,temp1
	pop temp1
	do_lcd_command 0b11000000
	sbrs r26,5
	do_lcd_command 0b000000010
	do_lcd_data'S'
	do_lcd_data'T'
	do_lcd_data' '
	do_lcd_data' '
	do_lcd_data' '
	do_lcd_data' '
	do_lcd_data' '
	do_lcd_data' '
	do_lcd_data' '
	do_lcd_data' '
	sbrs r26,5
	do_lcd_data'N'
	do_lcd_data'F'
	ldi r16,0b00010000
	or r26,r16
	rjmp comp	
RESET:
	in r16,DDRE
	ori r16,0b00010000
	out DDRE,r16
	clr r16
	sts OCR3BH,r16
	ldi r16,0  
	sts OCR3BL,r16
	ldi r16,(1<<CS30)
	sts TCCR3B,r16
	ldi r16,(1<<WGM30)|(1<<COM3B1)
	sts TCCR3A,r16
	ser temp1 //set port L for output
	sts DDRL,temp1
	ldi temp1,(2<<ISC00)|(2<<ISC10) //EICA (3-0) set ISC00 ISC01 0 1 for falling edge triiger interrupt(2 = 10)
	sts EICRA,temp1

	in temp1,EIMSK   //enable int0(mask EIMSk bit 0 =1)
	ori temp1,(1<<Int0)|(1<<INT1)
	out EIMSK,temp1

	sei   //enable SREG I bit(global interrupt)

	ldi r26,0b00000000
	ldi temp1,PORTFDIR //DDRF 1111 0000 bit 4-7 for output 0-3 input
	out DDRC,temp1

	ldi r16, low(RAMEND)//put the pointer of stack to the lowest address to avoid conflict
	out SPL, r16
	ldi r16, high(RAMEND)
	out SPH, r16

	ser r16 //portA to control lcd,portF for lcd output
	STORE LCD_DATA_DDR, r16
	STORE LCD_CTRL_DDR, r16
	clr r16
	STORE LCD_DATA_PORT, r16
	STORE LCD_CTRL_PORT, r16

	//Software Initialization(8 bits)
	do_lcd_command 0b00111000 ; 2x5x7  Software Initialization 2line display,8-bit length,5 x 7 dots 
	//Function Set Command: (8-Bit interface) BF cannot be checked before this command
	rcall sleep_5ms //No data should be transferred to or from the display during this time.
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00001110 ; increment, no display shift //Cursor or Display Shift Shifts cursor position to the right (AC is incremented by one)
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink
	do_lcd_data'X'
	do_lcd_data':'
	ldi r27,0

main:
	sbrc r26,0
	rjmp inbutton
	ldi cmask,INITCOLMASK //colmask from left
	clr col  //row from 0
	rjmp colloop

colloop:
	cpi col,4  //all nor pressed back
	breq main
	out PORTC,cmask  //scan column
	ldi temp1,0xFF

delay:
	dec temp1 //slow down scan colum
	brne delay

	in temp1,PINC   //read portF
	andi temp1,ROWMASK //get value from cureet colum
	cpi temp1,0xF
	breq nextcol //no 0(pressed) scan next colum

	ldi rmask,INITROWMASK //rowmask from 0001
	clr row //from 0

rowloop:
	cpi row,4 //row scan over
	breq nextcol 
	mov temp2,temp1
	and temp2,rmask //get (colum,row) pressed or not
	breq continue //0 to get number
	inc row
	lsl rmask //0001 -- 0010 -- 0100 -- 1000
	jmp rowloop

nextcol:  //row scan over
	lsl cmask 
	inc col // column +1
	jmp colloop

continue:
	in temp1,PINC  //read portC
	andi temp1,ROWMASK //get value from cureet colum
	cpi temp1,0xF 
	breq convert //loose button then display it
	rjmp continue 

convert:
	cpi col,3 //co3 has A,B,C,D
	breq letters
	cpi row,3
	breq symbols //row3 0,*,#
	mov temp1,row // or 1-9
	lsl temp1 //row *3 + col
	add temp1,row
	add temp1,col
	subi temp1,-1
	ldi r16,'0'
	add r16,temp1
	rcall lcd_data
	rcall lcd_wait
	rjmp convert_end

letters:
	jmp wrong

symbols:
	cpi col,0
	breq star //*
	cpi col,1
	breq zero //0
	ldi r19,63
	cp r19,r27
	brlo wrong
	ldi r19,0b00000001
	or r26,r19
	rjmp playxyz

star://*
	mov r28,r27 //1st num to r28
	ldi r27,0 //r27 clear
	ldi r19,0b00000010
	//or r26,r19
	do_lcd_command 0b11000000
	do_lcd_data'Y'
	do_lcd_data':'
	rjmp main
zero:
	ldi temp1,0
	ldi r16,'0'
	add r16,temp1
	rcall lcd_data
	rcall lcd_wait
convert_end: 
	ldi r16,10
	mul r27,r16
	mov r27,r0
	add r27,temp1
	ldi r19,63
	cp r19,r27
	brlo wrong
	rjmp main

wrong:
	do_lcd_command 0b00000001
	do_lcd_data'w'
	do_lcd_data'r'
	do_lcd_data'o'
	do_lcd_data'n'
	do_lcd_data'g'
	ldi r19,0
delay1s:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ldi r18,1
	add r19,r18
	ldi r18,255
	cp r18,r19
	brne delay1s
rest:
	rjmp reset

playxyz:
	mov r2,r28
	mov r3,r27
	ldi ZH, high(table<<1) ; initialize Z 
	ldi ZL, low(table<<1)
	ldi r19,64
	mul r27,r19
	mov r16,r0
	mov r17,r1
	add r16,r28
	ldi r19,0
	adc r17,r19
	clc
	add r30,r16
	adc r31,r19
	clc
	add r31,r17
	lpm r17, Z
	do_lcd_command 0b00000001
	do_lcd_data'('
	ldi r16,10
	ldi r18,0
	mov r19,r28
	cp r28,r16
	brsh sub10
	ldi r16,'0'
	add r16,r19
	rcall lcd_data
	rcall lcd_wait
	rjmp disy
sub10:
	 sub r19,r16
	 inc r18
	 cp r19,r16
	 brsh sub10
	 ldi r16,'0'
	 add r16,r18
	 rcall lcd_data
	 rcall lcd_wait
	 ldi r16,'0'
	 add r16,r19
	 rcall lcd_data
	 rcall lcd_wait	
disy:
	do_lcd_data','
	ldi r16,10
	ldi r18,0
	mov r19,r27
	cp r27,r16
	brsh sub10_y
	ldi r16,'0'
	add r16,r19
	rcall lcd_data
	rcall lcd_wait
	rjmp dis_z
sub10_y:
	 sub r19,r16
	 inc r18
	 cp r19,r16
	 brsh sub10_y
	 ldi r16,'0'
	 add r16,r18
	 rcall lcd_data
	 rcall lcd_wait
	 ldi r16,'0'
	 add r16,r19
	 rcall lcd_data
	 rcall lcd_wait	
dis_z:
	do_lcd_data','
	ldi r16,10
	ldi r18,0
	mov r19,r17
	cp r17,r16
	brsh sub10_z
	ldi r16,'0'
	add r16,r19
	rcall lcd_data
	rcall lcd_wait
	do_lcd_data')'
	ldi r19,0b10000000
	or r17,r19
	st Z,r17
	lpm r17,Z
	sbrc r17,7
	do_lcd_data' '
	rjmp showstatus
sub10_z:
	 sub r19,r16
	 inc r18
	 cp r19,r16
	 brsh sub10_z
	 ldi r16,'0'
	 add r16,r18
	 rcall lcd_data
	 rcall lcd_wait
	 ldi r16,'0'
	 add r16,r19
	 rcall lcd_data
	 rcall lcd_wait
	 do_lcd_data')'
	 ldi r19,0b10000000
	 or r17,r19
	  st Z,r17
	 lpm r17,Z
	 
showstatus:
	ldi ZH, high(table<<1) ; initialize Z 
	ldi ZL, low(table<<1)
	ldi r19,64
	mul r27,r19
	mov r16,r0
	mov r17,r1
	add r16,r28
	ldi r19,0
	adc r17,r19
	clc
	add r30,r16
	adc r31,r19
	clc
	add r31,r17
	lpm r17, Z
	do_lcd_command 0b11000000
	
	do_lcd_data's'
	do_lcd_data't'
	do_lcd_data'a'
	do_lcd_data't'
	do_lcd_data'u'
	do_lcd_data's'
	do_lcd_data':'
	do_lcd_data'U'
	do_lcd_data'B'	
inbutton:
	sbrs r26,1
	rjmp inbutton
	ldi r17,0
	ldi r21,0
	ldi ZH, high(table<<1) ; initialize Z 
	ldi ZL, low(table<<1)
	lpm r22,Z
	do_lcd_command 0b11000000
	do_lcd_data's'
	do_lcd_data't'
	do_lcd_data'a'
	do_lcd_data't'
	do_lcd_data'u'
	do_lcd_data's'
	do_lcd_data':'
	do_lcd_data'U'
	do_lcd_data'p'
	ldi r16,0xFF
	sts OCR3BL,r16
	ldi r16,10
	ldi r18,0
	mov r19,r22	
startup:
	ldi r16,10
	cp r22,r16
	brsh sub10_zu
	rjmp upz
sub10_zu:
	 sub r19,r16
	 inc r18
	 cp r19,r16
	 brsh sub10_zu
	 ldi r20,0
upz:
	do_lcd_command 0b10000000
	do_lcd_data'('
	do_lcd_data'0'
	do_lcd_data','
	do_lcd_data'0'
	do_lcd_data')'
	do_lcd_data' '

	inc r20
	inc r19
	ldi r16,0
	adc r18,r16
	clc
	ldi r16,'0'
	add r16,r18
	rcall lcd_data
	rcall lcd_wait
	ldi r16,'0'
	add r16,r19
	rcall lcd_data
	rcall lcd_wait
	ldi r16,0
	rcall delay1s_0
	ldi r16,5
	cp r20,r16
	brne upz
startsea:
	do_lcd_command 0b11000000
	do_lcd_data's'
	do_lcd_data't'
	do_lcd_data'a'
	do_lcd_data't'
	do_lcd_data'u'
	do_lcd_data's'
	do_lcd_data':'
	do_lcd_data'S'
	do_lcd_data'E'
	ldi r16,0b01000000
	or r26,r16
	ldi r23,0
	ldi ZH, high(table<<1) ; initialize Z 
	ldi ZL, low(table<<1)
	ldi r17,0
	ldi r21,0
comp:
	ldi r16,0
delay1s_5:
	rcall sleep_1ms
	ldi r19,1
	add r16,r19
	ldi r19,100
	cp r19,r16
	brne delay1s_5
	mov r19,r17
	do_lcd_command 0b10000000
	do_lcd_data'('
	mov r19,r17
	rcall getnum
	mov r17,r19
	do_lcd_data','
	mov r19,r21
	rcall getnum
	mov r21,r19
	do_lcd_data')'
	do_lcd_data' '
	lpm r22,Z
	ldi r16,5
	add r22,r16
	mov r19,r22
	rcall getnum
	do_lcd_data' '
	mov r22,r19

	sbrc r26,5
	rjmp back
	sbrc r26,4
	rjmp back
	cp r2,r17
	breq cpb
	rjmp oe
cpb:
	cp r3,r21
	breq found
	rjmp oe
found:
	ldi r27,0x1F
	sts OCR3BL,r27
	mov r4,r22
	do_lcd_command 0b11000000
	do_lcd_data's'
	do_lcd_data't'
	do_lcd_data'a'
	do_lcd_data't'
	do_lcd_data'u'
	do_lcd_data's'
	do_lcd_data':'
	do_lcd_data'F'
	do_lcd_data'O'
	ldi temp1,0b11111111
	sts PORTL,temp1
	ldi r16,0
	rcall delay1s_0
	ldi temp1,0b00000000
	sts PORTL,temp1
	ldi r16,0
	rcall delay1s_0
	ldi temp1,0b11111111
	sts PORTL,temp1
	ldi r16,0
	rcall delay1s_0
	ldi temp1,0b00000000
	sts PORTL,temp1
	rcall delay1s_0
	ldi temp1,0b11111111
	sts PORTL,temp1
	ldi r16,0
	rcall delay1s_0
	ldi temp1,0b00000000
	sts PORTL,temp1
	ldi r16,0
	rcall delay1s_0
	ldi r16,0b00100000
	or r26,r16
	ldi r27,0xFF
	sts OCR3BL,r27`
	rjmp comp

back:
	sbrc r26,6
	rjmp odd0

	ldi r16,63
	cp r17,r16
	breq set63
	inc r17
	ldi r16,1
	add r30,r16
	ldi r16,0
	adc r31,r16
	clc
	rjmp comp
set63:
	ldi r17,63
	dec r21
	ldi r16,64
	sub r30,r16
	ldi r16,0
	sbc r31,r16
	clc
	ldi r16,0b01000000
	or r26,r16
	rjmp comp

dee:
	ldi r16,0
	cp r21,r16
	breq endi
	dec r21
	ldi r16,64
	sub r30,r16
	ldi r16,0
	sbc r31,r16
	clc
	andi r26,0b10111111
	rjmp comp
	
endi: 
	sbrs r26,5
	rjmp unfound
delay1s_8:
	rcall sleep_1ms
	ldi r19,1
	add r16,r19
	ldi r19,100
	cp r19,r16
	brne delay1s_8
	mov r19,r17
	do_lcd_command 0b10000000
	do_lcd_data'('
	mov r19,r2
	rcall getnum
	do_lcd_data','
	mov r19,r3
	rcall getnum
	do_lcd_data','
	mov r19,r4
	ldi r16,5
	sub r19,r16
	rcall getnum
	do_lcd_data')'
	do_lcd_data' '

eddd:
	ldi temp1,0x00
	sts OCR3BL,temp1`
	rjmp eddd
odd0:
	ldi r16,0
	cp r17,r16
	breq dee
	dec r17
	ldi r16,1
	sub r30,r16
	ldi r16,0
	sbc r31,r16
	clc
	rjmp comp

oe:
	sbrc r26,6
	rjmp odd
	ldi r16,0
	cp r17,r16
	breq pl11
	dec r17
	ldi r16,1
	sub r30,r16
	ldi r16,0
	sbc r31,r16
	clc
	rjmp comp

pl11:
	ldi r17,0
	inc r21
	ldi r16,64
	add r30,r16
	ldi r16,0
	adc r31,r16
	clc
	ldi r23,0
	ldi r16,0b01000000
	or r26,r16
	do_lcd_data' '
	rjmp comp
odd:
	ldi r16,63
	cp r17,r16
	breq mul64
	inc r17
	ldi r16,1
	add r30,r16
	ldi r16,0
	adc r31,r16
	clc 
	do_lcd_data' '
	rjmp comp

mul64:

	ldi r16,64
	add r30,r16
	ldi r16,0
	adc r31,r16
	clc
	inc r21
	andi r26,0b10111111
	do_lcd_data' '
	rjmp comp

getnum:
	ldi r18,0
	ldi r16,10
	cp r19,r16
	brsh sub10_num
	ldi r16,'0'
	add r16,r19
	rcall lcd_data
	rcall lcd_wait
	ret
sub10_num:
	 sub r19,r16
	 inc r18
	 cp r19,r16
	 brsh sub10_num
	 ldi r16,'0'
	 add r16,r18
	 rcall lcd_data
	 rcall lcd_wait
	 ldi r16,'0'
	 add r16,r19
	 rcall lcd_data
	 rcall lcd_wait
	 ldi r16,10
	mul r18,r16
	mov r18,r0
	add r19,r18
	 ret
	 
	
end:
	ldi temp1,0x00
	sts OCR3BL,temp1`
	rjmp end


unfound:
	do_lcd_command 0b11000000
	do_lcd_data's'
	do_lcd_data't'
	do_lcd_data'a'
	do_lcd_data't'
	do_lcd_data'u'
	do_lcd_data's'
	do_lcd_data':'
	do_lcd_data'U'
	do_lcd_data'F'
	do_lcd_command 0b10000000
	do_lcd_data'('
	do_lcd_data'0'
	do_lcd_data','
	do_lcd_data'0'
	do_lcd_data','
	do_lcd_data'0'
	do_lcd_data')'
	do_lcd_data'A'
	do_lcd_data'b'
	do_lcd_data' '
	rjmp end

.macro lcd_set
	sbi LCD_CTRL_PORT, @0
.endmacro
.macro lcd_clr
	cbi LCD_CTRL_PORT, @0
.endmacro

;
; Send a command to the LCD (r16)
;

lcd_command:
	STORE LCD_DATA_PORT, r16 //RS = 0, RW = 0 for a command write
	rcall sleep_1ms //delay to meet timing (Set up time)
	lcd_set LCD_E //turn on the enable pin
	rcall sleep_1ms //delay to meet timing (Enable pulse width)
	lcd_clr LCD_E //turn off the enable pin
	rcall sleep_1ms //delay to meet timing (Enable cycle time)
	ret

lcd_data:
	STORE LCD_DATA_PORT, r16 //set the data port's value up
	lcd_set LCD_RS //RS = 1, RW = 0 for a data write
	rcall sleep_1ms //delay to meet timing (Set up time)
	lcd_set LCD_E //turn on the enable pin
	rcall sleep_1ms //delay to meet timing (Enable pulse width)
	lcd_clr LCD_E //turn off the enable pin
	rcall sleep_1ms //delay to meet timing (Enable cycle time)
	lcd_clr LCD_RS //RS = 0 stop writing
	ret

lcd_wait: //set portf for input,close output
	push r16
	clr r16
	STORE LCD_DATA_DDR, r16
	STORE LCD_DATA_PORT, r16
	lcd_set LCD_RW // for read
lcd_wait_loop: 
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	LOAD r16, LCD_DATA_PIN //load data to r16
	lcd_clr LCD_E
	sbrc r16, 7//check busy flag 
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser r16
	STORE LCD_DATA_DDR, r16
	pop r16
	ret

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

sleep_1ms:
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)
delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret

sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret

delay1s_0:
	rcall sleep_1ms
	ldi r24,1
	add r16,r24
	ldi r24,100
	cp r24,r16
	brne delay1s_0
	reti


table:.db 10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,15,15,15,15,15,15,15,15,15,15,15,15,15,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,15,15,15,15,15,15,15,15,15,15,15,15,15,15,10,10,15,20,20,20,20,20,20,20,20,20,20,20,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,15,20,20,20,20,20,20,20,20,20,20,20,20,15,10,10,15,20,25,25,25,25,25,25,25,25,25,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,15,20,25,25,25,25,25,25,25,25,25,25,20,15,10,10,15,20,25,30,30,30,30,30,30,30,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,15,20,25,30,30,30,30,30,30,30,30,25,20,15,10,10,15,20,25,30,35,35,35,35,35,35,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,15,20,25,30,35,35,35,35,35,35,30,25,20,15,10,10,15,20,25,30,35,40,40,40,40,35,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,15,20,25,30,35,40,40,40,40,35,30,25,20,15,10,10,15,20,25,30,35,40,45,45,40,35,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,15,20,25,30,35,40,45,45,40,35,30,25,20,15,10,10,15,20,25,30,35,40,45,45,40,35,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,15,20,25,30,35,40,45,45,40,35,30,25,20,15,10,10,15,20,25,30,35,40,40,40,40,35,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,15,20,25,30,35,40,40,40,40,35,30,25,20,15,10,10,15,20,25,30,35,35,35,35,35,35,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,15,20,25,30,35,35,35,35,35,35,30,25,20,15,10,10,15,20,25,30,30,30,30,30,30,30,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,15,20,25,30,30,30,30,30,30,30,30,25,20,15,10,10,15,20,25,25,25,25,25,25,25,25,25,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,15,20,25,25,25,25,25,25,25,25,25,25,20,15,10,10,15,20,20,20,20,20,20,20,20,20,20,20,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,15,20,20,20,20,20,20,20,20,20,20,20,20,15,10,10,15,15,15,15,15,15,15,15,15,15,15,15,15,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,15,15,15,15,15,15,15,15,15,15,15,15,15,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,25,25,25,25,25,25,25,25,25,25,25,25,25,25,20,20,25,25,25,25,25,25,25,25,25,25,25,25,25,25,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,25,30,30,30,30,30,30,30,30,30,30,30,30,25,20,20,25,30,30,30,30,30,30,30,30,30,30,30,30,25,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,25,30,35,35,35,35,35,35,35,35,35,35,30,25,20,20,25,30,35,35,35,35,35,35,35,35,35,35,30,25,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,25,30,35,40,40,40,40,40,40,40,40,35,30,25,20,20,25,30,35,40,40,40,40,40,40,40,40,35,30,25,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,25,30,35,40,45,45,45,45,45,45,40,35,30,25,20,20,25,30,35,40,45,45,45,45,45,45,40,35,30,25,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,25,30,35,40,45,50,50,50,50,45,40,35,30,25,20,20,25,30,35,40,45,50,50,50,50,45,40,35,30,25,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,25,30,35,40,45,50,55,55,50,45,40,35,30,25,20,20,25,30,35,40,45,50,55,55,50,45,40,35,30,25,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,25,30,35,40,45,50,55,55,50,45,40,35,30,25,20,20,25,30,35,40,45,50,55,55,50,45,40,35,30,25,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,25,30,35,40,45,50,50,50,50,45,40,35,30,25,20,20,25,30,35,40,45,50,50,50,50,45,40,35,30,25,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,25,30,35,40,45,45,45,45,45,45,40,35,30,25,20,20,25,30,35,40,45,45,45,45,45,45,40,35,30,25,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,25,30,35,40,40,40,40,40,40,40,40,35,30,25,20,20,25,30,35,40,40,40,40,40,40,40,40,35,30,25,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,25,30,35,35,35,35,35,35,35,35,35,35,30,25,20,20,25,30,35,35,35,35,35,35,35,35,35,35,30,25,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,25,30,30,30,30,30,30,30,30,30,30,30,30,25,20,20,25,30,30,30,30,30,30,30,30,30,30,30,30,25,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,25,25,25,25,25,25,25,25,25,25,25,25,25,25,20,20,25,25,25,25,25,25,25,25,25,25,25,25,25,25,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,20,25,25,25,25,25,25,25,25,25,25,25,25,25,25,20,20,25,25,25,25,25,25,25,25,25,25,25,25,25,25,20,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,20,25,30,30,30,30,30,30,30,30,30,30,30,30,25,20,20,25,30,30,30,30,30,30,30,30,30,30,30,30,25,20,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,20,25,30,35,35,35,35,35,35,35,35,35,35,30,25,20,20,25,30,35,35,35,35,35,35,35,35,35,35,30,25,20,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,20,25,30,35,40,40,40,40,40,40,40,40,35,30,25,20,20,25,30,35,40,40,40,40,40,40,40,40,35,30,25,20,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,20,25,30,35,40,45,45,45,45,45,45,40,35,30,25,20,20,25,30,35,40,45,45,45,45,45,45,40,35,30,25,20,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,20,25,30,35,40,45,50,50,50,50,45,40,35,30,25,20,20,25,30,35,40,45,50,50,50,50,45,40,35,30,25,20,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,20,25,30,35,40,45,50,55,55,50,45,40,35,30,25,20,20,25,30,35,40,45,50,55,55,50,45,40,35,30,25,20,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,20,25,30,35,40,45,50,55,55,50,45,40,35,30,25,20,20,25,30,35,40,45,50,55,55,50,45,40,35,30,25,20,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,20,25,30,35,40,45,50,50,50,50,45,40,35,30,25,20,20,25,30,35,40,45,50,50,50,50,45,40,35,30,25,20,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,20,25,30,35,40,45,45,45,45,45,45,40,35,30,25,20,20,25,30,35,40,45,45,45,45,45,45,40,35,30,25,20,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,20,25,30,35,40,40,40,40,40,40,40,40,35,30,25,20,20,25,30,35,40,40,40,40,40,40,40,40,35,30,25,20,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,20,25,30,35,35,35,35,35,35,35,35,35,35,30,25,20,20,25,30,35,35,35,35,35,35,35,35,35,35,30,25,20,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,20,25,30,30,30,30,30,30,30,30,30,30,30,30,25,20,20,25,30,30,30,30,30,30,30,30,30,30,30,30,25,20,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,20,25,25,25,25,25,25,25,25,25,25,25,25,25,25,20,20,25,25,25,25,25,25,25,25,25,25,25,25,25,25,20,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,20,20,20,20,20,20,20,20,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,50,45,40,35,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,50,45,40,35,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,50,45,40,35,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,50,45,40,35,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,50,45,40,35,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,50,45,40,35,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,50,45,40,35,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,50,45,40,35,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,50,45,40,35,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,50,45,40,35,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,50,45,40,35,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,50,45,40,35,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,50,45,40,35,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,50,45,40,35,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,50,45,40,35,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50,50,45,40,35,30,25,20,15,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,15,20,25,30,35,40,45,50