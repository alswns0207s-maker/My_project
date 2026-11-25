/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * File Name          : freertos.c
  * Description        : Code for freertos applications
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

/* Includes ------------------------------------------------------------------*/
#include "FreeRTOS.h"
#include "task.h"
#include "main.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include "cmsis_os.h"
#include "app/car_tasks.h"
#include "driver/motor.h"
#include "driver/button.h"
#include "driver/ultrasonic.h"
#include "driver/bluetooth.h"
#include "app/car_control.h"
#include "app/rtos_trace.h"

/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

typedef struct
{
    uint32_t samples;
    uint32_t interval_min_ms;
    uint32_t interval_max_ms;
    uint32_t interval_avg_us;
    uint32_t work_min_cycles;
    uint32_t work_max_cycles;
    uint32_t work_avg_cycles;
    uint32_t clock_hz;
} control_timing_t;

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */

#define CONTROL_TIMING_SAMPLES 1000U
#define CONTROL_PERIOD_MS 10U

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
/* USER CODE BEGIN Variables */

volatile uint32_t control_interval_ms;
volatile control_timing_t control_timing;
/* Change to 0 in GDB before ControlTask starts to compare with osDelay(). */
volatile uint32_t control_use_fixed_period = 1U;

/* USER CODE END Variables */

/* Private function prototypes -----------------------------------------------*/
/* USER CODE BEGIN FunctionPrototypes */

/* USER CODE END FunctionPrototypes */

/* GetIdleTaskMemory prototype (linked to static allocation support) */
void vApplicationGetIdleTaskMemory( StaticTask_t **ppxIdleTaskTCBBuffer, StackType_t **ppxIdleTaskStackBuffer, uint32_t *pulIdleTaskStackSize );

/* USER CODE BEGIN GET_IDLE_TASK_MEMORY */
static StaticTask_t xIdleTaskTCBBuffer;
static StackType_t xIdleStack[configMINIMAL_STACK_SIZE];

void vApplicationGetIdleTaskMemory( StaticTask_t **ppxIdleTaskTCBBuffer, StackType_t **ppxIdleTaskStackBuffer, uint32_t *pulIdleTaskStackSize )
{
  *ppxIdleTaskTCBBuffer = &xIdleTaskTCBBuffer;
  *ppxIdleTaskStackBuffer = &xIdleStack[0];
  *pulIdleTaskStackSize = configMINIMAL_STACK_SIZE;
  /* place for user code */
}
/* USER CODE END GET_IDLE_TASK_MEMORY */

/* Private application code --------------------------------------------------*/
/* USER CODE BEGIN Application */

/* Tiny task-only mailboxes protected during copies, never during GPIO polling.
 * ControlTask exclusively owns the FSM. MotorTask exclusively owns PWM.
 * Stop is latched independently so a later movement byte cannot overwrite it.
 */
static car_input_t car_inputs;
static car_output_t car_output;

void car_button_task(void)
{
    button_init();
    for (;;)
    {
        car_rtos_trace_mark(CAR_TRACE_JOB_START, 0U);
        button_update();
        uint8_t auto_event = button_get_press_event(BUTTON_0);
        uint8_t manual_event = button_get_press_event(BUTTON_1);
        uint8_t stop = button_is_pressed(BUTTON_2);
        (void)button_get_press_event(BUTTON_2);
        taskENTER_CRITICAL();
        if (stop) car_inputs.stop = 1;
        else if (manual_event) car_inputs.mode_request = 2;
        else if (auto_event) car_inputs.mode_request = 1;
        taskEXIT_CRITICAL();
        car_rtos_trace_mark(CAR_TRACE_JOB_END, 0U);
        osDelay(5);
    }
}
void car_ultrasonic_task(void)
{
    ultrasonic_init();
    for (;;)
    {
        for (unsigned i = 0; i < ULTRASONIC_COUNT; i++)
        {
            car_rtos_trace_mark(CAR_TRACE_JOB_START, (uint16_t)i);
            car_range_t sample = {0};
            sample.valid = ultrasonic_read_cm((ultrasonic_id_t)i, &sample.cm);
            sample.tick = HAL_GetTick();
            taskENTER_CRITICAL();
            car_inputs.range[i] = sample;
            taskEXIT_CRITICAL();
            car_rtos_trace_mark(CAR_TRACE_RANGE, (uint16_t)((i << 10) | sample.cm));
            car_rtos_trace_mark(CAR_TRACE_JOB_END, (uint16_t)i);
            osDelay(60);
        }
    }
}
void car_bluetooth_task(void)
{
    uint32_t old_errors = 0, old_overflows = 0;
    if (!bluetooth_init())
    {
        taskENTER_CRITICAL();
        car_inputs.stop = 1;
        taskEXIT_CRITICAL();
        for (;;) osDelay(100);
    }
    for (;;)
    {
        car_rtos_trace_mark(CAR_TRACE_JOB_START, 0U);
        bluetooth_service();
        uint32_t errors = bluetooth_get_error_count();
        uint32_t overflows = bluetooth_get_overflow_count();
        uint8_t command = 0, mode = 0;
        uint8_t stop = errors != old_errors || overflows != old_overflows;
        old_errors = errors;
        old_overflows = overflows;
        for (unsigned i = 0; i < 64; i++)
        {
            uint8_t data;
            if (!bluetooth_read_byte(&data)) break;
            if (data >= 'a' && data <= 'z') data -= 'a' - 'A';
            switch (data)
            {
            case 'S': stop = 1; break;
            case 'A': mode = 1; command = 0; break;
            case 'M': mode = 2; command = 0; break;
            case 'F': case 'B': case 'L': case 'R': command = data; break;
            default: break; /* CR/LF and unknown bytes do not renew timeout. */
            }
        }
        taskENTER_CRITICAL();
        if (stop) car_inputs.stop = 1;
        if (mode) car_inputs.mode_request = mode;
        if (command) { car_inputs.command = command; car_inputs.command_tick = HAL_GetTick(); }
        taskEXIT_CRITICAL();
        car_rtos_trace_mark(CAR_TRACE_JOB_END, 0U);
        osDelay(5);
    }
}

void car_control_task(void)
{
    car_control_t car;
    car_control_init(&car);

    uint32_t last_start_ms = 0U;
    uint32_t samples = 0U;
    uint32_t interval_min_ms = UINT32_MAX, interval_max_ms = 0U;
    uint32_t work_min_cycles = UINT32_MAX, work_max_cycles = 0U;
    uint64_t interval_sum_ms = 0U, work_sum_cycles = 0U;
    uint8_t have_last_start = 0U;

    /* Share the cycle counter with the ultrasonic driver without resetting it. */
    CoreDebug->DEMCR |= CoreDebug_DEMCR_TRCENA_Msk;
    DWT->CTRL |= DWT_CTRL_CYCCNTENA_Msk;
    control_timing.clock_hz = HAL_RCC_GetHCLKFreq();

    TickType_t last_release = xTaskGetTickCount();
    const TickType_t period = pdMS_TO_TICKS(CONTROL_PERIOD_MS);
    const uint8_t fixed_period = control_use_fixed_period != 0U;
    for (;;)
    {
        car_rtos_trace_mark(CAR_TRACE_JOB_START, 0U);
        // [추가 1] ControlTask 실행 시작
        uint32_t start_ms = HAL_GetTick();
        HAL_GPIO_WritePin(GPIOB, GPIO_PIN_0, GPIO_PIN_SET);
        uint32_t work_start = DWT->CYCCNT;

        car_input_t input;
        taskENTER_CRITICAL();
        input = car_inputs;
        car_inputs.stop = car_inputs.mode_request = car_inputs.command = 0;
        taskEXIT_CRITICAL();

        car_output_t output =
            car_control_step(&car, &input, HAL_GetTick());

        taskENTER_CRITICAL();
        car_output = output;
        taskEXIT_CRITICAL();

        // [추가 2] ControlTask 처리 종료
        uint32_t work_cycles = DWT->CYCCNT - work_start;
        HAL_GPIO_WritePin(GPIOB, GPIO_PIN_0, GPIO_PIN_RESET);

        if (have_last_start)
        {
            uint32_t interval_ms = start_ms - last_start_ms;
            control_interval_ms = interval_ms;

            if (samples < CONTROL_TIMING_SAMPLES)
            {
                if (interval_ms < interval_min_ms) interval_min_ms = interval_ms;
                if (interval_ms > interval_max_ms) interval_max_ms = interval_ms;
                if (work_cycles < work_min_cycles) work_min_cycles = work_cycles;
                if (work_cycles > work_max_cycles) work_max_cycles = work_cycles;
                interval_sum_ms += interval_ms;
                work_sum_cycles += work_cycles;
                ++samples;

                if (samples == CONTROL_TIMING_SAMPLES)
                {
                    control_timing.interval_min_ms = interval_min_ms;
                    control_timing.interval_max_ms = interval_max_ms;
                    control_timing.interval_avg_us =
                        (uint32_t)((interval_sum_ms * 1000U + CONTROL_TIMING_SAMPLES / 2U) /
                                   CONTROL_TIMING_SAMPLES);
                    control_timing.work_min_cycles = work_min_cycles;
                    control_timing.work_max_cycles = work_max_cycles;
                    control_timing.work_avg_cycles =
                        (uint32_t)((work_sum_cycles + CONTROL_TIMING_SAMPLES / 2U) /
                                   CONTROL_TIMING_SAMPLES);
                }
                control_timing.samples = samples;
            }
        }
        last_start_ms = start_ms;
        have_last_start = 1U;
        car_rtos_trace_mark(CAR_TRACE_JOB_END, 0U);
        if (fixed_period)
        {
            const TickType_t elapsed = xTaskGetTickCount() - last_release;
            if (elapsed > period)
            {
                /* Retain phase but skip missed releases instead of running a burst. */
                const TickType_t missed = elapsed / period;
                last_release += missed * period;
                car_rtos_trace_mark(CAR_TRACE_SKIPPED_RELEASES,
                                    missed > UINT16_MAX ? UINT16_MAX : (uint16_t)missed);
            }
            vTaskDelayUntil(&last_release, period);
        }
        else
        {
            osDelay(CONTROL_PERIOD_MS);
        }
    }
}

void car_motor_task(void)
{
    int16_t last_left = 0, last_right = 0;
    uint32_t left_drive_tick = 0, right_drive_tick = 0;
    motor_init();
    for (;;)
    {
        car_rtos_trace_mark(CAR_TRACE_JOB_START, 0U);
        car_output_t output;
        uint8_t stop;
        taskENTER_CRITICAL();
        output = car_output;
        stop = car_inputs.stop;
        taskEXIT_CRITICAL();
        uint32_t now = HAL_GetTick();
        if (stop || (uint32_t)(now - output.tick) >= 100U)
            output.left = output.right = 0;
        if (((last_left * output.left < 0) && (uint32_t)(now - left_drive_tick) < 50U) ||
            ((last_right * output.right < 0) && (uint32_t)(now - right_drive_tick) < 50U))
            output.left = output.right = 0;
        motor_set(output.left, output.right);
        if (output.left) { last_left = output.left; left_drive_tick = now; }
        if (output.right) { last_right = output.right; right_drive_tick = now; }
        car_rtos_trace_mark(CAR_TRACE_JOB_END, 0U);
        osDelay(5);
    }
}


/* USER CODE END Application */
