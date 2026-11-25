# 20261016 StopWatch + 시계

STM32F411RETx / NUCLEO-F411RE용 STM32CubeIDE 프로젝트입니다. 첨부 `Src.zip`의 Application -> Driver -> HAL 구조와 TIM3 FND 표시 방식을 바탕으로 시계 기능을 추가했습니다. 기존 workspace의 다른 실습 프로젝트는 수정하지 않았습니다.

## 이 PC에서 Run으로 실행

CubeIDE 기본 작업 공간을 `D:\STM32\workspace`로 지정하고 이 프로젝트를 등록했습니다. `20261016_StopWatch_Clock Debug.launch` 실행 구성을 프로젝트에 저장했으며 Run 즐겨찾기에도 등록했습니다.

1. NUCLEO-F411RE의 ST-LINK USB 포트를 PC에 연결합니다.
2. CubeIDE에서 `20261016_StopWatch_Clock` 프로젝트를 선택합니다.
3. 상단 초록색 **Run** 버튼을 누릅니다. Debug 빌드, 플래시 다운로드와 검증, 프로그램 실행이 이어서 수행됩니다.

실행 구성은 `Debug/20261016_StopWatch_Clock.elf`, ST-LINK GDB server, SWD, Connect under reset, 자동 빌드를 사용합니다. Run 메뉴의 실행 항목 이름은 `20261016_StopWatch_Clock Debug`입니다. 실행 후 콘솔의 `<terminated>`는 다운로드 도구가 종료됐다는 뜻이며 MCU 프로그램은 계속 실행됩니다.

Windows 보안에서 ST-LINK GDB 서버 네트워크 권한 창이 표시되면 사용자가 직접 처리해야 합니다. 이 PC에서는 해당 창이 표시된 상태에서도 보드 프로그램 다운로드와 실행을 확인했습니다.

## 실행과 버튼

전원 또는 Reset 후 시계 모드의 `00.00`으로 시작합니다. 왼쪽 두 자리는 분, 오른쪽 두 자리는 초입니다.

| 버튼 | 핀 | 동작 |
| --- | --- | --- |
| MODE | PC0 | 시계 / 스톱워치 모드 전환 |
| RUN / STOP | PC1 | 스톱워치 시작 / 정지 / 이어서 시작 |
| CLEAR | PC3 | 스톱워치 정지 중 눌렀다가 떼면 초기화 |

각 버튼을 해당 핀과 GND 사이에 연결합니다. 내부 Pull-up을 사용하므로 누르면 LOW입니다. 20 ms 동안 안정된 입력만 인정하며 길게 눌러도 한 번만 동작합니다.

- 시계: `MM.SS`, `00.00`부터 `59.59`까지 진행한 뒤 `00.00`으로 돌아갑니다. 가운데 소수점(D2)이 0.5초 켜짐 / 0.5초 꺼짐을 반복합니다.
- 스톱워치: `SSS.s`, 0.1초 단위로 `000.0`부터 `999.9`까지 표시한 뒤 `000.0`으로 돌아갑니다. D3 소수점은 계속 켜집니다.
- 정지 후 다시 시작하면 정지 전의 값과 0.1초 미만의 시간도 이어서 측정합니다.
- 모드 전환은 표시와 버튼의 대상을 바꿉니다. 시계는 계속 진행하고 실행 중인 스톱워치도 계속 측정합니다.
- 시계 모드에서 RUN / STOP과 CLEAR는 무시합니다. 스톱워치 실행 중 CLEAR도 무시합니다. 초기화하려면 먼저 정지하고 CLEAR를 새로 눌렀다가 뗍니다.
- MODE와 다른 버튼의 이벤트가 동시에 발생하면 MODE를 우선합니다. 정지 중 유효한 CLEAR 해제와 RUN 입력이 겹치면 CLEAR를 우선합니다.

시계는 PDF 6쪽의 **분·초 표시**에 맞춘 타이머 시계입니다. RTC나 현재 시각 설정은 사용하지 않으며 전원을 끄거나 Reset하면 초기화됩니다. 시작 모드는 시계, 모드 전환 중 계수 유지, 60분 순환은 자료에 세부 동작이 없어 정한 구현 기준입니다.

## LED

| LED | 핀 | 켜지는 조건 |
| --- | --- | --- |
| 시계 | PB15 | 시계 모드 |
| 스톱워치 | PB14 | 스톱워치 모드 |
| STOP | PB13 | 스톱워치 모드의 정지 상태 |
| RUN | PC4 | 스톱워치 모드의 실행 상태 |

LED는 HIGH일 때 켜지는 연결을 사용합니다. PB15/PB14는 PDF의 LED 실습 출력, PB13/PC4는 첨부 StopWatch 소스의 STOP/RUN 출력에 대응합니다. 시계 모드에서는 시계 LED 하나만 켜집니다.

## FND 핀

첨부 소스의 공통 캐소드 배치를 사용합니다. 자리 선택은 LOW, 세그먼트 점등은 HIGH입니다.

| FND | MCU | FND | MCU |
| --- | --- | --- | --- |
| A | PA6 | D1, 맨 왼쪽 | PA5 |
| B | PA9 | D2 | PB6 |
| C | PB5 | D3 | PC7 |
| D | PB10 | D4, 맨 오른쪽 | PA10 |
| E | PA8 | DP | PB4 |
| F | PA7 | G | PB3 |

PA5는 보드 LD2와 공유합니다. PB3/PB4는 FND 출력으로 사용하므로 디버그 연결은 SWD(Serial Wire)를 사용합니다. 실제 FND가 공통 애노드라면 `Core/Src/driver/fnd/fnd.h`의 `FND_COMMON_ANODE`를 `1`로 바꿉니다.

## 소프트웨어 구조

```text
Core/Src/main.c                  HAL, 시스템 클럭, GPIO, TIM2/TIM3 초기화
Core/Src/ap/ap_main.c            모드, 버튼 처리, 표시/LED, 타이머 콜백
Core/Src/ap/StopWatch/StopWatch.c STOP / RUN / CLEAR와 경과 시간
Core/Src/ap/Clock/Clock.c         분·초 시계와 소수점 점멸
Core/Src/driver/button/button.c  누름/해제 이벤트와 비차단 디바운싱
Core/Src/driver/fnd/fnd.c        숫자/소수점, 네 자리 스캔
Core/Src/driver/led/led.c        첨부 LED 구조체 드라이버
Core/Src/stm32f4xx_it.c          TIM2/TIM3 IRQ -> HAL IRQ handler
Core/Src/stm32f4xx_hal_msp.c     타이머 클럭과 NVIC 설정
20261016_StopWatch_Clock.ioc     핀, 타이머, NVIC, 클럭 설정
tests/verify_firmware.py        빌드된 ARM ELF 동작 검사
firmware/                       빌드한 ELF / HEX / BIN
validation/                     빌드·동작 검사 결과
```

`main()`에서 `ap_init()`을 한 번 호출하고 반복문에서 `ap_task()`를 실행합니다. 첨부 소스와 같은 진입점 `ap_main()`도 제공하지만 현재 main에서는 반복 초기화 없이 `ap_init()` / `ap_task()`를 사용합니다.

TIM2의 1 ms 인터럽트는 시계와 실행 중 스톱워치의 시간을 증가시킵니다. TIM3의 1 ms 인터럽트는 한 자리를 표시하여 네 자리 전체를 4 ms마다 갱신합니다. 메인 루프는 버튼과 표시 데이터를 처리하며 `HAL_Delay()`를 사용하지 않습니다.

숫자와 소수점은 한 개의 32비트 값으로 전달합니다. FND는 D1에서 이를 받아 D4까지 같은 값을 표시하므로 자리 스캔 도중 숫자가 섞이지 않습니다. 표시를 바꾸기 전에 모든 자리를 끕니다. 스톱워치 상태 변경은 짧은 임계 구역으로 보호하고 기존 인터럽트 마스크를 복원합니다.

## 타이머와 빌드

- 첨부 자료와 같은 HSE 8 MHz, PLL M=4 / N=100 / P=2, SYSCLK 100 MHz입니다.
- APB1은 50 MHz, TIM2/TIM3 입력 클럭은 100 MHz입니다.
- 두 타이머 모두 PSC=99, ARR=999로 `100 MHz / 100 / 1000 = 1 kHz`입니다.
- TIM3의 인터럽트 우선순위는 0, TIM2는 1입니다. HAL SysTick은 기본 1 ms입니다.
- `HAL_TIM_MODULE_ENABLED`, TIM HAL 소스/헤더, NVIC와 IRQ handler를 프로젝트에 포함했습니다.

HSE 설정은 첨부 소스의 `RCC_HSE_ON`(외부 크리스털)을 유지했습니다. 실제 보드가 ST-LINK MCO의 외부 클럭을 사용한다면 CubeMX에서 HSE를 **Bypass Clock Source**로 변경하여 코드를 재생성해야 합니다.

1. CubeIDE에서 `File > Import > General > Existing Projects into Workspace`를 선택합니다.
2. 이 프로젝트 폴더 또는 제공된 ZIP을 선택하여 가져옵니다.
3. `Debug` 또는 `Release`를 빌드합니다.
4. ST-LINK와 실제 회로를 연결하고 Run / Debug로 다운로드합니다.

`firmware/20261016_StopWatch_Clock_Debug.elf`와 `firmware/20261016_StopWatch_Clock_Release.elf`는 이미 빌드한 실행 파일입니다. 같은 이름의 HEX/BIN도 포함합니다. BIN을 별도 도구로 기록할 때 시작 주소는 `0x08000000`입니다.

## 검증 결과

STM32CubeIDE 2.2.0 / GNU Tools for STM32 14.3.rel1에서 Debug와 Release 모두 **오류 0개, 경고 0개**로 빌드했습니다.

Debug ELF의 실제 ARM 명령을 Unicorn에서 실행하고 GPIO, 타이머, NVIC 레지스터를 모의하여 다음을 확인했습니다.

- GPIO Pull-up, TIM2/TIM3 PSC/ARR, RCC/NVIC, 타이머 시작과 초기 상태.
- 실제 TIM IRQ -> HAL -> 앱 콜백 경로, 0.5초 점멸, 초/분 올림과 59:59 순환.
- 0.1초 경계, 정지/재시작의 남은 시간, 정지 중 해제 초기화, 실행 중 CLEAR 무시, 999.9 순환.
- 20 ms 디바운싱, 길게 누름, 해제, SysTick의 32비트 오버플로.
- 모드 전환, 네 LED, 백그라운드 계수, 다른 모드의 버튼 무시, 동시 입력 우선순위.
- FND 0~9, 자리 순서, 앞자리 0, 소수점, 자리 끄기, 스캔 중 데이터 일관성.

검사를 다시 실행하려면 Debug 빌드 후 `python -m pip install unicorn pyelftools`로 검사 의존성을 설치하고 프로젝트 폴더에서 다음을 실행합니다.

```powershell
python tests/verify_firmware.py
```

NUCLEO-F411RE를 ST-LINK로 연결하여 IDE의 Run 구성으로 다운로드·실행했습니다. 이후 보드를 리셋하지 않는 Hot Plug 메모리 읽기로 `clockMs` 증가, 시계 표시 데이터, HSE/PLL 준비 상태, PLL 시스템 클럭 선택, TIM2/TIM3 PSC=99 / ARR=999를 확인했습니다. 결과는 `validation/hardware-run.log`에 있습니다.

실제 FND 표시, 외부 버튼/LED 배선, 밝기와 장시간 클럭 정확도는 확인하지 않았습니다. 보드에서 시계 점멸 -> 모드 변경 -> 시작 -> 정지 -> 초기화 -> 모드 변경 중 계수 유지 순서로 확인할 수 있습니다.

## 첨부 자료 반영

PDF 1~3쪽의 LED 구조체, 버튼 디바운싱, Application/Driver/HAL 계층과 STOP/RUN/CLEAR 구조를 사용했습니다. 4~5쪽의 100 MHz 타이머 설정과 6쪽의 모드 버튼, 네 LED, 분·초 표시, 0.5초 점멸 및 별도 시계용 타이머를 반영했습니다.

첨부 소스에서 수정한 부분은 PC0 모드 버튼 추가, LED 동작 연결, 비차단 버튼 처리, 시계 모듈/TIM2 추가, 정확한 100 ms 스톱워치 계수, 소수점과 일관된 FND 스캔입니다. `driver/led`는 첨부 소스를 유지했습니다. TIM HAL 파일은 로컬 STM32Cube FW_F4 V1.28.3에서 가져왔으며 ST/CMSIS 라이선스 파일을 포함합니다.
