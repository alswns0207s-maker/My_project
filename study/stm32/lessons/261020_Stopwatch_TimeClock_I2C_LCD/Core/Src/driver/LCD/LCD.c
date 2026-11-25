/*
 * LCD.c
 *
 *  Created on: 2026. 10. 21.
 *      Author: kccistc
 */

#include "LCD.h"
#include "stm32f4xx_hal.h"

#define LCD_RS	0
#define LCD_RW	1
#define LCD_E	2
#define LCD_BL	3

extern I2C_HandleTypeDef hi2c1;


uint8_t LCDdata = 0;

void LCD_senddata(uint8_t data){
	HAL_I2C_Master_Transmit(&hi2c1, 0x27<<1, &data, 1, 100);
}

void LCD_cmdmode(void){
	LCDdata &= ~(1 << LCD_RS);
}

void LCD_datamode(void){
	LCDdata |= (1 << LCD_RS);
}

void LCD_writemode(void){
	LCDdata &= ~(1 << LCD_RW);
}
void LCD_enhigh(void){
	LCDdata |= (1 << LCD_E);
	LCD_senddata(LCDdata);
}
void LCD_enlow(void){
	LCDdata &= ~(1 << LCD_E);
	LCD_senddata(LCDdata);
}
void LCD_backlighton(void){
	LCDdata |= (1 << LCD_BL);
	LCD_senddata(LCDdata);
}
void LCD_backlightoff(void){
	LCDdata &= ~(1 << LCD_BL);
	LCD_senddata(LCDdata);
}

void LCD_writenibble(uint8_t data){
	LCDdata = (LCDdata & 0x0f) | (data & 0xf0);
	LCD_enlow();
	HAL_Delay(1);
	LCD_enhigh();
	HAL_Delay(1);
	LCD_enlow();
	HAL_Delay(1);
}
void LCD_writebyte(uint8_t data){
	LCD_writenibble(data); // data 상위 4bit전송
	data <<= 4;
	LCD_writenibble(data); // data 하위 4bit전송
}

void LCD_writecmddata(uint8_t data){
	LCD_cmdmode();
	LCD_writemode();
	LCD_writebyte(data);
}

void LCD_writechardata(uint8_t data){
	LCD_datamode();
	LCD_writemode();
	LCD_writebyte(data);

}

void LCD_init(void){
	HAL_Delay(40);
	LCD_cmdmode();
	LCD_writemode();
	LCD_writenibble(0x30);
	HAL_Delay(5);
	LCD_writenibble(0x30);
	HAL_Delay(1);
	LCD_writenibble(0x30);

	LCD_writenibble(0x20);
	LCD_writebyte(0x28); //function set
	LCD_writebyte(0x08); //display off
	LCD_writebyte(0x01); //display clear
	HAL_Delay(3);
	LCD_writebyte(0x06); //entry mode set
	LCD_writebyte(0x0C); //display on
	LCD_backlighton();
}

void LCD_writestring(char *str){
	for(int i = 0; str[i]; i++){
		LCD_writechardata(str[i]);
	}
}

void LCD_gotoXY(uint8_t row, uint8_t col){
	col %= 16;
	row %= 2;

	uint8_t LCDregaddr = (0x40 * row) + col;
	uint8_t cmd = 0x80 + LCDregaddr;
	LCD_writecmddata(cmd);
}
void LCD_writestringXY(uint8_t row, uint8_t col, char *str)
{
	LCD_gotoXY(row, col);
	LCD_writestring(str);
}



