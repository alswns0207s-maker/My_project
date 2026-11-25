#include "lcd.h"
#define LCD_ADDRESS (0x27U << 1)
static I2C_HandleTypeDef *lcd_i2c;

/* PCF8574: P0=RS, P1=RW, P2=E, P3=backlight, P4..7=data. */
static void nibble(uint8_t data)
{
    uint8_t bytes[3] = {data | 0x08U, data | 0x0CU, data | 0x08U};
    HAL_I2C_Master_Transmit(lcd_i2c, LCD_ADDRESS, bytes, 3, 10);
}

static void write_byte(uint8_t data, uint8_t rs)
{
    nibble((data & 0xF0U) | rs);
    nibble((data << 4) | rs);
}

HAL_StatusTypeDef Lcd_init(I2C_HandleTypeDef *i2c)
{
    lcd_i2c = i2c;
    HAL_Delay(50);
    if (HAL_I2C_IsDeviceReady(i2c, LCD_ADDRESS, 2, 10) != HAL_OK)
        return HAL_ERROR;
    nibble(0x30);
    HAL_Delay(5);
    nibble(0x30);
    HAL_Delay(1);
    nibble(0x30);
    HAL_Delay(1);
    nibble(0x20);
    write_byte(0x28, 0);
    write_byte(0x08, 0);
    write_byte(0x01, 0);
    HAL_Delay(2); /* Clear needs extra time. */
    write_byte(0x06, 0);
    write_byte(0x0C, 0);
    return HAL_OK;
}

void Lcd_writeLine(uint8_t row, const char *text)
{
    write_byte(row == 0 ? 0x80 : 0xC0, 0);
    for (uint8_t col = 0; col < 16; col++)
        write_byte(*text ? (uint8_t)*text++ : ' ', 1);
}
