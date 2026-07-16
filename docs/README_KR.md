# VC707 Ethernet → DDR3 Image Buffer → TargetTracking_YOLO 연결 패키지

이 패키지는 두 업로드 파일을 같이 기준으로 만든 수정 소스입니다.

- `VC707_MB_OSS_ETH_BRAM_NO_UART_self_contained_260602.zip`: 이미 구현된 Ethernet/UDP/BRAM 베이스
- `TargetTracking_YOLO.zip`: YOLO Verilog 모듈 묶음

## 목표 구조

```text
노트북 AirSim/Python
  ↓ UDP, 기존 MBWR 프로토콜
VC707 Ethernet/UDP endpoint
  ↓ 기존 32-bit BRAM-like write pulse
bram32_udp_to_mem_cmd
  ↓ command FIFO
vc707_yolo_ddr3_core
  ↓ AXI4 single beat master
MIG 7 Series AXI slave
  ↓
VC707 보드 DDR3
  ↑
global_feature_buffer_ddr3_adapter
  ↑
YOLO 모듈(data_formatter/yolo_head_wrapper 등)
```

## 핵심 파일

```text
rtl/ddr3/vc707_yolo_ddr3_core.v
rtl/ddr3/bram32_udp_to_mem_cmd.v
rtl/ddr3/global_feature_buffer_ddr3_adapter.v
rtl/ddr3/ddr3_cmd_arbiter_2to1.v
rtl/ddr3/axi4_single_beat_master.v
rtl/yolo/*.v
pc_tools/airsim_image_to_ddr3_mbwr.py
vivado/add_ddr3_yolo_sources.tcl
```

## 중요한 현실 제한

이 패키지는 Vivado에서 바로 bitstream이 나온다고 보장되는 완성 `.bit`가 아닙니다. 이유는 VC707 DDR3는 Vivado에서 MIG 7 Series IP를 실제 보드 preset으로 생성해야 하기 때문입니다. 다만 Ethernet/UDP로 들어온 이미지를 DDR3 명령으로 바꾸는 RTL과, 업로드한 YOLO의 GFB 읽기 방식에 맞는 DDR3 어댑터는 포함되어 있습니다.

## Vivado에서 할 일

1. 원본 VC707 프로젝트를 엽니다.
2. Tcl Console에서 이 패키지 루트 기준으로 실행합니다.

```tcl
source vivado/add_ddr3_yolo_sources.tcl
```

3. IP Catalog에서 `MIG 7 Series`를 추가합니다.
4. VC707 DDR3 preset을 선택합니다.
5. AXI4 interface를 켭니다.
6. 가능하면 AXI data width를 32-bit로 맞춥니다. MIG가 64/128-bit로만 잡히면 AXI Interconnect/Data Width Converter를 중간에 넣어야 합니다.
7. `vc707_yolo_ddr3_core`의 `m_axi_*`를 MIG의 `S_AXI`에 연결합니다.
8. MIG의 `ui_clk`와 `ui_clk_sync_rst`, `init_calib_complete`를 확인합니다.
9. 처음에는 `init_calib_complete`를 LED나 ILA로 확인하세요.

## YOLO 쪽 연결 방식

업로드된 YOLO에는 전체 top/control이 없어서, 최종 YOLO top 내부에서 기존 `global_feature_buffer`를 쓰던 곳을 DDR3 어댑터 신호로 바꿔야 합니다.

기존 BRAM 방식:

```verilog
global_feature_buffer u_gfb (...);
```

DDR3 방식:

```verilog
vc707_yolo_ddr3_core u_mem (...
    .yolo_gfb_raddr(o_gb_raddr),
    .yolo_gfb_re(o_gb_ren),
    .yolo_gfb_rdata(i_gb_rdata),
    .yolo_gfb_rvalid(i_gb_rvalid),
    ...
);
```

`data_formatter.v`와 `yolo_head_wrapper.v`는 이미 `i_gb_rvalid`를 입력으로 갖기 때문에 DDR3 지연을 받을 수 있는 형태입니다.

## DDR3 주소 맵

기본 설정:

```text
0x0000_0000 : 프레임 헤더 FRM0
0x0000_0100 : 이미지/GFB 데이터 시작
```

`global_feature_buffer_ddr3_adapter`는 GFB 주소 1개를 2048-bit = 256 byte로 봅니다.

```text
GFB raddr 0 → DDR3 0x0000_0100 ~ 0x0000_01FF
GFB raddr 1 → DDR3 0x0000_0200 ~ 0x0000_02FF
GFB raddr 2 → DDR3 0x0000_0300 ~ 0x0000_03FF
```

## PC에서 AirSim 이미지 전송

이미지 파일 테스트:

```powershell
python pc_tools\airsim_image_to_ddr3_mbwr.py --fpga-ip 192.168.1.10 --image dataset\images\val\drone_00000.jpg --resize 640x480
```

AirSim 직접 캡처:

```powershell
python pc_tools\airsim_image_to_ddr3_mbwr.py --fpga-ip 192.168.1.10 --vehicle Tracker --camera front_center --resize 640x480
```

기본 UDP 목적지는 기존과 같은 `192.168.1.10:5005`입니다.

## 주의

- UDP write는 기존 `MBWR` 프로토콜을 그대로 사용합니다.
- 기존 endpoint의 `MBRD` readback은 BRAM 고정 지연을 가정하므로 DDR3 디버그 readback은 완전하지 않습니다. 이미지 저장/YOLO 읽기 경로는 별도의 valid 기반 GFB 어댑터가 담당합니다.
- 업로드된 YOLO 모듈은 전체 시스템 top이 없기 때문에, 실제 YOLO start/control/bbox 출력까지 완성하려면 팀이 만든 top FSM에 이 GFB DDR3 인터페이스를 연결해야 합니다.
