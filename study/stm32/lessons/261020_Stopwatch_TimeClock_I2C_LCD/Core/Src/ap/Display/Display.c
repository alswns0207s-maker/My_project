#include <stdio.h>
#include "Display.h"
#include "../ap_main.h"
#include "../TimeClock/TimeClock.h"
#include "../StopWatch/StopWatch.h"
#include "../../driver/LCD/LCD.h"
#include "../../driver/fnd/fnd.h"

static uint32_t previousTime;
static app_mode_t previousMode;

void Disp_init(void)
{
    previousTime = HAL_GetTick() - 500U;
    previousMode = TIME_CLOCK_MODE;
}

void Disp_task(void)
{
    uint32_t now = HAL_GetTick();
    app_mode_t mode = ap_getMode();
    if (mode == previousMode && (uint32_t)(now - previousTime) < 500U)
        return;
    previousTime = now;
    previousMode = mode;

    TimeClock_t clock = TimeClock_getTimeData();
    char text[17];
    const char *weekdays[] = {"---", "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"};

    // 첫째 줄: 두 모드 모두 실제 시각
    if (TimeClock_isValid()) {
        snprintf(text, sizeof(text), "Time %02u:%02u:%02u   ",
            (unsigned)clock.hour % 100, (unsigned)clock.min % 100,
            (unsigned)clock.sec % 100);
        LCD_writestringXY(0, 0, text);
    } else {
        LCD_writestringXY(0, 0, "RTC CHECK/SET   ");
    }

    // 둘째 줄: 모드에 따라 달력 또는 스톱워치
    if (mode == TIME_CLOCK_MODE) {
        if (TimeClock_isValid()) {
            snprintf(text, sizeof(text), "%04u-%02u-%02u %s  ",
                (unsigned)clock.year % 10000, (unsigned)clock.month % 100,
                (unsigned)clock.date % 100,
                weekdays[clock.weekday <= 7 ? clock.weekday : 0]);
            LCD_writestringXY(1, 0, text);
        } else {
            LCD_writestringXY(1, 0, "---- -- -- ---  ");
        }
    } else {
        stopWatch_t watch = StopWatch_getTimeData();
        // msec는 기존 이름이며 실제 단위는 0.01초(00~99).
        snprintf(text, sizeof(text), "S/W  %02u:%02u:%02u:%02u",
            (unsigned)watch.hour % 100, (unsigned)watch.min % 100,
            (unsigned)watch.sec % 100, (unsigned)watch.msec % 100);
        LCD_writestringXY(1, 0, text);
    }
}

void Disp_ISR(void)
{
    fnd_show_number(); // 인터럽트에서는 LCD/I2C를 호출하지 않는다.
}
