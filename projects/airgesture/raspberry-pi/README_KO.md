# AIRGESTURE 실행용 정리본

원본: AIRGESTURE_ALL_20261007.zip
실행 코드, 모델, 연결 설정은 원본과 바이트 단위로 동일합니다. 동작 변경 없이 파일만 정리했습니다.

## 실행
현재 사용하던 Raspberry Pi 환경에서:

```bash
source ~/.venv/bin/activate
cd ~/work/teampj/AIRGESTURE
python main.py --camera 0 --headless --fps 30 --preview-fps 25
```

PC에서는 기존 AirGesture_PC_bridge 수신기를 실행합니다. 이 ZIP은 Pi 인식 프로그램입니다.
기존 PC 수신기 폴더도 별도로 보관해야 합니다.
PC 주소 또는 연결 키가 바뀌었을 때만 `python configure_bridge.py`를 실행합니다.

## 포함한 것
- main.py 및 여기서 사용하는 Python 모듈 23개(연결 설정 도구 포함)
- models/hand_landmarker.task: MediaPipe 손 랜드마크 모델
- models/volume_ready_mlp.npz: 볼륨 준비 자세 분류 모델
- bridge_config.json: 기존 PC 연결 설정
- requirements-controls.txt: 기존 의존성 목록

wrist_swipe.py는 현재 코드가 import하므로 남겼습니다. 실제 스와이프 판정은 palm_swipe.py입니다.

## 제외한 것
- 프로젝트 내부 .venv, __pycache__, pyc
- test_*.py, install_patch.py, 기존 변경 이력 및 중복 안내문
- 비어 있는 내부 AIRGESTURE.zip
- 현재 사용하지 않는 swipe_ml.py, swipe_features.py, models/swipe_mlp.npz
- Pi main.py에서 사용하지 않는 구형 Windows 보조 실행기 pc_companion.py, start_companion.cmd, requirements-pc.txt

현재 쓰는 홈 디렉터리의 ~/.venv는 이 정리 작업의 대상이 아니며 실행할 때 그대로 사용합니다.
다른 Pi에 옮기는 경우 가상환경을 별도로 준비해야 합니다.
원본 ZIP에는 제외된 파일도 모두 남아 있습니다.

## 원본에서 확인한 동작
- 스와이프: OK 0.35초 진입, 주먹 0.35초 해제, 이동량 기준 8%
- MAIN 복귀: 엄지를 접고 나머지 4손가락 1.2초
- 주의: 이 원본 ZIP의 PPT 조건은 검지+중지+약지 OPEN, 새끼손가락 CLOSED입니다.
  요청했던 검지+중지+새끼손가락 조건과 다릅니다. 이번 정리는 코드를 변경하지 않았습니다.
- main.py 시작 안내의 OK again=exit는 예전 문구입니다. 실제 swipe_session.py는 주먹 해제입니다.

새 폴더에 압축을 해제해야 깔끔한 구성이 됩니다. 기존 폴더 위에 덮어쓰기만 하면 불필요한 파일이 남습니다.
기존 AIRGESTURE 폴더는 이름을 바꿔 보관한 뒤 새 정리본을 해제하세요.
