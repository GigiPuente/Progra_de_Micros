/*
 * LAB 4.c
 *
 * Created:
 * Author:
 * Description:
 */

/****************************************/
// Encabezado (Libraries)

#define F_CPU 16000000UL

#include <avr/io.h>
#include <util/delay.h>

#define ANTIREBOTE_MS 25

// Transistores de multiplexado
#define DISPLAY_IZQ PC2
#define DISPLAY_DER PC5
#define LEDS_MUX PB0

// LEDs directos
#define LED_ALARMA PB1
#define LED8 PB2

// Cambiar a 1 si el LED de alarma es activo en bajo
#define LED_ALARMA_ACTIVO_BAJO 0

/****************************************/
// Function prototypes

void config_pines(void);
void config_adc(void);
void show_contador(void);
unsigned char leer_pot(void);
unsigned char numero_7seg(unsigned char numero);
void displays_off(void);
void F5_ADC_hex(void);
void show_ADC_hex(void);
void revisar_botones(void);
void comparar_adc_contador(void);
void led_alarma_off(void);
void led_alarma_on(void);

/****************************************/
// Main Function

unsigned char contador = 0;
unsigned char lectura = 0;
unsigned char high = 0;
unsigned char low = 0;
unsigned char segmentos = 0;
unsigned char leds_contador = 0;
unsigned char boton_inc_on = 1;
unsigned char boton_dec_on = 1;

int main(void)
{
	config_pines();
	config_adc();
	show_contador();

	while (1)
	{
		//Leer ADC y separar en dos dígitos hex
		F5_ADC_hex();
		//Revisar botones de INC y DEC
		revisar_botones();
		//Comparar ADC con contador para LED de alarma
		comparar_adc_contador();
		//MUX
		show_ADC_hex();
	}
}

/****************************************/
// NON-Interrupt subroutines

void config_pines(void)
{
	//PORTD salida para segmentos
	DDRD = 0b01111111;
	PORTD = 0b00000000;

	//PB0 = transistor 8 LEDs
	//PB1 = LED alarma
	//PB2 = LED8 directo
	DDRB = 0b00000111;

	//Apagar PB0-PB2
	PORTB = 0b00000000;

	//Dejar LED alarma apagado al iniciar
	led_alarma_off();

	//PC5 = display derecho
	//PC2 = display izquierdo
	//PC4, PC3 y PC0 entrada
	DDRC = 0b00100100;
	
	//Pull-up en PC4 y PC3
	PORTC = 0b00011000;
}

void config_adc(void)
{
	//REFS0 = 1, ADLAR = 1
	ADMUX = 0b01100000;

	//ADEN = 1 y prescaler = 128
	ADCSRA = 0b10000111;

	//Desactivar entrada digital en A0
	DIDR0 = 0b00000001;
}

void show_contador(void)
{
	//Apagar patrón anterior
	leds_contador = 0b00000000;

	//LED1 = E
	if (contador & 0x01)
	{
		leds_contador |= 0b00000100;
	}

	//LED2 = D
	if (contador & 0x02)
	{
		leds_contador |= 0b00000001;
	}

	//LED3 = C
	if (contador & 0x04)
	{
		leds_contador |= 0b00000010;
	}

	//LED4 = G
	if (contador & 0x08)
	{
		leds_contador |= 0b01000000;
	}

	//LED5 = F
	if (contador & 0x10)
	{
		leds_contador |= 0b00100000;
	}

	//LED6 = A
	if (contador & 0x20)
	{
		leds_contador |= 0b00010000;
	}

	//LED7 = B
	if (contador & 0x40)
	{
		leds_contador |= 0b00001000;
	}

	//LED8 = D10 directo
	if (contador & 0x80)
	{
		PORTB |= (1 << LED8);
	}
	else
	{
		PORTB &= ~(1 << LED8);
	}
}

unsigned char leer_pot(void)
{
	//Conversión ADC
	ADCSRA |= (1 << ADSC);

	while (ADCSRA & (1 << ADSC))
	{
	}

	//Devolver HIGH (8 bits)
	return ADCH;
}

unsigned char numero_7seg(unsigned char numero)
{
	switch (numero)
	{
		//Números
		case 0:
			return 0b00111111;
		case 1:
			return 0b00001010;
		case 2:
			return 0b01011101;
		case 3:
			return 0b01011011;
		case 4:
			return 0b01101010;
		case 5:
			return 0b01110011;
		case 6:
			return 0b01110111;
		case 7:
			return 0b00011010;
		case 8:
			return 0b01111111;
		case 9:
			return 0b01111011;
		//Letras hex A-F
		case 10:
			return 0b01111110;
		case 11:
			return 0b01100111;
		case 12:
			return 0b00110101;
		case 13:
			return 0b01001111;
		case 14:
			return 0b01110101;
		case 15:
			return 0b01110100;
		default:
			return 0;
	}
}

void displays_off(void)
{
	//Apagar displays y banco de LEDs
	PORTC &= ~(1 << DISPLAY_IZQ);
	PORTC &= ~(1 << DISPLAY_DER);
	PORTB &= ~(1 << LEDS_MUX);
}

void F5_ADC_hex(void)
{
	//Leer ADC
	lectura = leer_pot();
	//Separar HIGH y LOW
	high = (lectura >> 4) & 0x0F;
	low = lectura & 0x0F;
}

void show_ADC_hex(void)
{
/************DISPLAY IZQUIERDO************/
	//Apagar antes de cambiar
	displays_off();
	
	//Mostrar HIGH
	segmentos = numero_7seg(high);
	
	//Cargar segmentos
	PORTD = segmentos;
	
	//Encender display izquierdo = A2
	PORTC |= (1 << DISPLAY_IZQ);
	_delay_ms(4);

/************DISPLAY DERECHO************/
	//Apagar antes de cambiar
	displays_off();
	
	//Mostrar LOW
	segmentos = numero_7seg(low);
	
	//Cargar segmentos
	PORTD = segmentos;
	
	//Encender display derecho = A5
	PORTC |= (1 << DISPLAY_DER);
	_delay_ms(4);

/************8 LEDs************/
	//Apagar antes de cambiar
	displays_off();

	//Cargar patrón del contador
	PORTD = leds_contador;

	//Encender transistor de los 8 LEDs = D8
	PORTB |= (1 << LEDS_MUX);
	_delay_ms(4);

	//Apagar para el siguiente ciclo
	displays_off();
}

void revisar_botones(void)
{
	//Leer boton INC
	if (((PINC & (1 << PINC3)) == 0) && (boton_inc_on != 0))
	{
		_delay_ms(ANTIREBOTE_MS);

		//Leerlo otra vez
		if ((PINC & (1 << PINC3)) == 0)
		{
			//INC
			contador++;
			show_contador();
			//Esperar a que se libere para aceptar otra pulsación
			boton_inc_on = 0;
		}
	}
	else if ((PINC & (1 << PINC3)) != 0)
	{
		//Botón liberado
		boton_inc_on = 1;
	}

	//Leer boton DEC
	if (((PINC & (1 << PINC4)) == 0) && (boton_dec_on != 0))
	{
		_delay_ms(ANTIREBOTE_MS);

		//Leerlo otra vez
		if ((PINC & (1 << PINC4)) == 0)
		{
			//DEC
			contador--;
			show_contador();
			//Esperar a que se suelte para aceptar otra pulsación
			boton_dec_on = 0;
		}
	}
	else if ((PINC & (1 << PINC4)) != 0)
	{
		//Botón liberado
		boton_dec_on = 1;
	}
}

void comparar_adc_contador(void)
{
	//Si ADC es mayor que el contador, encender alarma
	if (lectura > contador)
	{
		led_alarma_on();
	}
	else
	{
		led_alarma_off();
	}
}

void led_alarma_off(void)
{
#if LED_ALARMA_ACTIVO_BAJO
	PORTB |= (1 << LED_ALARMA);
#else
	PORTB &= ~(1 << LED_ALARMA);
#endif
}

void led_alarma_on(void)
{
#if LED_ALARMA_ACTIVO_BAJO
	PORTB &= ~(1 << LED_ALARMA);
#else
	PORTB |= (1 << LED_ALARMA);
#endif
}

/****************************************/
// Interrupt routines
