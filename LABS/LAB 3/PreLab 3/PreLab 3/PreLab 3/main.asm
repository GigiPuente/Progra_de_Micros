/*
* PreLab3.asm
*
* Creado: Jorge Puente
* Autor :
* Descripción: Contador binario de 4 bits (interrupciones)
*/
/****************************************/
// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"

.dseg
.org SRAM_START

contador:	.byte   1

// Guardar
EAN:		.byte   1  

.cseg
.org 0x0000

RJMP SETUP

// Vector PORTB
.org 0x0006                    
RJMP INTER

/****************************************/
// Configuración de la pila
LDI     R16, LOW(RAMEND)
OUT     SPL, R16
LDI     R16, HIGH(RAMEND)
OUT     SPH, R16

/****************************************/
// Configuracion MCU
SETUP:

//Salida
LDI     R16, 0b00001111
OUT     DDRC, R16

//Botones
CBI     DDRB, PB0
CBI     DDRB, PB1

SBI     PORTB, PB0
SBI     PORTB, PB1

//0
LDI     R16, 0x00
STS     contador, R16

//Guardar
IN      R16, PINB
STS     EAN, R16

//Interrupciones
LDI     R16, (1<<PCIE0)
STS     PCICR, R16

LDI     R16, (1<<PCINT0)|(1<<PCINT1)
STS     PCMSK0, R16

SEI

/****************************************/
// Loop Infinito
MAIN_LOOP:
LDS     R16, contador
OUT     PORTC, R16

RJMP    MAIN_LOOP

/****************************************/
// NON-Interrupt subroutines

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
// Interrupt routines

INTER:
PUSH    R16
PUSH    R17
PUSH    R18

IN      R16, PINB
LDS     R17, EAN

//Cambio
MOV     R18, R16
EOR     R18, R17

// Boton 1
SBRS    R18, PB0
RJMP    RD

//Presionado
SBRS    R16, PB0 
RCALL   INCC

RD:
SBRS    R18, PB1
RJMP    TI

SBRS    R16, PB1
RCALL   DECC

TI:
// Actualizar
STS     EAN, R16

POP     R18
POP     R17
POP     R16
RETI

/****************************************/