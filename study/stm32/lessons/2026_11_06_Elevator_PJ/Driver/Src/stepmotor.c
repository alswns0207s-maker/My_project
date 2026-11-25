#include "stepmotor.h"
#include "stm32f4xx_hal.h"

/* Bit 0..3 = IN1..IN4. Direction is electrical, not floor direction. */
static const uint8_t phases[8] = {0x1, 0x3, 0x2, 0x6, 0x4, 0xC, 0x8, 0x9};
static StepMotor_State state;
static uint32_t remaining, interval, last_tick;
static uint8_t phase;
static int8_t direction;
static bool initialized;

static void write_coils(uint8_t bits)
{
    /* Clear inactive coils first, then energize the requested coils. */
    if (!(bits & 1U)) HAL_GPIO_WritePin(GPIOA, GPIO_PIN_0, GPIO_PIN_RESET);
    if (!(bits & 2U)) HAL_GPIO_WritePin(GPIOA, GPIO_PIN_1, GPIO_PIN_RESET);
    if (!(bits & 4U)) HAL_GPIO_WritePin(GPIOA, GPIO_PIN_4, GPIO_PIN_RESET);
    if (!(bits & 8U)) HAL_GPIO_WritePin(GPIOB, GPIO_PIN_0, GPIO_PIN_RESET);
    if (bits & 1U) HAL_GPIO_WritePin(GPIOA, GPIO_PIN_0, GPIO_PIN_SET);
    if (bits & 2U) HAL_GPIO_WritePin(GPIOA, GPIO_PIN_1, GPIO_PIN_SET);
    if (bits & 4U) HAL_GPIO_WritePin(GPIOA, GPIO_PIN_4, GPIO_PIN_SET);
    if (bits & 8U) HAL_GPIO_WritePin(GPIOB, GPIO_PIN_0, GPIO_PIN_SET);
}

void StepMotor_Init(void)
{
    initialized = true;
    StepMotor_Stop();
}

void StepMotor_Stop(void)
{
    if (initialized) write_coils(0);
    remaining = 0;
    state = STEPMOTOR_IDLE;
}

bool StepMotor_Start(StepMotor_Direction dir, uint32_t steps,
                     uint32_t interval_ms, uint32_t now_ms)
{
    /* Bench limits; deliberate explicit reset after a timing fault. */
    if (!initialized || state == STEPMOTOR_RUNNING || state == STEPMOTOR_FAULT ||
        (dir != STEPMOTOR_FORWARD && dir != STEPMOTOR_REVERSE) ||
        steps == 0U || steps > 4096U || interval_ms < 5U || interval_ms > 20U)
        return false;
    direction = (int8_t)dir;
    remaining = steps;
    interval = interval_ms;
    last_tick = now_ms;
    /* Initial excitation aligns the rotor; it is not a measured move. */
    phase = 0;
    write_coils(phases[phase]);
    state = STEPMOTOR_RUNNING;
    return true;
}

void StepMotor_Update(uint32_t now_ms)
{
    if (state != STEPMOTOR_RUNNING) return;
    uint32_t elapsed = now_ms - last_tick; /* uint32_t wrap-safe */
    if (elapsed > 100U) {
        write_coils(0);
        remaining = 0;
        state = STEPMOTOR_FAULT;
        return;
    }
    if (elapsed < interval) return;
    last_tick = now_ms; /* Never catch up with a burst of steps. */
    if (remaining == 0U) {
        /* Keep the final phase energized for a complete interval. */
        write_coils(0);
        state = STEPMOTOR_DONE;
        return;
    }
    phase = (uint8_t)((phase + (direction > 0 ? 1U : 7U)) & 7U);
    write_coils(phases[phase]);
    --remaining;
}

StepMotor_State StepMotor_GetState(void) { return state; }
uint32_t StepMotor_GetRemaining(void) { return remaining; }
