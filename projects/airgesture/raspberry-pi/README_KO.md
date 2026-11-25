# Raspberry Pi 인식부

[AirGesture 실행 방법과 최종 동작](../README.md)을 먼저 확인합니다.

이 폴더의 `main.py`는 MediaPipe 손 좌표, 상태 판정, 음량 MLP 및 PC 명령·미리보기 전송을 연결합니다. 카메라만 확인할 때는 `python main.py --camera 0 --no-bridge --no-stream`을 실행합니다. PC 주소와 새 연결 키는 `python configure_bridge.py`로 설정합니다.

기본 스와이프 판정은 [swipe_session.py](swipe_session.py)의 모드·진입 상태와 [palm_swipe.py](palm_swipe.py)의 수평 이동량을 사용합니다. 학습 모델과 비교 자료는 [학습 폴더](../training/swipe/)에 있습니다.
