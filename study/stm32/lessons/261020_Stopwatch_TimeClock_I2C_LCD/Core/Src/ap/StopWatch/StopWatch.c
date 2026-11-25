/*
 * StopWatch.c
 *
 *  Created on: 2026. 10. 16.
 *      Author: rhoblack
 */

#include "StopWatch.h"
#include "../../driver/button/button.h"
#include "../../driver/led/led.h"
#include "../../driver/fnd/fnd.h"

typedef enum {STOP, RUN, CLEAR} stopWatch_state_t;

static void StopWatch_stop();
static void StopWatch_run();
static void StopWatch_clear();
static void StopWatch_setState(stopWatch_state_t s);
static stopWatch_state_t StopWatch_getState(void);
static void StopWatch_incMSec(void);
static void StopWatch_clearTime(void);

static volatile stopWatch_t stopWatch_time;
static volatile stopWatch_state_t stopWatch_state;

static led_t led_run;
static led_t led_stop;

static button_t btn_run_stop;
static button_t btn_clear;

extern TIM_HandleTypeDef htim3;

stopWatch_t StopWatch_getTimeData(void)
{
	// 복사 중 시간이 바뀌지 않도록 잠깐 보호한다.
	uint32_t mask = __get_PRIMASK();
	__disable_irq();
	stopWatch_t time = stopWatch_time;
	__set_PRIMASK(mask);
	return time;
}

void StopWatch_ISR(void)
{
	if (stopWatch_state == RUN) {
		StopWatch_incMSec();
	}
}

static void StopWatch_incMSec(void)
{
	if (stopWatch_time.msec < 99) {
		stopWatch_time.msec++;
		return;
	}
	stopWatch_time.msec = 0;
	if (stopWatch_time.sec < 59) {
		stopWatch_time.sec++;
		return;
	}
	stopWatch_time.sec = 0;
	if (stopWatch_time.min < 59) {
		stopWatch_time.min++;
		return;
	}
	stopWatch_time.min = 0;
	if (stopWatch_time.hour < 99) {
		stopWatch_time.hour++;
		return;
	}
	stopWatch_time.hour = 0;
}

static void StopWatch_clearTime(void)
{
	stopWatch_time.hour = 0;
	stopWatch_time.min = 0;
	stopWatch_time.sec = 0;
	stopWatch_time.msec = 0;
}

static void StopWatch_setState(stopWatch_state_t s)
{
	stopWatch_state = s;
}

static stopWatch_state_t StopWatch_getState(void)
{
	return stopWatch_state;
}

void StopWatch_init(void)
{
	stopWatch_state = STOP;

	led_init(&led_stop, GPIOB, GPIO_PIN_13);
	led_init(&led_run, GPIOC, GPIO_PIN_4);

	button_init(&btn_run_stop, GPIOC, GPIO_PIN_1);
	button_init(&btn_clear, GPIOC, GPIO_PIN_3);

	stopWatch_time.hour = 0;
	stopWatch_time.min = 0;
	stopWatch_time.sec = 0;
	stopWatch_time.msec = 0;

	HAL_TIM_Base_Start_IT(&htim3);
}

void StopWatch_task(void)
{
	switch(StopWatch_getState())
	{
	case STOP:
		StopWatch_stop();
		break;
	case RUN:
		StopWatch_run();
		break;
	case CLEAR:
		StopWatch_clear();
		break;
	default:
		StopWatch_stop();
		break;
	}
}

static void StopWatch_stop()
{
	if (button_getState(&btn_run_stop) == ACT_PUSH) {
		StopWatch_setState(RUN);
	}
	else if (button_getState(&btn_clear) == ACT_RELEASE) {
		StopWatch_setState(CLEAR);
	}

	uint16_t num;
	num = (stopWatch_time.sec * 100) + stopWatch_time.msec;
	fnd_set_num(num);
}

static void StopWatch_run()
{
	if (button_getState(&btn_run_stop) == ACT_PUSH) {
		StopWatch_setState(STOP);
	}

	uint16_t num;
	num = (stopWatch_time.sec * 100) + stopWatch_time.msec;
	fnd_set_num(num);

	if (stopWatch_time.msec < 50) {
		fnd_set_dp(FND_DIGIT_2, FND_DP_ON);
	}
	else {
		fnd_set_dp(FND_DIGIT_2, FND_DP_OFF);
	}
}

static void StopWatch_clear()
{
	StopWatch_clearTime();

	uint16_t num;
	num = (stopWatch_time.sec * 100) + stopWatch_time.msec;
	fnd_set_num(num);

	StopWatch_setState(STOP);
}

