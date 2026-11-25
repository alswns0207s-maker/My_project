#include "StopWatch.h"

static volatile stopWatch_t state;
static volatile uint32_t elapsedMs;
static uint8_t clearArmed;

void StopWatch_init(void)
{
    state = STOPWATCH_STOP;
    elapsedMs = 0U;
    clearArmed = 0U;
}

void StopWatch_tick1ms(void)
{
    if (state == STOPWATCH_RUN) {
        uint32_t next = elapsedMs + 1U;
        elapsedMs = (next == 1000000U) ? 0U : next;
    }
}

void StopWatch_cancelClear(void)
{
    clearArmed = 0U;
}

void StopWatch_task(button_state_t runStop, button_state_t clear)
{
    /* The ISR must not increment between clearing the time and stopping. */
    uint32_t savedMask = __get_PRIMASK();
    __disable_irq();
    switch (state) {
    case STOPWATCH_STOP:
        if (clear == ACT_PUSH) {
            clearArmed = 1U;
        }
        /* Keep the supplied source's clear-on-release behavior. */
        if (clear == ACT_RELEASE && clearArmed != 0U) {
            state = STOPWATCH_CLEAR;
            clearArmed = 0U;
        } else if (runStop == ACT_PUSH) {
            state = STOPWATCH_RUN;
            clearArmed = 0U;
        }
        break;
    case STOPWATCH_RUN:
        clearArmed = 0U;
        if (runStop == ACT_PUSH) {
            state = STOPWATCH_STOP;
        }
        break;
    case STOPWATCH_CLEAR:
        break;
    default:
        state = STOPWATCH_STOP;
        clearArmed = 0U;
        break;
    }
    if (state == STOPWATCH_CLEAR) {
        elapsedMs = 0U;
        state = STOPWATCH_STOP;
    }
    __set_PRIMASK(savedMask);
}

stopWatch_t StopWatch_getState(void)
{
    return state;
}

uint16_t StopWatch_getCounter(void)
{
    /* One aligned 32-bit read snapshots the ISR-owned time. */
    uint32_t snapshot = elapsedMs;
    return (uint16_t)(snapshot / 100U);
}
