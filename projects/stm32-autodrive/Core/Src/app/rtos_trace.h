#ifndef CAR_RTOS_TRACE_H
#define CAR_RTOS_TRACE_H

#include <stdint.h>

enum
{
    CAR_TRACE_SWITCH_IN = 1,
    CAR_TRACE_JOB_START,
    CAR_TRACE_JOB_END,
    CAR_TRACE_RANGE,
    CAR_TRACE_SKIPPED_RELEASES
};

void car_rtos_trace_switch_in(const void *task);
void car_rtos_trace_mark(uint8_t kind, uint16_t value);

#endif
