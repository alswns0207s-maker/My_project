#ifndef SRC_DRIVER_FND_FND_H_
#define SRC_DRIVER_FND_FND_H_
#include "main.h"
/* Supplied wiring: segment HIGH, digit LOW for a common cathode FND. */
#ifndef FND_COMMON_ANODE
#define FND_COMMON_ANODE 0
#endif
void fnd_init(void);
/* dotMask bits 0..3 correspond to left-to-right digits D1..D4. */
void fnd_set_frame(uint16_t number, uint8_t dotMask);
void fnd_set_num(uint16_t number);
uint16_t fnd_get_num(void);
void fnd_show_number(void); /* Exactly one digit per TIM3 interrupt. */
#endif
