#ifndef DHT11_H
#define DHT11_H

#include "stm32f4xx_hal.h"

typedef enum {
    DHT11_OK = 0,
    DHT11_ERROR_ARGUMENT,
    DHT11_ERROR_NOT_INITIALIZED,
    DHT11_ERROR_CONTEXT,
    DHT11_ERROR_DWT,
    DHT11_ERROR_TOO_SOON,
    DHT11_ERROR_TIMEOUT,
    DHT11_ERROR_CHECKSUM
} DHT11_Status;

typedef struct {
    uint8_t humidity_integer;
    uint8_t humidity_decimal;
    uint8_t temperature_integer;
    uint8_t temperature_decimal;
    uint8_t raw[5];
} DHT11_Data;

/* Single DHT11 on PC8. Call after HAL, clock and GPIO initialization.
 * init waits 2 seconds for power stabilization. Call from main context only.
 * read blocks about 20-25 ms; retry at least 2 seconds after each attempt.
 * Output is modified only on success. Not reentrant; not a DHT22 driver. */
DHT11_Status dht11_init(void);
DHT11_Status dht11_read(DHT11_Data *data);
const char *dht11_status_string(DHT11_Status status);

#endif
