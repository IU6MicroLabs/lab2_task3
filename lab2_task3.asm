; ===* Задание *===
; Написать программу, которая при нажатии кнопки SWi, подключённой к
; выводу порта Px, кратковременно включает светодиод LEDj на 40мс.
; =================

.include "m8515def.inc" ;файл определений для ATmega8515

.def temp = r16
.def led = r20
.def timerCount = r21
.def pinState = r22
.def nextMode = r23
.def prevMode = r24
.def counter = r25

.equ TARGET_BUTTON = 3 ; Третья кнопка
.equ TARGET_LED = ~0b00000001 ; Будем включать первый светодиод
.equ TIMER_COUNT = 1; 22 ; раз, т.к. 700мс задержка => 15,625 (Гц, частота процессора) / (700 / 1000 (Гц)))

; Режимы счёта
.equ MODE_BIN = 0
.equ MODE_DEC = 1
.equ MODE_BIN_INVERSE = 2
.equ MODE_DEC_INVERSE = 3


.org $000
	; Векторы прерываний
	rjmp INIT
	reti ; INT0
	reti ; INT1
	reti
	reti
	reti
	reti
	rjmp ON_TIMER_OVERFLOW ; T/C0 OVF

; Инициализация
INIT:
	; Cброс led.0 для включения LED0
	ldi led, 0xFE

	; Установка указателя стека на последнюю ячейку ОЗУ
	ldi temp, $5F
	out SPL, temp
	ldi temp, $02
	out SPH, temp

	; Инициализация порта PB на вывод
	ser temp
	out DDRB, temp

	; Погасить светодиоды
	out PORTB, temp

	; Инициализация нужных выводов портов PD на вводы
	ldi temp, ((1 << MODE_BIN) | (1 << MODE_DEC) | (1 << MODE_BIN_INVERSE) | (1 << MODE_DEC_INVERSE))
	out DDRD, temp
	out PORTD, temp

	; Разрешение прерывания переполнения timer0
	ldi temp, (1 << TOIE0)
	out TIMSK, temp

	; Включаем timer0
	ldi temp, (1 << CS00);CS12)
	out TCCR0, temp

	; Устанавливаем счётчик таймера
	ldi timerCount, TIMER_COUNT

	; Сбрасываем счётчик
	clr counter

	; Устанавливаем режим по умолчанию
	ldi prevMode, (1 << MODE_BIN)

	; Глобальное разрешение прерываний
	sei

; Главная подпрограмма
MAIN:
	; По умолчанию режим не меняем
	mov nextMode, prevMode

	; Считываем состояние кнопок
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

; Изменение режима и сброс счётчика
CHANGE_MODE:
	; Выключаем прерывания
	cli

	; Сбрасываем счётчик, выключаем лампочки
	clr counter
	ser led
	out PORTB, led

	; Задаём новый режим
	mov prevMode, nextMode

	; Включаем прерывания
	sei

	ret

; Обработчик переполнения счётчика таймера
ON_TIMER_OVERFLOW:
	; Уменьшаем счётчик повторений
	dec timerCount

	; Если timerCount != 0, то завершаем обработку прерывания
	clr temp
	cpse timerCount, temp
	reti

	; Иначе выключаем лампочку и таймер
	rcall ON_TIMER_DONE
	reti

; Таймер отсчитал 700мс
ON_TIMER_DONE:
	; Сброс счётчика повторений таймера
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

; Настройка счётчика для двоичного режима
SETUP_BIN:
	ldi counter, 1
	ret

; Шаг режима MODE_BIN
HANDLE_MODE_BIN:
	; Если не первый раз тут, то продолжим считать, иначе проинициализируем счётчик
	ldi temp, 0
	cp temp, counter
	breq SETUP_BIN

	; Увеличиваем счётчик
	rol counter

	; Включим нужную лампочку
	mov led, counter
	com led
	out PORTB, led

	ret

; Шаг режима MODE_DEC
HANDLE_MODE_DEC:
	; Увеличиваем счётчик
	inc counter

	; Если досчитали до 8, то сбросим счётчик
	sbrc counter, 3
	clr counter

	; Включим нужную лампочку
	mov led, counter
	com led
	out PORTB, led

	ret

; Шаг режима MODE_BIN_INVERSE
HANDLE_MODE_BIN_INVERSE:
	; Если не первый раз тут, то продолжим считать, иначе проинициализируем счётчик
	ldi temp, 0
	cp temp, counter
	breq SETUP_BIN

	; Увеличиваем счётчик
	ror counter

	; Включим нужную лампочку
	mov led, counter
	com led
	out PORTB, led

	ret

; Шаг режима MODE_DEC_INVERSE
HANDLE_MODE_DEC_INVERSE:
	; Увеличиваем счётчик
	inc counter

	; Если досчитали до 8, то сбросим счётчик
	sbrc counter, 3
	clr counter

	; Включим нужную лампочку
	mov led, counter
	out PORTB, led

	ret

