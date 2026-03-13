/*
* Reloj.asm
*
* Creado: 
* Autor : 
* Descripción: es un reloj con displays de 7 segmentos
*              si no funciona no se que decirte
*/

/****************************************/
.include "M328PDEF.inc"

//7S
.equ    SEG_D = PD0
.equ    SEG_C = PD1 
.equ    SEG_E = PD2
.equ    SEG_B = PD3
.equ    SEG_A = PD4
.equ    SEG_F = PD5
.equ    SEG_G = PD6

//LEDs
.equ    LED_SUP = PB2  
.equ    LED_INF = PB3   
.equ    LED_ALM = PB4  

//Botones
.equ    BTN_INC  = PB0 
.equ    BTN_DEC  = PB1   
.equ    BTN_MODE = PB5   
.equ    BTN_ALM  = PC0   
.equ    BTN_OFF  = PC1   

//Trans MUX
.equ    TRANS_D1 = PC4   //DH
.equ    TRANS_D2 = PC5   //UH
.equ    TRANS_D3 = PC2   //DM
.equ    TRANS_D4 = PC3   //UM

//Mascaras
.equ    DDRD_MASK   = 0b01111111   //PORTD -ult
.equ    DDRB_MASK   = 0b00011100   //Botones
.equ    PORTB_INIT  = 0b00101111   //LEDs y Botones
.equ    DDRC_MASK   = 0b00111100   //Trans out, Botones in 
.equ    PORTC_PU    = 0b00000011   //Botones pull-up
.equ    TRANS_MASK  = 0b00111100   //Trans off

//TIMERS
//Timer1:
.equ    OCR1A_VAL = 1564

// Timer0 
.equ    OCR0A_VAL = 249   

//Antirrebote
.equ    AR = 50

/****************************************/
//SRAM
.dseg
.org SRAM_START
segs:      .byte 1   
min_uni:   .byte 1  
min_dec:   .byte 1   
hr_uni:    .byte 1 
hr_dec:    .byte 1  
turno:     .byte 1  

/****************************************/
.cseg

//Interrupciones
.org 0x0000
    JMP     INICIO 
.org 0x0016
    JMP     TICK          
.org 0x001C
    JMP     REFRESCA       

INICIO:
//PILA
    LDI     R16, LOW(RAMEND)
    OUT     SPL, R16
    LDI     R16, HIGH(RAMEND)
    OUT     SPH, R16

SETUP:
    //7S
    LDI     R16, DDRD_MASK
    OUT     DDRD, R16
    LDI     R16, 0x00
    OUT     PORTD, R16

    //LEDs PORTB
    LDI     R16, DDRB_MASK
    OUT     DDRB, R16
    LDI     R16, PORTB_INIT 
    OUT     PORTB, R16

    //Trans y Botones
    LDI     R16, DDRC_MASK
    OUT     DDRC, R16
    LDI     R16, PORTC_PU
    OUT     PORTC, R16

    //0
    LDI     R16, 0
    STS     segs, R16
    STS     min_uni, R16
    STS     min_dec, R16
    STS     hr_uni, R16
    STS     hr_dec, R16
    STS     turno, R16

    //Timer0
	//Modo
    LDI     R16, (1<<WGM01)
    OUT     TCCR0A, R16

    LDI     R16, OCR0A_VAL
    OUT     OCR0A, R16

	//Prescaler
    LDI     R16, (1<<CS01)|(1<<CS00)
    OUT     TCCR0B, R16

    LDI     R16, (1<<OCIE0A)
    STS     TIMSK0, R16

    //Timer1
	//Modo
    LDI     R16, 0x00
    STS     TCCR1A, R16

    LDI     R16, HIGH(OCR1A_VAL)
    STS     OCR1AH, R16
    LDI     R16, LOW(OCR1A_VAL)
    STS     OCR1AL, R16
    LDI     R16, (1<<OCIE1A)
    STS     TIMSK1, R16

	//Prescaler
    LDI     R16, (1<<WGM12)|(1<<CS12)|(1<<CS10)
    STS     TCCR1B, R16

    SEI  

/****************************************/
MAIN_LOOP:
    IN      R16, PINB
    SBRC    R16, BTN_INC      
    RJMP    CHECAR_DEC
    RCALL   AR_INC
    RCALL   SUBIR_MIN

CHECAR_DEC:
    IN      R16, PINB
    SBRC    R16, BTN_DEC
    RJMP    FIN_LOOP
    RCALL   AR_DEC
    RCALL   BAJAR_MIN

FIN_LOOP:
    RJMP    MAIN_LOOP

/****************************************/
AR_INC:
    LDI     R20, AR
DB_INC_LOOP:
    RCALL   ESPERAR_1MS
    DEC     R20
    BRNE    DB_INC_LOOP

    //Presionado?
    IN      R16, PINB
    SBRS    R16, BTN_INC       //Si
    RET
    RET                        //NO

AR_DEC:
    LDI     R20, AR

DB_DEC_LOOP:
    RCALL   ESPERAR_1MS
    DEC     R20
    BRNE    DB_DEC_LOOP
    IN      R16, PINB
    SBRS    R16, BTN_DEC
    RET
    RET

/****************************************/
ESPERAR_1MS:
    PUSH    R24
    PUSH    R25
    LDI     R24, LOW(5333)     
    LDI     R25, HIGH(5333)

W1MS_LOOP:
    SBIW    R24, 1             
    BRNE    W1MS_LOOP
    POP     R25
    POP     R24
    RET

/****************************************/
SUBIR_MIN:
    PUSH    R16

    LDS     R16, min_uni
    INC     R16
    CPI     R16, 10
    BRSH    SUBIR_MIN_DEC      //OVF

    STS     min_uni, R16       
    POP     R16
    RET

SUBIR_MIN_DEC:
    LDI     R16, 0
    STS     min_uni, R16       //0

    LDS     R16, min_dec
    INC     R16
    CPI     R16, 6
    BRSH    SUBIR_MIN_OVF59    //OVF

    STS     min_dec, R16
    POP     R16
    RET

SUBIR_MIN_OVF59:
    LDI     R16, 0
    STS     min_dec, R16      
    STS     min_uni, R16
    POP     R16
    RET

/****************************************/
BAJAR_MIN:
    PUSH    R16

    LDS     R16, min_uni
    CPI     R16, 0
    BREQ    BAJAR_MIN_DEC      //Si

    DEC     R16
    STS     min_uni, R16       
    POP     R16
    RET

BAJAR_MIN_DEC:
    LDS     R16, min_dec
    CPI     R16, 0
    BREQ    BAJAR_MIN_OVF00    //OVF

    DEC     R16
    STS     min_dec, R16    
    LDI     R16, 9
    STS     min_uni, R16     
    POP     R16
    RET

BAJAR_MIN_OVF00:
    LDI     R16, 5
    STS     min_dec, R16       //OVF
    LDI     R16, 9
    STS     min_uni, R16
    POP     R16
    RET

/****************************************/
TICK:
    PUSH    R16
    IN      R16, SREG
    PUSH    R16
    PUSH    R17

    //+S
    LDS     R16, segs
    INC     R16
    CPI     R16, 60
    BRSH    SEGS_OVF          //OVF
    STS     segs, R16
    RJMP    FIN_TICK

SEGS_OVF:
    LDI     R16, 0
    STS     segs, R16

    //+UM
    LDS     R16, min_uni
    INC     R16
    CPI     R16, 10
    BRSH    MINU_OVF
    STS     min_uni, R16
    RJMP    FIN_TICK

MINU_OVF:
    LDI     R16, 0
    STS     min_uni, R16

    //+DM
    LDS     R16, min_dec
    INC     R16
    CPI     R16, 6
    BRSH    MIND_OVF
    STS     min_dec, R16
    RJMP    FIN_TICK

MIND_OVF:
    LDI     R16, 0
    STS     min_dec, R16

    //+H
    LDS     R16, hr_uni
    INC     R16
    LDS     R17, hr_dec
    CPI     R17, 2
    BRNE    CHECAR_HRU         //24 NO
    CPI     R16, 4
    BREQ    RESET_TOTAL        //24 SI

CHECAR_HRU:
    CPI     R16, 10
    BRSH    HRU_OVF
    STS     hr_uni, R16
    RJMP    FIN_TICK

HRU_OVF:
    LDI     R16, 0
    STS     hr_uni, R16

    //+DH
    LDS     R16, hr_dec
    INC     R16
    STS     hr_dec, R16
    RJMP    FIN_TICK

RESET_TOTAL:
    //00:00
    LDI     R16, 0
    STS     hr_uni, R16
    STS     hr_dec, R16

FIN_TICK:
    POP     R17
    POP     R16
    OUT     SREG, R16
    POP     R16
    RETI

/****************************************/
REFRESCA:
    PUSH    R16
    IN      R16, SREG
    PUSH    R16
    PUSH    R17
    PUSH    R18
    PUSH    R19
    PUSH    ZL
    PUSH    ZH

    //0
    IN      R16, PORTC
    ANDI    R16, ~TRANS_MASK
    OUT     PORTC, R16
    LDI     R16, 0x00
    OUT     PORTD, R16

    //Display
    LDS     R17, turno

    CPI     R17, 0
    BREQ    TURNO_0
    CPI     R17, 1
    BREQ    TURNO_1
    CPI     R17, 2
    BREQ    TURNO_2
    RJMP    TURNO_3

TURNO_0:   //DH
    LDS     R18, hr_dec
    LDI     R19, (1<<TRANS_D1)
    RJMP    MOSTRAR

TURNO_1:   //UH
    LDS     R18, hr_uni
    LDI     R19, (1<<TRANS_D2)
    RJMP    MOSTRAR

TURNO_2:   //DM
    LDS     R18, min_dec
    LDI     R19, (1<<TRANS_D3)
    RJMP    MOSTRAR

TURNO_3:   //UM
    LDS     R18, min_uni
    LDI     R19, (1<<TRANS_D4)

MOSTRAR:
    LDI     ZH, HIGH(TABLA_7SEG << 1)
    LDI     ZL, LOW(TABLA_7SEG << 1)
    CLR     R16
    ADD     ZL, R18
    ADC     ZH, R16
    LPM     R18, Z 

    //Encender
    OUT     PORTD, R18
    IN      R16, PORTC
    OR      R16, R19
    OUT     PORTC, R16

    //Siguiente
    INC     R17
    CPI     R17, 4
    BRLO    GUARDAR_TURNO
    LDI     R17, 0

GUARDAR_TURNO:
    STS     turno, R17

    POP     ZH
    POP     ZL
    POP     R19
    POP     R18
    POP     R17
    POP     R16
    OUT     SREG, R16
    POP     R16
    RETI

/****************************************/

TABLA_7SEG:
    .DB  0b00111111, 0b00001010   //0, 1
    .DB  0b01011101, 0b01011011   //2, 3
    .DB  0b01101010, 0b01110011   //4, 5
    .DB  0b01110111, 0b00011010   //6, 7
    .DB  0b01111111, 0b01111011   //8, 9