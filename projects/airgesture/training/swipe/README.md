# AirGesture 스와이프 MLP 학습

이 폴더에는 좌·우·해당 없음(left/right/none)을 분류하는 실험 모델의 수집·전처리·학습 코드가 있습니다. 저장소의 [실험 가중치](../../raspberry-pi/models/swipe_mlp.npz)와 [기존 평가 기록](training-results.ko.md)을 함께 볼 수 있습니다. 최종 제출 앱은 기본 동작에 손바닥 변위를 사용합니다.

## 데이터 수집

Python 3.11 또는 3.12 환경에서 다음을 실행합니다.

```bash
python -m pip install -r requirements.txt
python record_swipe.py --camera 0 --person subject01 --session s01
```

화면 기준 1·2·3 키로 왼쪽·오른쪽·해당 없음 클립을 수집합니다. 각 시도는 한 방향으로 움직이고, 다음 클립에서 조건을 바꿉니다. 동일 인물·동일 촬영 조건의 연속 기록에는 같은 그룹 이름을 씁니다. 수집 도구는 21개 랜드마크, 프레임 타임스탬프, 라벨과 분할용 그룹 ID를 `swipe_data/`에 기록합니다. 사람별 좌표·원본 영상은 로컬에서 관리합니다.

## 특성과 학습

```bash
python train_swipe.py --data swipe_data --group session --output models/swipe_mlp.npz
```

- 1개 클립을 시간축 **24개 구간**으로 맞춥니다.
- 각 구간은 손목 기준 좌표 **63개**와 시작점 대비 손목 이동 **3개**를 사용합니다.
- **1,584 → 64 ReLU → 3 softmax**를 NumPy로 학습합니다.
- 동일 세션이 서로 다른 분할에 섞이지 않도록 구성합니다. 표준화 통계는 훈련 분할에서만 계산하고, 검증 손실로 학습 중단 시점을 선택합니다.
- 결과는 NPZ 가중치와 같은 이름의 `.report.json`을 생성합니다. 새 사람 기준의 평가에는 `--group person`을 사용합니다.

## 결과 읽기

정리한 359개 클립 중 훈련 235, 검증 64, 테스트 60개를 사용했습니다. 기록된 test 좌표를 동작 시퀀스로 재생했을 때 39개 스와이프 중 **37개**가 정상 명령을 냈고 none 21개에서는 오입력이 없었습니다. 좌표 기반으로 정리한 라벨과 같은 참가자의 세션을 사용한 실험입니다. 다른 사람과 조명 조건에서의 성능은 새로운 데이터로 확인해야 합니다.

## 학습 도구 테스트

이 폴더에서 실행하며, 모델 추론 모듈을 찾도록 `raspberry-pi`를 PYTHONPATH에 추가합니다.

```powershell
$env:PYTHONPATH = (Resolve-Path ../../raspberry-pi).Path
python -m unittest discover -p "test_*.py"
```
