"""Check dependencies, TFLite bundle initialization and web routes without a camera."""
import numpy as np
import mediapipe as mp
from model_utils import bundle_bytes
from main import app

options = mp.tasks.vision.GestureRecognizerOptions(
    base_options=mp.tasks.BaseOptions(model_asset_buffer=bundle_bytes()), num_hands=2)
with mp.tasks.vision.GestureRecognizer.create_from_options(options) as model:
    result = model.recognize(mp.Image(image_format=mp.ImageFormat.SRGB, data=np.zeros((480,640,3),dtype=np.uint8)))
    assert len(result.hand_landmarks) == 0
client=app.test_client()
assert client.get('/').status_code == 200
assert client.get('/api/state').json['phase'] == 'ready'
assert client.post('/api/start', json={}).status_code == 409
assert client.post('/api/reset', json={}).status_code == 200
print('PASS: real TFLite inference on blank image, HTML, state, camera guard, reset')
