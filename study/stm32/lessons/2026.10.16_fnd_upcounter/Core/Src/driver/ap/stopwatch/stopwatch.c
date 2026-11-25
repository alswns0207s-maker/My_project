/*
 * stopwatch.c
 *
 *  Created on: 2026. 10. 16.
 *      Author: kccistc
 */

#include "stopwatch.h"

typedef enum{
	STOP,
	RUN,
	CLEAR}stopwatch_t;


	stopwatch_t stopwatch_state;

	static uint16_t counter;
	void stopwatch_set_state(stopwatch_t s)
	{
		stopwatch_state = s;
	}
	stopwatch_t stopwatch_get_state(void)
	{
		return stopwatch_state;
	}


	void stopwatch_incounter(void)
	{
		counter ++;
	}
	void stopwatch_clearcounter(void)
	{
		counter = 0;
	}
	void stopwatch_set_counter(uint16_t c){
		counter = c;
	}
	uint16_t stopwatch_get_counter(void){
		return counter;
	}

	void stopwatch_init(void){
		stopwatch_state = STOP;
		counter = 0;

	}
	void stopwatch_task(void){

		switch(stopwatch_state)
		{
		case STOP:
			stopwatch_stop();
			break;
		case RUN:
			stopwatch_run();
			break;
		case CLEAR:
			stopwatch_clear();
			break;
		default:
			stopwatch_stop();
			break;

		}

	}


	void stopwatch_stop(){
		if(button_getstate(btn_run_stop) == ACT_PUSH){
			stopwatch_set_state(run);
		}
		else if(button_getstate(btn_clear)== ACT_RELEASE){
			stopwatch_set_state(CLEAR);
		};

		uint16_t num = stopwatch_get_counter();
		fnd_show_number(num);
	};
	void stopwatch_run()
	{
		if(button )
		uint16_t num;
		stopwatch_inc_counter();
		num = stopwatch_get_counter();
		fnd_show_number(num);
	};
	void stopwatch_clear()
	{
	};
