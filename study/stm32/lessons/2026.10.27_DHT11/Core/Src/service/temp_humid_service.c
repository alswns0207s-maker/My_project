#include "temp_humid_service.h"
static uint32_t last_read;

DHT11_Status TempHumid_Init(void)
{
    DHT11_Status status = dht11_init();
    last_read = HAL_GetTick() - 2000U;
    return status;
}

uint8_t TempHumid_Task(DHT11_Data *data, DHT11_Status *status)
{
    if ((uint32_t)(HAL_GetTick() - last_read) < 2000U) return 0;
    *status = dht11_read(data);
    /* End time guarantees the driver's minimum interval. */
    last_read = HAL_GetTick();
    return 1;
}
