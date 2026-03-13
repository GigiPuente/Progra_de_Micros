/*
* NombreProgra.asm
*
* Creado: 
* Autor : 
* Descripción: Reloj con base de tiempo de 1 segundo
*/
/****************************************/
// Encabezado
.include "M328PDEF.inc"

.dseg
.org SRAM_START

segundos:  .byte 1
minutos:   .byte 1
horas:     .byte 1

.cseg
.org 0x0000
    RJMP RESET

.org OC1Aaddr
    RJMP TIMER1_COMPA_ISR

/****************************************/
// RESET
RESET:

// Configuración de la pila
LDI     R16, LOW(RAMEND)
OUT     SPL, R16
LDI     R16, HIGH(RAMEND)
OUT     SPH, R16

/****************************************/
// Configuracion MCU
SETUP:

// Inicializar reloj en 00:00:00
LDI R16, 0
STS segundos, R16
STS minutos, R16
STS horas, R16

// SEGMENTOS (PD0–PD6) como salida
LDI     R16, 0b01111111
OUT     DDRD, R16

LDI     R16, 0x00
OUT     PORTD, R16

// TRANSISTORES DISPLAYS (PC2–PC5) salida
LDI     R16, 0b00111100
OUT     DDRC, R16

LDI     R16, 0x00
OUT     PORTC, R16

// LEDS (PB2, PB3, PB4) como salida
LDI     R16, (1<<PB2)|(1<<PB3)|(1<<PB4)
OUT     DDRB, R16

// Encender LED superior e inferior permanentemente
LDI     R16, (1<<PB2)|(1<<PB3)
OUT     PORTB, R16

// Activar pull-ups en botones PB0, PB1, PB5
LDI     R16, (1<<PB0)|(1<<PB1)|(1<<PB5)|(1<<PB2)|(1<<PB3)
OUT     PORTB, R16

// Activar pull-ups en PC0 y PC1
LDI     R16, (1<<PC0)|(1<<PC1)
OUT     PORTC, R16

// Configurar Timer1 en modo CTC
LDI R16, (1<<WGM12)
STS TCCR1B, R16

// Valor para 1 segundo (16MHz / 1024 = 15625)
LDI R16, LOW(15624)
STS OCR1AL, R16
LDI R16, HIGH(15624)
STS OCR1AH, R16

// Prescaler 1024
LDS R16, TCCR1B
ORI R16, (1<<CS12)|(1<<CS10)
STS TCCR1B, R16

// Habilitar interrupción por comparación A
LDI R16, (1<<OCIE1A)
STS TIMSK1, R16

// Habilitar interrupciones globales
SEI

/****************************************/
// Loop Infinito
MAIN_LOOP:
    RJMP MAIN_LOOP

/****************************************/
// INTERRUPCIÓN TIMER1 - 1 segundo
TIMER1_COMPA_ISR:

PUSH R16
PUSH R17

// Incrementar segundos
LDS R16, segundos
INC R16
CPI R16, 60
BRLO GUARDAR_SEG

// Si segundos = 60
LDI R16, 0
STS segundos, R16

// Incrementar minutos
LDS R16, minutos
INC R16
CPI R16, 60
BRLO GUARDAR_MIN

// Si minutos = 60
LDI R16, 0
STS minutos, R16

// Incrementar horas
LDS R16, horas
INC R16
CPI R16, 24
BRLO GUARDAR_HORA

// Si horas = 24
LDI R16, 0

GUARDAR_HORA:
STS horas, R16
RJMP FIN_ISR

GUARDAR_MIN:
STS minutos, R16
RJMP FIN_ISR

GUARDAR_SEG:
STS segundos, R16

FIN_ISR:
POP R17
POP R16
RETI

/****************************************/