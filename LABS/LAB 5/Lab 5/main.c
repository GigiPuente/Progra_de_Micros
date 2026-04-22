/*
 * Lab5.c
 *
 * Created:
 * Author:
 * Description: 
 */
/****************************************/
// Encabezado (Libraries)
#include <avr/io.h>
#include <avr/interrupt.h>
#include "pwm1.h"
#include "pwm2.h"

/****************************************/
// Function prototypes
void iniciarADC(void);
void iniciarTimer0(void);
void cambiarADC(unsigned char nuevoADC);
unsigned char mapLED(unsigned int valor);

/****************************************/
// Variables globales
volatile unsigned int potServo1 = 0;
volatile unsigned int potServo2 = 0;
volatile unsigned int potLED = 0;
volatile unsigned char brilloLED = 0;
volatile unsigned char canalADC = 2;

/****************************************/
// Main Function
int main(void)
{
    cli(); //Desactivar interrupciones

    DDRD |= 0b00000100; //D2 salida
    PORTD &= 0b11111011; //LED apagado

    pwm1_init(); //Timer 1
    pwm2_init(); //Timer 2
    iniciarTimer0(); //Timer 0
    iniciarADC(); //Iniciar ADC

    sei(); //Activar interrupciones

    while (1)
    {
    }
}

/****************************************/
// NON-Interrupt subroutines
void iniciarTimer0(void)
{
    TCCR0A = 0; //Clear
    TCCR0B = 0;

    TCCR0A |= (1 << WGM01); //Modo CTC
    TCCR0B |= (1 << CS01); //Prescaler 8
    OCR0A = 249; //125 us
    TIMSK0 |= (1 << OCIE0A); //Interrupción
}

void iniciarADC(void)
{
    ADMUX = 0; //Clear
    ADCSRA = 0;             
    ADCSRB = 0;            

    ADMUX |= (1 << REFS0); //AVcc
    cambiarADC(2); //Inicia A2

    DIDR0 |= 0b00001110; //A3 A2 A1

    ADCSRA |= (1 << ADEN); //ADC on
    ADCSRA |= (1 << ADIE); //Interrupción ADC
    ADCSRA |= (1 << ADPS2); //Prescaler 128
    ADCSRA |= (1 << ADPS1); 
    ADCSRA |= (1 << ADPS0); 

    ADCSRA |= (1 << ADSC); //Empezar
}

void cambiarADC(unsigned char nuevoCanal)
{
    ADMUX &= 0xF0; //Borra canal
    ADMUX |= nuevoCanal; //Nuevo canal
}

unsigned char mapLED(unsigned int valor)
{
    unsigned char brillo;

    if (valor > 1023)
    {
        valor = 1023; //Máximo
    }

    brillo = (unsigned char)(((unsigned long)valor * 64) / 1023); //0 a 64

    return brillo;
}

/****************************************/
// Interrupt routines
ISR(ADC_vect)
{
    if (canalADC == 2) //Leer A2
    {
        potServo1 = ADC; //Guardar dato
        pwm1_servo1(pwm1_mapear(potServo1)); //Mover servo D9
        canalADC = 1; //A1
        cambiarADC(1);
    }
    else
    {
        if (canalADC == 1) //Leer A1
        {
            potServo2 = ADC; //Guardar dato
            pwm1_servo2(pwm1_mapear(potServo2)); //Mover servo D10
            pwm2_servo(pwm2_mapear(potServo2)); //Mover PWM2
            canalADC = 3; //A3
            cambiarADC(3);
        }
        else
        {
            potLED = ADC; //Guardar dato
            brilloLED = mapLED(potLED); //Brillo LED
            canalADC = 2; //Regresar a A2
            cambiarADC(2);
        }
    }

    ADCSRA |= (1 << ADSC); //Otra lectura
}

ISR(TIMER0_COMPA_vect)
{
    static unsigned char cuenta = 0;

    if (cuenta < brilloLED) //Encender LED
    {
        PORTD |= 0b00000100;
    }
    else
    {
        PORTD &= 0b11111011;
    }

    cuenta++;

    if (cuenta >= 64)
    {
        cuenta = 0;
    }
}
