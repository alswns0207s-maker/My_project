#include "upcounter.h"
#include "../driver/button/button.h"
#include "../driver/fnd/fnd.h"

typedef enum {
  STOP,
  RUN,
  CLEAR
} UpCounterState_t;

static UpCounterState_t state;
static uint16_t counter;
static uint32_t prevTime;
static Button_t btnRunStop;
static Button_t btnClear;

void UpCounter_Init(void)
{
  state = STOP;
  counter = 0;
  prevTime = HAL_GetTick();
  Button_Init(&btnRunStop, BTN_RUN_STOP_GPIO_Port, BTN_RUN_STOP_Pin);
  Button_Init(&btnClear, BTN_CLEAR_GPIO_Port, BTN_CLEAR_Pin);
  FND_SetData(counter);
}

void UpCounter_Task(void)
{
  ButtonState_t btn_run_stop = Button_GetState(&btnRunStop);
  ButtonState_t btn_clear = Button_GetState(&btnClear);

  switch (state) {
    case STOP:
      if (btn_clear == BUTTON_PRESSED) {
        state = CLEAR;
      }
      else if (btn_run_stop == BUTTON_PRESSED) {
        state = RUN;
        prevTime = HAL_GetTick();
      }
      break;

    case RUN:
      if (btn_run_stop == BUTTON_PRESSED) {
        state = STOP;
        break;
      }

      if (HAL_GetTick() - prevTime > 100U) {
        prevTime = HAL_GetTick();

        if (counter == 9999U) {
          counter = 0;
        }
        else {
          counter++;
        }
      }
      break;

    case CLEAR:
      counter = 0;
      prevTime = HAL_GetTick();
      state = STOP;
      break;

    default:
      state = STOP;
      break;
  }

  FND_SetData(counter);
}
