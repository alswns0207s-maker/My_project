#ifndef LCD_H
#define LCD_H
#include "stm32f4xx_hal.h"
HAL_StatusTypeDef Lcd_init(I2C_HandleTypeDef *i2c);
void Lcd_writeLine(uint8_t row, const char *text);
#endif
