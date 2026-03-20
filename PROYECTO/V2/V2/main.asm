/*
* Reloj.asm
* Creado:
* Autor:
* un reloj, funciona creo
*/

.include "M328PDEF.inc"

//7s
.equ A  = PD4
.equ B  = PD3
.equ C  = PD1  
.equ D  = PD0 
.equ E  = PD2
.equ F  = PD5
.equ G  = PD6

//LEDs
.equ L_SUP = PB2
.equ L_INF = PB3
.equ L_ALM = PB4  

//Botones PORTB
.equ B_UP = PB0
.equ B_DN = PB1
.equ MOD = PB5

//Botones PORTC
.equ B_ALM = PC0
.equ B_OFF = PC1

//Transistores
.equ T1 = PC4 //DH
.equ T2 = PC5 //UH
.equ T3 = PC2 //DM
.equ T4 = PC3 //UM

//Mascaras
.equ DDRD_M = 0b01111111 //DDRD
.equ DDRB_M = 0b00011100 //DDRB
.equ IB  = 0b00101111 //LEDs y pullup PORTB
.equ DDRC_M = 0b00111100 //DDRC
.equ PUC = 0b00000011 //Pullup PORTC
.equ TM  = 0b00111100 //Trans apagado

//Timers
.equ OCR1 = 15624  
.equ OCR0 = 249    

//Hora alarma
.equ ALM_H = 6 
.equ ALM_M = 7

// SRAM
.dseg
.org SRAM_START
sg:  .byte 1  //Segs
mu:  .byte 1  //UM
md:  .byte 1  //DM
hu:  .byte 1  //UH
hd:  .byte 1  //DH
tx:  .byte 1  //Turno display
alm: .byte 1  //Flag alarma

.cseg

//Vectores
.org 0x0000
    JMP INI
.org 0x0016
    JMP TK //Timer1
.org 0x001C
    JMP RF //Timer0

INI:
    LDI R16, LOW(RAMEND)
    OUT SPL, R16
    LDI R16, HIGH(RAMEND)
    OUT SPH, R16

    //PORTD 7S
    LDI R16, DDRD_M
    OUT DDRD, R16
    LDI R16, 0
    OUT PORTD, R16

    //PORTB leds y botones
    LDI R16, DDRB_M
    OUT DDRB, R16
    LDI R16, IB
    OUT PORTB, R16

    //PORTC trans y botones
    LDI R16, DDRC_M
    OUT DDRC, R16
    LDI R16, PUC
    OUT PORTC, R16

   
    LDI R16, 0
    STS sg, R16
    STS mu, R16
    STS md, R16
    STS hu, R16
    STS hd, R16
    STS tx, R16
    STS alm, R16 //alrm apagada

    //Timer0
    LDI R16, (1<<WGM01)
    OUT TCCR0A, R16
    LDI R16, OCR0
    OUT OCR0A, R16
    LDI R16, (1<<CS01)|(1<<CS00)
    OUT TCCR0B, R16
    LDI R16, (1<<OCIE0A)
    STS TIMSK0, R16

    //Timer1
    LDI R16, 0
    STS TCCR1A, R16
    LDI R16, HIGH(OCR1)
    STS OCR1AH, R16
    LDI R16, LOW(OCR1)
    STS OCR1AL, R16
    LDI R16, (1<<OCIE1A)
    STS TIMSK1, R16
    LDI R16, (1<<WGM12)|(1<<CS12)|(1<<CS10)
    STS TCCR1B, R16

    SEI


LOOP:
    //LED alarma
    LDS R16, alm
    CPI R16, 1
    BRNE ALM_OFF
    SBI PORTB, L_ALM 
    RJMP CHK_BOFF

ALM_OFF:
    CBI PORTB, L_ALM  

//Boton alarma
CHK_BOFF:
    IN R16, PINC
    SBRC R16, B_OFF
    RJMP CHK_UP //no apachado
    LDI R16, 0
    STS alm, R16 //apagar alarma
    CBI PORTB, L_ALM

CHK_UP:
    //Sube minutos
    IN R16, PINB
    SBRC R16, B_UP
    RJMP CHK_DEC
    RCALL ARB_B
    SBRC R16, B_UP
    RJMP CHK_DEC
    RCALL SUB_MAS
    RCALL SOLTAR_UP
    RJMP LOOP

CHK_DEC:
    //Baja minutos
    IN R16, PINB
    SBRC R16, B_DN
    RJMP CHK_MOD
    RCALL ARB_B
    SBRC R16, B_DN
    RJMP CHK_MOD
    RCALL SUB_MEN
    RCALL SOLTAR_DN
    RJMP LOOP

CHK_MOD:
    //Sube horas
    IN R16, PINB
    SBRC R16, MOD
    RJMP CHK_ALM
    RCALL ARB_B
    SBRC R16, MOD
    RJMP CHK_ALM
    RCALL SUB_MAS_H
    RCALL SOLTAR_MOD
    RJMP LOOP

CHK_ALM:
    //Baja horas
    IN R16, PINC
    SBRC R16, B_ALM
    RJMP LOOP
    RCALL ARB_C
    SBRC R16, B_ALM
    RJMP LOOP
    RCALL SUB_MEN_H
    RCALL SOLTAR_ALM

    RJMP LOOP

//Antirrebote
ARB_B:
    PUSH R24
    PUSH R25
    LDI R20, 20
ARB_BL:
    LDI R24, LOW(5333)
    LDI R25, HIGH(5333)
ARB_BW:
    SBIW R24, 1
    BRNE ARB_BW
    DEC R20
    BRNE ARB_BL
    IN R16, PINB
    POP R25
    POP R24
    RET

ARB_C:
    PUSH R24
    PUSH R25
    LDI R20, 20
ARB_CL:
    LDI R24, LOW(5333)
    LDI R25, HIGH(5333)
ARB_CW:
    SBIW R24, 1
    BRNE ARB_CW
    DEC R20
    BRNE ARB_CL
    IN R16, PINC      
    POP R25
    POP R24
    RET


SOLTAR_UP:
    PUSH R24
    PUSH R25
SUP_L:
    IN R16, PINB
    SBRC R16, B_UP
    RJMP SUP_OK
    RJMP SUP_L 
SUP_OK:
    LDI R20, 50      
SUP_RB:
    LDI R24, LOW(5333)
    LDI R25, HIGH(5333)
SUP_W:
    SBIW R24, 1
    BRNE SUP_W
    DEC R20
    BRNE SUP_RB

    IN R16, PINB
    SBRS R16, B_UP     
    RJMP SUP_L
    POP R25
    POP R24
    RET


SOLTAR_DN:
    PUSH R24
    PUSH R25
SDN_L:
    IN R16, PINB
    SBRC R16, B_DN
    RJMP SDN_OK
    RJMP SDN_L
SDN_OK:
    LDI R20, 50
SDN_RB:
    LDI R24, LOW(5333)
    LDI R25, HIGH(5333)
SDN_W:
    SBIW R24, 1
    BRNE SDN_W
    DEC R20
    BRNE SDN_RB
    IN R16, PINB
    SBRS R16, B_DN
    RJMP SDN_L
    POP R25
    POP R24
    RET

//Soltar Modo
SOLTAR_MOD:
    PUSH R24
    PUSH R25
SMO_L:
    IN R16, PINB
    SBRC R16, MOD
    RJMP SMO_OK
    RJMP SMO_L
SMO_OK:
    LDI R20, 50
SMO_RB:
    LDI R24, LOW(5333)
    LDI R25, HIGH(5333)
SMO_W:
    SBIW R24, 1
    BRNE SMO_W
    DEC R20
    BRNE SMO_RB
    IN R16, PINB
    SBRS R16, MOD
    RJMP SMO_L
    POP R25
    POP R24
    RET

//Soltar Alarma
SOLTAR_ALM:
    PUSH R24
    PUSH R25
SAL_L:
    IN R16, PINC
    SBRC R16, B_ALM
    RJMP SAL_OK
    RJMP SAL_L
SAL_OK:
    LDI R20, 50
SAL_RB:
    LDI R24, LOW(5333)
    LDI R25, HIGH(5333)
SAL_W:
    SBIW R24, 1
    BRNE SAL_W
    DEC R20
    BRNE SAL_RB
    IN R16, PINC
    SBRS R16, B_ALM
    RJMP SAL_L
    POP R25
    POP R24
    RET

//Botón INC
SUB_MAS:
    PUSH R16
    LDS R16, mu
    INC R16
    CPI R16, 10
    BRSH MAS_DEC
    STS mu, R16
    POP R16
    RET

MAS_DEC:
    LDI R16, 0
    STS mu, R16
    LDS R16, md
    INC R16
    CPI R16, 6
    BRSH MAS_59 //OVF
    STS md, R16
    POP R16
    RET

MAS_59:
    LDI R16, 0
    STS md, R16
    STS mu, R16
    POP R16
    RET

//Boton DEC
SUB_MEN:
    PUSH R16
    LDS R16, mu
    CPI R16, 0
    BREQ MEN_DEC
    DEC R16
    STS mu, R16
    POP R16
    RET

MEN_DEC:
    LDS R16, md
    CPI R16, 0
    BREQ MEN_59 //OVF
    DEC R16
    STS md, R16
    LDI R16, 9
    STS mu, R16
    POP R16
    RET

MEN_59:
    LDI R16, 5
    STS md, R16
    LDI R16, 9
    STS mu, R16
    POP R16
    RET

//Subir Horas
SUB_MAS_H:
    PUSH R16
    PUSH R17
    LDS R16, hu
    INC R16
    LDS R17, hd
    CPI R17, 2        
    BRNE MAS_H_CHK10
    CPI R16, 4
    BRSH MAS_H_23 //OVF

MAS_H_CHK10:
    CPI R16, 10
    BRSH MAS_H_DEC
    STS hu, R16
    POP R17
    POP R16
    RET

MAS_H_DEC:
    LDI R16, 0
    STS hu, R16
    LDS R16, hd
    INC R16
    STS hd, R16
    POP R17
    POP R16
    RET

MAS_H_23:
    LDI R16, 0
    STS hu, R16
    STS hd, R16
    POP R17
    POP R16
    RET

//Bajar Horas
SUB_MEN_H:
    PUSH R16
    LDS R16, hu
    CPI R16, 0
    BREQ MEN_H_DEC
    DEC R16
    STS hu, R16
    POP R16
    RET

MEN_H_DEC:
    LDS R16, hd
    CPI R16, 0
    BREQ MEN_H_23 //OVF
    DEC R16
    STS hd, R16
    LDI R16, 9
    STS hu, R16
    POP R16
    RET

MEN_H_23:
    LDI R16, 2
    STS hd, R16
    LDI R16, 3
    STS hu, R16
    POP R16
    RET

//Timer1
TK:
    PUSH R16
    IN R16, SREG
    PUSH R16
    PUSH R17

    LDS R16, sg
    INC R16
    CPI R16, 60
    BRSH OVS
    STS sg, R16
    RJMP CHK_ALM_H

OVS: //Segs > 60
    LDI R16, 0
    STS sg, R16
    LDS R16, mu
    INC R16
    CPI R16, 10
    BRSH OVMU
    STS mu, R16
    RJMP CHK_ALM_H

OVMU: //UM > 10
    LDI R16, 0
    STS mu, R16
    LDS R16, md
    INC R16
    CPI R16, 6
    BRSH OVMD
    STS md, R16
    RJMP CHK_ALM_H

OVMD: //DM > 6
    LDI R16, 0
    STS md, R16
    LDS R16, hu
    INC R16
    LDS R17, hd
    CPI R17, 2
    BRNE CHK_HU
    CPI R16, 4
    BREQ R24H //OVF

CHK_HU:
    CPI R16, 10
    BRSH OVHU
    STS hu, R16
    RJMP CHK_ALM_H

OVHU: //UH > 10
    LDI R16, 0
    STS hu, R16
    LDS R16, hd
    INC R16
    STS hd, R16
    RJMP CHK_ALM_H

R24H: //OVF
    LDI R16, 0
    STS hu, R16
    STS hd, R16

    //checar alarma
CHK_ALM_H:
    LDS R16, hd
    LDI R17, ALM_H/10
    CP R16, R17
    BRNE FTK
    LDS R16, hu
    LDI R17, ALM_H - ((ALM_H/10)*10)
    CP R16, R17
    BRNE FTK
    LDS R16, md
    LDI R17, ALM_M/10
    CP R16, R17
    BRNE FTK
    LDS R16, mu
    LDI R17, ALM_M - ((ALM_M/10)*10)
    CP R16, R17
    BRNE FTK
    LDI R16, 1
    STS alm, R16       // hora exacta = activar alarma

FTK:
    POP R17
    POP R16
    OUT SREG, R16
    POP R16
    RETI

//TIMER 0
RF:
    PUSH R16
    IN R16, SREG
    PUSH R16
    PUSH R17
    PUSH R18
    PUSH R19
    PUSH ZL
    PUSH ZH

    //Apagar todo
    IN R16, PORTC
    ANDI R16, ~TM
    OUT PORTC, R16
    LDI R16, 0
    OUT PORTD, R16

    LDS R17, tx

    CPI R17, 0
    BREQ D0
    CPI R17, 1
    BREQ D1
    CPI R17, 2
    BREQ D2
    RJMP D3

D0: LDS R18, hd //DH
    LDI R19, (1<<T1)
    RJMP SHOW

D1: LDS R18, hu //UH
    LDI R19, (1<<T2)
    RJMP SHOW

D2: LDS R18, md //DM
    LDI R19, (1<<T3)
    RJMP SHOW

D3: LDS R18, mu //UM
    LDI R19, (1<<T4)

SHOW:
    //Buscar en tabla
    LDI ZH, HIGH(SEG7 << 1)
    LDI ZL, LOW(SEG7 << 1)
    CLR R16
    ADD ZL, R18
    ADC ZH, R16
    LPM R18, Z

    OUT PORTD, R18
    IN R16, PORTC
    OR R16, R19
    OUT PORTC, R16

    //Siguiente
    INC R17
    CPI R17, 4
    BRLO GTXN
    LDI R17, 0
GTXN:
    STS tx, R17

    POP ZH
    POP ZL
    POP R19
    POP R18
    POP R17
    POP R16
    OUT SREG, R16
    POP R16
    RETI

//Tabla 7S
SEG7:
    .DB 0b00111111, 0b00001010  // 0 1
    .DB 0b01011101, 0b01011011  // 2 3
    .DB 0b01101010, 0b01110011  // 4 5
    .DB 0b01110111, 0b00011010  // 6 7
    .DB 0b01111111, 0b01111011  // 8 9