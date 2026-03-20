/****************************************/
// Reloj.asm
// Creado:
// Autor:
// Descripcion: Reloj digital con displays 7 segmentos multiplexados
//              Modos: Hora, Fecha, Config.Hora, Config.Fecha, Config.Alarma
//              Arduino Nano - ATMega328P
/****************************************/

.include "M328PDEF.inc"

/****************************************/
// ENTRADAS Y SALIDAS
/****************************************/

// Segmentos 7-seg - PORTD (PD0-PD6 salidas)
.equ SEG_A     = PD4
.equ SEG_B     = PD3
.equ SEG_C     = PD1   // TX - desconectar al programar
.equ SEG_D     = PD0   // RX - desconectar al programar
.equ SEG_E     = PD2
.equ SEG_F     = PD5
.equ SEG_G     = PD6

// Boton en PORTD
.equ BTN_MINS_UP = PD7 // sube min      - D7 (entrada con pullup)

// LEDs - PORTB
.equ LED_FECHA  = PB0  // LED modo fecha - D8
.equ LED_PTS_UP = PB2  // punto arriba  - D10
.equ LED_PTS_DN = PB3  // punto abajo   - D11
.equ LED_ALARM  = PB4  // LED alarma    - D12

// Botones - PORTB
.equ BTN_MINS_DN = PB1 // baja min      - D9
.equ BTN_HRS_UP  = PB5 // sube hr / apaga alarma - D13

// Botones - PORTC
.equ BTN_HRS_DN  = PC0 // baja hr       - A0
.equ BTN_MODO    = PC1 // cambia modo / apaga alarma - A1

// Transistores MUX - PORTC
.equ TRANS_DH = PC4    // decenas horas
.equ TRANS_UH = PC5    // unidades horas
.equ TRANS_DM = PC2    // decenas minutos
.equ TRANS_UM = PC3    // unidades minutos

/****************************************/
// MASCARAS DE PUERTOS
/****************************************/

// PORTD: PD7=entrada(BTN_MINS_UP) | PD0-PD6=salidas(segmentos)
.equ DIR_PORTD  = 0b01111111
// Pullup en PD7 para BTN_MINS_UP, segmentos en 0
.equ PULLUP_D   = 0b10000000

// PORTB: sal: PB0(LED_FECHA),PB2,PB3,PB4 | ent: PB1,PB5
.equ DIR_PORTB  = 0b00011101
// LED_FECHA apagado al inicio | LEDs dos puntos ON | pullups PB1,PB5
.equ INIT_PORTB = 0b00100010  // LEDs dos puntos OFF al inicio + pullups PB1,PB5

.equ DIR_PORTC  = 0b00111100  // sal: PC2-PC5 | ent: PC0,PC1
.equ PULLUP_C   = 0b00000011  // pullups BTN_HRS_DN y BTN_MODO
.equ MASK_TRANS = 0b00111100  // apaga los 4 transistores de un golpe

/****************************************/
// MODOS
/****************************************/

.equ MODO_HORA  = 0  // muestra hora
.equ MODO_FECHA = 1  // muestra fecha
.equ MODO_CFG_H = 2  // configura hora
.equ MODO_CFG_F = 3  // configura fecha
.equ MODO_CFG_A = 4  // configura alarma

/****************************************/
// CONFIGURACION TIMERS
/****************************************/

// Timer1 - cuenta el tiempo (1 segundo exacto)
// F_CPU=16MHz | Prescaler=1024 | OCR1A = 16000000/1024 - 1 = 15624
.equ TIMER1_TOP = 15624

// Timer0 - multiplexado displays (~1ms por display)
// F_CPU=16MHz | Prescaler=64 | OCR0A = 16000000/64/1000 - 1 = 249
.equ TIMER0_TOP = 249

/****************************************/
// VARIABLES EN SRAM
/****************************************/

.dseg
.org SRAM_START

// Tiempo
segs:    .byte 1  // segundos (0-59)
min_uni: .byte 1  // minutos unidades (0-9)
min_dec: .byte 1  // minutos decenas (0-5)
hr_uni:  .byte 1  // horas unidades (0-9)
hr_dec:  .byte 1  // horas decenas (0-2)

// Display
disp_turno: .byte 1  // display activo en el MUX (0-3)
modo:       .byte 1  // modo actual (0-4)
blink_flag: .byte 1  // estado parpadeo puntos: 0=apagado 1=encendido
blink_cnt:  .byte 1  // contador ticks para la velocidad de parpadeo

// Alarma
alarma_flag:   .byte 1  // 0=apagada 1=sonando
alarma_snooze: .byte 1  // 1=ya se apago este minuto, no volver a disparar
amin_uni: .byte 1  // alarma minutos unidades
amin_dec: .byte 1  // alarma minutos decenas
ahr_uni:  .byte 1  // alarma horas unidades
ahr_dec:  .byte 1  // alarma horas decenas

// Fecha
dia_uni: .byte 1  // dia unidades
dia_dec: .byte 1  // dia decenas
mes_uni: .byte 1  // mes unidades
mes_dec: .byte 1  // mes decenas

/****************************************/
// VECTORES DE INTERRUPCION
/****************************************/

.cseg

.org 0x0000
    JMP INI       // reset
.org 0x0016
    JMP TK        // Timer1 COMPA -> cuenta el tiempo
.org 0x001C
    JMP RF        // Timer0 COMPA -> multiplexado

/****************************************/
// INICIALIZACION
/****************************************/

INI:
    // Pila
    LDI R16, LOW(RAMEND)
    OUT SPL, R16
    LDI R16, HIGH(RAMEND)
    OUT SPH, R16

    // PORTD - segmentos (PD0-PD6 salidas) + BTN_MINS_UP (PD7 entrada con pullup)
    LDI R16, DIR_PORTD
    OUT DDRD, R16
    LDI R16, PULLUP_D       // activa pullup en PD7, segmentos en 0
    OUT PORTD, R16

    // PORTB - LED_FECHA, LEDs dos puntos, LED alarma, botones
    LDI R16, DIR_PORTB
    OUT DDRB, R16
    LDI R16, INIT_PORTB
    OUT PORTB, R16

    // PORTC - transistores MUX, botones
    LDI R16, DIR_PORTC
    OUT DDRC, R16
    LDI R16, PULLUP_C
    OUT PORTC, R16

    // Variables de tiempo a 0
    LDI R16, 0
    STS segs,    R16
    STS min_uni, R16
    STS min_dec, R16
    STS hr_uni,  R16
    STS hr_dec,  R16

    // Variables de display a 0
    STS disp_turno, R16
    STS modo,       R16
    STS blink_cnt,  R16
    LDI R16, 1
    STS blink_flag, R16   // parpadeo arranca encendido

    // Alarma: hora imposible (25:00) para que no dispare sola al inicio
    LDI R16, 0
    STS alarma_flag,   R16
    STS alarma_snooze, R16
    STS amin_uni,      R16
    STS amin_dec,      R16
    LDI R16, 5
    STS ahr_uni, R16   // hr uni = 5  -> 25:xx (imposible)
    LDI R16, 2
    STS ahr_dec, R16   // hr dec = 2  -> 25:00

    // Fecha inicial: 20/03
    LDI R16, 0
    STS dia_uni, R16
    LDI R16, 2
    STS dia_dec, R16   // dia dec = 2
    LDI R16, 3
    STS mes_uni, R16   // mes = 03
    LDI R16, 0
    STS mes_dec, R16

//----------------------------------------
// Timer0 - MUX displays (1ms)
//----------------------------------------

    LDI R16, (1<<WGM01)              // CTC
    OUT TCCR0A, R16
    LDI R16, TIMER0_TOP              // top = 249
    OUT OCR0A, R16
    LDI R16, (1<<CS01)|(1<<CS00)    // prescaler 64
    OUT TCCR0B, R16
    LDI R16, (1<<OCIE0A)             // habilitar interrupcion COMPA
    STS TIMSK0, R16

//----------------------------------------
// Timer1 - cuenta de tiempo (1 segundo)
//----------------------------------------

    LDI R16, 0x00
    STS TCCR1A, R16
    LDI R16, HIGH(TIMER1_TOP)        // escribir HIGH primero (buf interno AVR)
    STS OCR1AH, R16
    LDI R16, LOW(TIMER1_TOP)
    STS OCR1AL, R16
    LDI R16, (1<<OCIE1A)             // habilitar interrupcion COMPA
    STS TIMSK1, R16
    LDI R16, (1<<WGM12)|(1<<CS12)|(1<<CS10)  // CTC + prescaler 1024
    STS TCCR1B, R16

    SEI  // interrupciones globales ON

/****************************************/
// LOOP PRINCIPAL
/****************************************/

LOOP:
//----------------------------------------
// LEDs de los dos puntos
//----------------------------------------

    // En modos config parpadean (blink_flag lo maneja TK)
    // En el resto siempre encendidos
    LDS R16, modo
    CPI R16, MODO_CFG_H
    BREQ LOOP_BLINK_CHK
    CPI R16, MODO_CFG_F
    BREQ LOOP_BLINK_CHK
    SBI PORTB, LED_PTS_UP
    SBI PORTB, LED_PTS_DN
    RJMP SKIP_LEDS_ON
LOOP_BLINK_CHK:
    LDS R16, blink_flag
    CPI R16, 1
    BRNE LOOP_BLINK_OFF
    SBI PORTB, LED_PTS_UP
    SBI PORTB, LED_PTS_DN
    RJMP SKIP_LEDS_ON
LOOP_BLINK_OFF:
    CBI PORTB, LED_PTS_UP
    CBI PORTB, LED_PTS_DN
SKIP_LEDS_ON:

//----------------------------------------
// LED fecha (D8/PB0) - encendido solo en modo Fecha
//----------------------------------------

    LDS R16, modo
    CPI R16, MODO_FECHA
    BRNE LED_FECHA_OFF
    SBI PORTB, LED_FECHA
    RJMP LED_FECHA_DONE
LED_FECHA_OFF:
    CBI PORTB, LED_FECHA
LED_FECHA_DONE:

//----------------------------------------
// LED alarma - refleja el flag en todo momento
//----------------------------------------

    LDS R16, alarma_flag
    CPI R16, 1
    BRNE LED_ALARM_OFF
    SBI PORTB, LED_ALARM
    RJMP CHK_D13
LED_ALARM_OFF:
    CBI PORTB, LED_ALARM

//----------------------------------------
// BTN_HRS_UP (D13) - apaga alarma si esta sonando
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
// BTN_MODO (A1) - apaga alarma si suena, sino cambia modo
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
// Botones de ajuste - solo activos en modos config
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

// W20MS - 20ms debounce de bajada (press)
// W80MS - 80ms debounce de subida (release)
// Ambas preservan todos los registros
W20MS:
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
    RET

W80MS:
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
    RET

/****************************************/
// CAMBIO DE MODO
/****************************************/

// Ciclo: Hora -> Fecha -> Cfg.Hora -> Cfg.Fecha -> Cfg.Alarma -> Hora
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

// Patron de cada boton:
//   1. SBRC detecta press (pin en bajo)
//   2. W20MS debounce bajada
//   3. Ejecutar accion
//   4. Esperar soltar (loop SBRS)
//   5. W80MS debounce subida
//   6. RET

//----------------------------------------
// Config Hora: BTN_MINS_UP/DN = minutos | BTN_HRS_UP/DN = horas
// BTN_MINS_UP en PIND (PD7) | BTN_MINS_DN y BTN_HRS_UP en PINB | BTN_HRS_DN en PINC
//----------------------------------------

POLL_BTNS_H:
    IN R16, PIND              // leer PORTD para BTN_MINS_UP (PD7)
    IN R17, PINC
    SBRC R16, BTN_MINS_UP
    RJMP PH_NO_MINSUP
    RCALL W20MS
    RCALL SUB_MAS
PH_REL_MINSUP:
    IN R16, PIND
    SBRS R16, BTN_MINS_UP
    RJMP PH_REL_MINSUP
    RCALL W80MS
    RET

PH_NO_MINSUP:
    IN R16, PINB
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
    SBRC R17, BTN_HRS_DN
    RET
    RCALL W20MS
    RCALL SUB_MEN_H
PH_REL_HRSDN:
    IN R17, PINC
    SBRS R17, BTN_HRS_DN
    RJMP PH_REL_HRSDN
    RCALL W80MS
    RET

//----------------------------------------
// Config Fecha: BTN_MINS_UP/DN = dia | BTN_HRS_UP/DN = mes
//----------------------------------------

POLL_BTNS_F:
    IN R16, PIND              // BTN_MINS_UP en PD7
    IN R17, PINC
    SBRC R16, BTN_MINS_UP
    RJMP PF_NO_MINSUP
    RCALL W20MS
    RCALL SUB_MAS_DIA
PF_REL_MINSUP:
    IN R16, PIND
    SBRS R16, BTN_MINS_UP
    RJMP PF_REL_MINSUP
    RCALL W80MS
    RET

PF_NO_MINSUP:
    IN R16, PINB
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
    SBRC R17, BTN_HRS_DN
    RET
    RCALL W20MS
    RCALL SUB_MEN_MES
PF_REL_HRSDN:
    IN R17, PINC
    SBRS R17, BTN_HRS_DN
    RJMP PF_REL_HRSDN
    RCALL W80MS
    RET

//----------------------------------------
// Config Alarma: BTN_MINS_UP/DN = min alarma | BTN_HRS_UP/DN = hr alarma
//----------------------------------------

POLL_BTNS_A:
    IN R16, PIND              // BTN_MINS_UP en PD7
    IN R17, PINC
    SBRC R16, BTN_MINS_UP
    RJMP PA_NO_MINSUP
    RCALL W20MS
    RCALL SUB_MAS_A
PA_REL_MINSUP:
    IN R16, PIND
    SBRS R16, BTN_MINS_UP
    RJMP PA_REL_MINSUP
    RCALL W80MS
    RET

PA_NO_MINSUP:
    IN R16, PINB
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

// SUB_MAS: +1 min | SUB_MEN: -1 min | wrap 00<->59
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

// SUB_MAS_H: +1 hr | SUB_MEN_H: -1 hr | wrap 00<->23
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

// SUB_MAS_A: +1 min | SUB_MEN_A: -1 min | wrap 00<->59
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

// SUB_MAS_AH: +1 hr | SUB_MEN_AH: -1 hr | wrap 00<->23
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

// Recorta el dia al maximo del mes si es necesario
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

// Se ejecuta cada 1 segundo
// Cadena: segs -> min_uni -> min_dec -> hr_uni -> hr_dec -> INC_DIA (a medianoche)
// En modos config el tiempo NO avanza (solo parpadea)
// Al final siempre verifica la alarma
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
    CPI R16, 1        // cada tick cambia estado (~1Hz)
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
// Incremento en cascada: segs -> mins -> horas
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
    RCALL INC_DIA     // medianoche -> avanzar fecha

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
    // hora coincide: activar si no fue apagada este minuto
    LDS R16, alarma_snooze
    CPI R16, 1
    BREQ FTK
    LDI R16, 1
    STS alarma_flag, R16
    RJMP FTK

ALM_NO_MATCH:
    LDI R16, 0
    STS alarma_snooze, R16  // limpiar snooze para el proximo minuto

FTK:
    POP R17
    POP R16
    OUT SREG, R16
    POP R16
    RETI

/****************************************/
// ISR TIMER0 - MULTIPLEXADO DE DISPLAYS
/****************************************/

// Se ejecuta cada ~1ms
// Rota entre los 4 displays: 0=DH 1=UH 2=DM 3=UM
// Muestra hora, fecha o alarma segun el modo actual
RF:
    PUSH R16
    IN R16, SREG
    PUSH R16
    PUSH R17
    PUSH R18
    PUSH R19
    PUSH ZL
    PUSH ZH

    // Anti-ghosting: apagar transistores antes de cambiar
    // PORTD: apagar segmentos (PD0-PD6), preservar PD7 (pullup BTN_MINS_UP)
    IN R16, PORTC
    ANDI R16, ~MASK_TRANS
    OUT PORTC, R16
    IN R16, PORTD
    ANDI R16, 0b10000000   // preservar PD7, apagar segmentos PD0-PD6
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
// Fecha (MODO_FECHA y MODO_CFG_F) - formato DD/MM
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
// Buscar patron en tabla y encender display
//----------------------------------------

SHOW:
    LDI ZH, HIGH(SEG7 << 1)
    LDI ZL, LOW(SEG7 << 1)
    CLR R16
    ADD ZL, R18
    ADC ZH, R16
    LPM R18, Z        // R18 = patron de segmentos para el digito
    // OR con PORTD preservando PD7 (pullup de BTN_MINS_UP)
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
// AVANCE DE FECHA (medianoche)
/****************************************/

// Incrementa dia, cambia de mes si corresponde
// Usa DIAS_MES para saber cuantos dias tiene cada mes
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
// TABLAS EN FLASH
/****************************************/

// Dias por mes 2026 (no bisiesto, febrero = 28 dias)
// Indexada 1-12, posicion 0 = dummy
// En pares para evitar byte de padding del ensamblador
DIAS_MES:
    .DB  0, 31   // [0] dummy | [1] enero   = 31
    .DB 28, 31   // [2] feb   = 28 | [3] marzo  = 31
    .DB 30, 31   // [4] abril = 30 | [5] mayo   = 31
    .DB 30, 31   // [6] junio = 30 | [7] julio  = 31
    .DB 31, 30   // [8] ago   = 31 | [9] sep    = 30
    .DB 31, 30   // [10] oct  = 31 | [11] nov   = 30
    .DB 31,  0   // [12] dic  = 31 | [13] padding

// Patrones 7-segmentos para digitos 0-9
// Mapeo pines: PD4=A PD3=B PD1=C PD0=D PD2=E PD5=F PD6=G
// bit: 7  6  5  4  3  2  1  0
//      -  G  F  A  B  E  C  D
// En pares para evitar byte de padding del ensamblador
SEG7:
    .DB 0b00111111, 0b00001010  // 0, 1
    .DB 0b01011101, 0b01011011  // 2, 3
    .DB 0b01101010, 0b01110011  // 4, 5
    .DB 0b01110111, 0b00011010  // 6, 7
    .DB 0b01111111, 0b01111011  // 8, 9
/****************************************/