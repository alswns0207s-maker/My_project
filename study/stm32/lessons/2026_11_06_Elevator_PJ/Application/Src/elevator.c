#include "elevator.h"
#include "stepmotor.h"
#include "button.h"
#include "photo_sensor.h"
#include <stdbool.h>

volatile Elevator_State elevator_state;
volatile uint32_t elevator_button_raw, elevator_photo_raw;
volatile uint32_t elevator_input_samples, elevator_buttons_pressed;
volatile uint32_t elevator_direction;
volatile uint32_t elevator_forward_starts, elevator_reverse_starts;
volatile uint32_t elevator_last_stop_reason;
/* Reasons: 1=opposite direction pressed, 2=stop/conflicting buttons, 3=time limit, 4=timing fault. */
static uint32_t started_at, released_at;
static bool release_timing;

static void stop_at(Elevator_State next)
{
    StepMotor_Stop();
    elevator_direction = 0U;
    elevator_state = next;
    release_timing = false;
}

void Elevator_Init(void)
{
    StepMotor_Init();
    Button_Init();
    elevator_button_raw = Button_ReadRaw();
    elevator_photo_raw = PhotoSensor_ReadRaw();
    elevator_input_samples = 0U;
    elevator_forward_starts = elevator_reverse_starts = 0U;
    elevator_last_stop_reason = 0U;
    elevator_buttons_pressed = Button_GetPressed();
    stop_at(ELEVATOR_DISABLED); /* all released for 100 ms before arming */
}

void Elevator_Run(uint32_t now_ms)
{
    Button_Update(now_ms);
    elevator_button_raw = Button_ReadRaw();
    elevator_buttons_pressed = Button_GetPressed();
    elevator_photo_raw = PhotoSensor_ReadRaw(); /* polarity not assumed */
    ++elevator_input_samples;
    uint32_t pressed = elevator_buttons_pressed;
    uint32_t raw = Button_GetRawPressed();

    if (elevator_state == ELEVATOR_FAULT) {
        /* Explicit stop button acknowledgement with direction buttons released. */
        if (pressed == 2U && raw == 2U) stop_at(ELEVATOR_DONE);
        return;
    }
    if ((raw & 2U) || (pressed & 2U) || (raw & 5U) == 5U) {
        elevator_last_stop_reason = 2U;
        stop_at(ELEVATOR_DONE);
        return;
    }
    if (elevator_state == ELEVATOR_TESTING) {
        /* A released button does not cancel a latched 8-second move.
         * An opposite-direction press stops; release and press again to reverse. */
        uint32_t opposite = elevator_direction == 1U ? 4U : 1U;
        if (pressed & opposite) {
            elevator_last_stop_reason = 1U;
            stop_at(ELEVATOR_DONE);
            return;
        }
        StepMotor_Update(now_ms);
        if (StepMotor_GetState() == STEPMOTOR_FAULT || now_ms - started_at > 10000U) {
            elevator_last_stop_reason = 4U;
            stop_at(ELEVATOR_FAULT);
        } else if (StepMotor_GetState() == STEPMOTOR_DONE) {
            elevator_last_stop_reason = 3U;
            stop_at(ELEVATOR_DONE);
        }
        return;
    }
    if (elevator_state != ELEVATOR_READY) {
        if (raw == 0U && pressed == 0U) {
            if (!release_timing) { released_at = now_ms; release_timing = true; }
            if (now_ms - released_at >= 100U) elevator_state = ELEVATOR_READY;
        } else release_timing = false;
        return;
    }
    if ((pressed == 1U || pressed == 4U) && raw == pressed) {
        if (StepMotor_Start(pressed == 1U ? STEPMOTOR_FORWARD : STEPMOTOR_REVERSE,
                            1600U, 5U, now_ms)) {
            started_at = now_ms;
            elevator_direction = pressed == 1U ? 1U : 2U;
            elevator_state = ELEVATOR_TESTING;
            elevator_last_stop_reason = 0U;
            if (pressed == 1U) ++elevator_forward_starts;
            else ++elevator_reverse_starts;
        } else stop_at(ELEVATOR_FAULT);
    }
}
