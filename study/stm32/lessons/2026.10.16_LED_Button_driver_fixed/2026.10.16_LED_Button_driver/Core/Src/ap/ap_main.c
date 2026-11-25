/*
 * ap_main.c
 *
 *  Created on: 2026. 10. 16.
 *      Author: kccistc
 */

#include "ap_main.h"
#include "main.h"
#include "../driver/led/led.h"
#include "../driver/btn/btn.h"

enum { STOP, RUN, CLEAR };

void ap_main(void)
{
    // 1. LED 객체 초기화
    led_t led_power = {GPIOB, GPIO_PIN_15};
    led_t led_run   = {GPIOB, GPIO_PIN_14};
    led_t led_stop  = {GPIOB, GPIO_PIN_13};
    led_t led_clear = {GPIOC, GPIO_PIN_4};

    // 2. 버튼 객체 초기화
    button_t btn_power     = {GPIOC, GPIO_PIN_0, RELEASED};
    button_t btn_run_stop  = {GPIOC, GPIO_PIN_1, RELEASED};
    button_t btn_clear     = {GPIOC, GPIO_PIN_3, RELEASED};

    int state = STOP; // 상태 변수 초기화

    while (1)
    {
        // 버튼 상태 읽기
        button_state_t run_stop_action = button_getstate(&btn_run_stop);
        button_state_t clear_action    = button_getstate(&btn_clear);
        button_state_t power_action    = button_getstate(&btn_power);

        // 상태 머신 (FSM) 처리
        switch (state)
        {
            case STOP:
                led_on(&led_power);
                led_off(&led_run);
                led_on(&led_stop);
                led_off(&led_clear);

                if (run_stop_action == ACT_PUSH) {
                    state = RUN;
                }
                else if (clear_action == ACT_PUSH) {
                    state = CLEAR;
                }
                break;

            case RUN:
                led_on(&led_power);
                led_on(&led_run);
                led_off(&led_stop);
                led_off(&led_clear);

                if (run_stop_action == ACT_PUSH) {
                    state = STOP;
                }
                break;

            case CLEAR:
                led_off(&led_power);
                led_off(&led_run);
                led_off(&led_stop);
                led_on(&led_clear);

                if (run_stop_action == ACT_PUSH) {
                    state = STOP;
                }
                break;

            default:
                state = STOP;
                break;
        }

        if (power_action == ACT_PUSH) {
            // 전원 버튼 처리 로직
        }

        HAL_Delay(10);
    }
}
