#include "Clock.h"

/* PDF's clock display is minutes/seconds, wrapping after 59:59. */
static volatile uint32_t clockMs;

void Clock_init(void)
{
    clockMs = 0U;
}

void Clock_tick1ms(void)
{
    uint32_t next = clockMs + 1U;
    clockMs = (next == 3600000U) ? 0U : next;
}

void Clock_getDisplay(uint16_t *number, uint8_t *dotMask)
{
    uint32_t snapshot = clockMs;
    uint32_t seconds = snapshot / 1000U;
    *number = (uint16_t)((seconds / 60U) * 100U + seconds % 60U);
    /* D2 decimal point: 500 ms on, 500 ms off. */
    *dotMask = (snapshot % 1000U < 500U) ? 0x02U : 0U;
}
