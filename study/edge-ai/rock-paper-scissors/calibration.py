"""Local, user-labelled landmark templates. No camera images are persisted."""
import json
import math
from pathlib import Path
from rps_recognition import angle, distance

LABELS = ('paper', 'scissors', 'rock', 'other')
NAMES = dict(zip(LABELS, ('보', '가위', '바위', '기타 자세')))

def features(points):
    if len(points) != 21 or not all(math.isfinite(v) for p in points for v in p):
        return None
    output=[]
    for m,p,d,t in [(5,6,7,8),(9,10,11,12),(13,14,15,16),(17,18,19,20)]:
        a,b=angle(points[m],points[p],points[d]),angle(points[p],points[d],points[t])
        length=sum(distance(points[x],points[y]) for x,y in [(m,p),(p,d),(d,t)])
        if a is None or b is None or length<1e-6:
            return None
        output.extend([a/180,b/180,distance(points[m],points[t])/length])
    return output

def rms(a,b):
    return math.sqrt(sum((x-y)**2 for x,y in zip(a,b))/len(a))

class Calibration:
    def __init__(self,path):
        self.path=Path(path)
        self.samples={k:[] for k in LABELS}
        self.active=None
        self.message='보 → 가위 → 바위 → 기타 자세 순서로 등록해주세요'
        try:
            data=json.loads(self.path.read_text(encoding='utf-8'))
            if data.get('version') != 1:
                raise ValueError('Unsupported calibration')
            for k in LABELS:
                rows=data['samples'][k]
                if not isinstance(rows,list) or len(rows)>240 or any(len(v)!=12 or not all(isinstance(x,(int,float)) and math.isfinite(x) and 0<=x<=1.001 for x in v) for v in rows):
                    raise ValueError('Invalid calibration')
                self.samples[k]=rows
        except FileNotFoundError:
            pass
        except (ValueError,TypeError,KeyError,OSError):
            self.samples={k:[] for k in LABELS}
            self.message='등록 파일을 읽지 못했습니다. 다시 등록해주세요'

    @property
    def ready(self):
        return all(len(self.samples[k])>=12 for k in LABELS)

    def start(self,label,now):
        if label not in LABELS or self.active:
            return False
        self.active={'label':label,'begin':now+3,'end':now+11,'last':-1,'rows':[]}
        return True

    def update(self,now,rows):
        a=self.active
        if not a:return
        if now>=a['end']:
            if len(a['rows'])<12:
                self.message='등록 실패: 손 전체를 보여주고 다시 등록해주세요'
            else:
                proposed=dict(self.samples)
                proposed[a['label']]=a['rows']
                try:
                    tmp=self.path.with_suffix('.tmp')
                    tmp.write_text(json.dumps({'version':1,'samples':proposed}),encoding='utf-8')
                    tmp.replace(self.path)
                    self.samples=proposed
                    self.message=NAMES[a['label']]+' 등록 완료'+(' · 맞춤 인식 사용 중' if self.ready else ' · 나머지 자세도 등록해주세요')
                except OSError:
                    self.message='저장 실패: 프로젝트 폴더 쓰기 권한을 확인해주세요'
            self.active=None
        elif now>=a['begin'] and now-a['last']>=.09:
            a['last']=now
            a['rows'].extend([r for r in rows if r is not None][:2])

    def predict(self,row):
        if not self.ready or row is None or self.active:return None
        scores=sorted((sum(sorted(rms(row,r) for r in values)[:3])/3,k) for k,values in self.samples.items())
        best,label=scores[0]
        if best>.13 or scores[1][0]-best<.025:return None
        return label

    def snapshot(self,now):
        message=self.message
        if self.active:
            a=self.active
            if now<a['begin']:
                message=f"{NAMES[a['label']]} 준비 · {math.ceil(a['begin']-now)}초 후 등록"
            else:
                message=f"{NAMES[a['label']]} 유지하며 천천히 각도 변경 · {max(0,math.ceil(a['end']-now))}초"
        return {'ready':self.ready,'active':self.active is not None,'message':message,
                'counts':{k:len(v) for k,v in self.samples.items()}}
