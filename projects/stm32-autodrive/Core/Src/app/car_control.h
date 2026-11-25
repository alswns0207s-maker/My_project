#ifndef CAR_CONTROL_H
#define CAR_CONTROL_H
#include <stdint.h>
#define CAR_SENSOR_MAX_AGE_MS 500U
#define CAR_MANUAL_TIMEOUT_MS 500U
#define CAR_STOP_CM 25U
#define CAR_CLEAR_CM 35U
#define CAR_SPEED 35
/* All timestamps use HAL_GetTick milliseconds; subtraction tolerates wrap. */
typedef enum { CAR_STOPPED, CAR_MANUAL, CAR_AUTO } car_mode_t;
typedef enum { CAR_IDLE, CAR_FORWARD, CAR_TURN_LEFT, CAR_TURN_RIGHT, CAR_SETTLE } car_state_t;
typedef struct { uint16_t cm; uint8_t valid; uint32_t tick; } car_range_t;
typedef struct {
    car_range_t range[3]; /* front, left, right */
    uint8_t stop, mode_request, command; /* mode request: 1 auto, 2 manual */
    uint32_t command_tick;
} car_input_t;
typedef struct { int16_t left, right; uint32_t tick; } car_output_t;
typedef struct {
    car_mode_t mode;
    car_state_t state;
    uint8_t command;
    uint32_t command_tick, state_tick;
} car_control_t;
void car_control_init(car_control_t *car);
car_output_t car_control_step(car_control_t *car, const car_input_t *input, uint32_t now);
#endif
