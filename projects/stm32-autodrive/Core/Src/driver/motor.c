/*
 * motor.c
 *
 *  Created on: 2026. 11. 13.
 *      Author: kccistc
 */

#include "motor.h"
#include "main.h"

extern TIM_HandleTypeDef htim3;

// 속도 범위 제한
static int16_t motor_limit(int16_t speed)
{
    if (speed > 100) return 100;
    if (speed < -100) return -100;

    return speed;
}

// 모터 초기화
void motor_init(void)
{
    motor_stop();

    HAL_TIM_PWM_Start(&htim3, TIM_CHANNEL_1);
    HAL_TIM_PWM_Start(&htim3, TIM_CHANNEL_3);
}

// 좌우 모터 독립 제어
void motor_set(int16_t left, int16_t right)
{
    left = motor_limit(left);
    right = motor_limit(right);

    // PWM 출력 0으로 설정
    __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_1, 0);
    __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_3, 0);

    // 왼쪽 모터 방향
    HAL_GPIO_WritePin(MOTOR_IN1_GPIO_Port, MOTOR_IN1_Pin,
        left > 0 ? GPIO_PIN_SET : GPIO_PIN_RESET);

    HAL_GPIO_WritePin(MOTOR_IN2_GPIO_Port, MOTOR_IN2_Pin,
        left < 0 ? GPIO_PIN_SET : GPIO_PIN_RESET);

    // 오른쪽 모터 방향
    HAL_GPIO_WritePin(MOTOR_IN3_GPIO_Port, MOTOR_IN3_Pin,
        right > 0 ? GPIO_PIN_SET : GPIO_PIN_RESET);

    HAL_GPIO_WritePin(MOTOR_IN4_GPIO_Port, MOTOR_IN4_Pin,
        right < 0 ? GPIO_PIN_SET : GPIO_PIN_RESET);

    // PWM 비교값 계산
    uint32_t period =
        __HAL_TIM_GET_AUTORELOAD(&htim3) + 1U;

    uint32_t leftDuty =
        period * (uint32_t)(left < 0 ? -left : left) / 100U;

    uint32_t rightDuty =
        period * (uint32_t)(right < 0 ? -right : right) / 100U;

    // 모터 속도 적용
    __HAL_TIM_SET_COMPARE(&htim3,
        TIM_CHANNEL_1, leftDuty);

    __HAL_TIM_SET_COMPARE(&htim3,
        TIM_CHANNEL_3, rightDuty);
}

// 전진
void motor_forward(uint8_t speed)
{
    motor_set(speed, speed);
}

// 후진
void motor_backward(uint8_t speed)
{
	motor_set(-(int16_t)speed, -(int16_t)speed);
}

// 좌회전
void motor_turnleft(uint8_t speed)
{
	motor_set(speed / 2, speed);
}

// 우회전
void motor_turnright(uint8_t speed)
{
	motor_set(speed, speed / 2);
}

// 제자리 좌회전
void motor_rotateleft(uint8_t speed)
{
	motor_set(-(int16_t)speed, speed);
}

// 제자리 우회전
void motor_rotateright(uint8_t speed)
{
	motor_set(speed, -(int16_t)speed);
}

// 정지
void motor_stop(void)
{
    __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_1, 0);
    __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_3, 0);

    HAL_GPIO_WritePin(MOTOR_IN1_GPIO_Port,
        MOTOR_IN1_Pin, GPIO_PIN_RESET);
    HAL_GPIO_WritePin(MOTOR_IN2_GPIO_Port,
        MOTOR_IN2_Pin, GPIO_PIN_RESET);
    HAL_GPIO_WritePin(MOTOR_IN3_GPIO_Port,
        MOTOR_IN3_Pin, GPIO_PIN_RESET);
    HAL_GPIO_WritePin(MOTOR_IN4_GPIO_Port,
        MOTOR_IN4_Pin, GPIO_PIN_RESET);
}
