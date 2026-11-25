/*
 * StopWatch.h
 *
 *  Created on: 2026. 10. 16.
 *      Author: rhoblack
 */

#ifndef SRC_AP_STOPWATCH_STOPWATCH_H_
#define SRC_AP_STOPWATCH_STOPWATCH_H_

#include <stdint.h>

typedef struct {
	uint8_t hour;
	uint8_t min;
	uint8_t sec;
	uint8_t msec;
} stopWatch_t;

void StopWatch_init(void);
void StopWatch_task(void);
void StopWatch_ISR(void);
stopWatch_t StopWatch_getTimeData(void); // 현재 시간의 복사본 반환

#endif /* SRC_AP_STOPWATCH_STOPWATCH_H_ */
