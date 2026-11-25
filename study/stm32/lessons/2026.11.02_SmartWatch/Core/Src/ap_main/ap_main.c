/*
 * ap_main.c
 *
 *  Created on: 2026. 11. 2.
 *      Author: kccistc
 */

#include "ap_main.h"
#include "service/timeClock.h"
#include "service/tempHumid/tempHumid.h"
#include "../driver/button/button.h"



typedef enum
{
	S_CALENDAR = 0,
	S_TEMP_HUMID,
	S_RULER,
	S_STOPWATCH
} smartWatch_state_t;

smartWatch_state_t smartWatch_state = S_CALENDAR;
static button_t btnMode;
//dht11과 delay를 위해서 common단이 필요(driver)
int ap_main(void)
{
	button_init(&btnMode, GPIOC, GPIO_PIN_0);
	timeClock_init();
	tempHumid_init();
	while(1)
	{
		timeClock_task();


		switch(smartWatch_state)
		{
		case S_CALENDAR:
			if(button_getState(&btnMode)==ACT_RELEASE){
				smartWatch_state = S_TEMP_HUMID;
			}
			timeClock_calendar_task();
			break;

		case S_TEMP_HUMID:
			if(button_getState(&btnMode)==ACT_RELEASE){
				smartWatch_state = S_CALENDAR;
				timeClock_setDateFirstFlag();
			}
			tempHumid_task();
			break;

		case S_RULER:
			if(button_getState(&btnMode)==ACT_RELEASE){
				smartWatch_state = S_CALENDAR;
				timeClock_setDateFirstFlag();
			}
			/* ruler_task(); // 초음파 서비스 구현 후 연결 */
			break;

		case S_STOPWATCH:

			break;
		default:
			break;

		}
	}

	return 0;
}
