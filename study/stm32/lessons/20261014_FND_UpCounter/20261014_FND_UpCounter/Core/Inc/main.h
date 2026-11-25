/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.h
  * @brief          : Header for main.c file.
  *                   This file contains the common defines of the application.
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2026 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */

/* Define to prevent recursive inclusion -------------------------------------*/
#ifndef __MAIN_H
#define __MAIN_H

#ifdef __cplusplus
extern "C" {
#endif

/* Includes ------------------------------------------------------------------*/
#include "stm32f4xx_hal.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */

/* USER CODE END Includes */

/* Exported types ------------------------------------------------------------*/
/* USER CODE BEGIN ET */

/* USER CODE END ET */

/* Exported constants --------------------------------------------------------*/
/* USER CODE BEGIN EC */

/* USER CODE END EC */

/* Exported macro ------------------------------------------------------------*/
/* USER CODE BEGIN EM */

/* USER CODE END EM */

/* Exported functions prototypes ---------------------------------------------*/
void Error_Handler(void);

/* USER CODE BEGIN EFP */

/* USER CODE END EFP */

/* Private defines -----------------------------------------------------------*/
#define BTN_RUN_STOP_Pin GPIO_PIN_0
#define BTN_RUN_STOP_GPIO_Port GPIOC
#define BTN_CLEAR_Pin GPIO_PIN_1
#define BTN_CLEAR_GPIO_Port GPIOC
#define FND_D1_Pin GPIO_PIN_5
#define FND_D1_GPIO_Port GPIOA
#define FND_A_Pin GPIO_PIN_6
#define FND_A_GPIO_Port GPIOA
#define FND_F_Pin GPIO_PIN_7
#define FND_F_GPIO_Port GPIOA
#define FND_D_Pin GPIO_PIN_10
#define FND_D_GPIO_Port GPIOB
#define FND_D3_Pin GPIO_PIN_7
#define FND_D3_GPIO_Port GPIOC
#define FND_E_Pin GPIO_PIN_8
#define FND_E_GPIO_Port GPIOA
#define FND_B_Pin GPIO_PIN_9
#define FND_B_GPIO_Port GPIOA
#define FND_D4_Pin GPIO_PIN_10
#define FND_D4_GPIO_Port GPIOA
#define FND_G_Pin GPIO_PIN_3
#define FND_G_GPIO_Port GPIOB
#define FND_DP_Pin GPIO_PIN_4
#define FND_DP_GPIO_Port GPIOB
#define FND_C_Pin GPIO_PIN_5
#define FND_C_GPIO_Port GPIOB
#define FND_D2_Pin GPIO_PIN_6
#define FND_D2_GPIO_Port GPIOB

/* USER CODE BEGIN Private defines */

/* USER CODE END Private defines */

#ifdef __cplusplus
}
#endif

#endif /* __MAIN_H */
