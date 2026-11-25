#include "rtos_trace.h"
#include "FreeRTOS.h"
#include "task.h"
#include "cmsis_os.h"
#include "main.h"

#define TRACE_CAPACITY 1024U
#define TRACE_MAGIC 0x52544F53U

typedef struct
{
    uint32_t cycles;
    uint8_t task_id;
    uint8_t kind;
    uint16_t value;
} trace_event_t;

typedef struct
{
    uint32_t magic;
    uint32_t hclk_hz;
    uint32_t count;
    uint32_t complete;
    trace_event_t events[TRACE_CAPACITY];
} trace_capture_t;

_Static_assert(sizeof(trace_event_t) == 8U, "Trace decoder event layout");
_Static_assert(sizeof(trace_capture_t) == 16U + TRACE_CAPACITY * 8U,
               "Trace decoder capture layout");

extern osThreadId MotorTaskHandle;
extern osThreadId ControlTaskHandle;
extern osThreadId BluetoothTaskHandle;
extern osThreadId ButtonTaskHandle;
extern osThreadId UltrasonicTaskHandle;
extern osThreadId defaultTaskHandle;

/* Set request to 1 from GDB while stopped, then resume for a fresh capture. */
volatile uint32_t rtos_trace_request = 1U;
volatile trace_capture_t rtos_trace_capture;

static const void *previous_task;
static uint8_t running_task_id;
static volatile uint8_t capturing;

static uint8_t task_id(const void *task)
{
    if (task == MotorTaskHandle) return 1U;
    if (task == ControlTaskHandle) return 2U;
    if (task == BluetoothTaskHandle) return 3U;
    if (task == ButtonTaskHandle) return 4U;
    if (task == UltrasonicTaskHandle) return 5U;
    if (task == defaultTaskHandle) return 6U;
    return 0U; /* FreeRTOS Idle or a system task outside the car application. */
}

static void record_event(uint8_t kind, uint16_t value)
{
    const uint32_t index = rtos_trace_capture.count;

    rtos_trace_capture.events[index] = (trace_event_t){
        .cycles = DWT->CYCCNT,
        .task_id = running_task_id,
        .kind = kind,
        .value = value
    };
    rtos_trace_capture.count = index + 1U;
    if (index + 1U == TRACE_CAPACITY)
    {
        capturing = 0U;
        rtos_trace_capture.complete = 1U;
    }
}

void car_rtos_trace_switch_in(const void *task)
{
    if (rtos_trace_request != 0U)
    {
        rtos_trace_request = 0U;
        CoreDebug->DEMCR |= CoreDebug_DEMCR_TRCENA_Msk;
        DWT->CTRL |= DWT_CTRL_CYCCNTENA_Msk;

        rtos_trace_capture.complete = 0U;
        rtos_trace_capture.magic = TRACE_MAGIC;
        rtos_trace_capture.hclk_hz = SystemCoreClock;
        rtos_trace_capture.count = 0U;
        previous_task = NULL;
        capturing = 1U;
    }

    if (capturing && task != previous_task)
    {
        previous_task = task;
        running_task_id = task_id(task);
        record_event(CAR_TRACE_SWITCH_IN, 0U);
    }
}

void car_rtos_trace_mark(uint8_t kind, uint16_t value)
{
    if (capturing)
    {
        /* Serialize task markers with the switch hook. Interrupts still run
         * according to the normal FreeRTOS BASEPRI threshold. */
        taskENTER_CRITICAL();
        if (capturing) record_event(kind, value);
        taskEXIT_CRITICAL();
    }
}
