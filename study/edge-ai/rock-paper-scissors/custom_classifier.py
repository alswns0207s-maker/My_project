"""Run the Colab-trained classifier, preserving its feature/label contract."""
import hashlib
import json
import math
from pathlib import Path
import numpy as np
from training_features import training_features, FEATURE_VERSION, FEATURE_COUNT, LABELS

def select_prediction(probabilities, threshold, margin):
    p=np.asarray(probabilities,dtype=np.float32)
    if p.shape!=(4,) or not np.isfinite(p).all() or np.any(p<0) or np.any(p>1.001) or abs(float(p.sum())-1)>.01:
        raise ValueError('잘못된 모델 출력 확률')
    order=np.argsort(p)
    best=int(order[-1]);score=float(p[best])
    accepted=score>=threshold and score-float(p[order[-2]])>=margin
    return (LABELS[best] if accepted else None), score

class CustomClassifier:
    def __init__(self, model_dir, interpreter_factory=None):
        directory=Path(model_dir)
        data=(directory/'rps_custom.tflite').read_bytes()
        meta=json.loads((directory/'rps_custom.json').read_text(encoding='utf-8'))
        if meta.get('feature_version')!=FEATURE_VERSION or meta.get('feature_count')!=FEATURE_COUNT or meta.get('labels')!=LABELS:
            raise ValueError('학습 모델의 특징/라벨 순서가 게임과 다릅니다')
        if data[4:8]!=b'TFL3' or hashlib.sha256(data).hexdigest()!=meta.get('sha256'):
            raise ValueError('학습 모델 파일이 손상됐거나 JSON과 일치하지 않습니다')
        self.threshold=float(meta['threshold']);self.margin=float(meta['margin'])
        if not all(math.isfinite(v) and 0<=v<=1 for v in [self.threshold,self.margin]):
            raise ValueError('잘못된 모델 임계값')
        if interpreter_factory is None:
            try:
                from ai_edge_litert.interpreter import Interpreter
            except ImportError as exc:
                raise RuntimeError('LiteRT 미설치: .venv/bin/python -m pip install -r requirements_custom.txt') from exc
            interpreter_factory=Interpreter
        self.interpreter=interpreter_factory(model_content=data,num_threads=1)
        self.interpreter.allocate_tensors()
        inputs=self.interpreter.get_input_details();outputs=self.interpreter.get_output_details()
        if len(inputs)!=1 or len(outputs)!=1:
            raise ValueError('모델은 입력과 출력이 각각 하나여야 합니다')
        self.input,self.output=inputs[0],outputs[0]
        if list(self.input['shape'])!=[1,FEATURE_COUNT] or list(self.output['shape'])!=[1,4]:
            raise ValueError('모델 텐서 크기가 예상과 다릅니다')
        if self.input['dtype']!=np.float32 or self.output['dtype']!=np.float32:
            raise ValueError('float32 입력/출력 모델이 필요합니다')

    def predict_vector(self,vector):
        x=np.asarray(vector,dtype=np.float32)
        if x.shape!=(FEATURE_COUNT,) or not np.isfinite(x).all():
            raise ValueError('잘못된 손 특징 입력')
        self.interpreter.set_tensor(self.input['index'],x[None,:])
        self.interpreter.invoke()
        probabilities=self.interpreter.get_tensor(self.output['index'])[0]
        label,score=select_prediction(probabilities,self.threshold,self.margin)
        return label,score,probabilities.copy()

    def predict(self,world):
        vector=training_features(world)
        if vector is None:
            return None,0.0
        label,score,_=self.predict_vector(vector)
        return label,score
