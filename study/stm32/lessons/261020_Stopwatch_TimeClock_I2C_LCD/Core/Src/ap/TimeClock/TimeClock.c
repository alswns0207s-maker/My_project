#include "TimeClock.h"
#include "RTC_initial_time.h"
#include "../../driver/fnd/fnd.h"

extern TIM_HandleTypeDef htim4;
extern I2C_HandleTypeDef hi2c1;

// 중심 데이터: 이 파일 안에서만 직접 접근한다.
static TimeClock_t timeClockData;
static uint8_t timeValid;
static uint32_t previousRead;

TimeClock_t TimeClock_getTimeData(void)
{
    return timeClockData; // 복사본 전달: clock.hour처럼 사용
}

uint8_t TimeClock_isValid(void)
{
    return timeValid;
}

void TimeClock_init(void)
{
    // 최초 사용(OSF=1)일 때만 준비 시각으로 설정한다.
    // 통신 오류나 일반 재부팅 때문에 정상 시각을 덮어쓰지 않는다.
    uint8_t status;
    if (HAL_I2C_Mem_Read(&hi2c1, 0x68 << 1, 0x0F,
            I2C_MEMADD_SIZE_8BIT, &status, 1, 100) == HAL_OK &&
            (status & 0x80)) {
        DS3231_Time_t initialTime = RTC_INITIAL_TIME;
        DS3231_setTime(&initialTime);
    }
    timeClockData = (TimeClock_t){0};
    timeValid = 0;
    previousRead = HAL_GetTick() - 500U;
    // TIM4는 스톱워치의 0.01초 계산에 계속 필요하다.
    HAL_TIM_Base_Start_IT(&htim4);
    TimeClock_task();
}

void TimeClock_task(void)
{
    uint32_t now = HAL_GetTick();
    if ((uint32_t)(now - previousRead) < 500U) return;
    previousRead = now;
    // 실제 시각 계산은 DS3231이 한다. 여기서는 읽기만 한다.
    timeValid = (DS3231_readTime(&timeClockData) == HAL_OK);
}

void TimeClock_showFND(void)
{
    uint16_t number = timeValid ?
        timeClockData.min * 100 + timeClockData.sec : 0;
    fnd_set_num(number);
    fnd_set_dp(FND_DIGIT_2,
        timeValid && (timeClockData.sec % 2 == 0) ? FND_DP_ON : FND_DP_OFF);
}
