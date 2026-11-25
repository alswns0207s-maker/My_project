#include "button.h"

void button_init(button_t *btn, GPIO_TypeDef *GPIOx, uint16_t GPIO_Pin)
{
    btn->GPIOx = GPIOx;
    btn->GPIO_Pin = GPIO_Pin;
    btn->lastReading = HAL_GPIO_ReadPin(GPIOx, GPIO_Pin);
    btn->stableState = btn->lastReading;
    btn->changedAt = HAL_GetTick();
}

button_state_t button_getState(button_t *btn)
{
    uint32_t now = HAL_GetTick();
    GPIO_PinState reading = HAL_GPIO_ReadPin(btn->GPIOx, btn->GPIO_Pin);
    if (reading != btn->lastReading) {
        btn->lastReading = reading;
        btn->changedAt = now;
    }
    if (reading != btn->stableState &&
        (uint32_t)(now - btn->changedAt) >= BUTTON_DEBOUNCE_MS) {
        btn->stableState = reading;
        return (reading == GPIO_PIN_RESET) ? ACT_PUSH : ACT_RELEASE;
    }
    return NO_ACT;
}
