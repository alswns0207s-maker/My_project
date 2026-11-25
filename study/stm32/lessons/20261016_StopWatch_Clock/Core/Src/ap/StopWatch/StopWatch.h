#ifndef SRC_AP_STOPWATCH_STOPWATCH_H_
#define SRC_AP_STOPWATCH_STOPWATCH_H_
#include "../../driver/button/button.h"
typedef enum { STOPWATCH_STOP, STOPWATCH_RUN, STOPWATCH_CLEAR } stopWatch_t;
void StopWatch_init(void);
void StopWatch_task(button_state_t runStop, button_state_t clear);
void StopWatch_tick1ms(void); /* Called only by TIM2 interrupt. */
void StopWatch_cancelClear(void);
stopWatch_t StopWatch_getState(void);
uint16_t StopWatch_getCounter(void); /* Tenths of a second: 0..9999. */
#endif
