"""Explicit, user-labelled recording sessions with held-out capture rounds."""
import io
import json
import math
import time
import uuid
import zipfile
from pathlib import Path
from training_features import training_features, FEATURE_VERSION, FEATURE_COUNT, LABELS

SPLITS = ['train', 'val', 'test']
HANDS = ['left', 'right']
MIN_SAMPLES = 40

class Collector:
    def __init__(self, root):
        self.root = Path(root)
        self.active = None
        self.last = '한 손씩 촬영합니다. 먼저 1회차 / 왼손 / 보를 선택하세요.'
        self.clips = []
        for path in sorted(self.root.glob('*/meta.json')):
            try:
                meta=json.loads(path.read_text(encoding='utf-8'))
                if meta.get('feature_version') == FEATURE_VERSION:
                    self.clips.append(meta)
            except (OSError, ValueError):
                pass

    def start(self, split, hand, label, now):
        if self.active:
            raise ValueError('이미 촬영 중입니다')
        if split not in SPLITS or hand not in HANDS or label not in LABELS:
            raise ValueError('회차, 손, 동작을 선택해주세요')
        clip_id=time.strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]
        self.active = {'id':clip_id,'split':split,'hand':hand,'label':label,
                       'begin':now+5,'end':now+25,'last_sample':-1,'rows':[],
                       'images':[],'last_image':-1,'rejected':0,'reason':'5초 후 촬영합니다'}

    def cancel(self):
        self.active = None
        self.last = '촬영을 취소했습니다. 이번 촬영 데이터는 저장하지 않았습니다.'

    def sample(self, now, candidate, reason='', review_jpeg=None):
        a=self.active
        if a is None:
            return
        if now>=a['end']:
            self.finish()
            return
        if now<a['begin'] or now-a['last_sample']<.1:
            return
        a['last_sample']=now
        vector=training_features(candidate['world']) if candidate else None
        if vector is None:
            a['rejected']+=1
            a['reason']=reason or '관절 좌표가 불안정합니다'
            return
        a['reason']='수집 중 · 동작을 유지하며 손목을 천천히 돌리세요'
        row=dict(candidate)
        row.update(features=vector,elapsed=round(now-a['begin'],3))
        a['rows'].append(row)
        if review_jpeg is not None and now-a['last_image']>=2:
            a['images'].append((len(a['rows'])-1,review_jpeg))
            a['last_image']=now

    def needs_image(self, now):
        a=self.active
        return bool(a and a['begin']<=now<a['end'] and now-a['last_image']>=2)

    def finish(self):
        a=self.active
        if not a:return
        self.active=None
        if len(a['rows'])<MIN_SAMPLES:
            self.last=f"저장 안 됨: 유효 표본 {len(a['rows'])}개 / 최소 {MIN_SAMPLES}개. 한 손 전체를 보여주고 다시 촬영하세요."
            return
        folder=self.root/a['id']
        try:
            folder.mkdir(parents=True,exist_ok=False)
            meta={k:a[k] for k in ['id','split','hand','label','rejected']}
            meta.update(count=len(a['rows']),feature_version=FEATURE_VERSION,feature_count=FEATURE_COUNT,
                        duration=20,created=time.strftime('%Y-%m-%dT%H:%M:%S'),review_images=[])
            (folder/'samples.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in a['rows']),encoding='utf-8')
            for i,(row_index,image) in enumerate(a['images']):
                name=f'review_{i:02d}.jpg'
                (folder/name).write_bytes(image)
                meta['review_images'].append({'file':name,'row':row_index})
            # The manifest is the commit marker; incomplete folders never enter exports.
            (folder/'meta.json').write_text(json.dumps(meta,indent=2),encoding='utf-8')
            self.clips.append(meta)
            self.last=f"저장 완료: {a['hand']} / {a['label']} / {len(a['rows'])}개. 검토 사진에서 동작과 관절선을 확인하세요."
        except OSError as exc:
            self.last=f'저장 실패: {exc}'

    def snapshot(self,now):
        a=self.active
        countdown=0
        message=self.last
        if a:
            countdown=max(0,math.ceil((a['begin'] if now<a['begin'] else a['end'])-now))
            message=f"준비 {countdown}초 · 선택한 손 하나만 보여주세요" if now<a['begin'] else a['reason']
        counts={s:{h:{l:0 for l in LABELS} for h in HANDS} for s in SPLITS}
        for c in self.clips:
            counts[c['split']][c['hand']][c['label']]+=c['count']
        return {'active':bool(a),'message':message,'countdown':countdown,
                'saved':len(a['rows']) if a else 0,'rejected':a['rejected'] if a else 0,
                'counts':counts,'clips':list(reversed(self.clips))}

    def archive(self):
        out=io.BytesIO()
        with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
            z.writestr('dataset.json',json.dumps({'feature_version':FEATURE_VERSION,'labels':LABELS,'clips':len(self.clips)}))
            for clip in self.clips:
                folder=self.root/clip['id']
                for p in folder.iterdir():
                    if p.is_file() and (p.name in ('meta.json','samples.jsonl') or p.name.startswith('review_')):
                        z.write(p,clip['id']+'/'+p.name)
        out.seek(0)
        return out
