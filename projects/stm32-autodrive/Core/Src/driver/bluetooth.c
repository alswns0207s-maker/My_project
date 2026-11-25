#include "bluetooth.h"
#include "main.h"
extern UART_HandleTypeDef huart6;
#define BT_SIZE 64U
static uint8_t rx_byte, buffer[BT_SIZE];
static volatile uint16_t head, tail;
static volatile uint32_t overflows, errors;
static volatile uint8_t recovery;
uint8_t bluetooth_init(void)
{
    head = tail = 0;
    overflows = errors = 0;
    recovery = 0;
    return HAL_UART_Receive_IT(&huart6, &rx_byte, 1) == HAL_OK;
}
void HAL_UART_RxCpltCallback(UART_HandleTypeDef *uart)
{
    if (uart->Instance != USART6) return;
    uint16_t next = (head + 1U) % BT_SIZE;
    if (next == tail) { overflows++; recovery = 1; }
    else { buffer[head] = rx_byte; __DMB(); head = next; }
    if (HAL_UART_Receive_IT(uart, &rx_byte, 1) != HAL_OK)
    { errors++; recovery = 1; }
}
void HAL_UART_ErrorCallback(UART_HandleTypeDef *uart)
{
    if (uart->Instance == USART6) { errors++; recovery = 1; }
}
/* Called only by BluetoothTask. Drop potentially corrupted pending commands. */
void bluetooth_service(void)
{
    uint32_t mask = __get_PRIMASK();
    __disable_irq();
    if (recovery)
    {
        HAL_UART_AbortReceive(&huart6);
        __HAL_UART_CLEAR_OREFLAG(&huart6);
        tail = head;
        recovery = HAL_UART_Receive_IT(&huart6, &rx_byte, 1) != HAL_OK;
        if (recovery) errors++;
    }
    __set_PRIMASK(mask);
}
uint8_t bluetooth_read_byte(uint8_t *data)
{
    if (!data || recovery || tail == head) return 0;
    uint16_t pos = tail;
    __DMB();
    *data = buffer[pos];
    __DMB();
    tail = (pos + 1U) % BT_SIZE;
    return 1;
}
uint8_t bluetooth_send_byte(uint8_t data)
{ return HAL_UART_Transmit(&huart6, &data, 1, 20) == HAL_OK; }
uint32_t bluetooth_get_overflow_count(void) { return overflows; }
uint32_t bluetooth_get_error_count(void) { return errors; }
