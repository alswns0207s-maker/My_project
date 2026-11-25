# RTL·FPGA·임베디드 학습 기록

대표 프로젝트를 만들기 전후에 실습한 설계 소스, 테스트벤치, 보드 설정과 학습 노트를 모았습니다. 날짜별 폴더에는 같은 주제의 초기본과 수정본도 있으므로 실습을 하나씩 열어 비교합니다.

| 분야 | 내용 | 자료 |
| --- | --- | --- |
| FPGA·디지털 설계 | 조합·순차 논리, 카운터·FSM, 디지털 시계, UART·FIFO, 센서 연동, RV32I, AXI와 MicroBlaze | [FPGA 실습과 코드](fpga/) |
| SystemVerilog·UVM | 클래스 기반 검증, Adder·Counter 예제, 설계 Top과 테스트벤치 Top | [FPGA 실습 목록](fpga/lesson-index.md) |
| STM32 | GPIO, Bare-metal, FND 스캔, 타이머, I²C LCD·RTC, DHT11, 부저, FreeRTOS, 엘리베이터·스마트워치 | [STM32 실습과 학습 노트](stm32/) |
| Edge AI | Raspberry Pi 관절 특징 추출, NumPy 스와이프 모델, Colab 가위바위보 학습 및 TFLite 추론 | [AirGesture 학습 코드](../projects/airgesture/training/swipe/) · [가위바위보 학습 노트북](edge-ai/rock-paper-scissors/) |

보드, Top, XDC·핀, 미들웨어를 각 실습에서 확인합니다. 이 폴더의 코드는 날짜별 학습 스냅샷이며 실제 보드에서 전체 실습을 다시 검증한 기록은 아닙니다.
