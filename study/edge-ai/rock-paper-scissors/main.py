"""Raspberry Pi USB webcam RPS. Run: python main.py"""
import argparse
import logging
import threading
import time
from pathlib import Path

from flask import Flask, Response, jsonify, render_template, request, send_file, send_from_directory
from game import Game
from model_utils import bundle_bytes
from rps_recognition import recognize
from calibration import Calibration, features
from collector import Collector
from custom_classifier import CustomClassifier

app = Flask(__name__)
lock = threading.Lock()
game = Game()
calibration = Calibration(Path(__file__).resolve().parent / 'calibration.json')
collector = Collector(Path(__file__).resolve().parent / 'dataset')
status = {'camera': False, 'error': '카메라를 준비하고 있습니다', 'hands': {}, 'fps': 0, 'latency': 0, 'temperature': None}
jpeg = None
frame_seq = 0
last_processed = 0.0
stop = threading.Event()

class Camera:
    """Continuously drain the camera; inference consumes only the latest frame."""
    def __init__(self, cv2, device, width, height):
        self.cv2 = cv2
        self.device, self.width, self.height = device, width, height
        self.lock = threading.Lock()
        self.latest = None
        self.number = 0
        self.failed = False

    def run(self):
        cap = self.cv2.VideoCapture(self.device, self.cv2.CAP_V4L2)
        try:
            if not cap.isOpened():
                raise RuntimeError(f'카메라 {self.device}를 열 수 없습니다')
            cap.set(self.cv2.CAP_PROP_FOURCC, self.cv2.VideoWriter_fourcc(*'YUYV'))
            cap.set(self.cv2.CAP_PROP_FRAME_WIDTH, self.width)
            cap.set(self.cv2.CAP_PROP_FRAME_HEIGHT, self.height)
            cap.set(self.cv2.CAP_PROP_FPS, 30)
            cap.set(self.cv2.CAP_PROP_BUFFERSIZE, 1)
            failures = 0
            while not stop.is_set():
                ok, frame = cap.read()
                if not ok:
                    failures += 1
                    if failures > 15:
                        raise RuntimeError('웹캠 영상 수신이 끊겼습니다. 연결 확인 후 서버를 재시작하세요')
                    time.sleep(.05)
                    continue
                failures = 0
                with self.lock:
                    self.latest = (frame, time.monotonic())
                    self.number += 1
        except Exception as exc:
            self.failed = True
            with lock:
                status.update(camera=False, error=str(exc), hands={})
        finally:
            cap.release()

def temperature():
    try:
        return round(int(Path('/sys/class/thermal/thermal_zone0/temp').read_text())/1000, 1)
    except (OSError, ValueError):
        return None

def worker(args):
    global jpeg, frame_seq, last_processed
    try:
        import cv2
        import mediapipe as mp
        cv2.setNumThreads(1)
        custom_dir=Path(__file__).resolve().parent/'models'
        has_custom=any((custom_dir/name).exists() for name in ['rps_custom.tflite','rps_custom.json'])
        use_custom=args.classifier=='custom' or (args.classifier=='auto' and has_custom)
        classifier=CustomClassifier(custom_dir) if use_custom else None
        with lock:
            status['classifier']='custom' if classifier else 'legacy'
        print('RPS classifier:', 'Colab TFLite' if classifier else 'legacy', flush=True)
        options = mp.tasks.vision.GestureRecognizerOptions(
            base_options=mp.tasks.BaseOptions(model_asset_buffer=bundle_bytes()),
            running_mode=mp.tasks.vision.RunningMode.VIDEO,
            num_hands=2, min_hand_detection_confidence=.6,
            min_hand_presence_confidence=.6, min_tracking_confidence=.5)
        camera = Camera(cv2, args.camera, args.width, args.height)
        threading.Thread(target=camera.run, daemon=True).start()
        mapping = {'Closed_Fist': 'rock', 'Open_Palm': 'paper', 'Victory': 'scissors'}
        connections = [(0,1),(1,2),(2,3),(3,4),(0,5),(5,6),(6,7),(7,8),(5,9),(9,10),(10,11),(11,12),(9,13),(13,14),(14,15),(15,16),(13,17),(0,17),(17,18),(18,19),(19,20)]
        prev_number, prev_timestamp, last_time = -1, -1, time.monotonic()
        with mp.tasks.vision.GestureRecognizer.create_from_options(options) as recognizer:
            while not stop.is_set() and not camera.failed:
                begin = time.monotonic()
                with camera.lock:
                    item, number = camera.latest, camera.number
                if item is None or number == prev_number:
                    time.sleep(.005)
                    continue
                frame, captured = item
                prev_number = number
                # Mirrored input makes MediaPipe handedness correspond to the user's hands.
                frame = cv2.flip(frame, 1)
                rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                timestamp = max(prev_timestamp+1, int(captured*1000))
                prev_timestamp = timestamp
                result = recognizer.recognize_for_video(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb), timestamp)
                # Record from raw detection, independent of gesture or handedness confidence.
                # The person selects the true hand and label; exactly one visible hand is required.
                with lock:
                    collecting = collector.active is not None
                    need_review = collector.needs_image(time.monotonic())
                if collecting:
                    candidate, review = None, None
                    collection_reason = '손 하나만 화면에 보여주세요'
                    if len(result.hand_landmarks) == 1 and len(result.hand_world_landmarks) == 1:
                        lm = result.hand_landmarks[0]
                        hh, ww = frame.shape[:2]
                        xs, ys = [p.x for p in lm], [p.y for p in lm]
                        if min(xs)<.015 or max(xs)>.985 or min(ys)<.015 or max(ys)>.985:
                            collection_reason = '손끝과 손목까지 화면 안에 넣어주세요'
                        elif (max(xs)-min(xs))*ww<60 or (max(ys)-min(ys))*hh<60:
                            collection_reason = '손이 너무 작습니다. 카메라에 조금 가까이 보여주세요'
                        elif time.monotonic()-captured>.5:
                            collection_reason = '영상이 지연되고 있습니다'
                        else:
                            cats=result.gestures[0]
                            top=max(cats,key=lambda c:c.score) if cats else None
                            candidate={'world':[[p.x,p.y,p.z] for p in result.hand_world_landmarks[0]],
                                       'landmarks':[[p.x,p.y,p.z] for p in lm],
                                       'model_label':top.category_name if top else 'None',
                                       'model_score':top.score if top else 0}
                            if need_review:
                                x1,x2=max(0,int(min(xs)*ww)-16),min(ww,int(max(xs)*ww)+16)
                                y1,y2=max(0,int(min(ys)*hh)-16),min(hh,int(max(ys)*hh)+16)
                                raw=frame[y1:y2,x1:x2].copy()
                                overlay=raw.copy()
                                points=[(int(p.x*ww)-x1,int(p.y*hh)-y1) for p in lm]
                                for u,v in connections:
                                    cv2.line(overlay,points[u],points[v],(0,220,255),2)
                                for point in points:
                                    cv2.circle(overlay,point,3,(0,255,100),-1)
                                preview=cv2.hconcat([raw,overlay])
                                if preview.shape[1]>640:
                                    preview=cv2.resize(preview,(640,int(preview.shape[0]*640/preview.shape[1])))
                                valid, buffer=cv2.imencode('.jpg',preview,[cv2.IMWRITE_JPEG_QUALITY,85])
                                review=buffer.tobytes() if valid else None
                    with lock:
                        collector.sample(time.monotonic(),candidate,collection_reason,review)
                hands, centers = {}, {}
                calibration_rows = []
                duplicate = False
                h, w = frame.shape[:2]
                for landmarks, world, handedness, gestures in zip(result.hand_landmarks, result.hand_world_landmarks, result.handedness, result.gestures):
                    if not handedness or handedness[0].score < .7:
                        continue
                    side = handedness[0].category_name.lower()
                    if side not in ('left', 'right'):
                        continue
                    if side in hands:
                        duplicate = True
                    cat = max(gestures, key=lambda c: c.score) if gestures else None
                    raw_name, raw_score = (cat.category_name, cat.score) if cat else ('None', 0)
                    world_points = [(p.x,p.y,p.z) for p in world]
                    gesture, source, detail = recognize(world_points, raw_name, raw_score, args.confidence)
                    vector = features(world_points)
                    if classifier:
                        prediction, probability=classifier.predict(world_points)
                        gesture=prediction if prediction in ('rock','paper','scissors') else None
                        source='Colab 학습 모델' if gesture else ('기타 동작 · 판정 보류' if prediction=='other' else '학습 모델 · 확인 중')
                        raw_name,raw_score=prediction or '불확실',probability
                    else:
                        with lock:
                            personal = calibration.predict(vector)
                        if personal:
                            gesture = personal if personal != 'other' else None
                            source = '내 손 맞춤 인식' if gesture else '등록된 기타 자세'
                    # Clipped fingers can yield plausible but incorrect inferred joints.
                    if any(p.x < .015 or p.x > .985 or p.y < .015 or p.y > .985 for p in landmarks):
                        gesture, source = None, '손 전체가 화면 안에 들어오게 해주세요'
                    elif vector is not None:
                        calibration_rows.append(vector)
                    hands[side] = {'gesture': gesture, 'confidence': round(raw_score, 2),
                                   'source': source, 'detail': detail, 'raw': raw_name}
                    centers[side] = (sum(p.x for p in landmarks)/21, sum(p.y for p in landmarks)/21)
                    pts = [(int(p.x*w), int(p.y*h)) for p in landmarks]
                    x1=max(0,min(x for x,y in pts)-8);y1=max(0,min(y for x,y in pts)-8)
                    x2=min(w-1,max(x for x,y in pts)+8);y2=min(h-1,max(y for x,y in pts)+8)
                    cv2.rectangle(frame,(x1,y1),(x2,y2),(25,25,25),3)
                    cv2.rectangle(frame,(x1,y1),(x2,y2),(240,240,240),1)
                    label=f'{side.upper()} / {(gesture or "?").upper()}'
                    origin=(max(5,min(x1,w-180)),max(22,y1-8))
                    cv2.putText(frame,label,origin,cv2.FONT_HERSHEY_SIMPLEX,.5,(15,15,15),3,cv2.LINE_AA)
                    cv2.putText(frame,label,origin,cv2.FONT_HERSHEY_SIMPLEX,.5,(245,245,245),1,cv2.LINE_AA)
                pair = None
                reason = '양손을 모두 보여주세요'
                if not duplicate and all(hands.get(s, {}).get('gesture') for s in ('left','right')):
                    a,b = centers['left'], centers['right']
                    if (a[0]-b[0])**2+(a[1]-b[1])**2 > .12**2:
                        pair = (hands['left']['gesture'], hands['right']['gesture'])
                        reason = '양손 인식 완료 · 동작을 유지하세요'
                    else:
                        reason = '양손 사이를 조금 더 벌려주세요'
                elif duplicate:
                    reason = '왼손·오른손 구분 확인 중 · 손을 교차하지 마세요'
                elif len(hands) == 2:
                    reason = '손은 감지됨 · 가위/바위/보 동작을 확인 중'
                now = time.monotonic()
                # Stale camera frames cannot contribute to a valid round.
                if now-captured > .5:
                    pair = None
                    reason = '영상 처리가 지연되고 있습니다'
                ok, encoded = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 78])
                with lock:
                    calibration.update(now, calibration_rows if now-captured<=.5 else [])
                    game.update(now, pair if not calibration.active and not collector.active else None)
                    status.update(camera=True, error=None, diagnostic=reason, version='6.0', hands=hands, fps=round(1/max(.001, now-last_time),1),
                                  latency=round((now-captured)*1000), temperature=temperature())
                    last_processed = now
                    if ok:
                        jpeg = encoded.tobytes()
                        frame_seq += 1
                last_time = now
                target = min(args.fps, 10) if (status['temperature'] or 0) >= 75 else args.fps
                stop.wait(max(0, 1/target-(time.monotonic()-begin)))
    except Exception as exc:
        logging.exception('Camera/model worker failed')
        with lock:
            status.update(camera=False, error=str(exc), hands={})

@app.get('/')
def index():
    return render_template('index.html')

@app.get('/collect')
def collect_page():
    return render_template('collect.html')

@app.get('/api/collection')
def collection_state():
    with lock:
        now=time.monotonic()
        if collector.active and now>=collector.active['end']:
            collector.finish()
        return jsonify(collector.snapshot(now))

@app.post('/api/collection')
def collection_action():
    if not request.is_json:
        return jsonify(error='JSON required'),415
    data=request.get_json(silent=True)
    if not isinstance(data,dict):
        return jsonify(error='Invalid request'),400
    with lock:
        if data.get('action')=='cancel':
            collector.cancel()
            return jsonify(ok=True)
        if calibration.active or game.phase in ('countdown','judging'):
            return jsonify(error='게임이나 손 등록을 먼저 마쳐주세요'),409
        if not status['camera'] or time.monotonic()-last_processed>2:
            return jsonify(error='카메라 연결을 확인해주세요'),409
        try:
            collector.start(data.get('split'),data.get('hand'),data.get('label'),time.monotonic())
        except ValueError as exc:
            return jsonify(error=str(exc)),400
    return jsonify(ok=True)

@app.get('/dataset.zip')
def dataset_download():
    with lock:
        if collector.active:
            return '촬영이 끝난 후 다운로드하세요',409
        if not collector.clips:
            return '저장된 촬영 데이터가 없습니다',404
        archive=collector.archive()
    return send_file(archive,mimetype='application/zip',as_attachment=True,download_name='rps_dataset.zip')

@app.get('/review/<clip_id>/<filename>')
def review_image(clip_id,filename):
    with lock:
        clip=next((c for c in collector.clips if c['id']==clip_id),None)
        if not clip or filename not in [r['file'] for r in clip['review_images']]:
            return 'Not found',404
    return send_from_directory(collector.root/clip_id,filename)

@app.get('/api/state')
def state():
    with lock:
        now = time.monotonic()
        data = dict(status)
        if now-last_processed > 2:
            data.update(camera=False, hands={})
            game.update(now, None)
        data.update(game.snapshot(now))
        calibration.update(now, [])
        data['calibration'] = calibration.snapshot(now)
        return jsonify(data)

@app.post('/api/<action>')
def action(action):
    global game
    if not request.is_json:
        return jsonify(error='JSON request required'), 415
    with lock:
        if action == 'start':
            if calibration.active or collector.active:
                return jsonify(error='손 등록이 끝난 후 시작해주세요'), 409
            if not status['camera'] or time.monotonic()-last_processed > 2:
                return jsonify(error='카메라 연결을 먼저 확인해주세요'), 409
            if not game.start(time.monotonic()):
                return jsonify(error='이미 라운드가 진행 중입니다'), 409
        elif action == 'reset':
            game = Game()
        elif action == 'calibrate':
            if status.get('classifier')=='custom':
                return jsonify(error='Colab 모델 사용 중에는 기존 개인화 등록을 사용하지 않습니다'),409
            if collector.active:
                return jsonify(error='데이터 촬영이 끝난 후 등록해주세요'),409
            if not status['camera'] or time.monotonic()-last_processed>2:
                return jsonify(error='카메라 연결을 확인해주세요'),409
            if game.phase in ('countdown','judging'):
                return jsonify(error='라운드 종료 후 등록해주세요'),409
            if not calibration.start((request.get_json(silent=True) or {}).get('label'),time.monotonic()):
                return jsonify(error='등록 중이거나 잘못된 동작입니다'),409
        else:
            return jsonify(error='Unknown action'), 404
    return jsonify(ok=True)

@app.get('/video')
def video():
    def generate():
        seen = -1
        while not stop.is_set():
            with lock:
                data, number = jpeg, frame_seq
            if data is not None and number != seen:
                seen = number
                yield b'--frame\r\nContent-Type: image/jpeg\r\n\r\n' + data + b'\r\n'
            else:
                time.sleep(.025)
    return Response(generate(), mimetype='multipart/x-mixed-replace; boundary=frame', headers={'Cache-Control': 'no-store'})

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--camera', type=int, default=0)
    parser.add_argument('--width', type=int, default=640)
    parser.add_argument('--height', type=int, default=480)
    parser.add_argument('--fps', type=float, default=15, help='Inference rate cap, camera requests 30fps')
    parser.add_argument('--confidence', type=float, default=.65)
    parser.add_argument('--classifier',choices=['auto','custom','legacy'],default='auto',help='auto loads the custom model if present; legacy restores previous recognition')
    parser.add_argument('--port', type=int, default=8501)
    args = parser.parse_args()
    if args.fps <= 0 or not 0 < args.confidence <= 1:
        parser.error('fps must be positive; confidence must be in (0, 1]')
    threading.Thread(target=worker, args=(args,), daemon=True).start()
    logging.getLogger('werkzeug').setLevel(logging.ERROR)
    try:
        app.run(host='0.0.0.0', port=args.port, threaded=True, debug=False, use_reloader=False)
    finally:
        stop.set()
