/*
 * button.h
 *
 *  Created on: 2026. 11. 13.
 *      Author: kccistc
 */

#ifndef SRC_DRIVER_BUTTON_H_
#define SRC_DRIVER_BUTTON_H_

#include <stdint.h>

typedef enum
{
    BUTTON_0 = 0,
    BUTTON_1,
    BUTTON_2,
    BUTTON_COUNT
} button_id_t;

void button_init(void);
void button_update(void);

uint8_t button_is_pressed(button_id_t button);
uint8_t button_get_press_event(button_id_t button);



#endif /* SRC_DRIVER_BUTTON_H_ */
