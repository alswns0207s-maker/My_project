import math
import unittest
from rps_recognition import geometry, recognize

def hand(pattern):
    pts=[(0.,0.,0.) for _ in range(21)]
    for n,base in enumerate([5,9,13,17]):
        x=(n-1.5)*.02
        coords=[(x,.06,0),(x,.09,0),(x,.12,0),(x,.14,0)] if pattern[n]=='E' else [(x,.06,0),(x,.09,0),(x,.07,.02),(x,.055,.015)]
        pts[base:base+4]=coords
    return pts

class RecognitionTests(unittest.TestCase):
    def test_shapes_and_rotation(self):
        for pattern, expected in [('EEEE','paper'),('FFFF','rock'),('EEFF','scissors')]:
            pts=hand(pattern)
            self.assertEqual(geometry(pts)[0],expected)
            # Reflection, scale, translation and rotation preserve the joint angles.
            transformed=[(2*z+3,-2*y+4,2*x-1) for x,y,z in pts]
            self.assertEqual(geometry(transformed)[0],expected)

    def test_other_and_invalid(self):
        self.assertIsNone(geometry(hand('EFFF'))[0])
        self.assertIsNone(geometry([(0,0,0)]*21)[0])
        self.assertIsNone(geometry([(math.nan,0,0)]*21)[0])

    def test_fallback_and_conflict(self):
        self.assertEqual(recognize(hand('EEEE'),'None',.9)[0],'paper')
        self.assertIsNone(recognize(hand('EEEE'),'Closed_Fist',.9)[0])
        self.assertEqual(recognize(hand('EEEE'),'Open_Palm',.9)[1],'모델+관절')

if __name__=='__main__':unittest.main()
