#include "fnd.h"

static const uint8_t fndFont[10] = {
  0x3F, 0x06, 0x5B, 0x4F, 0x66,
  0x6D, 0x7D, 0x07, 0x7F, 0x6F
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

static uint16_t fndData;
static uint8_t digitPos;
static uint32_t prevTime;

static void FND_DigitOff(void)
{
  for (uint8_t i = 0; i < 4; i++) {
    HAL_GPIO_WritePin(digitPort[i], digitPin[i],
                     FND_COMMON_ANODE ? GPIO_PIN_RESET : GPIO_PIN_SET);
  }
}

static void FND_WriteSegments(uint8_t pattern)
{
  for (uint8_t i = 0; i < 8; i++) {
    GPIO_PinState pinState = (pattern & (1U << i)) ? GPIO_PIN_SET : GPIO_PIN_RESET;
    if (FND_COMMON_ANODE) {
      pinState = (pinState == GPIO_PIN_SET) ? GPIO_PIN_RESET : GPIO_PIN_SET;
    }
    HAL_GPIO_WritePin(segmentPort[i], segmentPin[i], pinState);
  }
}

void FND_Init(void)
{
  fndData = 0;
  digitPos = 0;
  prevTime = HAL_GetTick() - 1U;
  FND_DigitOff();
  FND_WriteSegments(0);
}

void FND_SetData(uint16_t data)
{
  fndData = data % 10000U;
}

void FND_Disp(void)
{
  uint32_t curTime = HAL_GetTick();
  uint8_t number;

  if ((uint32_t)(curTime - prevTime) < 1U) {
    return;
  }
  prevTime = curTime;

  switch (digitPos) {
    case 0: number = fndData / 1000U; break;
    case 1: number = fndData / 100U % 10U; break;
    case 2: number = fndData / 10U % 10U; break;
    default: number = fndData % 10U; break;
  }

  /* Blank all digits before changing their shared segment lines. */
  FND_DigitOff();
  FND_WriteSegments(fndFont[number]);
  HAL_GPIO_WritePin(digitPort[digitPos], digitPin[digitPos],
                   FND_COMMON_ANODE ? GPIO_PIN_SET : GPIO_PIN_RESET);
  digitPos = (digitPos + 1U) % 4U;
}
