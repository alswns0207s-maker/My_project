#ifndef FND_H
#define FND_H

#include "main.h"

/* Set to 1 only when the connected FND is a common-anode part. */
#ifndef FND_COMMON_ANODE
#define FND_COMMON_ANODE 0
#endif

void FND_Init(void);
void FND_SetData(uint16_t data);
void FND_Disp(void);

#endif
