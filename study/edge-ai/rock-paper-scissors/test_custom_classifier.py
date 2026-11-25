import hashlib
import json
import tempfile
from pathlib import Path
import unittest
import numpy as np
from custom_classifier import CustomClassifier,select_prediction
from training_features import FEATURE_VERSION, LABELS

class FakeInterpreter:
    def __init__(self,**kwargs):self.x=None
    def allocate_tensors(self):pass
    def get_input_details(self):return [{'index':0,'shape':np.array([1,222]),'dtype':np.float32}]
    def get_output_details(self):return [{'index':1,'shape':np.array([1,4]),'dtype':np.float32}]
    def set_tensor(self,index,x):self.x=x
    def invoke(self):assert self.x.shape==(1,222)
    def get_tensor(self,index):return np.array([[.02,.92,.03,.03]],np.float32)

class CustomTests(unittest.TestCase):
    def test_reject_and_other(self):
        self.assertIsNone(select_prediction([.45,.44,.1,.01],.5,.1)[0])
        self.assertIsNone(select_prediction([.51,.46,.02,.01],.5,.1)[0])
        self.assertEqual(select_prediction([.01,.02,.03,.94],.5,.1)[0],'other')
        with self.assertRaises(ValueError):select_prediction([float('nan')]*4,.5,.1)

    def test_contract_and_integrity(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);blob=b'0000TFL3example'
            meta={'feature_version':FEATURE_VERSION,'feature_count':222,'labels':LABELS,'threshold':.5,'margin':.1,'sha256':hashlib.sha256(blob).hexdigest()}
            (root/'rps_custom.tflite').write_bytes(blob)
            (root/'rps_custom.json').write_text(json.dumps(meta))
            c=CustomClassifier(root,FakeInterpreter)
            self.assertEqual(c.predict_vector([.2]*222)[0],'paper')
            with self.assertRaises(ValueError):c.predict_vector([.2]*12)
            (root/'rps_custom.tflite').write_bytes(blob+b'changed')
            with self.assertRaises(ValueError):CustomClassifier(root,FakeInterpreter)

if __name__=='__main__':unittest.main()
