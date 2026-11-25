/*
 * ultrasonic.c
 *
 *  Created on: 2026. 11. 13.
 *      Author: kccistc
 */

#include "ultrasonic.h"
#include "main.h"

#define ULTRASONIC_TIMEOUT_US 30000U
#define TRIGGER_PULSE_US      10U

typedef struct
{
    GPIO_TypeDef *trig_port;
    uint16_t trig_pin;

    GPIO_TypeDef *echo_port;
    uint16_t echo_pin;
} ultrasonic_pin_t;

// 전방, 왼쪽, 오른쪽 순서
static const ultrasonic_pin_t sensor_pins[ULTRASONIC_COUNT] =
{
    {GPIOB, GPIO_PIN_10, GPIOB, GPIO_PIN_4},
    {GPIOA, GPIO_PIN_9,  GPIOA, GPIO_PIN_8},
    {GPIOB, GPIO_PIN_5,  GPIOB, GPIO_PIN_3}
};

static uint32_t cycles_per_us = 0;

// DWT를 이용한 us 단위 지연
static void ultrasonic_delay_us(uint32_t us)
{
    uint32_t start = DWT->CYCCNT;
    uint32_t wait_cycles = us * cycles_per_us;

    while ((uint32_t)(DWT->CYCCNT - start)
           < wait_cycles)
    {
    }
}

// DWT 초기화
void ultrasonic_init(void)
{
    CoreDebug->DEMCR |= CoreDebug_DEMCR_TRCENA_Msk;

    /* The RTOS trace shares this free-running counter. */
    DWT->CTRL |= DWT_CTRL_CYCCNTENA_Msk;

    cycles_per_us = HAL_RCC_GetHCLKFreq() / 1000000U;

    // 모든 TRIG를 LOW로 초기화
    for (uint8_t i = 0; i < ULTRASONIC_COUNT; i++)
    {
        HAL_GPIO_WritePin(
            sensor_pins[i].trig_port,
            sensor_pins[i].trig_pin,
            GPIO_PIN_RESET
        );
    }
}

// 초음파 거리 측정
uint8_t ultrasonic_read_cm(
    ultrasonic_id_t sensor,
    uint16_t *distance_cm)
{
    if ((unsigned)sensor >= ULTRASONIC_COUNT ||
        distance_cm == 0 ||
        cycles_per_us == 0)
    {
        return 0;
    }

    const ultrasonic_pin_t *pin =
        &sensor_pins[sensor];

    // ECHO가 이미 HIGH라면 비정상 상태
    if (HAL_GPIO_ReadPin(
            pin->echo_port,
            pin->echo_pin) != GPIO_PIN_RESET)
    {
        return 0;
    }

    // TRIG 신호 발생
    HAL_GPIO_WritePin(
        pin->trig_port,
        pin->trig_pin,
        GPIO_PIN_RESET
    );

    ultrasonic_delay_us(2);

    HAL_GPIO_WritePin(
        pin->trig_port,
        pin->trig_pin,
        GPIO_PIN_SET
    );

    ultrasonic_delay_us(TRIGGER_PULSE_US);

    HAL_GPIO_WritePin(
        pin->trig_port,
        pin->trig_pin,
        GPIO_PIN_RESET
    );

    // ECHO HIGH 시작 대기
    uint32_t start = DWT->CYCCNT;
    uint32_t timeout =
        ULTRASONIC_TIMEOUT_US * cycles_per_us;

    while (HAL_GPIO_ReadPin(
        pin->echo_port,
        pin->echo_pin) == GPIO_PIN_RESET)
    {
        if ((uint32_t)(DWT->CYCCNT - start)
            >= timeout)
        {
            return 0;
        }
    }

    // ECHO HIGH 시간 측정 시작
    uint32_t echo_start = DWT->CYCCNT;

    while (HAL_GPIO_ReadPin(
        pin->echo_port,
        pin->echo_pin) == GPIO_PIN_SET)
    {
        if ((uint32_t)(DWT->CYCCNT - echo_start)
            >= timeout)
        {
            return 0;
        }
    }

    // CPU Cycle -> microsecond
    uint32_t echo_cycles =
        (uint32_t)(DWT->CYCCNT - echo_start);

    uint32_t echo_us = echo_cycles / cycles_per_us;

    // microsecond -> cm (반올림)
    uint32_t cm = (echo_us + 29U) / 58U;

    // HC-SR04 유효 측정 범위 검사
    if (cm < 2U || cm > 400U)
    {
        return 0;
    }

    *distance_cm = (uint16_t)cm;

    return 1;
}
