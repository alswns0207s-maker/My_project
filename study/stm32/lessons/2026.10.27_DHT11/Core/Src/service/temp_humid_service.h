#ifndef TEMP_HUMID_SERVICE_H
#define TEMP_HUMID_SERVICE_H
#include "../driver/DHT11/dht11.h"
DHT11_Status TempHumid_Init(void);
/* Returns 1 only when a measurement was attempted (every 2 seconds). */
uint8_t TempHumid_Task(DHT11_Data *data, DHT11_Status *status);
#endif
