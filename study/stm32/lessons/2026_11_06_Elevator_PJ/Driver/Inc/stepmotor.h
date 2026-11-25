#ifndef STEPMOTOR_H
#define STEPMOTOR_H
#include <stdbool.h>
#include <stdint.h>

/* Single owner: call only from the main loop, never from interrupts. */
typedef enum { STEPMOTOR_IDLE, STEPMOTOR_RUNNING, STEPMOTOR_DONE,
               STEPMOTOR_FAULT } StepMotor_State;
typedef enum { STEPMOTOR_FORWARD = 1, STEPMOTOR_REVERSE = -1 } StepMotor_Direction;

/* GPIO clocks/output mode must already be configured by CubeMX. */
void StepMotor_Init(void);
bool StepMotor_Start(StepMotor_Direction direction, uint32_t steps,
                     uint32_t interval_ms, uint32_t now_ms);
void StepMotor_Update(uint32_t now_ms);
/* Releases all coils. This is NOT a mechanical brake. */
void StepMotor_Stop(void);
StepMotor_State StepMotor_GetState(void);
uint32_t StepMotor_GetRemaining(void);
#endif
