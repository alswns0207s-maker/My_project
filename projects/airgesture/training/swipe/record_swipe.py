"""GUI or headless browser collector. Never sends PC control commands."""
import argparse
import json
import threading
import time
import uuid
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit,parse_qs
import cv2
import numpy as np
from camera import Camera
from hand_tracker import HandTracker,draw_hand
from swipe_features import LABELS,DURATION,features

HTML='''<!doctype html><meta charset="utf-8"><title>Swipe recorder</title>
<style>body{background:#15212d;color:white;font:20px sans-serif;text-align:center}button{font-size:24px;margin:8px;padding:15px}img{max-width:95vw}</style>
<h2>AirGesture 스와이프 데이터 수집</h2><img src="/frame" width="640" id="cam">
<p>화면 기준 방향입니다. 한 번 녹화에 한 방향만 젓고 끝에서 멈추세요.</p>
<button onclick="record('left')">1 ← 왼쪽</button><button onclick="record('right')">2 오른쪽 →</button><button onclick="record('none')">3 스와이프 아님</button>
<pre id="status"></pre><script>
async function record(label){await fetch('/record?label='+label,{method:'POST'});}
setInterval(async()=>{cam.src='/frame?t='+Date.now();document.getElementById('status').textContent=await(await fetch('/status')).text()},150);
document.onkeydown=e=>{const l={'1':'left','2':'right','3':'none'}[e.key];if(l)record(l)};
</script>'''

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--camera',type=int,default=0)
    ap.add_argument('--headless',action='store_true')
    ap.add_argument('--port',type=int,default=8770)
    ap.add_argument('--person',required=True,help='Same ID for the same participant')
    ap.add_argument('--session',required=True,help='Change when lighting/distance/session changes')
    ap.add_argument('--output',default='swipe_data')
    a=ap.parse_args()
    if not all(s and all(c.isalnum() or c in '_-' for c in s) for s in (a.person,a.session)):
        ap.error('person/session: letters, digits, underscore or hyphen only')
    lock=threading.Lock();state={'jpeg':b'','status':'READY','request':None,'busy':False}
    def request(label):
        with lock:
            if state['busy'] or state['request'] is not None:return False
            state['request']=label;state['busy']=True
            return True
    class Handler(BaseHTTPRequestHandler):
        def log_message(self,*args):pass
        def do_GET(self):
            path=urlsplit(self.path).path
            with lock:
                body=state['jpeg'] if path=='/frame' else (state['status'].encode() if path=='/status' else HTML.encode())
            self.send_response(200);self.send_header('Cache-Control','no-store')
            self.send_header('Content-Type','image/jpeg' if path=='/frame' else 'text/plain; charset=utf-8' if path=='/status' else 'text/html; charset=utf-8')
            self.end_headers();self.wfile.write(body)
        def do_POST(self):
            label=parse_qs(urlsplit(self.path).query).get('label',[''])[0]
            accepted=urlsplit(self.path).path=='/record' and label in LABELS and request(label)
            self.send_response(202 if accepted else 409);self.end_headers()
    server=ThreadingHTTPServer(('0.0.0.0' if a.headless else '127.0.0.1',a.port),Handler)
    threading.Thread(target=server.serve_forever,daemon=True).start()
    print(f'Open http://PI_IP:{a.port}/ on PC (local PC: http://127.0.0.1:{a.port}/)')
    print('Stop main.py first: only one program can own the USB camera. Ctrl+C quits.')
    camera=tracker=None;seq=0;start=time.monotonic();last_ms=-1
    label=None;begin=None;points=[];times=[];writer=None;video_path=None
    out=Path(a.output)/a.person/a.session;out.mkdir(parents=True,exist_ok=True)
    try:
        camera=Camera(a.camera,640,480,30);tracker=HandTracker()
        while True:
            seq,frame=camera.snapshot(seq)
            if frame is None:raise RuntimeError('Camera stopped')
            frame=cv2.resize(frame,(640,480));frame=cv2.flip(frame,1)
            now=time.monotonic();ms=max(last_ms+1,int((now-start)*1000));last_ms=ms
            result=tracker.process(frame,ms)
            with lock:
                if state['request'] is not None:
                    label=state['request'];state['request']=None;begin=now+1.0
                    points=[];times=[]
                    video_path=out/(label+'_'+uuid.uuid4().hex+'.avi')
                    writer=cv2.VideoWriter(str(video_path),cv2.VideoWriter_fourcc(*'MJPG'),20,(640,480))
                    if not writer.isOpened():raise RuntimeError('Cannot create recording AVI')
            status='READY: 1 LEFT / 2 RIGHT / 3 NONE'
            if label:
                if now<begin:status=f'{label.upper()} GET READY {begin-now:.1f}s'
                elif now<begin+DURATION:
                    status=f'{label.upper()} RECORD {begin+DURATION-now:.1f}s'
                    writer.write(frame)
                    if len(result.hand_landmarks)==1:
                        points.append([[v.x,v.y,v.z] for v in result.hand_landmarks[0]])
                        times.append(now-begin)
                else:
                    writer.release();writer=None
                    try:
                        features(points,times)
                        meta={'label':label,'person':a.person,'session':a.session,'mirrored':True,'width':640,'height':480,'duration':DURATION,'video_fps_note':'AVI is preview only; NPZ timestamps are authoritative'}
                        np.savez_compressed(video_path.with_suffix('.npz'),points=np.array(points,dtype='float32'),timestamps=np.array(times),metadata=json.dumps(meta))
                        status=f'SAVED {video_path.stem}';print(status)
                    except ValueError as e:
                        status=f'REJECTED: {e}';print(status);video_path.unlink(missing_ok=True)
                    with lock:state['busy']=False
                    label=None
                    state['last_result']=status
            shown=frame.copy();draw_hand(shown,result)
            cv2.rectangle(shown,(0,0),(640,58),(20,25,30),-1)
            cv2.putText(shown,status,(10,23),cv2.FONT_HERSHEY_SIMPLEX,.55,(255,255,255),1)
            cv2.putText(shown,'ONE WAY ONLY; return-to-center belongs to NONE',(10,48),cv2.FONT_HERSHEY_SIMPLEX,.45,(0,220,255),1)
            ok,jpeg=cv2.imencode('.jpg',shown,[cv2.IMWRITE_JPEG_QUALITY,75])
            with lock:
                state['status']=status+'\n'+state.get('last_result','')
                if ok:state['jpeg']=jpeg.tobytes()
            if not a.headless:
                cv2.imshow('Swipe recorder',shown);key=cv2.waitKey(1)&255
                if key in (ord('q'),27):break
                if key in (ord('1'),ord('2'),ord('3')):request(LABELS[key-ord('1')])
    except KeyboardInterrupt:pass
    finally:
        if writer:
            writer.release()
            if video_path:video_path.unlink(missing_ok=True)
        if tracker:tracker.close()
        if camera:camera.release()
        server.shutdown();server.server_close()
        if not a.headless:cv2.destroyAllWindows()

if __name__=='__main__':main()
