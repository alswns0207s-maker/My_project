/*
 * Display.c
 *
 *  Created on: 2026. 10. 20.
 *      Author: kccistc
 */


#include "Display.h"
#include "../../driver/fnd/fnd.h"



//주소를 바당야 하기에 포인터 선언
stopwatchtime_t *pstopwatchtime;

void Disp_init(void){

}


void Disp_setstopwatchtime(stopwatchtime_t *ptime){
	pstopwatchtime = ptime;
}
void Disp_ISP(void){
	uint16_t num;
	if (pstopwatchtime == 0) {
		return;
	}
	num = (pstopwatchtime->sec * 100) + pstopwatchtime->msec;
	fnd_set_num(num);
}

void Disp_ISR(void){
	fnd_show_number();
}
