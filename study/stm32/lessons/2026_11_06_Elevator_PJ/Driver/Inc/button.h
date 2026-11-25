#ifndef BUTTON_H
#define BUTTON_H
#include <stdint.h>
/* PC0, PC1, PC3 idle levels were measured HIGH on this board.
 * Manual control uses active LOW. Preserve CubeMX input/pull configuration.
 * Bits 0,1,2 correspond to the three physical buttons. */
void Button_Init(void);
void Button_Update(uint32_t now_ms);
uint32_t Button_ReadRaw(void);
uint32_t Button_GetPressed(void);
uint32_t Button_GetRawPressed(void);
#endif
