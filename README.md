# 김민준 RTL·FPGA 프로젝트

RV32I SoC의 RTL과 AMBA APB 통합, VC707 FPGA와 PC 간 데이터 전송, STM32 실물 제어, Raspberry Pi 기반 손동작 인터페이스를 정리한 포트폴리오입니다. 각 프로젝트 README에 구현 범위, 실행 절차와 검증 근거를 기록했습니다.

## 프로젝트

| 프로젝트 | 구현과 통합 | 확인한 결과 |
| --- | --- | --- |
| [RV32I 멀티사이클 CPU와 APB SoC](projects/rv32i-apb-soc/) | Basys3, SystemVerilog, APB RAM·GPIO, XSim | 누적합 55 확인, APB 대기 상태 재현, PC+4 배치배선 비교 |
| [VC707 FPGA YOLOv5n와 드론 추적](projects/fpga-yolov5n/) | Ethernet/UDP, FIFO, AXI4·MIG·DDR3, YOLO Verilog | BBox 데이터 경로 확인, 독립 재양자화 모듈의 경로 지연 43.4% 감소 |
| [STM32 FreeRTOS 자율주행차](projects/stm32-autodrive/) | STM32F411RE, 초음파 입력, UART 블루투스, TIM3 PWM | 로직 애널라이저 PWM 기록과 ControlTask 주기 계측 코드 |
| [AirGesture 손동작 제어](projects/airgesture/) | Raspberry Pi, MediaPipe, NumPy MLP, Windows PC 연결 | 6,209개 파라미터 MLP 로드·추론 확인, 미디어·PPT·마우스 제어 경로 구현 |

## 구현과 검증 환경

- **RTL·SoC** — Verilog/SystemVerilog, RV32I, AMBA APB, MMIO, FIFO
- **FPGA 통합·타이밍** — Vivado, XSim, XDC, STA, Ethernet/UDP와 AXI4·DDR3 데이터 경로
- **임베디드·응용** — STM32CubeIDE, C, FreeRTOS, GPIO·타이머·UART, Python, Raspberry Pi

기존 VC707 통합 소스는 저장소의 `rtl/`, `pc_tools/`, `constraints/`, `vivado/`에 있습니다. 보드에서 재현하려면 프로젝트별 README의 보드·IP 버전 및 초기화 절차를 확인하세요.
