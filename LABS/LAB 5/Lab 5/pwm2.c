/*
 * pwm2.c
 *
 * Created:
 * Author:
 * Description: 
 */
/****************************************/
// Encabezado (Libraries)
#include "pwm2.h"

/****************************************/
// Function prototypes
unsigned int limitarPulso2(unsigned int valor);
unsigned char convertirTimer2(unsigned int valor);

/****************************************/
// NON-Interrupt subroutines
void pwm2_init(void)
{
    DDRB |= 0b00001000; //D11 salida
    DDRD |= 0b00001000; //D3 salida

    TCCR2A = 0; //Clear Timer
    TCCR2B = 0;

    TCCR2A |= (1 << COM2A1); //PWM A
    TCCR2A |= (1 << COM2B1); //PWM B
    TCCR2A |= (1 << WGM21); //Fast PWM
    TCCR2A |= (1 << WGM20); //Fast PWM

    TCCR2B |= (1 << CS22); //Prescaler 1024
    TCCR2B |= (1 << CS21);
    TCCR2B |= (1 << CS20);   

    OCR2A = 24; //Centro
    OCR2B = 24; 
}

void pwm2_servo(unsigned int usegundos)
{
    unsigned char numero;

    usegundos = limitarPulso2(usegundos); 
    numero = convertirTimer2(usegundos); //Guardar en Timer

    OCR2A = numero; //D11
    OCR2B = numero; //D3
}

unsigned int pwm2_mapear(unsigned int adc)
{
    unsigned int pulso;

    if (adc > 1023)
    {
        adc = 1023; //Máximo
    }

    pulso = 500 + (((unsigned long)adc * 2000) / 1023); //500 a 2500

    return pulso;
}

unsigned int limitarPulso2(unsigned int valor)
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

unsigned char convertirTimer2(unsigned int valor)
{
    unsigned char numero;

    numero = (unsigned char)((valor + 32) / 64); //64 us

    if (numero < 8)
    {
        numero = 8; //Mínimo
    }

    if (numero > 39)
    {
        numero = 39; //Máximo
    }

    return numero;
}
