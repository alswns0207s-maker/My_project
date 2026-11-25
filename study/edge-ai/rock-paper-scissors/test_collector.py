import tempfile
import unittest
import zipfile
from pathlib import Path
from collector import Collector
from training_features import training_features
from test_recognition import hand

class CollectorTests(unittest.TestCase):
    def candidate(self):
        return {'world':hand('EEEE'),'landmarks':hand('EEEE'),'model_label':'None','model_score':.9}

    def test_features_are_rotation_scale_reflection_invariant(self):
        points=hand('EEEE')
        a=training_features(points)
        b=training_features([(z*3+1,-y*3+2,x*3-2) for x,y,z in points])
        self.assertEqual(len(a),222)
        for x,y in zip(a,b):self.assertAlmostEqual(x,y)

    def test_invalid_and_cancel(self):
        with tempfile.TemporaryDirectory() as tmp:
            c=Collector(tmp)
            with self.assertRaises(ValueError):c.start('wrong','left','paper',0)
            c.start('train','left','paper',0)
            with self.assertRaises(ValueError):c.start('train','left','paper',1)
            c.cancel();self.assertIsNone(c.active);self.assertEqual(c.clips,[])

    def test_timing_minimum_and_sample_rejection(self):
        with tempfile.TemporaryDirectory() as tmp:
            c=Collector(tmp);c.start('train','left','paper',0)
            c.sample(4,self.candidate());self.assertEqual(len(c.active['rows']),0)
            c.sample(5,None,'No hand');self.assertEqual(c.active['rejected'],1)
            c.sample(5.2,self.candidate());self.assertEqual(len(c.active['rows']),1)
            c.sample(5.21,self.candidate());self.assertEqual(len(c.active['rows']),1)
            c.sample(26,self.candidate());self.assertIsNone(c.active);self.assertEqual(c.clips,[])

    def test_unknown_gesture_is_saved_and_restored(self):
        with tempfile.TemporaryDirectory() as tmp:
            c=Collector(tmp);c.start('val','right','paper',0)
            for i in range(50):c.sample(5+i*.2,self.candidate(),review_jpeg=b'example')
            c.sample(26,None)
            self.assertEqual(len(c.clips),1)
            self.assertEqual(c.clips[0]['count'],50)
            loaded=Collector(tmp)
            self.assertEqual(loaded.snapshot(30)['counts']['val']['right']['paper'],50)
            with zipfile.ZipFile(loaded.archive()) as z:
                self.assertIsNone(z.testzip())
                self.assertIn('dataset.json',z.namelist())
                self.assertTrue(any(n.endswith('samples.jsonl') for n in z.namelist()))

    def test_http_collection_requires_camera_and_valid_json(self):
        import main
        client=main.app.test_client()
        self.assertEqual(client.get('/collect').status_code,200)
        self.assertEqual(client.get('/api/collection').status_code,200)
        self.assertEqual(client.post('/api/collection',json={}).status_code,409)
        self.assertEqual(client.post('/api/collection',json=[]).status_code,400)
        self.assertEqual(client.get('/review/missing/review_00.jpg').status_code,404)

if __name__=='__main__':unittest.main()
