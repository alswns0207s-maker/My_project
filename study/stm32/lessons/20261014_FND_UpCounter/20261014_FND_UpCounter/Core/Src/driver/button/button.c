#include "button.h"

void Button_Init(Button_t *button, GPIO_TypeDef *gpioPort, uint16_t gpioPin)
{
  button->gpioPort = gpioPort;
  button->gpioPin = gpioPin;
  button->lastReading = HAL_GPIO_ReadPin(gpioPort, gpioPin);
  button->stableState = button->lastReading;
  button->prevTime = HAL_GetTick();
}

ButtonState_t Button_GetState(Button_t *button)
{
  uint32_t curTime = HAL_GetTick();
  GPIO_PinState curState = HAL_GPIO_ReadPin(button->gpioPort, button->gpioPin);

  if (curState != button->lastReading) {
    button->lastReading = curState;
    button->prevTime = curTime;
  }

  if (button->lastReading != button->stableState &&
      (uint32_t)(curTime - button->prevTime) >= BUTTON_DEBOUNCE_MS) {
    button->stableState = button->lastReading;
    if (button->stableState == GPIO_PIN_RESET) {
      return BUTTON_PRESSED;
    }
  }

  return BUTTON_NONE;
}
