/*
 * btn.c
 *
 *  Created on: 2026. 10. 16.
 *      Author: kccistc
 */
#include "btn.h"

// 구조체 포인터를 받아 해당 버튼의 상태를 체크하고 디바운싱을 처리하는 함수
button_state_t button_getstate(button_t *btn) {
    int curState;

    curState = HAL_GPIO_ReadPin(btn->GPIOx, btn->GPIO_PIN);

    if (curState != btn->preState) {
        HAL_Delay(5);
        if (HAL_GPIO_ReadPin(btn->GPIOx, btn->GPIO_PIN) != curState) {
            return NO_ACT;
        }
    }

    if ((btn->preState == RELEASED) && (curState == PUSHED)) {
        btn->preState = PUSHED;
        return ACT_PUSH;
    }
    else if ((btn->preState == PUSHED) && (curState == RELEASED)) {
        btn->preState = RELEASED;
        return ACT_RELEASED;
    }
    return NO_ACT;
}
