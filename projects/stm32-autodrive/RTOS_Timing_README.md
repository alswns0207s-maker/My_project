# AutoDrive RTOS timing

STM32 NUCLEO-F411RE, FreeRTOS 10.3.1, CMSIS-RTOS v1. 이 프로젝트는 2026.11.16 AutoDrive의 ControlTask 계측 복사본을 이어서 작업한 버전입니다.

## 1. 영상에서 관찰한 장면

- 약 7–21초에 첫 코너에서 차가 같은 구간에 머물며 위치와 방향을 조금씩 바꿉니다.
- 약 23–31초에는 차가 긴 통로를 따라 이동합니다. 중후반 코너에서도 잠깐 멈추고 방향을 바꾸는 장면이 보입니다.
- 시연 소스 RC_Kim은 회전 뒤 80 ms 기다린 다음 각 센서에서 새 값 세 개가 모일 때까지 판단을 미룹니다. 센서 사이 대기가 35 ms라면 읽는 시간과 스케줄링을 빼고도 전체 센서 순회 세 번에 약 315 ms 규모의 대기가 생깁니다. 화면에 보이는 수 초의 지연이 어느 상태에서 생겼는지는 로그로 확인해야 합니다.
- 계측 프로젝트 AutoDrive는 시연용 RC_Kim과 별도입니다. AutoDrive는 센서 사이 60 ms 대기, 최대 약 350 ms의 제자리 회전, 이후 300 ms 안정화 구간을 사용합니다. 어느 버전을 보드에 올렸는지 구분한 뒤 영상과 로그를 비교하세요.

## 2. 이번에 바꾼 내용

ControlTask의 다음 실행 기준을 기존의 상대 지연인 osDelay(10)에서 vTaskDelayUntil()의 10 tick 고정 기준으로 바꿨습니다. FreeRTOS tick은 1 kHz입니다. 일정 안에 제어를 끝내면 시작 기준을 일정하게 유지할 수 있습니다. 높은 우선순위 태스크와 인터럽트가 먼저 실행되면 실제 시작은 기준보다 늦어질 수 있습니다.

주기가 이미 지나갔을 때는 지나간 기준 시점을 건너뛰고 원래의 10 ms 간격을 유지합니다. 건너뛴 횟수는 trace에 기록합니다. 조향값, 회전 시간, 모터 안전 정지, Bluetooth 명령, 초음파 대기 설정은 기준 프로젝트와 같습니다.

| 태스크 | 우선순위 | 초기 설정 |
| --- | --- | --- |
| MotorTask | High | 처리 후 5 tick 대기 |
| ControlTask | AboveNormal | 기준 시점에서 10 tick마다 준비 상태 |
| ButtonTask | AboveNormal | 처리 후 5 tick 대기 |
| BluetoothTask | AboveNormal | 처리 후 5 tick 대기 |
| defaultTask | Normal | 1,000 tick 대기 |
| UltrasonicTask | Idle | 센서 한 개 측정 후 60 tick 대기 |

## 3. 문맥 전환이 생기는 순간

- 태스크가 지연 함수로 들어가면 Blocked가 됩니다. 스케줄러가 가장 우선순위 높은 Ready 태스크를 고릅니다.
- 예를 들어 초음파 ECHO를 기다리는 중 MotorTask의 5 tick 대기가 끝나면, MotorTask가 초음파 태스크를 선점할 수 있습니다. ECHO 폴링 중인 초음파 태스크는 Ready로 남고, 다시 선택되면 중단된 지점부터 이어집니다.
- 준비된 AboveNormal 태스크가 여러 개면 FreeRTOS의 tick time slicing으로 순서가 바뀔 수 있습니다. ControlTask와 MotorTask가 같은 tick에 준비되면 우선순위가 높은 MotorTask가 먼저 선택됩니다. 그때 MotorTask가 읽는 출력은 ControlTask가 앞선 반복에서 저장한 값일 수 있습니다.
- 이 STM32 포트에서는 FreeRTOS SysTick과 PendSV가 전환에 관여합니다. UART RX 인터럽트는 수신 링버퍼에 기록합니다. 현재 코드에는 해당 인터럽트에서 BluetoothTask를 즉시 깨우는 FreeRTOS 호출이 없습니다.

## 4. CubeIDE로 실제 순서 보기

1. 프로젝트를 가져와 Debug 빌드합니다. 바퀴를 들어 올리거나 모터 전원을 빼고 정지 모드에서 첫 계측을 진행합니다.
2. Debugger Console에서 main에 멈춘 상태로 Resume합니다. 부팅 후 첫 1,024개 이벤트를 SRAM에 기록합니다. 잠시 실행한 뒤 Suspend하고 아래 두 값이 1과 1024인지 봅니다.

       p rtos_trace_capture.complete
       p rtos_trace_capture.count

3. 완료했다면 GDB에 다음처럼 입력합니다. 첫 경로는 접근 가능한 절대 경로를 사용하세요. Windows에서도 경로 구분자는 /로 쓰면 편합니다.

       dump binary memory "C:/your-folder/rtos_trace.bin" (char *)&rtos_trace_capture (char *)(&rtos_trace_capture + 1)

4. 프로젝트 디렉터리에서 CSV로 변환합니다.

       python decode_rtos_trace.py C:/your-folder/rtos_trace.bin -o C:/your-folder/rtos_trace.csv

5. 같은 펌웨어로 기존 동작을 비교하려면 디버그를 재시작해 main에서 멈춘 뒤 아래 명령을 쓰고 Resume합니다. 첫 실험에서는 두 조건 모두 정지 모드로 맞추세요.

       set variable control_use_fixed_period = 0

   1은 고정 기준, 0은 기존 상대 지연입니다. 값은 ControlTask 최초 시작 시 읽습니다. 펌웨어를 리셋하면 기본값은 1입니다. 주행 도중 새 기록이 필요하면 정지한 디버거에서 set variable rtos_trace_request = 1을 실행하고 Resume합니다. 새 기록은 다음 스케줄러 호출에서 시작합니다.

## 5. CSV 해석

- switch_in은 실제로 다른 태스크가 선택된 시점입니다. 예를 들어 UltrasonicTask job_start와 job_end 사이에 MotorTask switch_in이 끼면 초음파 측정 도중에 MotorTask가 실행된 것을 뜻합니다.
- job_start 사이 간격은 해당 작업이 시작된 시각의 차이입니다. UltrasonicTask는 센서 하나를 작업 한 번으로 세므로 3센서 순회 시간은 같은 센서의 range 이벤트 간격으로 확인합니다.
- job_wall_us는 작업 시작부터 끝까지 걸린 시간입니다. job_scheduled_us는 그중 같은 태스크가 선택돼 있던 시간입니다. 인터럽트가 끼어든 시간은 이 기록만으로 빼지 못합니다.
- range는 전방·왼쪽·오른쪽 각각의 거리 또는 측정 실패입니다. skipped_releases는 ControlTask가 건너뛴 기준 시점입니다.
- DWT 기록 자체가 조금의 실행 비용을 더합니다. 측정 기준과 비교 조건을 맞춰서 전후의 시작 간격·편차·누락 횟수를 비교하세요.

기존 ControlTask 보드 실측은 정지 모드에서 약 10 ms 간격, 처리 구간 3.55 µs였습니다. 이 수치는 변경 전 계측이며, 같은 시연 영상에 대한 동기화 로그는 없습니다.
