# 학습 정리 · 드라이버에서 TIM3 인터럽트까지
> 목표: 1 ms를 계산하고, 초기화·시작·인터럽트 핸들러·콜백을 구분한다. 아래 상태 점검은 2026-10-16에 저장된 로컬 소스 기준이며 보드 실행 검증 결과는 아니다.
<table_of_contents/>
## 1. 프로젝트부터 구분하기
이날은 LED_Button_driver와 fnd_upcounter라는 서로 다른 프로젝트를 다룬다. 앞 프로젝트에 타이머 함수가 없다는 사실을 새 프로젝트에도 적용하면 안 된다.
- 2026.10.16_LED_Button_driver: LED/버튼 드라이버 중심. HAL 타이머 모듈이 비활성화되어 있고 타이머 HAL 소스가 없다.
- 2026.10.16_fnd_upcounter: TIM3 초기화, NVIC 설정, TIM3_IRQHandler, 타이머 HAL 소스가 있다.
새 FND 프로젝트에서 HAL_TIM_PeriodElapsedCallback의 기본 정의는 Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_tim.c에 있다. 검색 시 프로젝트 전체 범위에서 정확한 대소문자로 찾는다.
## 2. 왜 시간을 하드웨어 타이머로 나누는가
HAL_GetTick()을 반복문에서 비교하는 방식은 CPU가 그 검사 지점에 도착해야 일을 처리한다. HAL_Delay()나 긴 작업이 끼면 지연될 수 있다. 하드웨어 타이머는 설정한 클럭으로 독립적으로 카운트하여 주기 이벤트를 만든다.
하드웨어 이벤트의 주기와 CPU가 실제 콜백을 실행하는 시각은 구분한다. 인터럽트가 막혀 있거나 더 높은 우선순위 처리가 길면 실행이 늦어질 수 있다. 타이머를 사용한다고 모든 코드가 정확히 그 순간 동시에 실행되는 것은 아니다.
## 3. PSC와 ARR로 1 ms 계산하기
일반적인 내부 클럭·상향 카운트의 TIM3 예제에서는 다음을 사용한다.
```text
카운터 주파수 = 타이머 입력 클럭 / (PSC + 1)
업데이트 주파수 = 타이머 입력 클럭 / ((PSC + 1) × (ARR + 1))
업데이트 주기 = 1 / 업데이트 주파수
```
타이머 입력이 100 MHz라면 PSC=99로 100분주하여 카운터는 1 MHz, 즉 1 μs마다 증가한다. ARR=999이면 CNT는 0부터 999까지 세고 다음 tick에 0으로 돌아가므로 1000 μs=1 ms마다 업데이트 이벤트가 생긴다.
**주파수는 1 kHz, 주기는 1 ms다.** “주기가 1 kHz”는 단위가 섞인 표현이다. 레지스터 이름도 APR이 아니라 ARR이다.
APB 버스 클럭과 타이머 클럭은 항상 같지 않다. TIMPRE=0인 일반 설정에서는 APB 분주가 1이면 PCLK, 분주가 1보다 크면 2×PCLK가 타이머에 공급된다. 실제 값은 Clock Configuration의 타이머 클럭과 TIMPRE를 함께 확인한다.
근거: [STM32F411 RM0383 RCC 및 TIM3](https://www.st.com/resource/en/reference_manual/dm00119316-stm32f411xce-advanced-armbased-32bit-mcus-stmicroelectronics.pdf).
## 4. 인터럽트, 예외, NVIC, 벡터 테이블
<image src="file-upload://3fb6cbe6-8e4d-8129-842b-00b2f62fb83d"></image>
인터럽트는 평소 실행 흐름을 잠시 중단하고 사건을 처리하게 하는 요청이다. Cortex-M에서 인터럽트는 exception이라는 더 넓은 범주에 포함된다. SysTick과 HardFault 등은 시스템 예외이며, TIM3는 주변장치 인터럽트다.
NVIC는 허용 여부, pending 상태, 우선순위를 관리한다. 코드를 실행하는 것은 CPU다. 벡터 테이블에는 예외/인터럽트별 처리 함수의 주소가 있다. CPU는 진입 시 실행 문맥 일부를 스택에 저장하고 정상적인 예외 복귀 때 복원한다. HardFault 처리에서 무한 루프로 멈추는 코드라면 자동으로 원래 작업을 계속하는 것은 아니다.
낮은 우선순위 숫자가 더 높은 우선순위를 뜻한다. 현재 처리를 중단하고 끼어드는지는 선점 우선순위와 마스킹 설정 등에 달려 있으며, 서브우선순위만 높다고 선점하는 것은 아니다.
근거: [Arm CMSIS — NVIC와 예외](https://arm-software.github.io/CMSIS_6/main/Core/group__NVIC__gr.html).
## 5. 핸들러와 콜백은 왜 분리되는가
TIM3_IRQHandler()는 CPU가 들어오는 실제 인터럽트 진입 함수다. 이 함수가 HAL_TIM_IRQHandler(&htim3)를 호출하면 HAL은 어떤 타이머 원인이 발생했는지 확인하고 플래그를 처리한다. 주기 완료 이벤트이면 사용자 콜백이 호출된다.
HAL_TIM_PeriodElapsedCallback(TIM_HandleTypeDef *htim)의 htim은 타이머 핸들 구조체를 가리키는 포인터다. htim->Instance를 확인하면 여러 타이머 중 무엇이 콜백을 발생시켰는지 구분할 수 있다.
기본 콜백은 __weak로 제공된다. 기본 설정에서는 사용자 파일에 같은 이름과 정확한 원형으로 함수를 정의하면 그 구현을 사용할 수 있다. HAL 라이브러리 원본을 직접 수정하지 않는다. 이 프로젝트는 USE_HAL_TIM_REGISTER_CALLBACKS=0이다.
근거: [ST 공식 HAL TIM 소스](https://github.com/STMicroelectronics/stm32f4xx-hal-driver/blob/master/Src/stm32f4xx_hal_tim.c).
## 6. 생성만으로 실행되지 않는다
저장된 FND 프로젝트를 확인한 결과:
- MX_TIM3_Init()과 PSC=100-1, Period=1000-1 설정은 있다.
- TIM3_IRQHandler()에서 HAL_TIM_IRQHandler(&htim3)를 호출한다.
- 사용자 소스에 HAL_TIM_Base_Start_IT(&htim3) 호출과 사용자 PeriodElapsed 콜백 정의는 아직 없다.
- main의 반복문은 비어 있다. stopwatch 상태별 함수도 아직 빈 구현이다.
- fnd_show_number 계열의 기존 표시 코드에는 HAL_Delay(1)가 있으므로 그대로 ISR에 넣지 않는다.
따라서 “설정 완료”와 “실행 연결 완료”를 구분한다. 다음 예제는 콜백 호출을 확인하기 위한 독립적인 학습 예이며, 완성된 스톱워치 코드가 아니다.
```c
/* main.c: USER CODE BEGIN PV */
volatile int timer_seen = 0;

/* main.c: USER CODE BEGIN 4 */
void HAL_TIM_PeriodElapsedCallback(TIM_HandleTypeDef *htim)
{
    if (htim->Instance == TIM3)
    {
        timer_seen = 1;
    }
}

/* main.c: MX_TIM3_Init() 이후 USER CODE BEGIN 2 안에 넣을 문장 */
HAL_TIM_Base_Start_IT(&htim3);
```
세 부분은 각각 표시한 사용자 코드 영역에 나누어 넣는다. 마지막 호출 문장은 파일 전역이 아니라 main 안에 둔다. 디버거에서 timer_seen이 1이 되는지 확인할 수 있다.
volatile은 ISR에서 바뀌는 변수를 관찰하도록 돕지만, 이벤트 누락·원자성·여러 실행 흐름 사이 동기화를 모두 해결하지는 않는다. 이 플래그는 “적어도 한 번 실행됐는가”만 나타내고 정확한 횟수는 세지 않는다.
## 7. ISR에서는 짧은 작업만
ISR에서 HAL_Delay()를 사용하면 필요한 tick 인터럽트가 선점하지 못해 진행이 멈출 수 있고, 진행하더라도 다른 작업을 오래 지연시킨다. 긴 printf, 버튼 디바운싱 지연, 여러 자리 FND 전체 스캔 지연도 분리한다.
설계 방향은 짧은 주기마다 지연 없는 FND 한 자리 갱신, 필요한 시간 정보 기록, 메인에서 버튼·상태 머신 처리다. 기존 지연 함수를 호출만 옮겨서는 해결되지 않는다.
## 8. LED 두 개만 켜지는 현상과 상태 머신
별도 LED_Button_driver 코드의 STOP은 POWER+STOP, RUN은 POWER+RUN, CLEAR는 CLEAR만 켠다. 따라서 두 개 동시 점등 자체는 이 상태 출력에 맞다. 전원 버튼 처리 부분은 비어 있고, RUN 상태에서 CLEAR 이벤트는 처리하지 않는다.
하지만 실제로 특정 LED가 모든 상태에서 켜지지 않는다면 별도 핀·극성·배선 문제를 확인한다. 상태별 표시 요구와 실제 고장을 섞지 않는다.
**완료 기준:** 타이머 입력 클럭 확인 → PSC/ARR 계산 → NVIC 허용 → 시작 호출 → IRQ 진입 → HAL 처리 → 사용자 콜백 → 짧은 작업 및 메인 연결 순서로 설명하고 확인할 수 있다.
---
# 수업 기록 · 설정 화면과 인터럽트 메모

