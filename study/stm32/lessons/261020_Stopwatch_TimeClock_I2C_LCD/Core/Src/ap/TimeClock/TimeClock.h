#ifndef TIMECLOCK_H_
#define TIMECLOCK_H_
#include "../../driver/DS3231/DS3231.h"

typedef DS3231_Time_t TimeClock_t;
void TimeClock_init(void);
void TimeClock_task(void); // 두 모드 모두 메인 반복문에서 호출
void TimeClock_showFND(void); // 시계 모드에서만 호출
TimeClock_t TimeClock_getTimeData(void);
uint8_t TimeClock_isValid(void);
#endif
