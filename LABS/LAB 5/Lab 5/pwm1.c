/*
 * pwm1.c
 *
 * Created:
 * Author:
 * Description:
 */
/****************************************/
// Encabezado (Libraries)
#include "pwm1.h"

/****************************************/
// Function prototypes
unsigned int limitarPulso1(unsigned int valor);

/****************************************/
// NON-Interrupt subroutines
void pwm1_init(void)
{
    DDRB |= 0b00000110; //D9 y D10

    TCCR1A = 0; //Clear timer
    TCCR1B = 0;              

    TCCR1A |= (1 << COM1A1); //PWM A
    TCCR1A |= (1 << COM1B1); //PWM B
    TCCR1A |= (1 << WGM11); //Modo 14

    TCCR1B |= (1 << WGM13); //Modo 14
    TCCR1B |= (1 << WGM12); //Modo 14
    TCCR1B |= (1 << CS11); //Prescaler 8

    ICR1 = 39999; //20ms
    OCR1A = 0; //Centro
    OCR1B = 0; 
}

void pwm1_servo1(unsigned int usegundos)
{
    usegundos = limitarPulso1(usegundos); //Valor
    OCR1A = usegundos * 2; //D9
}

void pwm1_servo2(unsigned int usegundos)
{
    usegundos = limitarPulso1(usegundos); //Valor
    OCR1B = usegundos * 2; //D10
}

unsigned int pwm1_mapear(unsigned int adc)
{
    unsigned int pulso;

    if (adc > 1023)
    {
        adc = 1023; //Máximo
    }

    pulso = 500 + (((unsigned long)adc * 2000) / 1023); //500 a 2500

    return pulso;
}

unsigned int limitarPulso1(unsigned int valor)
{
    if (valor < 500)
    {
        valor = 500; //Mínimo
    }

    if (valor > 2500)
    {
        valor = 2500; //Máximo
    }

    return valor;
}
