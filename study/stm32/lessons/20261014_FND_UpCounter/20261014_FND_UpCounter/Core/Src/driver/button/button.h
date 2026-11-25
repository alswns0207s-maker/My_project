#ifndef BUTTON_H
#define BUTTON_H

#include "main.h"

#define BUTTON_DEBOUNCE_MS 20U

typedef enum {
  BUTTON_NONE,
  BUTTON_PRESSED
} ButtonState_t;

typedef struct {
  GPIO_TypeDef *gpioPort;
  uint16_t gpioPin;
  GPIO_PinState lastReading;
  GPIO_PinState stableState;
  uint32_t prevTime;
} Button_t;

void Button_Init(Button_t *button, GPIO_TypeDef *gpioPort, uint16_t gpioPin);
ButtonState_t Button_GetState(Button_t *button);

#endif
