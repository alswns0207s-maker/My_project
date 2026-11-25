# FND UpCounter 버튼 과제

NUCLEO-F411RE / STM32F411RETx용 CubeIDE 프로젝트.

## 수업 자료와 맞춘 내용

- 10/13 PDF 72쪽의 FND 핀 배치.
- 10/14 PDF 1쪽의 `HAL_GetTick() - prevTime > 100` 카운터 코드와 `9999 -> 0` 조건.
- 10/14 PDF 2쪽의 Application -> FND Driver -> HAL 구조와 `Core/Src/driver/fnd/fnd.c`, `fnd.h` 폴더 위치.
- 10/14 PDF 116쪽의 STOP / RUN / CLEAR 상태도. 시작 상태는 STOP이며 CLEAR는 STOP에서만 들어간다.

PDF에는 완성된 `fnd.c`와 버튼 드라이버 원문이 없으므로, 드라이버 전체가 수업 원본과 동일하다고 보장하지는 않는다. 자료에 확인되는 핀 배치, 폴더 구조, 시간 조건, 상태 전이를 기준으로 구현했다.

## 동작

1. 전원 또는 Reset 후 `0000`을 표시하고 정지한다.
2. PC0 버튼을 한 번 누르면 카운트가 시작된다. 다시 누르면 현재 숫자에서 멈춘다.
3. 정지 중 PC1 버튼을 누르면 `0000`으로 초기화하고 정지 상태로 돌아간다.
4. RUN 중 PC1 입력은 상태도대로 무시한다. 정지한 뒤 다시 PC1을 눌러 초기화한다.
5. 정지 후 다시 시작할 때는 카운트 시간을 새로 잡는다.

수업 코드와 같은 `> 100` 조건이므로 1 ms tick 기준 증가 주기는 최소 101 ms다. 정확히 100 ms마다 증가시키려면 `upcounter.c`에서 `> 100U`를 `>= 100U`로 바꾸면 된다.

두 버튼을 정지 중 동시에 누르면 초기화를 우선한다. 버튼 입력은 20 ms 동안 안정된 뒤 한 번만 처리한다. `HAL_Delay()` 없이 FND의 네 자리를 계속 스캔하므로 STOP 상태에서도 표시가 유지된다.

## 버튼 연결

| 기능 | MCU 핀 | 누르지 않음 | 누름 |
| --- | --- | --- | --- |
| 시작 / 정지 | PC0 | HIGH | LOW |
| 초기화 | PC1 | HIGH | LOW |

마지막 FSM 그림에는 버튼 핀 번호가 적혀 있지 않아, 앞선 버튼 실습의 PC0 / PC1 배치를 사용했다. GPIO 내부 Pull-up도 켜뒀다. 각 버튼을 해당 입력 핀과 GND 사이에 연결한다. 수업에서 사용한 외부 4.7 kOhm Pull-up도 함께 사용할 수 있다.

## FND 연결

| FND 신호 | FND 다리 번호 | MCU 핀 |
| --- | --- | --- |
| A | 11 | PA6 |
| B | 7 | PA9 |
| C | 4 | PB5 |
| D | 2 | PB10 |
| E | 1 | PA8 |
| F | 10 | PA7 |
| G | 5 | PB3 |
| DP | 3 | PB4 |
| D1, 맨 왼쪽 자리 | 12 | PA5 |
| D2 | 9 | PB6 |
| D3 | 8 | PC7 |
| D4, 맨 오른쪽 자리 | 6 | PA10 |

수업 배치의 각 자리 선택선에 330 Ohm 저항을 사용한다. DP는 사용하지 않아 항상 꺼진다. 출력 숫자는 앞자리 0을 포함해 네 자리로 표시한다.

기본 드라이버는 공통 캐소드 FND다. 실제 부품이 공통 애노드라면 `Core/Src/driver/fnd/fnd.h`의 `FND_COMMON_ANODE`를 `1`로 바꾼다. PDF에는 두 극성 설명이 함께 있으므로 실제 부품의 극성을 확인해야 한다.

PA5는 보드 내장 LD2와 공유하므로 이 프로젝트에서는 PA5를 FND D1로 사용한다. PB3/PB4가 FND 출력이어서 디버그는 SWD인 Serial Wire를 사용하고 SWO/JTAG를 사용하지 않는다.

## 파일 구조

```text
Core/Src/main.c                  초기화와 반복 호출
Core/Src/app/upcounter.c         STOP / RUN / CLEAR, counter, prevTime
Core/Src/app/upcounter.h
Core/Src/driver/button/button.c  버튼 디바운싱과 한 번 누름 검출
Core/Src/driver/button/button.h
Core/Src/driver/fnd/fnd.c         숫자 폰트와 네 자리 스캔
Core/Src/driver/fnd/fnd.h
20261014_FND_UpCounter.ioc       핀 배치와 100 MHz 클럭 설정
```

`main.c`의 사용자 코드 영역에서 `FND_Init()`, `UpCounter_Init()`을 초기화하고 반복문에서 `UpCounter_Task()`, `FND_Disp()`를 계속 호출한다. CubeMX 재생성 시 사용자 코드를 보존하도록 설정했다.

## 클럭과 실행 확인

이전에 PDF에 맞춰 설정한 HSE 8 MHz, PLL M=4 / N=100 / P=2, SYSCLK 100 MHz를 사용한다. HSE는 Crystal/Ceramic Resonator다. 실제 보드가 ST-LINK MCO 외부 클럭을 사용하는 구성이라면 CubeMX의 HSE를 Bypass Clock Source로 맞춘 뒤 코드를 재생성해야 한다.

STM32 Debug 빌드는 오류 0개, 경고 0개로 완료했다. 실행 파일은 `Debug/20261014_FND_UpCounter.elf`다.

버튼 디바운싱, 길게 누름, 시작/정지/초기화, 실행 중 CLEAR 무시, 동시 누름 우선순위, 9999 이후 0000, tick 오버플로를 실제 작성한 C 코드로 검사했다. FND는 두 극성 모두에서 0~9 폰트, 각 자리 순서, 앞자리 0, DP 꺼짐, 출력 변경 중 자리 비활성화를 확인했다.

실제 보드 다운로드, 부품 극성, 배선 및 표시 밝기는 하드웨어 연결 후 확인해야 한다. 프로젝트 ZIP에는 빌드 임시 파일을 제외한 전체 소스, CubeIDE 설정, CubeMX 설정을 포함했다.
