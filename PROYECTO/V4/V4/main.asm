/****************************************/
// Reloj.asm
// Creado:
// Autor:
// Descripcion: 
/****************************************/

.include "M328PDEF.inc"

/****************************************/
// ENTRADAS Y SALIDAS
/****************************************/

//7seg - PORTD
.equ SEG_A     = PD4
.equ SEG_B     = PD3
.equ SEG_C     = PD1 
.equ SEG_D     = PD0   
.equ SEG_E     = PD2
.equ SEG_F     = PD5
.equ SEG_G     = PD6
.equ LED_FECHA = PD7   //LED modo fecha

//LEDs - PORTB
.equ LED_PTS_UP = PB2  //Punto arriba  
.equ LED_PTS_DN = PB3  //Punto abajo   
.equ LED_ALARM  = PB4  //LED alarma    

//Botones - PORTB
.equ BTN_MINS_UP = PB0 //Sube min 
.equ BTN_MINS_DN = PB1 //Baja min  
.equ BTN_HRS_UP  = PB5 //Sube hr / apaga alarma

//Botones - PORTC
.equ BTN_HRS_DN  = PC0 //Baja hr  
.equ BTN_MODO    = PC1 //Cambia modo / apaga alarma 

// Trans MUX - PORTC
.equ TRANS_DH = PC4    //DH
.equ TRANS_UH = PC5    //UH
.equ TRANS_DM = PC2    //DM
.equ TRANS_UM = PC3    //UM

/****************************************/
// MASCARAS DE PUERTOS
/****************************************/

.equ DIR_PORTD  = 0b11111111  //PORTD todo salida
.equ DIR_PORTB  = 0b00011100  //sal: PB2,PB3,PB4 y ent: PB0,PB1,PB5
.equ INIT_PORTB = 0b00101111  //LEDs dos puntos ON + pullups botones
.equ DIR_PORTC  = 0b00111100  //sal: PC2-PC5 y ent: PC0,PC1
.equ PULLUP_C   = 0b00000011  //pullups BTN_HRS_DN y BTN_MODO
.equ MASK_TRANS = 0b00111100  //Off 4 trans

/****************************************/
// MODOS
/****************************************/

.equ MODO_HORA  = 0  //Hora
.equ MODO_FECHA = 1  //Fecha
.equ MODO_CFG_H = 2  //Config. Hora
.equ MODO_CFG_F = 3  //Config. Fecha
.equ MODO_CFG_A = 4  //Config. Alarma

/****************************************/
// CONFIGURACION TIMERS
/****************************************/

// Timer1
.equ TIMER1_TOP = 1388

// Timer0
.equ TIMER0_TOP = 249

/****************************************/
// VARIABLES EN SRAM
/****************************************/

.dseg
.org SRAM_START

//Tiempo
segs:    .byte 1  //segundos (0-59)
min_uni: .byte 1  //UM (0-9)
min_dec: .byte 1  //DM (0-5)
hr_uni:  .byte 1  //UH (0-9)
hr_dec:  .byte 1  //DH (0-2)

// Display
disp_turno: .byte 1  //Qué Display?
modo:       .byte 1  //Modo actual
blink_flag: .byte 1  //Parpadeo puntos: 0=OFF 1=ON
blink_cnt:  .byte 1  //V. Parpadeo

// Alarma
alarma_flag:   .byte 1  //0=apagada 1=sonando
alarma_snooze: .byte 1  //1=ya se apago este minuto, no volver 
amin_uni: .byte 1  //Alarma UM
amin_dec: .byte 1  //Alarma DM
ahr_uni:  .byte 1  //Alarma UH
ahr_dec:  .byte 1  //Alarma DH

// Fecha
dia_uni: .byte 1  //Dia unidades
dia_dec: .byte 1  //Dia decenas
mes_uni: .byte 1  //Mes unidades
mes_dec: .byte 1  //Mes decenas

/****************************************/
// VECTORES DE INTERRUPCION
/****************************************/

.cseg

.org 0x0000
    JMP INI   //reset
.org 0x0016
    JMP TK    //Timer1 COMPA (contar)
.org 0x001C
    JMP RF    //Timer0 COMPA (MUX)

/****************************************/
// INICIALIZACION
/****************************************/

INI:
    //Pila
    LDI R16, LOW(RAMEND)
    OUT SPL, R16
    LDI R16, HIGH(RAMEND)
    OUT SPH, R16

    //PORTD - 7s y LED_FECHA 
    LDI R16, DIR_PORTD
    OUT DDRD, R16
    LDI R16, 0
    OUT PORTD, R16

    //PORTB - LEDs dos puntos, LED alarma, botones
    LDI R16, DIR_PORTB
    OUT DDRB, R16
    LDI R16, INIT_PORTB
    OUT PORTB, R16

    //PORTC - trans MUX, botones
    LDI R16, DIR_PORTC
    OUT DDRC, R16
    LDI R16, PULLUP_C
    OUT PORTC, R16

    //0
    LDI R16, 0
    STS segs,    R16
    STS min_uni, R16
    STS min_dec, R16
    STS hr_uni,  R16
    STS hr_dec,  R16

    //0
    STS disp_turno, R16
    STS modo,       R16
    STS blink_cnt,  R16
    LDI R16, 1
    STS blink_flag, R16   //parpadeo encendido

    // Alarma
    LDI R16, 0
    STS alarma_flag,   R16
    STS alarma_snooze, R16
    STS amin_uni,      R16
    STS amin_dec,      R16
    LDI R16, 5
    STS ahr_uni, R16   //5
    LDI R16, 2
    STS ahr_dec, R16   //2

    // Fecha inicial
    LDI R16, 0
    STS dia_uni, R16
    LDI R16, 2
    STS dia_dec, R16   //Día
    LDI R16, 3
    STS mes_uni, R16   //Mes
    LDI R16, 0
    STS mes_dec, R16

//----------------------------------------
// Timer0
//----------------------------------------

    LDI R16, (1<<WGM01)   //CTC
    OUT TCCR0A, R16
    LDI R16, TIMER0_TOP   //Top = 249
    OUT OCR0A, R16
    LDI R16, (1<<CS01)|(1<<CS00)  //Prescaler 64
    OUT TCCR0B, R16
    LDI R16, (1<<OCIE0A)  //Habilitar interrupcion COMPA
    STS TIMSK0, R16

//----------------------------------------
// Timer1
//----------------------------------------

    LDI R16, 0x00
    STS TCCR1A, R16
    LDI R16, HIGH(TIMER1_TOP)        
    STS OCR1AH, R16
    LDI R16, LOW(TIMER1_TOP)
    STS OCR1AL, R16
    LDI R16, (1<<OCIE1A) //Habilitar interrupcion COMPA
    STS TIMSK1, R16
    LDI R16, (1<<WGM12)|(1<<CS11) //CTC + prescaler 1024
    STS TCCR1B, R16

    SEI  

/****************************************/
// LOOP
/****************************************/

LOOP:
//----------------------------------------
// LEDs de los dos puntos
//----------------------------------------

    //ON siempre
    SBI PORTB, LED_PTS_UP
    SBI PORTB, LED_PTS_DN
SKIP_LEDS_ON:

//----------------------------------------
// LED fecha
//----------------------------------------

    LDS R16, modo
    CPI R16, MODO_FECHA
    BRNE LED_FECHA_OFF
    SBI PORTD, LED_FECHA
    RJMP LED_FECHA_DONE
LED_FECHA_OFF:
    CBI PORTD, LED_FECHA
LED_FECHA_DONE:

//----------------------------------------
// LED alarma
//----------------------------------------

    LDS R16, alarma_flag
    CPI R16, 1
    BRNE LED_ALARM_OFF
    SBI PORTB, LED_ALARM
    RJMP CHK_D13
LED_ALARM_OFF:
    CBI PORTB, LED_ALARM

//----------------------------------------
// BTN_HRS_UP (Alarma OFF)
//----------------------------------------

CHK_D13:
    LDS R16, alarma_flag
    CPI R16, 1
    BRNE CHK_BMOD
    IN R16, PINB
    SBRC R16, BTN_HRS_UP
    RJMP CHK_BMOD
    RCALL W20MS
    LDI R16, 0
    STS alarma_flag,   R16
    LDI R16, 1
    STS alarma_snooze, R16
ALM_REL:
    IN R16, PINB
    SBRS R16, BTN_HRS_UP
    RJMP ALM_REL
    RCALL W80MS

//----------------------------------------
// BTN_MODO (Alarma OFF si ON si no modo)
//----------------------------------------

CHK_BMOD:
    IN R16, PINC
    SBRC R16, BTN_MODO
    RJMP CHK_BTNS
    RCALL W20MS
    LDS R16, alarma_flag
    CPI R16, 1
    BRNE BMOD_MODO
    LDI R16, 0
    STS alarma_flag,   R16
    LDI R16, 1
    STS alarma_snooze, R16
    RJMP BMOD_REL
BMOD_MODO:
    RCALL CAMBIAR_MODO
BMOD_REL:
    IN R16, PINC
    SBRS R16, BTN_MODO
    RJMP BMOD_REL
    RCALL W80MS

//----------------------------------------
// Botones de ajuste
//----------------------------------------

CHK_BTNS:
    LDS R16, modo
    CPI R16, MODO_CFG_H
    BRNE CHK_BTNS_F
    RJMP DO_BTNS_HORA
CHK_BTNS_F:
    CPI R16, MODO_CFG_F
    BRNE CHK_BTNS_A
    RJMP DO_BTNS_FECHA
CHK_BTNS_A:
    CPI R16, MODO_CFG_A
    BRNE CHK_BTNS_NONE
    RJMP DO_BTNS_ALM
CHK_BTNS_NONE:
    RJMP LOOP

DO_BTNS_HORA:
    RCALL POLL_BTNS_H
    RJMP LOOP

DO_BTNS_FECHA:
    RCALL POLL_BTNS_F
    RJMP LOOP

DO_BTNS_ALM:
    RCALL POLL_BTNS_A
    RJMP LOOP

/****************************************/
// ANTIRREBOTE
/****************************************/

W20MS:
    PUSH R20
    PUSH R24
    PUSH R25
    LDI R20, 20
W20_L:
    LDI R24, LOW(5333)
    LDI R25, HIGH(5333)
W20_W:
    SBIW R24, 1
    BRNE W20_W
    DEC R20
    BRNE W20_L
    POP R25
    POP R24
    POP R20
    RET

W80MS:
    PUSH R20
    PUSH R24
    PUSH R25
    LDI R20, 80
W80_L:
    LDI R24, LOW(5333)
    LDI R25, HIGH(5333)
W80_W:
    SBIW R24, 1
    BRNE W80_W
    DEC R20
    BRNE W80_L
    POP R25
    POP R24
    POP R20
    RET

/****************************************/
// CAMBIO DE MODO
/****************************************/

//Hora - Fecha - Cfg.Hora - Cfg.Fecha - Cfg.Alarma 
CAMBIAR_MODO:
    PUSH R16
    LDS R16, modo
    CPI R16, MODO_CFG_A
    BREQ CM_RESET
    INC R16
    CPI R16, 5
    BRSH CM_RESET
    STS modo, R16
    POP R16
    RET
CM_RESET:
    LDI R16, 0
    STS modo, R16
    POP R16
    RET

/****************************************/
// POLLING DE BOTONES
/****************************************/

//----------------------------------------
// Config Hora: BTN_MINS_UP/DN = minutos y BTN_HRS_UP/DN = horas
//----------------------------------------

POLL_BTNS_H:
    IN R16, PINB
    SBRC R16, BTN_MINS_UP
    RJMP PH_NO_MINSUP
    RCALL W20MS
    RCALL SUB_MAS
PH_REL_MINSUP:
    IN R16, PINB
    SBRS R16, BTN_MINS_UP
    RJMP PH_REL_MINSUP
    RCALL W80MS
    RET

PH_NO_MINSUP:
    IN R16, PINB //releer PINB 
    SBRC R16, BTN_MINS_DN
    RJMP PH_NO_MINSDN
    RCALL W20MS
    RCALL SUB_MEN
PH_REL_MINSDN:
    IN R16, PINB
    SBRS R16, BTN_MINS_DN
    RJMP PH_REL_MINSDN
    RCALL W80MS
    RET

PH_NO_MINSDN:
    IN R16, PINB //releer PINB
    SBRC R16, BTN_HRS_UP
    RJMP PH_NO_HRSUP
    RCALL W20MS
    RCALL SUB_MAS_H
PH_REL_HRSUP:
    IN R16, PINB
    SBRS R16, BTN_HRS_UP
    RJMP PH_REL_HRSUP
    RCALL W80MS
    RET

PH_NO_HRSUP:
    IN R17, PINC //releer PINC
    SBRC R17, BTN_HRS_DN
    RJMP PH_RET
    RCALL W20MS
    RCALL SUB_MEN_H
PH_REL_HRSDN:
    IN R17, PINC
    SBRS R17, BTN_HRS_DN
    RJMP PH_REL_HRSDN
    RCALL W80MS
PH_RET:
    RET

//----------------------------------------
// Config Fecha: BTN_MINS_UP/DN = dia y BTN_HRS_UP/DN = mes
//----------------------------------------

POLL_BTNS_F:
    IN R16, PINB
    SBRC R16, BTN_MINS_UP
    RJMP PF_NO_MINSUP
    RCALL W20MS
    RCALL SUB_MAS_DIA
PF_REL_MINSUP:
    IN R16, PINB
    SBRS R16, BTN_MINS_UP
    RJMP PF_REL_MINSUP
    RCALL W80MS
    RET

PF_NO_MINSUP:
    IN R16, PINB          //releer PINB 
    SBRC R16, BTN_MINS_DN
    RJMP PF_NO_MINSDN
    RCALL W20MS
    RCALL SUB_MEN_DIA
PF_REL_MINSDN:
    IN R16, PINB
    SBRS R16, BTN_MINS_DN
    RJMP PF_REL_MINSDN
    RCALL W80MS
    RET

PF_NO_MINSDN:
    IN R16, PINB          //releer PINB 
    SBRC R16, BTN_HRS_UP
    RJMP PF_NO_HRSUP
    RCALL W20MS
    RCALL SUB_MAS_MES
PF_REL_HRSUP:
    IN R16, PINB
    SBRS R16, BTN_HRS_UP
    RJMP PF_REL_HRSUP
    RCALL W80MS
    RET

PF_NO_HRSUP:
    IN R17, PINC          //releer PINC
    SBRC R17, BTN_HRS_DN
    RJMP PF_RET
    RCALL W20MS
    RCALL SUB_MEN_MES
PF_REL_HRSDN:
    IN R17, PINC
    SBRS R17, BTN_HRS_DN
    RJMP PF_REL_HRSDN
    RCALL W80MS
PF_RET:
    RET

//----------------------------------------
// Config Alarma: BTN_MINS_UP/DN = min alarma y BTN_HRS_UP/DN = hr alarma
//----------------------------------------

POLL_BTNS_A:
    IN R16, PINB
    SBRC R16, BTN_MINS_UP
    RJMP PA_NO_MINSUP
    RCALL W20MS
    RCALL SUB_MAS_A
PA_REL_MINSUP:
    IN R16, PINB
    SBRS R16, BTN_MINS_UP
    RJMP PA_REL_MINSUP
    RCALL W80MS
    RET

PA_NO_MINSUP:
    IN R16, PINB          //releer PINB
    SBRC R16, BTN_MINS_DN
    RJMP PA_NO_MINSDN
    RCALL W20MS
    RCALL SUB_MEN_A
PA_REL_MINSDN:
    IN R16, PINB
    SBRS R16, BTN_MINS_DN
    RJMP PA_REL_MINSDN
    RCALL W80MS
    RET

PA_NO_MINSDN:
    IN R16, PINB          //releer PINB 
    SBRC R16, BTN_HRS_UP
    RJMP PA_NO_HRSUP
    RCALL W20MS
    RCALL SUB_MAS_AH
PA_REL_HRSUP:
    IN R16, PINB
    SBRS R16, BTN_HRS_UP
    RJMP PA_REL_HRSUP
    RCALL W80MS
    RET

PA_NO_HRSUP:
    IN R17, PINC          //releer PINC 
    SBRC R17, BTN_HRS_DN
    RET
    RCALL W20MS
    RCALL SUB_MEN_AH
PA_REL_HRSDN:
    IN R17, PINC
    SBRS R17, BTN_HRS_DN
    RJMP PA_REL_HRSDN
    RCALL W80MS
    RET

/****************************************/
// AJUSTE DE MINUTOS DEL RELOJ
/****************************************/

// SUB_MAS: +1 min - SUB_MEN: -1 min - wrap 00-59
SUB_MAS:
    PUSH R16
    LDS R16, min_uni
    INC R16
    CPI R16, 10
    BRSH MAS_DEC
    STS min_uni, R16
    POP R16
    RET
MAS_DEC:
    LDI R16, 0
    STS min_uni, R16
    LDS R16, min_dec
    INC R16
    CPI R16, 6
    BRSH MAS_59
    STS min_dec, R16
    POP R16
    RET
MAS_59:
    LDI R16, 0
    STS min_dec, R16
    STS min_uni, R16
    POP R16
    RET

SUB_MEN:
    PUSH R16
    LDS R16, min_uni
    CPI R16, 0
    BREQ MEN_DEC
    DEC R16
    STS min_uni, R16
    POP R16
    RET
MEN_DEC:
    LDS R16, min_dec
    CPI R16, 0
    BREQ MEN_59
    DEC R16
    STS min_dec, R16
    LDI R16, 9
    STS min_uni, R16
    POP R16
    RET
MEN_59:
    LDI R16, 5
    STS min_dec, R16
    LDI R16, 9
    STS min_uni, R16
    POP R16
    RET

/****************************************/
// AJUSTE DE HORAS DEL RELOJ
/****************************************/

// SUB_MAS_H: +1 hr - SUB_MEN_H: -1 hr - wrap 00-23
SUB_MAS_H:
    PUSH R16
    PUSH R17
    LDS R16, hr_uni
    INC R16
    LDS R17, hr_dec
    CPI R17, 2
    BRNE MAS_H_10
    CPI R16, 4
    BRSH MAS_H_23
MAS_H_10:
    CPI R16, 10
    BRSH MAS_H_DEC
    STS hr_uni, R16
    POP R17
    POP R16
    RET
MAS_H_DEC:
    LDI R16, 0
    STS hr_uni, R16
    LDS R16, hr_dec
    INC R16
    STS hr_dec, R16
    POP R17
    POP R16
    RET
MAS_H_23:
    LDI R16, 0
    STS hr_uni, R16
    STS hr_dec, R16
    POP R17
    POP R16
    RET

SUB_MEN_H:
    PUSH R16
    LDS R16, hr_uni
    CPI R16, 0
    BREQ MEN_H_DEC
    DEC R16
    STS hr_uni, R16
    POP R16
    RET
MEN_H_DEC:
    LDS R16, hr_dec
    CPI R16, 0
    BREQ MEN_H_23
    DEC R16
    STS hr_dec, R16
    LDI R16, 9
    STS hr_uni, R16
    POP R16
    RET
MEN_H_23:
    LDI R16, 2
    STS hr_dec, R16
    LDI R16, 3
    STS hr_uni, R16
    POP R16
    RET

/****************************************/
// AJUSTE DE MINUTOS DE ALARMA
/****************************************/

// SUB_MAS_A: +1 min - SUB_MEN_A: -1 min - wrap 00-59
SUB_MAS_A:
    PUSH R16
    LDS R16, amin_uni
    INC R16
    CPI R16, 10
    BRSH MAS_A_DEC
    STS amin_uni, R16
    POP R16
    RET
MAS_A_DEC:
    LDI R16, 0
    STS amin_uni, R16
    LDS R16, amin_dec
    INC R16
    CPI R16, 6
    BRSH MAS_A_59
    STS amin_dec, R16
    POP R16
    RET
MAS_A_59:
    LDI R16, 0
    STS amin_dec, R16
    STS amin_uni, R16
    POP R16
    RET

SUB_MEN_A:
    PUSH R16
    LDS R16, amin_uni
    CPI R16, 0
    BREQ MEN_A_DEC
    DEC R16
    STS amin_uni, R16
    POP R16
    RET
MEN_A_DEC:
    LDS R16, amin_dec
    CPI R16, 0
    BREQ MEN_A_59
    DEC R16
    STS amin_dec, R16
    LDI R16, 9
    STS amin_uni, R16
    POP R16
    RET
MEN_A_59:
    LDI R16, 5
    STS amin_dec, R16
    LDI R16, 9
    STS amin_uni, R16
    POP R16
    RET

/****************************************/
// AJUSTE DE HORAS DE ALARMA
/****************************************/

// SUB_MAS_AH: +1 hr - SUB_MEN_AH: -1 hr - wrap 00-23
SUB_MAS_AH:
    PUSH R16
    PUSH R17
    LDS R16, ahr_uni
    INC R16
    LDS R17, ahr_dec
    CPI R17, 2
    BRNE MAS_AH_10
    CPI R16, 4
    BRSH MAS_AH_23
MAS_AH_10:
    CPI R16, 10
    BRSH MAS_AH_DEC
    STS ahr_uni, R16
    POP R17
    POP R16
    RET
MAS_AH_DEC:
    LDI R16, 0
    STS ahr_uni, R16
    LDS R16, ahr_dec
    INC R16
    STS ahr_dec, R16
    POP R17
    POP R16
    RET
MAS_AH_23:
    LDI R16, 0
    STS ahr_uni, R16
    STS ahr_dec, R16
    POP R17
    POP R16
    RET

SUB_MEN_AH:
    PUSH R16
    LDS R16, ahr_uni
    CPI R16, 0
    BREQ MEN_AH_DEC
    DEC R16
    STS ahr_uni, R16
    POP R16
    RET
MEN_AH_DEC:
    LDS R16, ahr_dec
    CPI R16, 0
    BREQ MEN_AH_23
    DEC R16
    STS ahr_dec, R16
    LDI R16, 9
    STS ahr_uni, R16
    POP R16
    RET
MEN_AH_23:
    LDI R16, 2
    STS ahr_dec, R16
    LDI R16, 3
    STS ahr_uni, R16
    POP R16
    RET

/****************************************/
// AJUSTE DE DIA Y MES
/****************************************/

// SUB_MAS_DIA: +1 dia (respeta max del mes)
// SUB_MEN_DIA: -1 dia (wrap al ultimo dia del mes)
// SUB_MAS_MES: +1 mes (ajusta dia si el nuevo mes tiene menos dias)
// SUB_MEN_MES: -1 mes (ajusta dia si el nuevo mes tiene menos dias)
SUB_MAS_DIA:
    PUSH R16
    PUSH R17
    PUSH R18
    PUSH ZL
    PUSH ZH
    LDS R16, dia_uni
    INC R16
    CPI R16, 10
    BRSH SMD_CARRY
    STS dia_uni, R16
    RJMP SMD_CHK
SMD_CARRY:
    LDI R16, 0
    STS dia_uni, R16
    LDS R16, dia_dec
    INC R16
    STS dia_dec, R16
SMD_CHK:
    LDS R16, dia_dec
    MOV R17, R16
    ADD R17, R16
    ADD R17, R17
    ADD R17, R17
    ADD R17, R16
    ADD R17, R16
    LDS R16, dia_uni
    ADD R17, R16
    LDS R16, mes_dec
    MOV R18, R16
    ADD R18, R16
    ADD R18, R18
    ADD R18, R18
    ADD R18, R16
    ADD R18, R16
    LDS R16, mes_uni
    ADD R18, R16
    LDI ZH, HIGH(DIAS_MES << 1)
    LDI ZL, LOW(DIAS_MES << 1)
    CLR R16
    ADD ZL, R18
    ADC ZH, R16
    LPM R16, Z
    CP R17, R16
    BRLO SMD_FIN
    BREQ SMD_FIN
    LDI R16, 0
    STS dia_dec, R16
    LDI R16, 1
    STS dia_uni, R16
SMD_FIN:
    POP ZH
    POP ZL
    POP R18
    POP R17
    POP R16
    RET

SUB_MEN_DIA:
    PUSH R16
    PUSH R17
    PUSH R18
    PUSH ZL
    PUSH ZH
    LDS R16, dia_dec
    MOV R17, R16
    ADD R17, R16
    ADD R17, R17
    ADD R17, R17
    ADD R17, R16
    ADD R17, R16
    LDS R16, dia_uni
    ADD R17, R16
    CPI R17, 1
    BREQ SMED_WRAP
    LDS R16, dia_uni
    CPI R16, 0
    BREQ SMED_BORROW
    DEC R16
    STS dia_uni, R16
    RJMP SMED_FIN
SMED_BORROW:
    LDI R16, 9
    STS dia_uni, R16
    LDS R16, dia_dec
    DEC R16
    STS dia_dec, R16
    RJMP SMED_FIN
SMED_WRAP:
    LDS R16, mes_dec
    MOV R18, R16
    ADD R18, R16
    ADD R18, R18
    ADD R18, R18
    ADD R18, R16
    ADD R18, R16
    LDS R16, mes_uni
    ADD R18, R16
    LDI ZH, HIGH(DIAS_MES << 1)
    LDI ZL, LOW(DIAS_MES << 1)
    CLR R16
    ADD ZL, R18
    ADC ZH, R16
    LPM R16, Z
    LDI R17, 0
SMED_DIV:
    CPI R16, 10
    BRLO SMED_DIV_FIN
    SUBI R16, 10
    INC R17
    RJMP SMED_DIV
SMED_DIV_FIN:
    STS dia_dec, R17
    STS dia_uni, R16
SMED_FIN:
    POP ZH
    POP ZL
    POP R18
    POP R17
    POP R16
    RET

SUB_MAS_MES:
    PUSH R16
    PUSH R17
    PUSH R18
    PUSH ZL
    PUSH ZH
    LDS R16, mes_uni
    INC R16
    CPI R16, 10
    BRSH SMM_CARRY
    STS mes_uni, R16
    RJMP SMM_CHK13
SMM_CARRY:
    LDI R16, 0
    STS mes_uni, R16
    LDS R16, mes_dec
    INC R16
    STS mes_dec, R16
SMM_CHK13:
    LDS R16, mes_dec
    CPI R16, 1
    BRNE SMM_CHK_DIA
    LDS R16, mes_uni
    CPI R16, 3
    BRLO SMM_CHK_DIA
    LDI R16, 0
    STS mes_dec, R16
    LDI R16, 1
    STS mes_uni, R16
SMM_CHK_DIA:
    RCALL AJUSTAR_DIA
    POP ZH
    POP ZL
    POP R18
    POP R17
    POP R16
    RET

SUB_MEN_MES:
    PUSH R16
    PUSH R17
    PUSH R18
    PUSH ZL
    PUSH ZH
    LDS R16, mes_uni
    CPI R16, 0
    BREQ SMN_BORROW
    DEC R16
    STS mes_uni, R16
    RJMP SMN_CHK0
SMN_BORROW:
    LDI R16, 9
    STS mes_uni, R16
    LDS R16, mes_dec
    DEC R16
    STS mes_dec, R16
SMN_CHK0:
    LDS R16, mes_dec
    CPI R16, 0
    BRNE SMN_CHK_DIA
    LDS R16, mes_uni
    CPI R16, 0
    BRNE SMN_CHK_DIA
    LDI R16, 1
    STS mes_dec, R16
    LDI R16, 2
    STS mes_uni, R16
SMN_CHK_DIA:
    RCALL AJUSTAR_DIA
    POP ZH
    POP ZL
    POP R18
    POP R17
    POP R16
    RET

//Recorta el dia al maximo del mes si es necesario
AJUSTAR_DIA:
    PUSH R16
    PUSH R17
    PUSH R18
    PUSH ZL
    PUSH ZH
    LDS R16, dia_dec
    MOV R17, R16
    ADD R17, R16
    ADD R17, R17
    ADD R17, R17
    ADD R17, R16
    ADD R17, R16
    LDS R16, dia_uni
    ADD R17, R16
    LDS R16, mes_dec
    MOV R18, R16
    ADD R18, R16
    ADD R18, R18
    ADD R18, R18
    ADD R18, R16
    ADD R18, R16
    LDS R16, mes_uni
    ADD R18, R16
    LDI ZH, HIGH(DIAS_MES << 1)
    LDI ZL, LOW(DIAS_MES << 1)
    CLR R16
    ADD ZL, R18
    ADC ZH, R16
    LPM R16, Z
    CP R17, R16
    BRLO AD_FIN
    BREQ AD_FIN
    LDI R17, 0
AD_DIV:
    CPI R16, 10
    BRLO AD_DIV_FIN
    SUBI R16, 10
    INC R17
    RJMP AD_DIV
AD_DIV_FIN:
    STS dia_dec, R17
    STS dia_uni, R16
AD_FIN:
    POP ZH
    POP ZL
    POP R18
    POP R17
    POP R16
    RET

/****************************************/
// ISR TIMER1 - CUENTA DE TIEMPO
/****************************************/

TK:
    PUSH R16
    IN R16, SREG
    PUSH R16
    PUSH R17

//----------------------------------------
// Parpadeo de puntos en modos config
//----------------------------------------

    LDS R16, modo
    CPI R16, MODO_CFG_H
    BREQ TK_TOGGLE
    CPI R16, MODO_CFG_F
    BREQ TK_TOGGLE
    RJMP TK_CONT
TK_TOGGLE:
    LDS R16, blink_cnt
    INC R16
    CPI R16, 1        //cada tick cambia estado
    BRSH TK_DO_TOGGLE
    STS blink_cnt, R16
    RJMP TK_CONT
TK_DO_TOGGLE:
    LDI R16, 0
    STS blink_cnt, R16
    LDS R16, blink_flag
    CPI R16, 1
    BRNE TK_BLINK_OFF
    LDI R16, 0
    RJMP TK_BLINK_SAVE
TK_BLINK_OFF:
    LDI R16, 1
TK_BLINK_SAVE:
    STS blink_flag, R16
TK_CONT:

//----------------------------------------
// En modos config el tiempo no avanza
//----------------------------------------

    LDS R16, modo
    CPI R16, MODO_CFG_H
    BRNE TK_CHK_F
    RJMP CHK_ALM_T
TK_CHK_F:
    CPI R16, MODO_CFG_F
    BRNE TK_CHK_A
    RJMP CHK_ALM_T
TK_CHK_A:
    CPI R16, MODO_CFG_A
    BRNE TK_CONTAR
    RJMP CHK_ALM_T
TK_CONTAR:

//----------------------------------------
// Incremento: segs - mins - horas
//----------------------------------------

    LDS R16, segs
    INC R16
    CPI R16, 60
    BRSH OVS
    STS segs, R16
    RJMP CHK_ALM_T

OVS:
    LDI R16, 0
    STS segs, R16
    LDS R16, min_uni
    INC R16
    CPI R16, 10
    BRSH OVMU
    STS min_uni, R16
    RJMP CHK_ALM_T

OVMU:
    LDI R16, 0
    STS min_uni, R16
    LDS R16, min_dec
    INC R16
    CPI R16, 6
    BRSH OVMD
    STS min_dec, R16
    RJMP CHK_ALM_T

OVMD:
    LDI R16, 0
    STS min_dec, R16
    LDS R16, hr_uni
    INC R16
    LDS R17, hr_dec
    CPI R17, 2
    BRNE CHK_HU
    CPI R16, 4
    BREQ R24H

CHK_HU:
    CPI R16, 10
    BRSH OVHU
    STS hr_uni, R16
    RJMP CHK_ALM_T

OVHU:
    LDI R16, 0
    STS hr_uni, R16
    LDS R16, hr_dec
    INC R16
    STS hr_dec, R16
    RJMP CHK_ALM_T

R24H:
    LDI R16, 0
    STS hr_uni, R16
    STS hr_dec, R16
    RCALL INC_DIA     //medianoche - avanzar fecha

//----------------------------------------
// Verificacion de alarma
//----------------------------------------

CHK_ALM_T:
    LDS R16, hr_dec
    LDS R17, ahr_dec
    CP R16, R17
    BRNE ALM_NO_MATCH
    LDS R16, hr_uni
    LDS R17, ahr_uni
    CP R16, R17
    BRNE ALM_NO_MATCH
    LDS R16, min_dec
    LDS R17, amin_dec
    CP R16, R17
    BRNE ALM_NO_MATCH
    LDS R16, min_uni
    LDS R17, amin_uni
    CP R16, R17
    BRNE ALM_NO_MATCH
    //Hora coincide: activar si no fue apagada este minuto
    LDS R16, alarma_snooze
    CPI R16, 1
    BREQ FTK
    LDI R16, 1
    STS alarma_flag, R16
    RJMP FTK

ALM_NO_MATCH:
    LDI R16, 0
    STS alarma_snooze, R16  //Limpiar snooze para el proximo minuto

FTK:
    POP R17
    POP R16
    OUT SREG, R16
    POP R16
    RETI

/****************************************/
// ISR TIMER0 - MUX DE DISPLAYS
/****************************************/

//0=DH 1=UH 2=DM 3=UM
RF:
    PUSH R16
    IN R16, SREG
    PUSH R16
    PUSH R17
    PUSH R18
    PUSH R19
    PUSH ZL
    PUSH ZH

    IN R16, PORTC
    ANDI R16, ~MASK_TRANS
    OUT PORTC, R16
    IN R16, PORTD
    ANDI R16, 0b10000000 
    OUT PORTD, R16

    LDS R17, disp_turno

//----------------------------------------
// Seleccionar que mostrar segun modo
//----------------------------------------

    LDS R16, modo
    CPI R16, MODO_CFG_A
    BREQ RF_ALM
    CPI R16, MODO_FECHA
    BRNE RF_CHK_CFGF
    RJMP RF_FECHA
RF_CHK_CFGF:
    CPI R16, MODO_CFG_F
    BRNE RF_HORA
    RJMP RF_FECHA

//----------------------------------------
// Hora (MODO_HORA y MODO_CFG_H)
//----------------------------------------

RF_HORA:
    CPI R17, 0
    BREQ RH0
    CPI R17, 1
    BREQ RH1
    CPI R17, 2
    BREQ RH2
    RJMP RH3
RH0: LDS R18, hr_dec
     LDI R19, (1<<TRANS_DH)
     RJMP SHOW
RH1: LDS R18, hr_uni
     LDI R19, (1<<TRANS_UH)
     RJMP SHOW
RH2: LDS R18, min_dec
     LDI R19, (1<<TRANS_DM)
     RJMP SHOW
RH3: LDS R18, min_uni
     LDI R19, (1<<TRANS_UM)
     RJMP SHOW

//----------------------------------------
// Alarma (MODO_CFG_A)
//----------------------------------------

RF_ALM:
    CPI R17, 0
    BREQ RA0
    CPI R17, 1
    BREQ RA1
    CPI R17, 2
    BREQ RA2
    RJMP RA3
RA0: LDS R18, ahr_dec
     LDI R19, (1<<TRANS_DH)
     RJMP SHOW
RA1: LDS R18, ahr_uni
     LDI R19, (1<<TRANS_UH)
     RJMP SHOW
RA2: LDS R18, amin_dec
     LDI R19, (1<<TRANS_DM)
     RJMP SHOW
RA3: LDS R18, amin_uni
     LDI R19, (1<<TRANS_UM)
     RJMP SHOW

//----------------------------------------
// Fecha (MODO_FECHA y MODO_CFG_F)
//----------------------------------------

RF_FECHA:
    CPI R17, 0
    BREQ RFE0
    CPI R17, 1
    BREQ RFE1
    CPI R17, 2
    BREQ RFE2
    RJMP RFE3
RFE0: LDS R18, dia_dec
      LDI R19, (1<<TRANS_DH)
      RJMP SHOW
RFE1: LDS R18, dia_uni
      LDI R19, (1<<TRANS_UH)
      RJMP SHOW
RFE2: LDS R18, mes_dec
      LDI R19, (1<<TRANS_DM)
      RJMP SHOW
RFE3: LDS R18, mes_uni
      LDI R19, (1<<TRANS_UM)

//----------------------------------------
//Buscar en Tabla
//----------------------------------------

SHOW:
    LDI ZH, HIGH(SEG7 << 1)
    LDI ZL, LOW(SEG7 << 1)
    CLR R16
    ADD ZL, R18
    ADC ZH, R16
    LPM R18, Z      

    IN R16, PORTD
    ANDI R16, 0b10000000  
    OR R18, R16
    OUT PORTD, R18
    IN R16, PORTC
    OR R16, R19
    OUT PORTC, R16
    INC R17
    CPI R17, 4
    BRLO GTXN
    LDI R17, 0
GTXN:
    STS disp_turno, R17
    POP ZH
    POP ZL
    POP R19
    POP R18
    POP R17
    POP R16
    OUT SREG, R16
    POP R16
    RETI

/****************************************/
// AVANCE DE FECHA 
/****************************************/

INC_DIA:
    PUSH R16
    PUSH R17
    PUSH R18
    PUSH ZL
    PUSH ZH
    LDS R16, dia_uni
    INC R16
    CPI R16, 10
    BRSH ID_CARRY
    STS dia_uni, R16
    RJMP ID_CHK
ID_CARRY:
    LDI R16, 0
    STS dia_uni, R16
    LDS R16, dia_dec
    INC R16
    STS dia_dec, R16
ID_CHK:
    LDS R16, dia_dec
    MOV R17, R16
    ADD R17, R16
    ADD R17, R17
    ADD R17, R17
    ADD R17, R16
    ADD R17, R16
    LDS R16, dia_uni
    ADD R17, R16
    LDS R16, mes_dec
    MOV R18, R16
    ADD R18, R16
    ADD R18, R18
    ADD R18, R18
    ADD R18, R16
    ADD R18, R16
    LDS R16, mes_uni
    ADD R18, R16
    LDI ZH, HIGH(DIAS_MES << 1)
    LDI ZL, LOW(DIAS_MES << 1)
    CLR R16
    ADD ZL, R18
    ADC ZH, R16
    LPM R16, Z
    CP R17, R16
    BREQ ID_FIN
    BRLO ID_FIN
    LDI R16, 0
    STS dia_dec, R16
    LDI R16, 1
    STS dia_uni, R16
    LDS R16, mes_uni
    INC R16
    CPI R16, 10
    BRSH ID_MES_CARRY
    STS mes_uni, R16
    RJMP ID_CHK_M13
ID_MES_CARRY:
    LDI R16, 0
    STS mes_uni, R16
    LDS R16, mes_dec
    INC R16
    STS mes_dec, R16
ID_CHK_M13:
    LDS R16, mes_dec
    CPI R16, 1
    BRNE ID_FIN
    LDS R16, mes_uni
    CPI R16, 3
    BRLO ID_FIN
    LDI R16, 0
    STS mes_dec, R16
    LDI R16, 1
    STS mes_uni, R16
ID_FIN:
    POP ZH
    POP ZL
    POP R18
    POP R17
    POP R16
    RET

/****************************************/
// TABLAS
/****************************************/

DIAS_MES:
    .DB  0, 31   // (1) enero
    .DB 28, 31   // (2) feb y (3) marzo
    .DB 30, 31   // (4) abril y (5) mayo
    .DB 30, 31   // (6) junio y (7) julio
    .DB 31, 30   // (8) ago y (9) sep 
    .DB 31, 30   // (10) oct y (11) nov  
    .DB 31,  0   // (12) dic  


SEG7:
    .DB 0b00111111, 0b00001010  // 0, 1
    .DB 0b01011101, 0b01011011  // 2, 3
    .DB 0b01101010, 0b01110011  // 4, 5
    .DB 0b01110111, 0b00011010  // 6, 7
    .DB 0b01111111, 0b01111011  // 8, 9
