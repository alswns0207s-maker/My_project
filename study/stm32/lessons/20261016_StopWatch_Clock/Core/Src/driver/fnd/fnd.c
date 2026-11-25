#include "fnd.h"

static const uint8_t font[10] = {
    0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F
};
static GPIO_TypeDef *const segmentPort[8] = {
    FND_A_GPIO_Port, FND_B_GPIO_Port, FND_C_GPIO_Port, FND_D_GPIO_Port,
    FND_E_GPIO_Port, FND_F_GPIO_Port, FND_G_GPIO_Port, FND_DP_GPIO_Port
};
static const uint16_t segmentPin[8] = {
    FND_A_Pin, FND_B_Pin, FND_C_Pin, FND_D_Pin,
    FND_E_Pin, FND_F_Pin, FND_G_Pin, FND_DP_Pin
};
static GPIO_TypeDef *const digitPort[4] = {
    FND_D1_GPIO_Port, FND_D2_GPIO_Port, FND_D3_GPIO_Port, FND_D4_GPIO_Port
};
static const uint16_t digitPin[4] = {
    FND_D1_Pin, FND_D2_Pin, FND_D3_Pin, FND_D4_Pin
};

/* One aligned word publishes the number and decimal points together. */
static volatile uint32_t pendingFrame;
static uint32_t scanFrame;
static uint8_t digit;

static void fnd_all_off(void)
{
    for (uint8_t i = 0U; i < 4U; ++i) {
        HAL_GPIO_WritePin(digitPort[i], digitPin[i],
                         FND_COMMON_ANODE ? GPIO_PIN_RESET : GPIO_PIN_SET);
    }
}

static void fnd_write_segments(uint8_t pattern)
{
    for (uint8_t i = 0U; i < 8U; ++i) {
        GPIO_PinState level = (pattern & (1U << i)) ? GPIO_PIN_SET : GPIO_PIN_RESET;
        if (FND_COMMON_ANODE) {
            level = (level == GPIO_PIN_SET) ? GPIO_PIN_RESET : GPIO_PIN_SET;
        }
        HAL_GPIO_WritePin(segmentPort[i], segmentPin[i], level);
    }
}

void fnd_init(void)
{
    pendingFrame = 0U;
    scanFrame = 0U;
    digit = 0U;
    fnd_all_off();
    fnd_write_segments(0U);
}

void fnd_set_frame(uint16_t number, uint8_t dotMask)
{
    pendingFrame = ((uint32_t)(dotMask & 0x0FU) << 16U) | (number % 10000U);
}

void fnd_set_num(uint16_t number)
{
    fnd_set_frame(number, 0U);
}

uint16_t fnd_get_num(void)
{
    return (uint16_t)(pendingFrame & 0xFFFFU);
}

void fnd_show_number(void)
{
    static const uint16_t divisor[4] = {1000U, 100U, 10U, 1U};
    if (digit == 0U) {
        /* Retain this snapshot until all four digits have been scanned. */
        scanFrame = pendingFrame;
    }
    uint16_t number = (uint16_t)(scanFrame & 0xFFFFU);
    uint8_t pattern = font[(number / divisor[digit]) % 10U];
    if ((scanFrame & (1UL << (16U + digit))) != 0U) {
        pattern |= 0x80U;
    }
    fnd_all_off();
    fnd_write_segments(pattern);
    HAL_GPIO_WritePin(digitPort[digit], digitPin[digit],
                     FND_COMMON_ANODE ? GPIO_PIN_SET : GPIO_PIN_RESET);
    digit = (digit + 1U) % 4U;
}
