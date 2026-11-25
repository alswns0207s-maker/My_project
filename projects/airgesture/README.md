# AirGesture 손동작 제어

2026년 10월 팀 프로젝트입니다. USB 웹캠의 영상을 Raspberry Pi에서 처리해 손동작을 판정하고, Windows PC에서 영상 재생·음량, PowerPoint 슬라이드와 마우스 포인터를 제어합니다.

![USB 웹캠, Raspberry Pi, 제어 모델과 Windows PC 연결](docs/airgesture-portfolio.jpg)

## 처리 흐름

```text
USB 웹캠 → MediaPipe 21개 손 관절 → 자세/동작 판정 → PC 제어 명령
                                 ↳ MLP로 음량 준비 자세 보강

Raspberry Pi → 미리보기 스트림 → Windows 오버레이
```

- **인식** — 관절 각도와 자세 유지 시간으로 상태를 판정합니다. 음량 준비 자세에서만 MLP 점수를 판정에 보조적으로 사용합니다.
- **입력 안정화** — 모드 진입 후 자세 해제, 명령별 유지 시간과 쿨다운, 손 소실 시 상태 초기화로 반복·오입력을 줄입니다.
- **Windows 연결** — PowerPoint COM으로 슬라이드를 제어하고, Playwright·Microsoft Edge를 통해 미디어를 제어합니다. 포인터와 버튼 상태를 전달하며, 손 추적이나 연결이 끊기면 버튼을 해제합니다.
- **표시** — 카메라 미리보기와 명령 전송은 별도 경로입니다. 오버레이에서 영상과 인식 상태를 함께 확인합니다.

## Raspberry Pi에서 인식만 실행

1. 웹캠을 연결하고 Pi에서 설치할 수 있는 Python·MediaPipe 조합을 사용합니다.
2. 아래 명령을 실행합니다. MediaPipe 모델은 첫 실행에서 공식 모델 파일을 내려받습니다. 음량 자세용 NumPy 모델은 포함되어 있습니다.

```bash
cd raspberry-pi
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-controls.txt
python main.py --camera 0 --no-bridge --no-stream
```

GUI 없이 인식 결과와 로그를 확인할 때는 `--headless`를 사용합니다.

## Windows PC와 연결

Windows에 Python, Microsoft Edge, PowerPoint 데스크톱 앱을 준비합니다. Pi와 PC는 서로 접근할 수 있는 동일한 로컬 네트워크에 둡니다.

```powershell
cd windows-pc
python -m pip install -r requirements.txt
python server.py
```

기본 수신 포트는 **8765**입니다. 첫 실행에서 PC 브리지가 연결 키를 생성합니다. Pi의 `raspberry-pi/` 폴더에서 `python configure_bridge.py`를 실행해 PC 주소와 브리지 키를 입력한 후 다음 명령을 실행합니다.

```bash
python main.py --camera 0 --headless --fps 30 --preview-fps 25
```

- `--fps 30`은 카메라 요청 설정값, `--preview-fps 25`는 미리보기 목표값입니다. 실제 추론 처리율은 환경에서 측정합니다.
- Windows 수신기에서 뜨는 연결 키와 Pi 설정은 로컬에 저장됩니다. 웹캠 스트림과 PC 제어는 신뢰할 수 있는 로컬 네트워크에서 사용합니다.
- Pi 소스에 포함된 이전 설명과 동작이 다른 경우에는 실제 모드 판정 코드인 [mode_manager.py](raspberry-pi/mode_manager.py), [gesture_controller.py](raspberry-pi/gesture_controller.py)를 확인합니다.

## 음량 자세 분류기

손목을 원점으로 옮기고 손 크기에 맞춰 21개 랜드마크의 `x, y, z`를 정규화합니다. 이때 얻은 **63차원** 입력을 **63 → 64 → 32 → 1** MLP에 넣습니다. 학습된 모델에는 **6,209개 파라미터**가 있습니다. 분류기의 출력을 상태·자세 보호 조건과 함께 사용합니다.

[학습 모델](raspberry-pi/models/volume_ready_mlp.npz) · [NumPy 추론 코드](raspberry-pi/volume_classifier.py) · [MATLAB 모델 분석](analysis/matlab/README_KO.md)

MATLAB용 영상 목록에는 라벨과 헤더 집계값이 들어 있습니다. 파일명은 번호로 치환했습니다. 실제 수집 영상의 프레임 수와 최종 학습에 사용한 샘플 수는 구분합니다.

## 검증 범위

| 항목 | 확인 범위 |
| --- | --- |
| 게시용 Python 소스 | 전체 파일 구문 검사 |
| NumPy MLP | 모델 로드, 6,209개 파라미터, 63차원 입력 배치 추론 확인 |
| 기존 발표자료 기록 | Pi 38개·PC 18개의 자동 테스트 기록과 합성 프레임의 localhost 미리보기 전송 25.0 fps 기록. 통합본 게시 시 해당 테스트 전체를 재실행하지는 않았습니다. |
| 실제 장치 | Pi 카메라부터 앱 제어까지의 성능은 카메라, 네트워크, OS 조건을 맞춰 별도로 측정합니다. |

원본 수집 영상과 개인 PC 설정은 저장소에서 제외했습니다. MediaPipe 모델은 Pi의 [모델 설정](raspberry-pi/config.py)에 지정된 제공처에서 내려받습니다.
