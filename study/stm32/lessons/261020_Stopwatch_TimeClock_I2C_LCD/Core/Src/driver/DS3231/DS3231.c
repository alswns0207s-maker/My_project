/*
 * DS3231.C
 *
 *  Created on: 2026. 10. 21.
 *      Author: kccistc
 */
#include "stm32f4xx_hal.h"

#define DS3231_ADDR 0x68
#define SECODNDS_ADDR 0x00
#define MINUTES_ADDR 0x10
#define HOURS_ADDR 0x20
#define DAY_ADDR 0x30
#define DATA_ADDR 0x40

typedef enum{
START_ON,
START_OFF
}start_state_t;

typedef enum{
ACK_OK,
ACK_NOK
}ack_state_t;

typedef struct {

}

struct DS3231_DATA{
	uint START : 1;
	uint8_t S_ADDR:7;
	uint RW : 1;
	uint ACK : 1;
	uint8_t DATA ;
}DS3231_t;

void DS3231_init(void){
	START = START_OFF;
	ACK = ACK_NOK;
}

void DS3231_senddata(void){
	HAL_I2C_Master_Transmit(hi2c, DS3231_ADDR,1,100);
	HAL_I2C_Master_Receive(hi2c, DS3231_ADDR, 4, 100);
}
