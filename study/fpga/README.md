# FPGA와 SystemVerilog 실습

[날짜별 실습 목록](lesson-index.md)에서 실습 폴더와 원본 Vivado 설정에 기록된 Top을 확인할 수 있습니다. HDL, 테스트벤치, XDC 및 선택된 블록 디자인을 보관했습니다.

[주제별 학습 노트](notes.md)에서 구현과 파형을 볼 때 확인한 항목을 정리했습니다.

## 학습 순서

| 주제 | 작성·검증한 내용 | 예제 |
| --- | --- | --- |
| 조합회로와 FND | Full Adder, 세그먼트 디코딩, 멀티플렉싱, 카운터 | [Adder·FND](lessons/2026_07_20_adder_fnd/) |
| 순차회로 | Moore FSM, 버튼 디바운스, 시계·스톱워치 상태 전이 | [Moore FSM](lessons/2026_07_23_moore_fsm/) · [Stopwatch](lessons/2026_07_28_stopwatch/) |
| 직렬 통신과 버퍼 | UART TX/RX, ASCII 명령 처리, FIFO 포인터와 full/empty 검증 | [UART](lessons/2026_08_05_UART/) · [FIFO](lessons/2026_08_10_fifo/) |
| SV·UVM | 클래스로 트랜잭션·드라이버·모니터를 표현하고 작은 DUT의 출력과 기대값 비교 | [SV OOP](lessons/2026_08_24_sv_oop/) · [Counter UVM](lessons/counter_uvm/) |
| 프로세서와 버스 | RV32I 데이터패스, AXI master/slave 핸드셰이크, GPIO 레지스터와 MicroBlaze | [RV32I](lessons/20260914_riscv_cpu/) · [AXI](lessons/2026.11.18_AXI_MASTER/) · [AXI GPIO](lessons/20261120_AXI_GPIO/) · [MicroBlaze](lessons/20261120_MicroBlaze_axi_gpio/) |

## 소스 사용

1. 실습 한 폴더를 선택하고 Vivado 프로젝트를 만듭니다. Basys3 실습은 해당 XDC의 보드·핀을 사용합니다.
2. `sources_1`은 설계, `sim_1`은 시뮬레이션, `constrs_1`은 제약입니다. import와 new 하위 파일의 모듈명을 확인하고 Top을 하나씩 선택합니다.
3. UVM 실습은 사용 중인 시뮬레이터에서 UVM 라이브러리를 설정합니다. MicroBlaze 블록 디자인은 Vivado IP Catalog에서 요구되는 IP를 다시 만들고 AXI GPIO 사용자 HDL을 등록합니다. [C 예제](lessons/20261120_MicroBlaze_axi_gpio/software/main.c)는 Vitis BSP 설정 후 사용합니다.
4. 일부 실습에는 같은 모듈의 연습 버전이 있습니다. 전체 폴더를 한 번에 컴파일하지 않고, 설계 Top과 테스트벤치가 참조하는 파일만 포함합니다.

프로젝트로 정리된 CPU 구현과 자동 테스트는 [RV32I APB SoC](../../projects/rv32i-apb-soc/)에서 확인할 수 있습니다.

FIFO 실습의 `fifo.v`와 `tb_fifo.v`는 Vivado 2020.2에서 컴파일과 elaboration을 확인했습니다.
