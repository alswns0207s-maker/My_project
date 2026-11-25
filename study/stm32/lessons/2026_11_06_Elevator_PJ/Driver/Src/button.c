#include "button.h"
#include "stm32f4xx_hal.h"
#include <stdbool.h>
static uint32_t raw, stable, candidate, changed_at[3];
static bool seeded;
uint32_t Button_ReadRaw(void)
{
    uint32_t mask = 0U;
    if (HAL_GPIO_ReadPin(GPIOC, GPIO_PIN_0) == GPIO_PIN_SET) mask |= 1U;
    if (HAL_GPIO_ReadPin(GPIOC, GPIO_PIN_1) == GPIO_PIN_SET) mask |= 2U;
    if (HAL_GPIO_ReadPin(GPIOC, GPIO_PIN_3) == GPIO_PIN_SET) mask |= 4U;
    return mask;
}
void Button_Init(void)
{
    raw = stable = candidate = Button_ReadRaw();
    seeded = false;
}
void Button_Update(uint32_t now_ms)
{
    raw = Button_ReadRaw();
    if (!seeded) {
        seeded = true;
        stable = candidate = raw;
        for (unsigned i = 0; i < 3; ++i) changed_at[i] = now_ms;
        return;
    }
    for (unsigned i = 0; i < 3; ++i) {
        uint32_t bit = 1U << i;
        if ((raw ^ candidate) & bit) {
            candidate = (candidate & ~bit) | (raw & bit);
            changed_at[i] = now_ms;
        }
        if (now_ms - changed_at[i] >= 20U)
            stable = (stable & ~bit) | (candidate & bit);
    }
}
uint32_t Button_GetPressed(void) { return (~stable) & 7U; }
uint32_t Button_GetRawPressed(void) { return (~raw) & 7U; }
