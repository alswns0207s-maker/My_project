/*
 * btn.h
 *
 *  Created on: 2026. 10. 16.
 *      Author: kccistc
 */

#ifndef SRC_DRIVER_BTN_BTN_H_
#define SRC_DRIVER_BTN_BTN_H_
#include "stm32f4xx_hal.h"
#include "main.h"

typedef enum {
    NO_ACT,
    ACT_PUSH,
    ACT_RELEASED
} button_state_t;

// 풀업/풀다운에 따른 누름/뗌 정의
enum { PUSHED = 0, RELEASED = 1 };

// 버튼 구조체 정의
typedef struct {
    GPIO_TypeDef *GPIOx;
    uint16_t GPIO_PIN;
    int preState;
} button_t;

// 버튼 상태 체크 함수 프로토타입
button_state_t button_getstate(button_t *btn);


#endif /* SRC_DRIVER_BTN_BTN_H_ */
