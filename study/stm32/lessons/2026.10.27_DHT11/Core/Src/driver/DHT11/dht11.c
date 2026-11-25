#include "dht11.h"

#include <stddef.h>

#define DHT11_PORT GPIOC
#define DHT11_PIN GPIO_PIN_8
#define DHT11_INTERVAL_MS 2000U
#define DHT11_EDGE_TIMEOUT_US 120U
/* Secondary bound also prevents a hang if a debugger stops CYCCNT. */
#define DHT11_POLL_LIMIT 100000U

static uint32_t cycles_per_us;
static uint32_t last_attempt;
static uint8_t initialized;
static uint8_t attempted;

static void pin_input(void)
{
    GPIO_InitTypeDef gpio = {0};
    gpio.Pin = DHT11_PIN;
    gpio.Mode = GPIO_MODE_INPUT;
    gpio.Pull = GPIO_PULLUP;
    HAL_GPIO_Init(DHT11_PORT, &gpio);
}

static void pin_low(void)
{
    GPIO_InitTypeDef gpio = {0};
    HAL_GPIO_WritePin(DHT11_PORT, DHT11_PIN, GPIO_PIN_RESET);
    gpio.Pin = DHT11_PIN;
    gpio.Mode = GPIO_MODE_OUTPUT_OD;
    gpio.Pull = GPIO_PULLUP;
    gpio.Speed = GPIO_SPEED_FREQ_LOW;
    HAL_GPIO_Init(DHT11_PORT, &gpio);
}

static uint32_t level(void)
{
    return (DHT11_PORT->IDR & DHT11_PIN) != 0U;
}

static int counter_running(void)
{
    uint32_t start = DWT->CYCCNT;
    for (volatile uint32_t i = 0U; i < 64U; ++i) {
        __NOP();
    }
    return DWT->CYCCNT != start;
}

/* Unsigned subtraction remains valid across the 32-bit counter wrap. */
static DHT11_Status wait_level(uint32_t target, uint32_t timeout_us)
{
    uint32_t start = DWT->CYCCNT;
    uint32_t limit = timeout_us * cycles_per_us;
    for (uint32_t n = 0U; n < DHT11_POLL_LIMIT; ++n) {
        if ((uint32_t)(DWT->CYCCNT - start) >= limit) {
            return DHT11_ERROR_TIMEOUT;
        }
        if (level() == target) {
            return DHT11_OK;
        }
    }
    return DHT11_ERROR_DWT;
}

DHT11_Status dht11_init(void)
{
    if (__get_IPSR() != 0U || __get_PRIMASK() != 0U) {
        return DHT11_ERROR_CONTEXT;
    }
    initialized = 0U;
    attempted = 0U;
    __HAL_RCC_GPIOC_CLK_ENABLE();
    pin_input();
    SystemCoreClockUpdate();
    cycles_per_us = SystemCoreClock / 1000000U;
    if (cycles_per_us == 0U) {
        return DHT11_ERROR_DWT;
    }
    CoreDebug->DEMCR |= CoreDebug_DEMCR_TRCENA_Msk;
    /* Do not reset CYCCNT: other code may also use the counter. */
    DWT->CTRL |= DWT_CTRL_CYCCNTENA_Msk;
    __DSB();
    __ISB();
    if (!counter_running()) {
        return DHT11_ERROR_DWT;
    }
    HAL_Delay(DHT11_INTERVAL_MS);
    initialized = 1U;
    return DHT11_OK;
}

DHT11_Status dht11_read(DHT11_Data *data)
{
    uint8_t bytes[5] = {0};
    DHT11_Status status;
    uint32_t now;
    uint32_t primask;

    if (data == NULL) return DHT11_ERROR_ARGUMENT;
    if (!initialized) return DHT11_ERROR_NOT_INITIALIZED;
    if (__get_IPSR() != 0U || __get_PRIMASK() != 0U) {
        return DHT11_ERROR_CONTEXT;
    }
    if (!counter_running()) return DHT11_ERROR_DWT;
    now = HAL_GetTick();
    if (attempted && (uint32_t)(now - last_attempt) < DHT11_INTERVAL_MS) {
        return DHT11_ERROR_TOO_SOON;
    }
    attempted = 1U;
    last_attempt = now;
    cycles_per_us = SystemCoreClock / 1000000U;
    if (cycles_per_us == 0U) return DHT11_ERROR_DWT;

    pin_low();
    HAL_Delay(20U); /* DHT11 start LOW must be at least 18 ms. */

    /* Protect pulse capture only, never HAL_Delay. About 3-5 ms.
     * SysTick/UART interrupts are deferred; HAL tick can lose a few ms. */
    primask = __get_PRIMASK();
    __disable_irq();
    pin_input(); /* Release bus; external pull-up raises the signal. */

    status = wait_level(1U, 20U); /* Host release HIGH. */
    if (status != DHT11_OK) goto done;
    status = wait_level(0U, DHT11_EDGE_TIMEOUT_US); /* Response LOW. */
    if (status != DHT11_OK) goto done;
    status = wait_level(1U, DHT11_EDGE_TIMEOUT_US); /* Response HIGH. */
    if (status != DHT11_OK) goto done;
    status = wait_level(0U, DHT11_EDGE_TIMEOUT_US); /* First bit LOW. */
    if (status != DHT11_OK) goto done;

    for (uint32_t bit = 0U; bit < 40U; ++bit) {
        uint32_t start;
        uint32_t high_cycles;
        status = wait_level(1U, DHT11_EDGE_TIMEOUT_US);
        if (status != DHT11_OK) goto done;
        start = DWT->CYCCNT;
        status = wait_level(0U, DHT11_EDGE_TIMEOUT_US);
        if (status != DHT11_OK) goto done;
        high_cycles = (uint32_t)(DWT->CYCCNT - start);
        /* 0: about 26 us HIGH, 1: about 70 us HIGH; MSB first. */
        bytes[bit / 8U] = (uint8_t)((bytes[bit / 8U] << 1U) |
                                  (high_cycles >= 50U * cycles_per_us));
    }
    status = wait_level(1U, DHT11_EDGE_TIMEOUT_US); /* Final LOW ends. */

done:
    __set_PRIMASK(primask);
    /* Pin already remains input on every capture exit. */
    if (status != DHT11_OK) return status;
    if ((uint8_t)(bytes[0] + bytes[1] + bytes[2] + bytes[3]) != bytes[4]) {
        return DHT11_ERROR_CHECKSUM;
    }
    data->humidity_integer = bytes[0];
    data->humidity_decimal = bytes[1];
    data->temperature_integer = bytes[2];
    data->temperature_decimal = bytes[3];
    for (uint32_t i = 0U; i < 5U; ++i) data->raw[i] = bytes[i];
    return DHT11_OK;
}

const char *dht11_status_string(DHT11_Status status)
{
    switch (status) {
    case DHT11_OK: return "OK";
    case DHT11_ERROR_ARGUMENT: return "invalid argument";
    case DHT11_ERROR_NOT_INITIALIZED: return "not initialized";
    case DHT11_ERROR_CONTEXT: return "call from main with IRQ enabled";
    case DHT11_ERROR_DWT: return "DWT counter unavailable";
    case DHT11_ERROR_TOO_SOON: return "read interval below 2 seconds";
    case DHT11_ERROR_TIMEOUT: return "sensor response timeout";
    case DHT11_ERROR_CHECKSUM: return "checksum mismatch";
    default: return "unknown error";
    }
}
