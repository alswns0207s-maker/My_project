#include "car_control.h"
static void car_stop(car_control_t *car)
{ car->mode = CAR_STOPPED; car->state = CAR_IDLE; car->command = 0; }
void car_control_init(car_control_t *car)
{ *car = (car_control_t){0}; }
static uint8_t car_range_ok(const car_range_t *range, uint32_t now)
{
    return range->valid && range->cm >= 2 && range->cm <= 400 &&
           (uint32_t)(now - range->tick) < CAR_SENSOR_MAX_AGE_MS;
}
car_output_t car_control_step(car_control_t *car, const car_input_t *input, uint32_t now)
{
    car_output_t out = {0, 0, now};
    if (input->stop || input->command == 'S') { car_stop(car); return out; }
    if (input->mode_request)
    {
        car_stop(car);
        car->mode = input->mode_request == 1 ? CAR_AUTO : CAR_MANUAL;
        car->state_tick = now;
        return out; /* Never move in the mode-switch cycle. */
    }
    if (car->mode == CAR_STOPPED) return out;
    if (car->mode == CAR_MANUAL)
    {
        if (input->command == 'F' || input->command == 'B' ||
            input->command == 'L' || input->command == 'R')
        { car->command = input->command; car->command_tick = input->command_tick; }
        if (!car->command) return out;
        if ((uint32_t)(now - car->command_tick) >= CAR_MANUAL_TIMEOUT_MS)
        { car_stop(car); return out; }
        switch (car->command)
        {
        case 'F': out.left = out.right = CAR_SPEED; break;
        case 'B': out.left = out.right = -CAR_SPEED; break;
        case 'L': out.left = CAR_SPEED / 2; out.right = CAR_SPEED; break;
        case 'R': out.left = CAR_SPEED; out.right = CAR_SPEED / 2; break;
        default: break;
        }
        return out;
    }
    for (unsigned i = 0; i < 3; i++)
        if (!car_range_ok(&input->range[i], now)) { car_stop(car); return out; }
    if (car->state == CAR_TURN_LEFT || car->state == CAR_TURN_RIGHT)
    {
        unsigned side = car->state == CAR_TURN_LEFT ? 1 : 2;
        if (input->range[side].cm <= CAR_STOP_CM) { car_stop(car); return out; }
        if ((uint32_t)(now - car->state_tick) >= 350U)
        { car->state = CAR_SETTLE; car->state_tick = now; return out; }
        out.left = car->state == CAR_TURN_LEFT ? -CAR_SPEED : CAR_SPEED;
        out.right = -out.left;
        return out;
    }
    if (car->state == CAR_SETTLE)
    {
        if ((uint32_t)(now - car->state_tick) < 300U) return out;
        car->state = CAR_IDLE;
    }
    uint16_t front = input->range[0].cm;
    if (front >= CAR_CLEAR_CM || (car->state == CAR_FORWARD && front > CAR_STOP_CM))
    { car->state = CAR_FORWARD; out.left = out.right = CAR_SPEED; return out; }
    uint16_t left = input->range[1].cm, right = input->range[2].cm;
    if (left < CAR_CLEAR_CM && right < CAR_CLEAR_CM) { car_stop(car); return out; }
    car->state = left >= right ? CAR_TURN_LEFT : CAR_TURN_RIGHT;
    car->state_tick = now;
    return out; /* One stopped cycle before turning. */
}
