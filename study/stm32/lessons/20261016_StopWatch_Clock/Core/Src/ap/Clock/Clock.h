#ifndef SRC_AP_CLOCK_CLOCK_H_
#define SRC_AP_CLOCK_CLOCK_H_
#include <stdint.h>
void Clock_init(void);
void Clock_tick1ms(void); /* Called only by TIM2 interrupt. */
void Clock_getDisplay(uint16_t *number, uint8_t *dotMask);
#endif
