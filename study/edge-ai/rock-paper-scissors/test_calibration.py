import tempfile
from pathlib import Path
import unittest
from calibration import Calibration, features
from test_recognition import hand

class CalibrationTests(unittest.TestCase):
    def test_features_rotation_and_invalid(self):
        pts=hand('EEEE')
        a=features(pts)
        b=features([(z*2+1,-y*2+2,x*2) for x,y,z in pts])
        for x,y in zip(a,b):self.assertAlmostEqual(x,y)
        self.assertIsNone(features([(0,0,0)]*21))

    def test_registration_persistence_and_rejection(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'calibration.json'
            c=Calibration(path)
            for label,pose in [('paper','EEEE'),('scissors','EEFF'),('rock','FFFF'),('other','EFFF')]:
                c.start(label,0)
                self.assertFalse(c.start(label,0))
                c.update(2,[features(hand(pose))]);self.assertEqual(len(c.active['rows']),0)
                for i in range(20):c.update(3+i*.15,[features(hand(pose))])
                c.update(12,[])
            self.assertTrue(c.ready)
            c=Calibration(path)
            self.assertEqual(c.predict(features(hand('EEEE'))),'paper')
            self.assertEqual(c.predict(features(hand('EEFF'))),'scissors')
            self.assertEqual(c.predict(features(hand('EFFF'))),'other')
            self.assertIsNone(c.predict([.3]*12))
            c.samples['rock']=c.samples['paper']
            self.assertIsNone(c.predict(features(hand('EEEE'))))

    def test_empty_registration_does_not_replace(self):
        with tempfile.TemporaryDirectory() as folder:
            c=Calibration(Path(folder)/'c.json')
            c.samples['paper']=[[.5]*12]*12
            c.start('paper',0);c.update(12,[])
            self.assertEqual(len(c.samples['paper']),12)

if __name__=='__main__':unittest.main()
