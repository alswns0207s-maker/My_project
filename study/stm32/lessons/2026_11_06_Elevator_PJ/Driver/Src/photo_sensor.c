#include "photo_sensor.h"
#include "stm32f4xx_hal.h"

uint32_t PhotoSensor_ReadRaw(void)
{
    uint32_t mask = 0U;
    if (HAL_GPIO_ReadPin(GPIOB, GPIO_PIN_13) == GPIO_PIN_SET) mask |= 1U;
    if (HAL_GPIO_ReadPin(GPIOB, GPIO_PIN_14) == GPIO_PIN_SET) mask |= 2U;
    if (HAL_GPIO_ReadPin(GPIOB, GPIO_PIN_15) == GPIO_PIN_SET) mask |= 4U;
    return mask;
}
