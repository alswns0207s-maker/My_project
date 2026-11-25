#ifndef BLUETOOTH_H
#define BLUETOOTH_H
#include <stdint.h>
uint8_t bluetooth_init(void);
uint8_t bluetooth_read_byte(uint8_t *data);
uint8_t bluetooth_send_byte(uint8_t data);
uint32_t bluetooth_get_overflow_count(void);
uint32_t bluetooth_get_error_count(void);
void bluetooth_service(void);
#endif
