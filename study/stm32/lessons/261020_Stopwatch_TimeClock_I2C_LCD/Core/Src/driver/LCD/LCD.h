/*
 * LCD.h
 *
 *  Created on: 2026. 10. 21.
 *      Author: kccistc
 */

#ifndef SRC_DRIVER_LCD_LCD_H_
#define SRC_DRIVER_LCD_LCD_H_

#include <stdint.h>


void LCD_backlighton(void);
void LCD_backlightoff(void);
void LCD_writecmddata(uint8_t data);
void LCD_writechardata(uint8_t data);
void LCD_init(void);
void LCD_writestring(char *str);
void LCD_writestringXY(uint8_t row, uint8_t col, char *str);
void LCD_gotoXY(uint8_t row, uint8_t col);

#endif /* SRC_DRIVER_LCD_LCD_H_ */
