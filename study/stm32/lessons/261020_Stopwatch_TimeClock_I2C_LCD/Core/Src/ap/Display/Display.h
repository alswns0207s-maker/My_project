#ifndef SRC_AP_DISPLAY_DISPLAY_H_
#define SRC_AP_DISPLAY_DISPLAY_H_

void Disp_init(void); // 시작할 때 한 번
void Disp_task(void); // 메인 반복문: LCD 출력
void Disp_ISR(void);  // TIM3 인터럽트: FND 갱신

#endif