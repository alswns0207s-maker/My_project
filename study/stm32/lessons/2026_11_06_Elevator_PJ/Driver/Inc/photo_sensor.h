#ifndef PHOTO_SENSOR_H
#define PHOTO_SENSOR_H
#include <stdint.h>
/* Electrical level only: bit 0/1/2 = floor 1/2/3, 1 = HIGH.
 * NOT a pressed/detected mask. No assumed polarity, debounce or pull resistor.
 * GPIO input configuration remains owned by CubeMX.
 */
uint32_t PhotoSensor_ReadRaw(void);
#endif
