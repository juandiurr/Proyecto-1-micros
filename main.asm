.include "M328PDEF.inc"
.cseg ;definir que se va  iniciatr el segmento de código del programa
.def umin = R19
.def dmin = R20
.def uhoras = R21
.def dhoras = R22
.def ovt1 = R23
.def display = R12
.def display_1 = R10
.def display_2 = R11
.def udia = R1
.def ddia = R13
.def umes = R14
.def dmes = R15
.org 0x00
	JMP MAIN
.org 0x0002
	JMP ISR_INT0
.org 0x000A
	JMP ISR_PCINT2
.org 0x001A
	JMP ISR_TIMER1_OVF
.org 0x0020
	JMP ISR_TIMER0_OVF

MAIN:
	LDI R16, LOW(RAMEND)
	OUT SPL, R16
	LDI R17, HIGH(RAMEND)
	OUT SPH, R17

SETUP:
	LDI R16, (1 << CLKPCE) ;Habilitar el prescalar el clk del uC
	STS CLKPR, R16
	LDI R16, (1 << CLKPS0) | (1 << CLKPS1) ;dividir la frecuencia del clk en 8, 16M/8 = 2M oscilaciones por segundo
	STS CLKPR, R16 ;mover a CLKPR
	CALL TIMER1
	CALL TIMER2
	CALL TIMER0
	//Habilitar interrupciones
	LDI R16, (1 << TOIE1)
	STS TIMSK1, R16 ;habilitar interrupcion timer1
	LDI R16, (1 << INT0)
	OUT EIMSK, R16 ;habilitar interrupcion externa INT0
	LDI R16, (1 << ISC01)
	STS EICRA, R16 ;interrupcion en flanco negativo
	LDI R16, (1 << PCIE2)
	STS PCICR, R16 ;habilitar interrupcion externa PCINT2 (PORTD)
	//declarando ouputs
	SBI	DDRB, PB0 ;A
	SBI	DDRB, PB1 ;B
	SBI	DDRB, PB2 ;C
	SBI	DDRB, PB3 ;D
	SBI	DDRB, PB4 ;E
	SBI DDRB, PB5 ;F
	SBI DDRC, PC0 ;G
	SBI DDRC, PC1 ;SELECTOR DISPLAY 1
	SBI DDRC, PC2 ;SELECTOR DISPLAY 2
	SBI DDRC, PC3 ;SELECTOR DISPLAY 3
	SBI DDRC, PC4 ;SELECTOR DISPLAY 4
	SBI DDRD, PD7
	LDI R16, 0
	OUT PORTB, R16
	OUT PORTC, R16
	//declarando inputs
	CBI DDRD, PD2 ;PUSHBOTTOM1
	CBI DDRD, PD3 ;PUSHBOTTOM2
	CBI DDRD, PD4 ;PUSHBOTTOM3
	CBI DDRD, PD5 ;PUSHBOTTOM4
	CBI DDRD, PD6 ;PUSHBOTTOM5
	LDI R16, 0b0111_1100
	OUT PORTD, R16
	//registros 
	LDI	R16, 0
	MOV R1, R16
	MOV R6, R16
	MOV R7, R16
	MOV R8, R16
	MOV R9, R16
	LDI R28, 0
	LDI R29, 1
	MOV udia, R29
	MOV ddia, R28
	MOV umes, R29
	MOV dmes, R16
	LDI umin, 0 ;display 1
	LDI dmin, 0 ;display 2
	LDI uhoras, 0 ;display 3
	LDI dhoras, 0 ;display 4
	LDI ovt1, 0 ;overflowtimer1
	LDI R17, 0
	SEI
	JMP MENU

//********************************************************************************************************************************
//SETEAR TIMERS
//********************************************************************************************************************************
TIMER1:
	LDI R16, (1 << CS12) | (1 << CS10) ;configurar el prescaler a 1024 para un reloj de 2M
	STS TCCR1B, R16
	LDI R16, 0b01011111 ;1s
	LDI R17, 0b11111000
	STS TCNT1H, R17
	STS TCNT1L, R16
	RET
TIMER2:
	LDI R16, (1 << CS22) | (1 << CS20) ;configurar el prescaler a 1024 para un reloj de 2M
	STS TCCR2B, R16
	LDI R16, 255 ;1ms
	STS TCNT2, R16
	RET
TIMER0:
	LDI R16, (1 << CS02) | (1 << CS00) ;configurar el prescaler a 1024 para un reloj de 2M
	OUT TCCR0B, R16
	RET

//********************************************************************************************************************************
//MENU
//********************************************************************************************************************************
MENU: 
	CPI R17, 0
	BREQ CM1
	CPI R17, 1
	BREQ CM0
	CPI R17, 2
	BREQ CH0
	CPI R17, 3
	BREQ CC
	CPI R17, 4
	BREQ FF
	CPI R17, 5
	BREQ CC2
CC2:
	JMP ACT2
FF:
	JMP FECHAS
CM1:
	JMP RELOJ
CM0:
	JMP CONF_MINS
CH0:
	JMP CONF_HORAS
CC:
	JMP ACT

//********************************************************************************************************************************
//RELOJ NORMAL
//********************************************************************************************************************************
RELOJ:
	CPI R18, 128 ;ALARMA ACTIVADA
	BREQ SET1
	CPI R18, 0
	BREQ SET0
SET0:
	LDI R16, (0 << PCINT19) | (0 << PCINT22) | (0 << PCINT21) | (1 << PCINT20)
	STS PCMSK2, R16 ;habilitar interrupcion en PD3, PD5 Y PD6
	JMP LOOP
SET1:
	LDI R16, (1 << PCINT19) | (0 << PCINT22) | (0 << PCINT21) | (1 << PCINT20)
	STS PCMSK2, R16 ;habilitar interrupcion en PD3, PD5 Y PD6
LOOP: ;LOOP principal donde se ve la hora
	CPI dhoras, 2 
	BREQ LOOP2
	CALL DISPLAY1
	CALL DISPLAY2
	CALL DISPLAY3
	CALL DISPLAY4
	CPI R17, 0
	BRNE MENU
	CPI ovt1, 120
	BRNE LOOP
	INC umin
	LDI ovt1, 0
	CPI umin, 10
	BRNE LOOP
	LDI umin, 0
	INC dmin
	CPI dmin, 6 ;decima de minuto
	BRNE LOOP
	LDI dmin, 0
	INC uhoras
	CPI uhoras, 10 ;unidad de hora
	BRNE LOOP
	LDI uhoras, 0
	INC dhoras
	CPI dhoras, 2 
	BRNE LOOP
LOOP2:
	CALL DISPLAY1
	CALL DISPLAY2
	CALL DISPLAY3
	CALL DISPLAY4
	CPI R17, 0
	BRNE MENU_
	CPI ovt1, 120
	BRNE LOOP2
	INC umin
	LDI ovt1, 0
	CPI umin, 10
	BRNE LOOP2
	LDI umin, 0
	INC dmin
	CPI dmin, 6 ;decima de minuto
	BRNE LOOP2
	LDI dmin, 0
	INC uhoras
	CPI uhoras, 4
	BRNE LOOP2
	LDI uhoras, 0
	LDI dhoras, 0
	INC udia
	RJMP LOOP
MENU_:
	JMP MENU

DISPLAY1:
	LDI ZH, HIGH(tabla7seg << 1)
	LDI ZL, LOW(tabla7seg << 1)
	ADD ZL, umin
	LPM display, Z
	SBI PORTC, 1
	SBRS display, 6
	CBI PORTC, 0
	SBRC display, 6
	SBI PORTC, 0
	OUT PORTB, display
	CALL DELAY
	CBI PORTC, 1
	RET

DISPLAY2:
	LDI ZH, HIGH(tabla7seg << 1)
	LDI ZL, LOW(tabla7seg << 1)
	ADD ZL, dmin
	LPM display, Z
	SBI PORTC, 2
	SBRS display, 6
	CBI PORTC, 0
	SBRC display, 6
	SBI PORTC, 0
	OUT PORTB, display
	CALL DELAY
	CBI PORTC, 2
	RET

DISPLAY3:
	LDI ZH, HIGH(tabla7seg << 1)
	LDI ZL, LOW(tabla7seg << 1)
	ADD ZL, uhoras
	LPM display, Z
	SBI PORTC, 3
	SBRS display, 6
	CBI PORTC, 0
	SBRC display, 6
	SBI PORTC, 0
	OUT PORTB, display
	CALL DELAY
	CBI PORTC, 3
	RET

DISPLAY4:
	LDI ZH, HIGH(tabla7seg << 1)
	LDI ZL, LOW(tabla7seg << 1)
	ADD ZL, dhoras
	LPM display, Z
	SBI PORTC, 4
	SBRS display, 6
	CBI PORTC, 0
	SBRC display, 6
	SBI PORTC, 0
	OUT PORTB, display
	CALL DELAY
	CBI PORTC, 4
	RET

DELAY:
	IN R16, TIFR2
	SBRS R16, TOV2
	RJMP DELAY
	LDI R16, 246 ;5ms
	STS TCNT2, R16
	SBI TIFR2, TOV2 ;apagar bandera
	RET

//********************************************************************************************************************************
//CONFIGURACION DE MINUTOS
//********************************************************************************************************************************
CONF_MINS:
	LDI R16, (1 << PCINT19) | (1 << PCINT22) | (1 << PCINT21) | (0 << PCINT20)
	STS PCMSK2, R16 ;habilitar interrupcion en PD3, PD5 Y PD6
	MOV R24, umin
	MOV R25, dmin
	MOV R26, uhoras
	MOV R27, dhoras
	MOV R6, umin
	MOV R7, dmin
	MOV R8, uhoras
	MOV R9, dhoras
LOOP_CONF_MINS: ;loop ´para no perder el valor de la hora mientras se esta en este modo
	CPI dhoras, 2 
	BREQ LOOP_CONF_MINS2
	CALL DISPLAY1C
	CALL DISPLAY2C
	CALL DISPLAY3C
	CALL DISPLAY4C
	CPI R17, 1
	BRNE MENU0
	CPI ovt1, 120
	BRNE LOOP_CONF_MINS
	INC umin
	LDI ovt1, 0
	CPI umin, 10
	BRNE LOOP_CONF_MINS
	LDI umin, 0
	INC dmin
	CPI dmin, 6 ;decima de segundo
	BRNE LOOP_CONF_MINS
	LDI dmin, 0
	INC uhoras
	CPI uhoras, 10 ;unidad de minuto
	BRNE LOOP_CONF_MINS
	LDI uhoras, 0
	INC dhoras
	CPI dhoras, 2 
	BRNE LOOP_CONF_MINS
LOOP_CONF_MINS2:
	CALL DISPLAY1C
	CALL DISPLAY2C
	CALL DISPLAY3C
	CALL DISPLAY4C
	CPI R17, 1
	BRNE MENU0
	CPI ovt1, 120
	BRNE LOOP_CONF_MINS2
	INC umin
	LDI ovt1, 0
	CPI umin, 10
	BRNE LOOP_CONF_MINS2
	LDI umin, 0
	INC dmin
	CPI dmin, 6 ;decima de segundo
	BRNE LOOP_CONF_MINS2
	LDI dmin, 0
	INC uhoras
	CPI uhoras, 4
	BRNE LOOP_CONF_MINS2
	LDI uhoras, 0
	LDI dhoras, 0
	INC udia
	RJMP LOOP_CONF_MINS
MENU0:
	JMP MENU
DISPLAY1C:
	LDI ZH, HIGH(tabla7seg << 1)
	LDI ZL, LOW(tabla7seg << 1)
	ADD ZL, R6
	LPM display_1, Z
	SBI PORTC, 1
	SBRS display_1, 6
	CBI PORTC, 0
	SBRC display_1, 6
	SBI PORTC, 0
	OUT PORTB, display_1
	CALL DELAY
	CBI PORTC, 1
	RET

DISPLAY2C:
	LDI ZH, HIGH(tabla7seg << 1)
	LDI ZL, LOW(tabla7seg << 1)
	ADD ZL, R7
	LPM display_2, Z
	SBI PORTC, 2
	SBRS display_2, 6
	CBI PORTC, 0
	SBRC display_2, 6
	SBI PORTC, 0
	OUT PORTB, display_2
	CALL DELAY
	CBI PORTC, 2
	RET

DISPLAY3C:
	LDI ZH, HIGH(tabla7seg << 1)
	LDI ZL, LOW(tabla7seg << 1)
	ADD ZL, R26
	LPM display, Z
	SBI PORTC, 3
	SBRS display, 6
	CBI PORTC, 0
	SBRC display, 6
	SBI PORTC, 0
	OUT PORTB, display
	CALL DELAY
	CBI PORTC, 3
	RET

DISPLAY4C:
	LDI ZH, HIGH(tabla7seg << 1)
	LDI ZL, LOW(tabla7seg << 1)
	ADD ZL, R27
	LPM display, Z
	SBI PORTC, 4
	SBRS display, 6
	CBI PORTC, 0
	SBRC display, 6
	SBI PORTC, 0
	OUT PORTB, display
	CALL DELAY
	CBI PORTC, 4
	RET

//********************************************************************************************************************************
//CONFIGURACION DE HORAS
//********************************************************************************************************************************
CONF_HORAS:
	LDI R16, (1 << PCINT19) | (1 << PCINT22) | (1 << PCINT21) | (0 << PCINT20)
	STS PCMSK2, R16 ;habilitar interrupcion en PD3, PD5 Y PD6
LOOP_CONF_HORAS: ;loop ´para no perder el valor de la hora mientras se esta en este modo
	CPI dhoras, 2 
	BREQ LOOP_CONF_HORAS2
	CALL DISPLAY1CH
	CALL DISPLAY2CH
	CALL DISPLAY3CH
	CALL DISPLAY4CH
	CPI R17, 2
	BRNE MENU1
	CPI ovt1, 120
	BRNE LOOP_CONF_HORAS
	INC umin
	LDI ovt1, 0
	CPI umin, 10
	BRNE LOOP_CONF_HORAS
	LDI umin, 0
	INC dmin
	CPI dmin, 6 ;decima de segundo
	BRNE LOOP_CONF_HORAS
	LDI dmin, 0
	INC uhoras
	CPI uhoras, 10 ;unidad de minuto
	BRNE LOOP_CONF_HORAS
	LDI uhoras, 0
	INC dhoras
	CPI dhoras, 2 
	BRNE LOOP_CONF_HORAS
LOOP_CONF_HORAS2:
	CALL DISPLAY1CH
	CALL DISPLAY2CH
	CALL DISPLAY3CH
	CALL DISPLAY4CH
	CPI R17, 2
	BRNE MENU1
	CPI ovt1, 120
	BRNE LOOP_CONF_HORAS2
	INC umin
	LDI ovt1, 0
	CPI umin, 10
	BRNE LOOP_CONF_HORAS2
	LDI umin, 0
	INC dmin
	CPI dmin, 6 ;decima de segundo
	BRNE LOOP_CONF_HORAS2
	LDI dmin, 0
	INC uhoras
	CPI uhoras, 4
	BRNE LOOP_CONF_HORAS2
	LDI uhoras, 0
	LDI dhoras, 0
	INC udia
	RJMP LOOP_CONF_HORAS

MENU1:
	JMP MENU
DISPLAY1CH:
	LDI ZH, HIGH(tabla7seg << 1)
	LDI ZL, LOW(tabla7seg << 1)
	ADD ZL, R24
	LPM display, Z
	SBI PORTC, 1
	SBRS display, 6
	CBI PORTC, 0
	SBRC display, 6
	SBI PORTC, 0
	OUT PORTB, display
	CALL DELAY
	CBI PORTC, 1
	RET

DISPLAY2CH:
	LDI ZH, HIGH(tabla7seg << 1)
	LDI ZL, LOW(tabla7seg << 1)
	ADD ZL, R25
	LPM display, Z
	SBI PORTC, 2
	SBRS display, 6
	CBI PORTC, 0
	SBRC display, 6
	SBI PORTC, 0
	OUT PORTB, display
	CALL DELAY
	CBI PORTC, 2
	RET

DISPLAY3CH:
	LDI ZH, HIGH(tabla7seg << 1)
	LDI ZL, LOW(tabla7seg << 1)
	ADD ZL, R8
	LPM display_1, Z
	SBI PORTC, 3
	SBRS display_1, 6
	CBI PORTC, 0
	SBRC display_1, 6
	SBI PORTC, 0
	OUT PORTB, display_1
	CALL DELAY
	CBI PORTC, 3
	RET

DISPLAY4CH:
	LDI ZH, HIGH(tabla7seg << 1)
	LDI ZL, LOW(tabla7seg << 1)
	ADD ZL, R9
	LPM display_2, Z
	SBI PORTC, 4
	SBRS display_2, 6
	CBI PORTC, 0
	SBRC display_2, 6
	SBI PORTC, 0
	OUT PORTB, display_2
	CALL DELAY
	CBI PORTC, 4
	RET


ACT:
	MOV umin, R24
	MOV dmin, R25
	MOV uhoras, R26
	MOV dhoras, R27
	LDI ovt1, 0
	LDI R17, 0
	JMP MENU
//********************************************************************************************************************************
//FECHAS
//********************************************************************************************************************************
FECHAS:
	LDI R16, (0 << PCINT19) | (1 << PCINT22) | (1 << PCINT21) | (1 << PCINT20)
	STS PCMSK2, R16 ;habilitar interrupcion en PD3, PD5 Y PD6
	MOV R24, umin
	MOV R25, dmin
	MOV R26, uhoras
	MOV R27, dhoras
LOOP_FECHAS: ;loop ´para no perder el valor de la hora mientras se esta en este modo
	CALL DISPLAYS
	LDI R29, 0
	CPI R17, 4
	BRNE MENUF
	LDI R28, 1
	CP umes, R28
	BREQ MESL_
	LDI R28, 2
	CP umes, R28
	BREQ FEB
	LDI R28, 3
	CP umes, R28
	BREQ MESL_
	LDI R28, 4
	CP umes, R28
	BREQ MESC_
	LDI R28, 5
	CP umes, R28
	BREQ MESL_
	LDI R28, 6
	CP umes, R28
	BREQ MESC_
	LDI R28, 7
	CP umes, R28
	BREQ MESL_
	LDI R28, 8
	CP umes, R28
	BREQ MESL_
	LDI R28, 9
	CP umes, R28
	BREQ MESC_
	LDI R28, 10
	CP umes, R28
	BREQ MESL_
	LDI R28, 11
	CP umes, R28
	BREQ MESC_
	LDI R28, 12
	CP umes, R28
	BREQ MESL_
	LDI R28, 1
	MOV umes, R28
	RJMP FECHAS
MENUF:
	JMP MENU
FEB:
	JMP MFEB
MESL_:
	JMP MESL
MESC_:
	JMP MESC
MESC:
	CALL DISPLAYS
	CPI R17, 4
	BRNE MENUF
	CPI R29, 1
	BREQ FECHAS_
	LDI R28, 10
	CP udia, R28
	BRNE MESC
	LDI R28, 0
	MOV udia, R28
	INC ddia
	LDI R28, 3
	CP ddia, R28 
	BRNE MESC
MESC2:
	CALL DISPLAYS
	CPI R17, 4
	BRNE MENUF
	CPI R29, 1
	BREQ FECHAS_
	LDI R28, 1
	CP udia, R28
	BRNE MESC2
	LDI R28, 1
	MOV udia, R28
	LDI R28, 0
	MOV ddia, R28
	INC umes
	JMP FECHAS
MESL:
	CALL DISPLAYS
	CPI R17, 4
	BRNE MENUF
	CPI R29, 1
	BREQ FECHAS_
	LDI R28, 10
	CP udia, R28
	BRNE MESL
	LDI R28, 0
	MOV udia, R28
	INC ddia
	LDI R28, 3
	CP ddia, R28 
	BRNE MESL
MESL2:
	CALL DISPLAYS
	CPI R17, 4
	BRNE MENUF
	CPI R29, 1
	BREQ FECHAS_
	LDI R28, 2
	CP udia, R28
	BRNE MESL2
	LDI R28, 1
	MOV udia, R28
	LDI R28, 0
	MOV ddia, R28
	INC umes
	JMP FECHAS
FECHAS_:
	JMP LOOP_FECHAS
MENUFF:
	JMP MENU
MFEB:
	CPI R29, 1
	BREQ FECHAS_
	CALL DISPLAYS
	CPI R17, 4
	BRNE MENUFF
	LDI R28, 10
	CP udia, R28
	BRNE MFEB
	LDI R28, 0
	MOV udia, R28
	INC ddia
	LDI R28, 2
	CP ddia, R28
	BRNE MFEB
MFEB2:
	CALL DISPLAYS
	CPI R17, 4
	BRNE MENUFF
	CPI R29, 1
	BREQ FECHAS_
	LDI R28, 9
	CP udia, R28
	BRNE MFEB2
	LDI R28, 1
	MOV udia, R28
	LDI R28, 0
	MOV ddia, R28
	INC umes
	JMP FECHAS

DISPLAYS:
	CALL DISPLAY1f
	CALL DISPLAY2f
	CALL DISPLAY3f
	CALL DISPLAY4f
	RET

tabla7seg: .DB 0x40, 0x79, 0x24, 0x30, 0x19, 0x12, 0x02, 0x78, 0x0, 0x10, 0x40, 0x79, 0x24, 0xFF
DISPLAY1f:
	LDI ZH, HIGH(tabla7seg << 1)
	LDI ZL, LOW(tabla7seg << 1)
	ADD ZL, udia
	LPM R19, Z
	SBI PORTC, 1
	SBRS R19, 6
	CBI PORTC, 0
	SBRC R19, 6
	SBI PORTC, 0
	OUT PORTB, R19
	CALL DELAY
	CBI PORTC, 1
	RET

DISPLAY2f:
	LDI ZH, HIGH(tabla7seg << 1)
	LDI ZL, LOW(tabla7seg << 1)
	ADD ZL, ddia
	LPM R19, Z
	SBI PORTC, 2
	SBRS R19, 6
	CBI PORTC, 0
	SBRC R19, 6
	SBI PORTC, 0
	OUT PORTB, R19
	CALL DELAY
	CBI PORTC, 2
	RET

DISPLAY3f:
	LDI ZH, HIGH(tabla7seg << 1)
	LDI ZL, LOW(tabla7seg << 1)
	ADD ZL, umes
	LPM R19, Z
	SBI PORTC, 3
	SBRS R19, 6
	CBI PORTC, 0
	SBRC R19, 6
	SBI PORTC, 0
	OUT PORTB, R19
	CALL DELAY
	CBI PORTC, 3
	RET

DISPLAY4f:
	LDI ZH, HIGH(tabla7seg << 1)
	LDI ZL, LOW(tabla7seg << 1)
	ADD ZL, dmes
	LPM R19, Z
	SBI PORTC, 4
	SBRS R19, 6
	CBI PORTC, 0
	SBRC R19, 6
	SBI PORTC, 0
	OUT PORTB, R19
	CALL DELAY
	CBI PORTC, 4
	RET

ACT2:
	MOV umin, R24
	MOV dmin, R25
	MOV uhoras, R26
	MOV dhoras, R27
	LDI R17, 0
	JMP MENU
//********************************************************************************************************************************
//INTERRUPCIONES
//********************************************************************************************************************************
ISR_TIMER1_OVF:
	PUSH R16
	IN R16, SREG
	PUSH R16 ;guardar en la pila el registro sreg
	IN R0, PORTC
	LDI R16, 0b11111100
	STS TCNT1H, R16
	LDI R16, 0b00101111;valor de desbordamiento 0.5S
	STS TCNT1L, R16
	LDI R16, 13
	SBI TIFR1, TOV1 ;apagar bandera
	CPI R17, 4
	BREQ MODO_FECHAS_
	INC ovt1 ;OVERFLOW TIMER1
	CPI R17, 1
	BREQ ISR_TIMER1_CM
	CPI R17, 2
	BREQ ISR_TIMER1_CH
	SBRC R18, 7
	JMP ALARMAA
	SBRC R18, 5
	JMP ALARMAAA_
	CPI R17, 0
	BREQ MODO_NORMAL
ISR_TIMER1_OUT_:
	JMP ISR_TIMER1_OUT
MODO_FECHAS_:
	JMP MODO_FECHAS
ALARMAAA_:
	INC R18
	CPI R18, 42
	BRNE ISR_TIMER1_OUT_
	LDI R18, 0
	CBI PORTD, 7
	JMP ISR_TIMER1_OUT
ALARMAA:
	SBI PORTC, 5
	CPSE R2, umin
	JMP ISR_TIMER1_OUT
	CPSE R3, dmin
	JMP ISR_TIMER1_OUT
	CPSE R4, uhoras
	JMP ISR_TIMER1_OUT
	CPSE R5, dhoras
	JMP ISR_TIMER1_OUT
	LDI R18, 32 ;1 EL BIT 5
	SBI PORTD, 7
	JMP ISR_TIMER1_OUT
MODO_NORMAL:
	SBRS R0, 5
	SBI PORTC, 5
	SBRC R0, 5
	CBI PORTC, 5
	JMP ISR_TIMER1_OUT
ISR_TIMER1_CM:
	SBI PORTC, 5
	SBRS display_1, 7 ;verifica que el bit 7 del display esta en 1, si esta en 1 el display esta apagado
	MOV R6, R16
	SBRC display_1, 7  ;si esta en 0 el display esta mostrando un numero
	MOV R6, R24
	SBRS display_2, 7 ;verifica que el bit 7 del display esta en 1, si esta en 1 el display esta apagado
	MOV R7, R16
	SBRC display_2, 7  ;si esta en 0 el display esta mostrando un numero
	MOV R7, R25
	JMP ISR_TIMER1_OUT
ISR_TIMER1_CH:
	CBI PORTC, 5
	SBRS display_1, 7 ;verifica que el bit 7 del display esta en 1, si esta en 1 el display esta apagado
	MOV R8, R16
	SBRC display_1, 7  ;si esta en 0 el display esta mostrando un numero
	MOV R8, R26
	SBRS display_2, 7 ;verifica que el bit 7 del display esta en 1, si esta en 1 el display esta apagado
	MOV R9, R16
	SBRC display_2, 7  ;si esta en 0 el display esta mostrando un numero
	MOV R9, R27
	JMP ISR_TIMER1_OUT
MODO_FECHAS:
	INC ovt1
	CPI R27, 2 
	BREQ MODO_FECHAS2
	CPI ovt1, 120
	BRNE ISR_TIMER1_OUT
	INC R24
	LDI ovt1, 0
	CPI R24, 10
	BRNE ISR_TIMER1_OUT
	LDI R24, 0
	INC R25
	CPI R25, 6 ;decima de segundo
	BRNE ISR_TIMER1_OUT
	LDI R25, 0
	INC R26
	CPI R26, 10 ;unidad de minuto
	BRNE ISR_TIMER1_OUT
	LDI R26, 0
	INC R27
	CPI R27, 2 
	BRNE ISR_TIMER1_OUT
MODO_FECHAS2:
	CPI ovt1, 120
	BRNE ISR_TIMER1_OUT
	INC R24
	LDI ovt1, 0
	CPI R24, 10
	BRNE ISR_TIMER1_OUT
	LDI R24, 0
	INC R25
	CPI R25, 6 ;decima de segundo
	BRNE ISR_TIMER1_OUT
	LDI R25, 0
	INC R26
	CPI R26, 4
	BRNE ISR_TIMER1_OUT
	LDI R26, 0
	LDI R27, 0
	INC udia
	RJMP ISR_TIMER1_OUT
ISR_TIMER1_OUT:
	POP R16 ;recuperar el valor de sreg
	OUT SREG, R16 ;guardar los valores antiguos de sreg
	POP R16
	RETI

ISR_INT0:
	PUSH R16 ;guardar en la pila el registro r16
	IN R16, SREG
	PUSH R16 ;guardar en la pila el registro sreg
	LDI R16, (1 << TOIE0)
	STS TIMSK0, R16 ;deshabilitar interrupcion timer0
	LDI R16, 2 ;10MS
	OUT TCNT0, R16
	POP R16 ;recuperar el valor de sreg
	OUT SREG, R16 ;guardar los valores antiguos de sreg
	POP R16 ;guardar los valores antiguos de r16
	RETI

ISR_TIMER0_OVF:
	PUSH R16 ;guardar en la pila el registro r16
	IN R16, SREG
	PUSH R16 ;guardar en la pila el registro sreg
	LDI R16, (0 << TOIE0)
	STS TIMSK0, R16 ;deshabilitar interrupcion timer0
	SBI TIFR0, TOV0 ;apagar bandera
	SBIS PIND, 2
	INC R17
	SBIS PIND, 4
	JMP FECHAS___
	SBIS PIND, 3
	JMP ALARMA
	SBIS PIND, 5
	JMP INCREMENTO
	SBIS PIND, 6
	JMP DECREMENTO
	CPI R17, 6
	BRLO ISR_OUT_
	LDI R17, 0
	JMP ISR_OUT
FECHAS___:
	CPI R17, 4
	BREQ FECHAS___2
	LDI R17, 4
	JMP ISR_OUT
FECHAS___2:
	LDI R17, 5
	JMP ISR_OUT
ISR_OUT_:
	JMP ISR_OUT
ALARMA:
	CPI R17, 0
	BRNE ALARMA_2_
	LDI R18, 0
	JMP ISR_OUT
ALARMA_2_:
	MOV R2, R24
	MOV R3, R25
	MOV R4, R26
	MOV R5, R27
	LDI R17, 0
	LDI R18, 128 ;PONE UN UNO EN EL BIT 7 Y 0
	JMP ISR_OUT
INCREMENTO:
	CPI R17, 1
	BREQ INCREMENTO_MINUTOS
	CPI R17, 2
	BREQ INCREMENTO_HORAS
	CPI R17, 0
	BREQ ISR_OUT_
	CPI R17, 4
	BREQ INCREMENTO_DIAS
	CPI R17, 3
	BREQ ISR_OUT_
INCREMENTO_MINUTOS:
	INC R24
	CPI R24, 10
	BRNE ISR_OUT_
	LDI R24, 0
	INC R25
	CPI R25, 6
	BRNE ISR_OUT_
	LDI R25, 0
	JMP ISR_OUT
INCREMENTO_HORAS:
	INC R26
	CPI R27, 2
	BREQ INCREMENTO_HORAS2
	CPI R26, 10
	BRNE ISR_OUT
	LDI R26, 0
	INC R27
	JMP ISR_OUT
INCREMENTO_HORAS2:
	CPI R26, 4
	BRNE ISR_OUT
	LDI R26, 0
	LDI R27, 0
	JMP ISR_OUT
DECREMENTO:
	CPI R17, 1
	BREQ DECREMENTO_MINUTOS
	CPI R17, 2
	BREQ DECREMENTO_HORAS
	CPI R17, 4
	BREQ INCREMENTO_MESES
	CPI R17, 0
	BREQ ISR_OUT
DECREMENTO_MINUTOS:
	DEC R24
	CPI R24, 0
	BRGE ISR_OUT
	LDI R24, 9
	DEC R25
	CPI R25, 0
	BRGE ISR_OUT 
	LDI R25, 5
	JMP ISR_OUT
DECREMENTO_HORAS:
	DEC R26
	CPI R26, 0
	BRGE ISR_OUT
	LDI R26, 9
	DEC R27
	CPI R27, 0
	BRGE ISR_OUT
	LDI R27, 2
	LDI R26, 3
	JMP ISR_OUT
INCREMENTO_DIAS:
	INC udia
	JMP ISR_OUT
HOLA:
	LDI R28, 1
	MOV dmes, R28
	JMP ISR_OUT
INCREMENTO_MESES:
	INC umes
	LDI R29, 1
	LDI R28, 10
	CP umes, R28
	BREQ HOLA
	LDI R28, 13
	CP umes, R28
	BRNE ISR_OUT
	LDI R28, 1
	MOV umes, R28
	LDI R28, 0
	MOV dmes, R28
	JMP ISR_OUT
ISR_OUT:
	POP R16 ;recuperar el valor de sreg
	OUT SREG, R16 ;guardar los valores antiguos de sreg
	POP R16 ;guardar los valores antiguos de r16
	RETI

ISR_PCINT2:
	PUSH R16 ;guardar en la pila el registro r16
	IN R16, SREG
	PUSH R16 ;guardar en la pila el registro sreg
	LDI R16, (1 << TOIE0)
	STS TIMSK0, R16 ;habilitar interrupcion timer0
	LDI R16, 100 ;10MS
	OUT TCNT0, R16
	POP R16 ;recuperar el valor de sreg
	OUT SREG, R16 ;guardar los valores antiguos de sreg
	POP R16 ;guardar los valores antiguos de r16
	RETI