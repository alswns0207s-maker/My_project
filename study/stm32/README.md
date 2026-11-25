# STM32 펌웨어 실습

STM32F411 계열 보드로 진행한 날짜별 실습입니다. [실습 전체 목록](lessons/)에는 CubeIDE 파일, CubeMX `.ioc`, 응용 소스, 필요한 HAL·CMSIS 및 기존 라이선스가 들어 있습니다.

| 주제 | 예제 | 확인할 내용 |
| --- | --- | --- |
| LED·버튼과 C | [LED 버튼](lessons/2026.10.12_LedBtn_homework/) · [C 실습](lessons/2026.10.13_C_Language/) | 핀 설정, 입력 읽기, GPIO 출력, 주소와 포인터 |
| Bare-metal·FND | [GPIO 레지스터](lessons/2026.10.15_baremetal_gpio/) · [FND Up Counter](lessons/2026.10.14_fnd_upcounter/) | RCC·GPIO 직접 접근, 자리 스캔과 카운터 |
| 타이머와 시계 | [Stopwatch·TimeClock](lessons/2026.10.19_stopwatch_timeclock/) · [아날로그 시계·스톱워치](lessons/analog-clock-stopwatch/) | 주기 인터럽트, 표시와 모터 동작, 상태 제어 |
| I²C LCD·RTC | [I²C 시계](lessons/2026.10.21_Stopwatch_timeclock_I2C/) · [DS3231 RTC](lessons/2026.10.22_SC3231/) | I²C 주소·레지스터, LCD 문자 출력, BCD 변환 |
| 센서·액추에이터 | [DHT11](lessons/2026.10.27_DHT11/) · [부저](lessons/2026.10.30_buzzer/) | 타이밍 기반 읽기와 출력 |
| 시스템 통합·RTOS | [스마트워치](lessons/2026.11.02_SmartWatch/) · [엘리베이터](lessons/2026_11_06_Elevator_PJ/) · [RTOS 기초](lessons/2026.11.10_RTOS_Test/) | 여러 주변장치 통합, 태스크와 타이밍 |

## 코드와 노트 보기

STM32CubeIDE에서 **File → Import → Existing Projects into Workspace**로 실제 `.project`가 들어 있는 폴더를 가져옵니다. `.ioc`에서 클럭·핀과 보드 설정을 먼저 확인하고 각 프로젝트를 따로 빌드합니다.

- [GPIO·LED·버튼·FND 학습 노트](notes/notion_20261012_16/)
- [Bare-metal GPIO 회로 자료와 코드](notes/2026-10-12_15/)
- [LED 버튼 드라이버 비교](notes/led_button_review/)
- [완성 프로젝트의 FreeRTOS 주기 계측](../../projects/stm32-autodrive/)

## 이번 게시 검증

DHT11 실습에서 서비스가 참조하는 드라이버 두 파일을 동일 날짜 보관본에서 복원했습니다. STM32CubeIDE 2.2.0 Debug 빌드는 오류·경고 없이 완료했습니다. 다른 실습은 프로젝트 구성과 소스를 보관했습니다.
