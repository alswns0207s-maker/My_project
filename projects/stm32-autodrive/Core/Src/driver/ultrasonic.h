#ifndef ULTRASONIC_H
#define ULTRASONIC_H
#include <stdint.h>
typedef enum { ULTRASONIC_FRONT, ULTRASONIC_LEFT, ULTRASONIC_RIGHT, ULTRASONIC_COUNT } ultrasonic_id_t;
void ultrasonic_init(void);
uint8_t ultrasonic_read_cm(ultrasonic_id_t sensor, uint16_t *distance_cm);
#endif
