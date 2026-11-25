"""Versioned features shared by collection, training and eventual deployment."""
from calibration import features
from rps_recognition import distance

FEATURE_VERSION = 'world_distances_angles_v1'
FEATURE_COUNT = 222
LABELS = ['rock', 'paper', 'scissors', 'other']

def training_features(points):
    angles = features(points)
    if angles is None:
        return None
    scale = distance(points[0], points[9])
    if scale < .00001:
        return None
    distances = [distance(points[i],points[j])/scale for i in range(21) for j in range(i+1,21)]
    return distances + angles
