/*
 * tempHumid.c
 *
 *  Created on: 2026. 11. 2.
 *      Author: kccistc
 */

#include "tempHumid.h"
#include "../../../driver/DHT11/DHT11.h"
#include "../../../driver/lcd/lcd.h"
#include <stdio.h>

static DHT11_Data tempHumid_data;

void tempHumid_disp(){
	char buff[30];
	snprintf(buff, sizeof(buff), "T:%02d.%1dC H:%02d%%   ",
			tempHumid_data.temperature_integer,
			tempHumid_data.temperature_decimal,
			tempHumid_data.humidity_integer);
	Lcd_writeStringXY(1, 0, buff);
}


void tempHumid_init(void){
	dht11_init();
}

void tempHumid_task(void){
	static uint32_t prevtime = 0;

	if((uint32_t)(HAL_GetTick()-prevtime) < 2000U){
		return;
	}
	DHT11_Status status = dht11_read(&tempHumid_data);
	prevtime = HAL_GetTick();
	if (status == DHT11_OK) {
		tempHumid_disp();
	} else {
		Lcd_writeStringXY(1, 0, "DHT11 error     ");
	}
}


