#ifndef ELEVATOR_H
#define ELEVATOR_H
#include <stdint.h>
/* MANUAL commissioning, not automatic floor selection.
 * Button 1 click=forward; button 2=stop/reset fault; button 3 click=reverse.
 * Runs for max 8 seconds per press; release all before restarting. Opposite button stops. */
typedef enum { ELEVATOR_DISABLED, ELEVATOR_READY, ELEVATOR_TESTING,
               ELEVATOR_DONE, ELEVATOR_FAULT } Elevator_State;
extern volatile Elevator_State elevator_state;
extern volatile uint32_t elevator_button_raw, elevator_photo_raw;
extern volatile uint32_t elevator_input_samples, elevator_buttons_pressed;
extern volatile uint32_t elevator_direction; /* 0 stopped, 1 forward, 2 reverse */
extern volatile uint32_t elevator_forward_starts, elevator_reverse_starts;
extern volatile uint32_t elevator_last_stop_reason;
void Elevator_Init(void);
void Elevator_Run(uint32_t now_ms);
#endif
