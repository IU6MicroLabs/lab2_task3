; ===* ������� *===
; �������� ���������, ������� ��� ������� ������ SWi, ������������ �
; ������ ����� Px, �������������� �������� ��������� LEDj �� 40��.
; =================

.include "m8515def.inc" ;���� ����������� ��� ATmega8515

.def temp = r16
.def led = r20
.def timerCount = r21
.def pinState = r22
.def nextMode = r23
.def prevMode = r24
.def counter = r25

.equ TARGET_BUTTON = 3 ; ������ ������
.equ TARGET_LED = ~0b00000001 ; ����� �������� ������ ���������
.equ TIMER_COUNT = 1; 22 ; ���, �.�. 700�� �������� => 15,625 (��, ������� ����������) / (700 / 1000 (��)))

; ������ �����
.equ MODE_BIN = 0
.equ MODE_DEC = 1
.equ MODE_BIN_INVERSE = 2
.equ MODE_DEC_INVERSE = 3


.org $000
	; ������� ����������
	rjmp INIT
	reti ; INT0
	reti ; INT1
	reti
	reti
	reti
	reti
	rjmp ON_TIMER_OVERFLOW ; T/C0 OVF

; �������������
INIT:
	; C���� led.0 ��� ��������� LED0
	ldi led, 0xFE

	; ��������� ��������� ����� �� ��������� ������ ���
	ldi temp, $5F
	out SPL, temp
	ldi temp, $02
	out SPH, temp

	; ������������� ����� PB �� �����
	ser temp
	out DDRB, temp

	; �������� ����������
	out PORTB, temp

	; ������������� ������ ������� ������ PD �� �����
	ldi temp, ((1 << MODE_BIN) | (1 << MODE_DEC) | (1 << MODE_BIN_INVERSE) | (1 << MODE_DEC_INVERSE))
	out DDRD, temp
	out PORTD, temp

	; ���������� ���������� ������������ timer0
	ldi temp, (1 << TOIE0)
	out TIMSK, temp

	; �������� timer0
	ldi temp, (1 << CS00);CS12)
	out TCCR0, temp

	; ������������� ������� �������
	ldi timerCount, TIMER_COUNT

	; ���������� �������
	clr counter

	; ������������� ����� �� ���������
	ldi prevMode, (1 << MODE_BIN)

	; ���������� ���������� ����������
	sei

; ������� ������������
MAIN:
	; �� ��������� ����� �� ������
	mov nextMode, prevMode

	; ��������� ��������� ������
	in pinState, PIND

	; case MODE_BIN: nextMode = MODE_BIN
	sbrs pinState, MODE_BIN
	ldi nextMode, MODE_BIN

	; case MODE_DEC: nextMode = MODE_DEC
	sbrs pinState, MODE_DEC
	ldi nextMode, MODE_DEC

	; case MODE_BIN_INVERSE: nextMode = MODE_BIN_INVERSE
	sbrs pinState, MODE_BIN_INVERSE
	ldi nextMode, MODE_BIN_INVERSE

	; case MODE_DEC_INVERSE: nextMode = MODE_DEC_INVERSE
	sbrs pinState, MODE_DEC_INVERSE
	ldi nextMode, MODE_DEC_INVERSE

	; if (nextMode == prevMode)
	cpse nextMode, prevMode
	rcall CHANGE_MODE

	; default
	rjmp MAIN

; ��������� ������ � ����� ��������
CHANGE_MODE:
	; ��������� ����������
	cli

	; ���������� �������, ��������� ��������
	clr counter
	ser led
	out PORTB, led

	; ����� ����� �����
	mov prevMode, nextMode

	; �������� ����������
	sei

	ret

; ���������� ������������ �������� �������
ON_TIMER_OVERFLOW:
	; ��������� ������� ����������
	dec timerCount

	; ���� timerCount != 0, �� ��������� ��������� ����������
	clr temp
	cpse timerCount, temp
	reti

	; ����� ��������� �������� � ������
	rcall ON_TIMER_DONE
	reti

; ������ �������� 700��
ON_TIMER_DONE:
	; ����� �������� ���������� �������
	ldi timerCount, TIMER_COUNT

	; case MODE_BIN
	sbrs prevMode, MODE_BIN
	rjmp HANDLE_MODE_BIN

	; case MODE_DEC
	sbrs prevMode, MODE_DEC
	rjmp HANDLE_MODE_DEC

	; case MODE_BIN_INVERSE
	sbrs prevMode, MODE_BIN_INVERSE
	rjmp HANDLE_MODE_BIN_INVERSE

	; case MODE_DEC_INVERSE
	sbrs prevMode, MODE_DEC_INVERSE
	rjmp HANDLE_MODE_DEC_INVERSE

	ret

; ��������� �������� ��� ��������� ������
SETUP_BIN:
	ldi counter, 1
	ret

; ��� ������ MODE_BIN
HANDLE_MODE_BIN:
	; ���� �� ������ ��� ���, �� ��������� �������, ����� ����������������� �������
	ldi temp, 0
	cp temp, counter
	breq SETUP_BIN

	; ����������� �������
	rol counter

	; ������� ������ ��������
	mov led, counter
	com led
	out PORTB, led

	ret

; ��� ������ MODE_DEC
HANDLE_MODE_DEC:
	; ����������� �������
	inc counter

	; ���� ��������� �� 8, �� ������� �������
	sbrc counter, 3
	clr counter

	; ������� ������ ��������
	mov led, counter
	com led
	out PORTB, led

	ret

; ��� ������ MODE_BIN_INVERSE
HANDLE_MODE_BIN_INVERSE:
	; ���� �� ������ ��� ���, �� ��������� �������, ����� ����������������� �������
	ldi temp, 0
	cp temp, counter
	breq SETUP_BIN

	; ����������� �������
	ror counter

	; ������� ������ ��������
	mov led, counter
	com led
	out PORTB, led

	ret

; ��� ������ MODE_DEC_INVERSE
HANDLE_MODE_DEC_INVERSE:
	; ����������� �������
	inc counter

	; ���� ��������� �� 8, �� ������� �������
	sbrc counter, 3
	clr counter

	; ������� ������ ��������
	mov led, counter
	out PORTB, led

	ret

