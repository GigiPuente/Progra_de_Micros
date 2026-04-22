#ifndef PWM1_H
#define PWM1_H

#include <avr/io.h>

#ifndef F_CPU
#define F_CPU 16000000UL
#endif

void pwm1_init(void);
void pwm1_servo1(unsigned int microsegundos);
void pwm1_servo2(unsigned int microsegundos);
unsigned int pwm1_mapear(unsigned int adc);

#endif
