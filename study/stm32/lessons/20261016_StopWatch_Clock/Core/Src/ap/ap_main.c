#include "ap_main.h"
#include "StopWatch/StopWatch.h"
#include "Clock/Clock.h"
#include "../driver/fnd/fnd.h"
#include "../driver/led/led.h"

typedef enum { MODE_CLOCK, MODE_STOPWATCH } appMode_t;
static appMode_t mode;
static button_t btnMode, btnRunStop, btnClear;
static led_t ledClock, ledStopwatch, ledStop, ledRun;
extern TIM_HandleTypeDef htim2;
extern TIM_HandleTypeDef htim3;

static void ap_update_outputs(void)
{
    if (mode == MODE_CLOCK) {
        uint16_t number;
        uint8_t dotMask;
        Clock_getDisplay(&number, &dotMask);
        fnd_set_frame(number, dotMask);
        led_on(&ledClock);
        led_off(&ledStopwatch);
        led_off(&ledStop);
        led_off(&ledRun);
    } else {
        fnd_set_frame(StopWatch_getCounter(), 0x04U); /* SSS.s */
        led_off(&ledClock);
        led_on(&ledStopwatch);
        if (StopWatch_getState() == STOPWATCH_RUN) {
            led_on(&ledRun);
            led_off(&ledStop);
        } else {
            led_off(&ledRun);
            led_on(&ledStop);
        }
    }
}

void HAL_TIM_PeriodElapsedCallback(TIM_HandleTypeDef *htim)
{
    if (htim->Instance == TIM2) {
        Clock_tick1ms();
        StopWatch_tick1ms();
    } else if (htim->Instance == TIM3) {
        fnd_show_number();
    }
}

void ap_init(void)
{
    mode = MODE_CLOCK;
    button_init(&btnMode, BTN_MODE_GPIO_Port, BTN_MODE_Pin);
    button_init(&btnRunStop, BTN_RUN_STOP_GPIO_Port, BTN_RUN_STOP_Pin);
    button_init(&btnClear, BTN_CLEAR_GPIO_Port, BTN_CLEAR_Pin);
    led_init(&ledClock, LED_CLOCK_GPIO_Port, LED_CLOCK_Pin);
    led_init(&ledStopwatch, LED_STOPWATCH_GPIO_Port, LED_STOPWATCH_Pin);
    led_init(&ledStop, LED_STOP_GPIO_Port, LED_STOP_Pin);
    led_init(&ledRun, LED_RUN_GPIO_Port, LED_RUN_Pin);
    fnd_init();
    Clock_init();
    StopWatch_init();
    ap_update_outputs();

    /* Init generates an update flag; clear it before enabling each IRQ. */
    __HAL_TIM_SET_COUNTER(&htim2, 0U);
    __HAL_TIM_CLEAR_FLAG(&htim2, TIM_FLAG_UPDATE);
    __HAL_TIM_SET_COUNTER(&htim3, 0U);
    __HAL_TIM_CLEAR_FLAG(&htim3, TIM_FLAG_UPDATE);
    if (HAL_TIM_Base_Start_IT(&htim2) != HAL_OK ||
        HAL_TIM_Base_Start_IT(&htim3) != HAL_OK) {
        Error_Handler();
    }
}

void ap_task(void)
{
    /* Poll all buttons in both modes so stale edges cannot be replayed. */
    button_state_t modeEvent = button_getState(&btnMode);
    button_state_t runEvent = button_getState(&btnRunStop);
    button_state_t clearEvent = button_getState(&btnClear);
    if (modeEvent == ACT_PUSH) {
        mode = (mode == MODE_CLOCK) ? MODE_STOPWATCH : MODE_CLOCK;
        StopWatch_cancelClear();
    } else if (mode == MODE_STOPWATCH) {
        StopWatch_task(runEvent, clearEvent);
    }
    ap_update_outputs();
}

int ap_main(void)
{
    ap_init();
    while (1) {
        ap_task();
    }
}
