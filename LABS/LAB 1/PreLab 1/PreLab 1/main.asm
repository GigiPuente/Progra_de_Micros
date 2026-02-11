/*
* Lab1: Doble Contador con Suma
* Autor : Jorge Puente
*/

.include "M328PDEF.inc"

.cseg
.org 0x0000
    RJMP RESET

/****************************************/
//Pila
RESET:
    LDI R16, LOW(RAMEND)
    OUT SPL, R16
    LDI R16, HIGH(RAMEND)
    OUT SPH, R16

/****************************************/
SETUP:

    //Botones
    CBI DDRD,2
    CBI DDRD,3
    CBI DDRD,4
    CBI DDRD,5
    CBI DDRD,6

    SBI PORTD,2
    SBI PORTD,3
    SBI PORTD,4
    SBI PORTD,5
    SBI PORTD,6

    //Contador 1
    LDI R16,0x0F
    OUT DDRB,R16

    //Contador 2
    LDI R16,0x0F
    OUT DDRC,R16

    //LEDs
    SBI DDRD,7    
    SBI DDRB,4      
    SBI DDRB,5      
    SBI DDRC,4      
    SBI DDRC,5      

    CLR R17    //C1     
    CLR R21    //C2 

    OUT PORTB,R17
    OUT PORTC,R21

/****************************************/
MAIN_LOOP:
    IN R18,PIND

    //C1
    SBRS R18,2
    RCALL BTN1_INC
    SBRS R18,3
    RCALL BTN1_DEC

	//C2
    SBRS R18,4
    RCALL BTN2_INC
    SBRS R18,5
    RCALL BTN2_DEC

    //Suma
    SBRS R18,6
    RCALL SUM

    RJMP MAIN_LOOP

/****************************************/
//C1
BTN1_INC:
    RCALL DELAY
    IN R18,PIND
    SBRS R18,2
    RJMP C1_INC
    RET

C1_INC:
    INC R17
    ANDI R17,0x0F
    OUT PORTB,R17

EI1:
    IN R18,PIND
    SBRS R18,2
    RJMP EI1
    RET


BTN1_DEC:
    RCALL DELAY
    IN R18,PIND
    SBRS R18,3
    RJMP C1_DEC
    RET

C1_DEC:
    DEC R17
    ANDI R17,0x0F
    OUT PORTB,R17

ED1:
    IN R18,PIND
    SBRS R18,3
    RJMP ED1
    RET

//C2
BTN2_INC:
    RCALL DELAY
    IN R18,PIND
    SBRS R18,4
    RJMP C2_INC
    RET

C2_INC:
    INC R21
    ANDI R21,0x0F
    OUT PORTC,R21

EI2:
    IN R18,PIND
    SBRS R18,4
    RJMP EI2
    RET


BTN2_DEC:
    RCALL DELAY
    IN R18,PIND
    SBRS R18,5
    RJMP C2_DEC
    RET

C2_DEC:
    DEC R21
    ANDI R21,0x0F
    OUT PORTC,R21

ED2:
    IN R18,PIND
    SBRS R18,5
    RJMP ED2
    RET

/****************************************/
//Suma
SUM:
    RCALL DELAY
    IN R18,PIND
    SBRS R18,6
    RJMP SUM_OK
    RET

SUM_OK:
    MOV R22,R17
    ADD R22,R21    

    SBRC R22,0
    SBI PORTD,7
    SBRS R22,0
    CBI PORTD,7

    SBRC R22,1
    SBI PORTB,4
    SBRS R22,1
    CBI PORTB,4

    SBRC R22,2
    SBI PORTB,5
    SBRS R22,2
    CBI PORTB,5

    SBRC R22,3
    SBI PORTC,4
    SBRS R22,3
    CBI PORTC,4

    //Carry
    SBRC R22,4
    SBI PORTC,5
    SBRS R22,4
    CBI PORTC,5

ES:
    IN R18,PIND
    SBRS R18,6
    RJMP ES
    RET

/****************************************/
//Antirrebote
DELAY:
    LDI R19,40
D1:
    LDI R20,255
D2:
    DEC R20
    BRNE D2
    DEC R19
    BRNE D1
    RET
