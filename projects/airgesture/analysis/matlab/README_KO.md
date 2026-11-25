# AirGesture MATLAB 그림 코드

## 실행

MATLAB R2020a 이상을 대상으로 작성했다. 압축을 풀고 Current Folder를 이 폴더로 지정한 뒤 명령 창에 `plot_airgesture`를 입력한다. 기본 MATLAB 함수만 사용하며 Python 및 Deep Learning Toolbox는 필요 없다.

함수는 figures 폴더에 그림 6종을 PNG(300dpi), 벡터 PDF, 편집 가능한 FIG로 저장한다. 예: `openfig('figures/03_mlp_structure.fig')`.

## 그림 구성

1. 실제 라벨별 영상 수와 AVI 헤더 프레임 수
2. VOLUME_READY / NOT_VOLUME_READY의 영상 단위 분포
3. 실제 저장 모델의 63–64–32–1 MLP 구성
4. NPZ에서 추출한 실제 학습 가중치 행렬
5. 21×3 좌표가 63개 특징으로 펼쳐지는 순서
6. MediaPipe, 규칙 판정, MLP 결합 구성도

## 분석한 자료

- AIRGESTURE.zip: AIRGESTURE/landmark_features.py, volume_classifier.py 및 models/volume_ready_mlp.npz
- 기존 제공 dataset_videos.zip: 6개 라벨별 AVI 2개씩, 총 12개
- AVI 헤더 기록: 총 3,600프레임, 모든 영상 640×480
- 이진 라벨 영상 수: 양성 2개, 음성 10개
- 모델: 입력 63 / 은닉 64 / 은닉 32 / 출력 1, ReLU 및 Sigmoid, threshold=0.8
- 가중치 6,112개와 편향 97개로 총 6,209개 파라미터

model_data.json에는 실제 가중치, 평균, 스케일과 원본 모델 SHA256이 있다. 모델 파일을 바꾸면 이 JSON도 새 모델에서 다시 추출해야 한다. video_inventory.csv는 기존 제공 ZIP의 스냅샷이며 다른 영상 파일을 추가해도 자동 갱신되지는 않는다.

## 해석할 때 주의

영상 파일 수와 헤더의 총 프레임 수는 최종 학습 샘플 수가 아니다. 손 검출 실패, 프레임 샘플링, 영상 단위 분할 등의 영향은 학습 스크립트와 결과 배열을 확인해야 한다. 이 CSV가 실제 학습에 모두 사용됐다는 증거는 없다.

가중치 히트맵은 실제 파라미터를 보여주지만 정확도나 각 좌표의 중요도 순위를 직접 나타내지는 않는다. 특징 순서 그림의 색은 특징 인덱스이며 측정값이 아니다. 가상의 정확도, 혼동행렬, 학습 곡선은 만들지 않았다.

normalize_airgesture.m은 기존 Python 좌표 정규화를 MATLAB로 옮긴 함수다. 21×3 실제 좌표 배열을 입력하며 저장 모델의 평균·스케일 표준화 전까지 처리한다. MATLAB에서는 reshape의 열 우선 순서 때문에 전치 후 펼쳐야 Python과 같은 순서가 된다.

## 검증 범위

원본 ZIP, 영상 헤더, 모델 배열 크기 및 파라미터 수를 확인했다. 이 작업 환경에 MATLAB/Octave 실행 파일이 없어 MATLAB 실행 및 그래픽 렌더링은 검증하지 못했다.

공식 함수 문서:
- https://www.mathworks.com/help/matlab/ref/readtable.html
- https://www.mathworks.com/help/matlab/ref/exportgraphics.html
