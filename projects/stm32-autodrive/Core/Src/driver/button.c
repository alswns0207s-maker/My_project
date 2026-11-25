/*
 * button.c
 *
 *  Created on: 2026. 11. 13.
 *      Author: kccistc
 */

#include "button.h"
#include "main.h"

#define DEBOUNCE_TIME_MS 20U

static GPIO_TypeDef *const button_port[BUTTON_COUNT] =
{
    GPIOC,
    GPIOC,
    GPIOC
};

static const uint16_t button_pin[BUTTON_COUNT] =
{
    GPIO_PIN_0,
    GPIO_PIN_1,
    GPIO_PIN_2
};

static uint8_t stable_state[BUTTON_COUNT];
static uint8_t last_raw_state[BUTTON_COUNT];
static uint8_t press_event[BUTTON_COUNT];

static uint32_t change_tick[BUTTON_COUNT];

// GPIO 입력값을 논리적인 버튼 상태로 변환
// 눌림 = 1, 안 눌림 = 0
static uint8_t button_read_raw(button_id_t button)
{
    return HAL_GPIO_ReadPin(
        button_port[button],
        button_pin[button]
    ) == GPIO_PIN_RESET;
}

void button_init(void)
{
    uint32_t now = HAL_GetTick();

    for (uint8_t i = 0; i < BUTTON_COUNT; i++)
    {
        uint8_t state = button_read_raw((button_id_t)i);

        stable_state[i] = state;
        last_raw_state[i] = state;
        press_event[i] = 0;
        change_tick[i] = now;
    }
}

void button_update(void)
{
    uint32_t now = HAL_GetTick();

    for (uint8_t i = 0; i < BUTTON_COUNT; i++)
    {
        uint8_t raw = button_read_raw((button_id_t)i);

        // 입력 상태가 바뀌면 시간 기록
        if (raw != last_raw_state[i])
        {
            last_raw_state[i] = raw;
            change_tick[i] = now;
        }

        // 20ms 동안 동일한 상태 유지 시 확정
        if ((now - change_tick[i]) >= DEBOUNCE_TIME_MS)
        {
            if (raw != stable_state[i])
            {
                stable_state[i] = raw;

                // 누르는 순간에만 이벤트 발생
                if (raw == 1)
                {
                    press_event[i] = 1;
                }
            }
        }
    }
}

uint8_t button_is_pressed(button_id_t button)
{
    if ((unsigned)button >= BUTTON_COUNT)
        return 0;

    return stable_state[button];
}

uint8_t button_get_press_event(button_id_t button)
{
    if ((unsigned)button >= BUTTON_COUNT)
        return 0;

    uint8_t event = press_event[button];
    press_event[button] = 0;

    return event;
}
