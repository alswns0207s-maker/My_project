import json,tempfile,unittest
from pathlib import Path
import numpy as np
from unittest.mock import patch,Mock
from types import SimpleNamespace
from swipe_features import features,SwipeModel,LABELS
from train_swipe import split_groups,load_data,train,forward

def clip(direction):
    t=np.linspace(0,1.15,25)
    rng=np.random.default_rng(8)
    shape=rng.normal(0,.06,(21,3));shape[0]=0
    shape[[5,9,13,17],1]=-.1
    p=np.tile(shape+.5,(len(t),1,1))
    p[:,:,0]+=direction*t[:,None]*.12
    return p,t

class FeatureTests(unittest.TestCase):
    def test_dimensions_and_direction_differ(self):
        left,t=clip(-1);right,_=clip(1)
        a=features(left,t);b=features(right,t)
        self.assertEqual(a.shape,(1584,))
        self.assertLess(a.reshape(24,66)[-1,63],0)
        self.assertGreater(b.reshape(24,66)[-1,63],0)
    def test_absolute_translation_invariance(self):
        p,t=clip(1)
        np.testing.assert_allclose(features(p,t),features(p+.2,t),atol=1e-5)
    def test_missing_tracking_rejected(self):
        p,t=clip(1);t[12:]+=.4
        with self.assertRaises(ValueError):features(p,t)
    def test_short_clip_rejected(self):
        p,t=clip(1)
        with self.assertRaises(ValueError):features(p[:5],t[:5])

class PipelineTests(unittest.TestCase):
    def test_recording_to_model_roundtrip_and_group_isolation(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            for session in range(6):
                for label,direction in zip(LABELS,(-1,1,0)):
                    for repetition in range(5):
                        p,t=clip(direction)
                        meta={'label':label,'person':'p01','session':f's{session}','mirrored':True,'height':480,'width':640}
                        np.savez(root/f'{session}_{label}_{repetition}.npz',points=p,timestamps=t,metadata=json.dumps(meta))
            x,y,g,paths,rejected=load_data(root)
            self.assertEqual(len(y),90);self.assertFalse(rejected)
            splits=split_groups(y,g,42)
            group_sets=[set(g[i]) for i in splits]
            self.assertFalse(group_sets[0]&group_sets[1] or group_sets[0]&group_sets[2] or group_sets[1]&group_sets[2])
            model,history=train(x,y,*splits[:2],epochs=35)
            model_path=root/'model.npz';np.savez(model_path,**model)
            predictor=SwipeModel(model_path)
            for expected,direction in enumerate((-1,1,0)):
                p,t=clip(direction)
                probabilities=predictor.predict(p,t)
                self.assertEqual(int(np.argmax(probabilities)),expected)
                self.assertAlmostEqual(float(probabilities.sum()),1,places=5)
            np.testing.assert_allclose(model['mean'],x[splits[0]].mean(0))
    def test_insufficient_sessions_rejected(self):
        with self.assertRaises(ValueError):split_groups(np.array([0,1,2]),np.array(['a']*3),42)
    def test_missing_class_rejected(self):
        with self.assertRaises(ValueError):split_groups(np.zeros(60,dtype=int),np.repeat(np.arange(6).astype(str),10),42)

class RuntimeTests(unittest.TestCase):
    def setUp(self):
        from swipe_ml import load_model
        load_model.cache_clear()
        self.addCleanup(load_model.cache_clear)

    def test_one_event_until_none_rearms(self):
        from swipe_ml import MLSwipeDetector
        p,t=clip(1);lm=[SimpleNamespace(x=v[0],y=v[1],z=v[2]) for v in p[0]]
        with patch('swipe_ml.SwipeModel') as factory:
            factory.return_value.predict.return_value=np.array([.01,.98,.01])
            detector=MLSwipeDetector('unused')
            events=[detector.update(lm,'UNKNOWN',i/30) for i in range(90)]
            self.assertEqual([e for e in events if e],['SWIPE_RIGHT'])
            factory.return_value.predict.return_value=np.array([.01,.01,.98])
            for i in range(90,110):detector.update(lm,'UNKNOWN',i/30)
            self.assertTrue(detector.armed)
            factory.return_value.predict.return_value=np.array([.98,.01,.01])
            events=[detector.update(lm,'UNKNOWN',i/30) for i in range(110,140)]
            self.assertEqual([e for e in events if e],['SWIPE_LEFT'])
    def test_low_confidence_never_commands(self):
        from swipe_ml import MLSwipeDetector
        p,t=clip(1);lm=[SimpleNamespace(x=v[0],y=v[1],z=v[2]) for v in p[0]]
        with patch('swipe_ml.SwipeModel') as factory:
            factory.return_value.predict.return_value=np.array([.4,.5,.1])
            detector=MLSwipeDetector('unused')
            self.assertFalse(any(detector.update(lm,'OPEN_PALM',i/30) for i in range(90)))
    def test_ok_never_produces_swipe(self):
        from swipe_ml import MLSwipeDetector
        p,t=clip(1);lm=[SimpleNamespace(x=v[0],y=v[1],z=v[2]) for v in p[0]]
        with patch('swipe_ml.SwipeModel') as factory:
            detector=MLSwipeDetector('unused')
            self.assertFalse(any(detector.update(lm,'OK',i/30) for i in range(90)))
            factory.return_value.predict.assert_not_called()

if __name__=='__main__':unittest.main()
