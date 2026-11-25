"""Check the local model interface with a synthetic input vector."""

from pathlib import Path

import numpy as np

from custom_classifier import CustomClassifier


if __name__ == "__main__":
    model = CustomClassifier(Path(__file__).resolve().parent / "models")
    _, _, probabilities = model.predict_vector(np.zeros(222, dtype=np.float32))
    if np.asarray(probabilities).shape != (4,) or not np.isfinite(probabilities).all():
        raise ValueError("Expected four finite output probabilities")
    print("PASS: custom TFLite loaded and 222-feature input / four-class output verified")
