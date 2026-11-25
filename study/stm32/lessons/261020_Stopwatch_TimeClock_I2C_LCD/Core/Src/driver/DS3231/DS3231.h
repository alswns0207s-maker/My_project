#ifndef DS3231_H_
#define DS3231_H_
#include "stm32f4xx_hal.h"

// 시간과 달력을 함께 담는다. weekday: 1=SUN ... 7=SAT
typedef struct {
    uint16_t year;
    uint8_t month, date, weekday;
    uint8_t hour, min, sec;
} DS3231_Time_t;

HAL_StatusTypeDef DS3231_readTime(DS3231_Time_t *time);
// 최초 설정 또는 시간 수정 때만 호출한다. 매 부팅마다 호출하지 않는다.
HAL_StatusTypeDef DS3231_setTime(const DS3231_Time_t *time);
#endif
