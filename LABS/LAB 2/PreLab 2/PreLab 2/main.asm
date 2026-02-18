/*
* PreLab 2.asm
*
* Creado: 
* Autor : Jorge Puente
* Descripción: contador binario 4 bits (100ms)
*/
/****************************************/
// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Include definitions specific to ATMega328P
.dseg
.org    SRAM_START
//variable_name:     .byte   1   // Memory alocation for variable_name:     .byte   (byte size)

.cseg
.org 0x0000

 /****************************************/
// Configuración de la pila
LDI     R16, LOW(RAMEND)
OUT     SPL, R16
LDI     R16, HIGH(RAMEND)
OUT     SPH, R16

/****************************************/
// Configuracion MCU
SETUP:
	//Contador
	LDI R16,0x0F
    OUT DDRD,R16

	//LEDs
    SBI	DDRD,2 
    SBI DDRD,3      
    SBI DDRD,4      
    SBI DDRD,5
	
	CLR R17 //0
	OUT PORTD, R17 

/****************************************/
// Loop Infinito
MAIN_LOOP:
	RCALL	INCC
	RCALL	DELAY_100MS
    RJMP	MAIN_LOOP

/****************************************/
// NON-Interrupt subroutines
//Increase
INCC:
	INC R17
	OUT PORTD, R17
	RET

DELAY_100MS:
    //TCNT0
    LDI R19, 61
    OUT TCNT0, R19

    // Normal (prescaler 1024)
    LDI R19, (1<<CS02)|(1<<CS00)
    OUT TCCR0B, R19

EOF:
    SBIS TIFR0, TOV0
    RJMP EOF

    // Limpiar bandera
    LDI R19, (1<<TOV0)
    OUT TIFR0, R19

    //Parar
    LDI R19, 0x00
    OUT TCCR0B, R19

    RET
