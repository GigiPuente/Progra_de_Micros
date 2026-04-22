#ifndef PWM2_H
#define PWM2_H

#include <avr/io.h>

#ifndef F_CPU
#define F_CPU 16000000UL
#endif

void pwm2_init(void);
void pwm2_servo(unsigned int microsegundos);
unsigned int pwm2_mapear(unsigned int adc);

#endif
