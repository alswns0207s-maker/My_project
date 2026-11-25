# FPGA와 SystemVerilog 학습 노트

## 조합 회로에서 상태 머신으로

[Adder·FND](lessons/2026_07_20_adder_fnd/)에서는 합과 캐리를 내는 회로를 세그먼트 디코더와 연결했습니다. [Moore FSM](lessons/2026_07_23_moore_fsm/)과 [Stopwatch](lessons/2026_07_28_stopwatch/)에서는 입력에 따라 다음 상태를 계산하는 부분과 클록 에지에서 상태를 저장하는 부분을 분리했습니다. 파형에서는 리셋부터 각 상태의 진입 조건, 카운터 증가 여부, 자리올림 순서로 봅니다.

## UART와 FIFO

[UART](lessons/2026_08_05_UART/)는 Idle의 High와 Start의 Low를 구별한 뒤 비트 시점에 맞춰 데이터를 읽고 Stop 상태를 확인합니다. RX 오버샘플링은 수신기에서 정해진 주기로 입력을 여러 번 관찰해 비트 가운데를 찾기 위한 것입니다. ASCII 명령을 시계 조작 신호로 변환하는 예제가 함께 있습니다.

[FIFO](lessons/2026_08_10_fifo/)는 쓰기·읽기 포인터와 full·empty에 따라 요청을 처리합니다. 경계에서는 쓰기/읽기가 막혀야 할 조건, 동시 push/pop, 주소가 끝을 지나 다시 0으로 돌아오는 경우를 확인합니다. 단일 클록 FIFO 코드는 같은 클록을 기준으로 합니다. 클록이 서로 다르면 포인터 전달과 플래그 생성 자체가 CDC 설계 대상입니다.

## SystemVerilog와 UVM

[SystemVerilog OOP](lessons/2026_08_24_sv_oop/)와 [Counter UVM](lessons/counter_uvm/)에서는 DUT 외부의 자극과 판정을 분리합니다. 트랜잭션으로 입력을 묶고 driver가 신호에 반영하며, monitor가 관측한 결과를 예상 결과와 비교합니다. 카운터는 reset·enable·증가가 만나는 에지에서 기대 상태를 계산하고 다음 관측 시점의 값으로 평가합니다. 같은 엣지에서 drive와 샘플을 섞을 때 생기는 race는 drive와 관찰 시점을 구분해 확인합니다.

## APB와 AXI4-Lite

[RV32I SoC](../../projects/rv32i-apb-soc/)에서 APB는 Setup에서 주소·방향·데이터를 준비하고 Access를 시작합니다. 선택, PENABLE, PREADY가 나타나는 완료 에지에서 쓰기는 RAM 갱신을, 읽기는 데이터와 목적 레지스터의 반영을 추적합니다. 응답이 늦으면 Access와 관련 값이 요청 완료까지 유지되어야 합니다.

[AXI 실습](lessons/2026.11.18_AXI_MASTER/)에서는 읽기 주소·데이터, 쓰기 주소·데이터·응답을 채널별로 살펴봅니다. 각 채널의 VALID와 READY가 함께 참인 에지에서 전달되므로, 파형에서 채널별 전달 순서와 응답을 따로 확인합니다. [AXI GPIO](lessons/20261120_AXI_GPIO/)의 레지스터는 [MicroBlaze C 예제](lessons/20261120_MicroBlaze_axi_gpio/software/main.c)와 함께 시스템에서 접근하는 실습으로 이어집니다.

## FPGA 타이밍 읽기

합성이나 배치배선이 끝난 뒤에는 실제 경로와 클록 제약을 함께 읽습니다. [PC+4 배치배선 기록](../../projects/rv32i-apb-soc/docs/timing/)에서 시작·끝 레지스터, 논리 단수, 배선 지연과 WNS를 확인할 수 있습니다. 비교 조건을 같게 유지해 어느 구간이 바뀌었는지 보고, RTL을 수정했다면 기능 테스트벤치도 다시 실행합니다.
