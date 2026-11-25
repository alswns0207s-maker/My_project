#include "ap_main.h"
#include "../service/temp_humid_service.h"
#include "../driver/lcd/lcd.h"
#include <stdio.h>

extern I2C_HandleTypeDef hi2c1;
static uint8_t lcd_ready;

void ap_init(void)
{
    lcd_ready = (Lcd_init(&hi2c1) == HAL_OK);
    if (!lcd_ready) printf("LCD not found (PB8/PB9, address 0x27)\r\n");
    DHT11_Status status = TempHumid_Init();
    if (status != DHT11_OK)
        printf("DHT11 init error: %s\r\n", dht11_status_string(status));
}

void ap_main(void)
{
    DHT11_Data data;
    DHT11_Status status;
    char line[32];
    if (!TempHumid_Task(&data, &status)) return;
    if (status != DHT11_OK) {
        if (lcd_ready) {
            Lcd_writeLine(0, "DHT11 error");
            Lcd_writeLine(1, "Check PC8 wire");
        }
        printf("DHT11 error: %s\r\n", dht11_status_string(status));
        return;
    }
    snprintf(line, sizeof(line), "Temp: %u.%u C",
             (unsigned)data.temperature_integer, (unsigned)data.temperature_decimal);
    if (lcd_ready) Lcd_writeLine(0, line);
    printf("%s  ", line);
    snprintf(line, sizeof(line), "Humi: %u.%u %%",
             (unsigned)data.humidity_integer, (unsigned)data.humidity_decimal);
    if (lcd_ready) Lcd_writeLine(1, line);
    printf("%s\r\n", line);
}
