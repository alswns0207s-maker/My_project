#ifndef SRC_DRIVER_BUTTON_BUTTON_H_
#define SRC_DRIVER_BUTTON_BUTTON_H_
#include "stm32f4xx_hal.h"
#define BUTTON_DEBOUNCE_MS 20U
typedef enum { NO_ACT, ACT_PUSH, ACT_RELEASE } button_state_t;
enum { PUSHED = 0, RELEASED = 1 };
typedef struct {
    GPIO_TypeDef *GPIOx;
    uint16_t GPIO_Pin;
    GPIO_PinState lastReading;
    GPIO_PinState stableState;
    uint32_t changedAt;
} button_t;
void button_init(button_t *btn, GPIO_TypeDef *GPIOx, uint16_t GPIO_Pin);
button_state_t button_getState(button_t *btn);
#endif
