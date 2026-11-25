/*
 * motor.h
 *
 *  Created on: 2026. 11. 13.
 *      Author: kccistc
 */

#ifndef SRC_DRIVER_MOTOR_H_
#define SRC_DRIVER_MOTOR_H_
#include <stdint.h>

//motor 초기화
void motor_init(void);
void motor_set(int16_t left, int16_t right);
void motor_forward(uint8_t speed);
void motor_backward(uint8_t speed);
void motor_turnright(uint8_t speed);
void motor_turnleft(uint8_t speed);

void motor_rotateleft(uint8_t speed);
void motor_rotateright(uint8_t speed);
void motor_stop(void);

#endif /* SRC_DRIVER_MOTOR_H_ */
