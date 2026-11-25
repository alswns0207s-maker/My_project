"""Build the MediaPipe bundle from the submitted, actually used TFLite files."""
from pathlib import Path
import io
import zipfile
import urllib.request
import hashlib
import json

ROOT = Path(__file__).resolve().parent / 'models'
URL = 'https://storage.googleapis.com/mediapipe-models/gesture_recognizer/gesture_recognizer/float16/1/gesture_recognizer.task'
GROUPS = {
    'hand_landmarker.task': ['hand_detector.tflite', 'hand_landmarks_detector.tflite'],
    'hand_gesture_recognizer.task': ['gesture_embedder.tflite', 'canned_gesture_classifier.tflite'],
}

def bundle_bytes():
    output = io.BytesIO()
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_STORED) as outer:
        for name, files in GROUPS.items():
            inner = io.BytesIO()
            with zipfile.ZipFile(inner, 'w', compression=zipfile.ZIP_STORED) as archive:
                for file in files:
                    data = (ROOT / file).read_bytes()
                    if data[4:8] != b'TFL3':
                        raise ValueError(f'Invalid TFLite model: {file}')
                    archive.writestr(file, data)
            outer.writestr(name, inner.getvalue())
    return output.getvalue()

def prepare():
    ROOT.mkdir(exist_ok=True)
    source = ROOT / 'gesture_recognizer.task'
    if not source.exists():
        urllib.request.urlretrieve(URL, source)
    with zipfile.ZipFile(source) as outer:
        for group, files in GROUPS.items():
            with zipfile.ZipFile(io.BytesIO(outer.read(group))) as inner:
                for file in files:
                    (ROOT / file).write_bytes(inner.read(file))
    manifest = {'source': URL, 'sha256': {
        name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
        for files in GROUPS.values() for name in files}}
    (ROOT / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    bundle_bytes()
    print('Models ready: 4 TFLite files verified.')

if __name__ == '__main__':
    prepare()
