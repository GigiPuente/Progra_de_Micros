/*
 * PRELAB4.c
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

/****************************************/
// Function prototypes

void configurar_pines(void);
void configurar_adc(void);
void mostrar_contador(void);
unsigned char leer_potenciometro(void);
unsigned char numero_7segmentos(unsigned char numero);
void apagar_displays(void);
void actualizar_voltaje(void);
void mostrar_voltaje(void);
void revisar_botones(void);

/****************************************/
// Main Function

unsigned char contador = 0;
unsigned char lectura = 0;
unsigned char valor = 0;
unsigned char entero = 0;
unsigned char decimal = 0;
unsigned char segmentos = 0;
unsigned char boton_inc_habilitado = 1;
unsigned char boton_dec_habilitado = 1;

int main(void)
{
	configurar_pines();
	configurar_adc();
	mostrar_contador();

	while (1)
	{
		//Leer ADC y convertirlo a voltaje
		actualizar_voltaje();
		//Revisar botones de incremento y decremento
		revisar_botones();
		//Multiplexar displays
		mostrar_voltaje();
	}
}

/****************************************/
// NON-Interrupt subroutines

void configurar_pines(void)
{
	//PORTD Salida
	DDRD = 0b11111111;
	PORTD = 0b00000000;

	//PB0-PB5 salida, PB6-PB7 entrada
	DDRB = 0b00111111;
	//Apagar PB0-PB5
	PORTB = 0b00000000;

	//PC5, PC2 y PC1 salida
	//PC4, PC3 y PC0 entrada
	DDRC = 0b00100110;
	//Pull-up en PC4 y PC3
	PORTC = 0b00011000;
}

void configurar_adc(void)
{
	// REFS0 = 1, ADLAR = 1
	ADMUX = 0b01100000;

	// ADEN = 1 y prescaler = 128 
	ADCSRA = 0b10000111;

	// Desactivar entrada digital en A0
	DIDR0 = 0b00000001;
}

void mostrar_contador(void)
{
	//Revisar bit 0 encendido
	if (contador & 0x01)
	{
		//Encender o apagar dependiendo del bit
		PORTD |= (1 << PORTD7);
	}
	else
	{
		PORTD &= ~(1 << PORTD7);
	}

	if (contador & 0x02)
	{
		//Bit 1
		PORTB |= (1 << PORTB0);
	}
	else
	{
		PORTB &= ~(1 << PORTB0);
	}

	if (contador & 0x04)
	{
		//Bit 2
		PORTB |= (1 << PORTB1);
	}
	else
	{
		PORTB &= ~(1 << PORTB1);
	}

	if (contador & 0x08)
	{
		//Bit 3
		PORTB |= (1 << PORTB2);
	}
	else
	{
		PORTB &= ~(1 << PORTB2);
	}

	if (contador & 0x10)
	{
		//Bit 4
		PORTB |= (1 << PORTB3);
	}
	else
	{
		PORTB &= ~(1 << PORTB3);
	}

	if (contador & 0x20)
	{
		//Bit 5
		PORTB |= (1 << PORTB4);
	}
	else
	{
		PORTB &= ~(1 << PORTB4);
	}

	if (contador & 0x40)
	{
		//Bit 6
		PORTC |= (1 << PORTC1);
	}
	else
	{
		PORTC &= ~(1 << PORTC1);
	}

	if (contador & 0x80)
	{
		//Bit 7
		PORTC |= (1 << PORTC2);
	}
	else
	{
		PORTC &= ~(1 << PORTC2);
	}
}

unsigned char leer_potenciometro(void)
{
	//Conversión ADC
	ADCSRA |= (1 << ADSC);

	while (ADCSRA & (1 << ADSC))
	{
	}

	//Devolver HIGH (8 bits)
	return ADCH;
}

unsigned char numero_7segmentos(unsigned char numero)
{
	switch (numero)
	{
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
		case 10:
			return 0b01110111;
		case 11:
			return 0b01111100;
		case 12:
			return 0b00111001;
		case 13:
			return 0b01011110;
		case 14:
			return 0b01111001;
		case 15:
			return 0b01110001;
		default:
			return 0;
	}
}

void apagar_displays(void)
{
	//Apagar los dos displays antes de actualizar
	PORTC &= ~(1 << PORTC5);
	PORTB &= ~(1 << PORTB5);
}

void actualizar_voltaje(void)
{
	lectura = leer_potenciometro();
	valor = (lectura * 50UL) / 255UL;
	entero = valor / 10;
	decimal = valor % 10;
}

void mostrar_voltaje(void)
{
	//Apagar antes de cambiar
	apagar_displays();
	//Mostrar decimal
	segmentos = numero_7segmentos(decimal);
	//Conservar estado del bit del contador en PD7
	PORTD = (PORTD & (1 << PORTD7)) | segmentos;
	//Encender display de la derecha
	PORTC |= (1 << PORTC5);
	_delay_ms(4);

	//Apagar antes de cambiar
	apagar_displays();
	//Mostrar entero
	segmentos = numero_7segmentos(entero);
	//Conservar estado del bit del contador en PD7
	PORTD = (PORTD & (1 << PORTD7)) | segmentos;
	//Encender display de la izquierda
	PORTB |= (1 << PORTB5);
	_delay_ms(4);

	//Apagar para el siguiente ciclo
	apagar_displays();
}

void revisar_botones(void)
{
	//Leer boton INC
	if (((PINC & (1 << PINC3)) == 0) && (boton_inc_habilitado != 0))
	{
		_delay_ms(ANTIREBOTE_MS);

		//Leerlo otra vez
		if ((PINC & (1 << PINC3)) == 0)
		{
			//INC
			contador++;
			mostrar_contador();
			//Esperar a que se libere para aceptar otra pulsación
			boton_inc_habilitado = 0;
		}
	}
	else if ((PINC & (1 << PINC3)) != 0)
	{
		//Botón suelto
		boton_inc_habilitado = 1;
	}

	//Leer boton DEC
	if (((PINC & (1 << PINC4)) == 0) && (boton_dec_habilitado != 0))
	{
		_delay_ms(ANTIREBOTE_MS);

		//Leerlo otra vez
		if ((PINC & (1 << PINC4)) == 0)
		{
			//DEC
			contador--;
			mostrar_contador();
			//Esperar a que se suelte para aceptar otra pulsación
			boton_dec_habilitado = 0;
		}
	}
	else if ((PINC & (1 << PINC4)) != 0)
	{
		//Botón suelto
		boton_dec_habilitado = 1;
	}
}

/****************************************/
// Interrupt routines


