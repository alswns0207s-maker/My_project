"""Small, thread-safe recognition/result snapshot for the desktop HUD."""
import math
import threading
import time
import base64
import binascii


class StatusState:
    def __init__(self):
        self.lock=threading.Lock()
        self.recognition={}
        self.received=None
        self.result={}
        self.pending=''
        self.visible=True

    def update(self,data):
        if data.get('mode') not in ('MAIN','MEDIA','PPT','MOUSE'):
            raise ValueError('Invalid recognition mode')
        clean={'mode':data['mode']}
        for key in ('gesture','selector','bridge_status'):
            clean[key]=str(data.get(key,''))[:70]
        for key in ('hand','enabled','volume_lock','release_gate'):
            clean[key]=data.get(key) is True
        progress=data.get('progress',0)
        if not isinstance(progress,(float,int)) or not math.isfinite(progress):
            raise ValueError('Invalid progress')
        clean['progress']=max(0,min(1,progress))
        frame=data.get('frame','')
        if not isinstance(frame,str) or len(frame)>130000:raise ValueError('Invalid preview size')
        if frame:
            try:raw=base64.b64decode(frame,validate=True)
            except (ValueError,binascii.Error):raise ValueError('Invalid preview encoding')
            if not raw.startswith(b'\xff\xd8') or not raw.endswith(b'\xff\xd9'):
                raise ValueError('Expected JPEG preview')
        clean['frame']=frame
        port=data.get('stream_port',8767)
        if type(port) is not int or not 1<=port<=65535: raise ValueError('Invalid stream port')
        clean['stream_port']=port
        clean['preview_transport']='mjpeg' if data.get('preview_transport')=='mjpeg' else 'legacy'
        clean['stream_host']=str(data.get('stream_host',''))[:64]
        with self.lock:
            self.recognition=clean;self.received=time.monotonic()

    def begin(self,command):
        with self.lock:self.pending=command

    def finish(self,command,result):
        with self.lock:
            self.pending='';self.result={**result,'command':command}

    def snapshot(self):
        with self.lock:
            age=None if self.received is None else time.monotonic()-self.received
            return {'recognition':dict(self.recognition),'age':age,'result':dict(self.result),
                    'pending':self.pending,'visible':self.visible}


def overlay_lines(data):
    r=data.get('recognition',{});result=data.get('result',{})
    age=data.get('age')
    online=age is not None and age<2.5
    if online:
        heading=f"{r.get('mode','MAIN')}  ·  손 {'감지' if r.get('hand') else '없음'}"
        gesture=r.get('gesture','NONE')
        name={'OPEN_PALM':'보자기','FIST':'주먹','VOLUME_READY':'음량 준비',
              'UNKNOWN':'판정 중','NONE':'손 없음'}.get(gesture,gesture)
        pose=f'동작: {name} ({gesture})'
        gate=('음량 잠금' if r.get('volume_lock') else '선택 자세를 풀어 주세요' if r.get('release_gate')
              else '제어 가능' if r.get('enabled') else '제어 대기')
        progress=r.get('progress',0)
        if progress:gate+=f' · 선택 {progress*100:.0f}%'
    else:
        heading='AIRGESTURE · Pi 신호 대기'
        pose='Pi 인식 프로그램/연결을 확인하세요'
        gate='최근 인식 상태가 없습니다'
    pending=data.get('pending')
    command=result.get('command','')
    if pending: outcome=f'{pending} 처리 중…'
    elif command:
        outcome=f'{command} '+('완료' if result.get('ok') else '실패')
        if 'volume' in result:outcome+=f" · 음량 {result['volume']}"
        if not result.get('ok'):outcome+=': '+str(result.get('detail',''))[:95]
    else:outcome='PC 명령 대기'
    return heading,pose,gate,outcome
