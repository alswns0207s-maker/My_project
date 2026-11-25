/*
 * Display.h
 *
 *  Created on: 2026. 10. 20.
 *      Author: kccistc
 */

#ifndef SRC_AP_DISPLAY_DISPLAY_H_
#define SRC_AP_DISPLAY_DISPLAY_H_

#include "../StopWatch/StopWatch.h"

typedef stopWatch_t stopwatchtime_t;

void Disp_init(void);
void Disp_setstopwatchtime(stopwatchtime_t *ptime);
void Disp_ISP(void);
void Disp_ISR(void);



#endif /* SRC_AP_DISPLAY_DISPLAY_H_ */
