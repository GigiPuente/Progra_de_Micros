/*
* Lab3.asm
*
* Creado: Jorge Puente
* Autor :
* Descripción: 
*/
/****************************************/
.include "M328PDEF.inc"

.dseg
.org SRAM_START

contador:      .byte 1
EAN:           .byte 1
unidades:      .byte 1
decenas:       .byte 1
delay:         .byte 1  

/****************************************/
.cseg
.org 0x0000

RJMP SETUP

.org 0x0006                    
RJMP INTER_PB

.org 0x001C
RJMP INTER_TMR

/****************************************/
SETUP:
	LDI     R16, LOW(RAMEND)
	OUT     SPL, R16
	LDI     R16, HIGH(RAMEND)
	OUT     SPH, R16

	LDI     R16, 0b00111111
	OUT     DDRC, R16

	LDI     R16, 0b01111111
	OUT     DDRD, R16

	CBI     DDRB, PB0
	CBI     DDRB, PB1

	SBI     PORTB, PB0
	SBI     PORTB, PB1

	LDI     R16, 0x00
	STS     contador, R16
	STS     unidades, R16
	STS     decenas, R16
	STS     delay, R16

	IN      R16, PINB
	STS     EAN, R16

	LDI     R16, (1<<PCIE0)
	STS     PCICR, R16

	LDI     R16, (1<<PCINT0)|(1<<PCINT1)
	STS     PCMSK0, R16

	LDI     R16, (1<<WGM01)
	OUT     TCCR0A, R16

	LDI     R16, (1<<CS02)|(1<<CS00)
	OUT     TCCR0B, R16

	LDI     R16, 155
	OUT     OCR0A, R16

	LDI     R16, (1<<OCIE0A)
	STS     TIMSK0, R16

SEI

/****************************************/
MAIN_LOOP:
	LDS     R16, contador
	OUT     PORTC, R16

	CBI     PORTC, PC4
	CBI     PORTC, PC5

	LDS     R16, unidades
	RCALL   TABLA_7S
	SBI     PORTC, PC4

	CBI     PORTC, PC4
	CBI     PORTC, PC5

	LDS     R16, decenas
	RCALL   TABLA_7S
	SBI     PORTC, PC5

	RJMP    MAIN_LOOP

/****************************************/
TABLA_7S:
	CPI R16, 0x00
	BREQ CERO
	CPI R16, 0x01
	BREQ UNO
	CPI R16, 0x02
	BREQ DOS
	CPI R16, 0x03
	BREQ TRES
	CPI R16, 0x04
	BREQ CUATRO
	CPI R16, 0x05
	BREQ CINCO
	CPI R16, 0x06
	BREQ SEIS
	CPI R16, 0x07
	BREQ SIETE
	CPI R16, 0x08
	BREQ OCHO
	CPI R16, 0x09
	BREQ NUEVE

CERO:   
	LDI R16, 0b00111111
	OUT PORTD, R16
	RET
UNO:    
	LDI R16, 0b00000110
	OUT PORTD, R16
	RET
DOS:    
	LDI R16, 0b01011011
	OUT PORTD, R16
	RET
TRES:   
	LDI R16, 0b01001111
	OUT PORTD, R16
	RET
CUATRO: 
	LDI R16, 0b01100110
	OUT PORTD, R16
	RET
CINCO:  
	LDI R16, 0b01101101
	OUT PORTD, R16
	RET
SEIS:   
	LDI R16, 0b01111101
	OUT PORTD, R16
	RET
SIETE:  
	LDI R16, 0b00000111
	OUT PORTD, R16
	RET
OCHO:   
	LDI R16, 0b01111111
	OUT PORTD, R16
	RET
NUEVE:  
	LDI R16, 0b01101111
	OUT PORTD, R16
	RET

/****************************************/
INTER_PB:
	PUSH    R16
	PUSH    R17
	PUSH    R18

	IN      R16, PINB
	LDS     R17, EAN

	MOV     R18, R16
	EOR     R18, R17

	SBRS    R18, PB0
	RJMP    RD

	SBRS    R16, PB0 
	RCALL   INCC

RD:
	SBRS    R18, PB1
	RJMP    TI_PB

	SBRS    R16, PB1
	RCALL   DECC

TI_PB:
	STS     EAN, R16

	POP     R18
	POP     R17
	POP     R16
	RETI

INCC:
	LDS     R16, contador
	INC     R16
	ANDI    R16, 0x0F 
	STS     contador, R16
	RET

DECC:
	LDS     R16, contador
	DEC     R16
	ANDI    R16, 0x0F
	STS     contador, R16
	RET

/****************************************/
INTER_TMR:
	PUSH    R16
	PUSH    R17

	LDS     R16, delay
	INC     R16
	STS     delay, R16

	CPI     R16, 100
	BRNE    TI_T

	LDI     R16, 0x00
	STS     delay, R16

	LDS     R17, unidades
	INC     R17
	CPI     R17, 10
	BRNE    GUARDAR

	LDI     R17, 0x00
	STS     unidades, R17

	LDS     R17, decenas
	INC     R17
	CPI     R17, 6
	BRNE    GUARDAR_DEC

	LDI     R17, 0x00
	STS     decenas, R17
	RJMP    TI_T

GUARDAR_DEC:
	STS     decenas, R17
	RJMP    TI_T

GUARDAR:
	STS     unidades, R17

TI_T:
	POP     R17
	POP     R16
	RETI

/****************************************/