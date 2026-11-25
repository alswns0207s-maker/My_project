"""Conservative RPS geometry fallback using world-space hand joints.

Heuristic thresholds are not calibrated probabilities. Unknown poses stay unknown.
"""
import math

MAPPING = {'Closed_Fist': 'rock', 'Open_Palm': 'paper', 'Victory': 'scissors'}

def distance(a, b):
    return math.sqrt(sum((x-y)**2 for x,y in zip(a,b)))

def angle(a, b, c):
    u, v = [x-y for x,y in zip(a,b)], [x-y for x,y in zip(c,b)]
    denom = math.sqrt(sum(x*x for x in u)*sum(x*x for x in v))
    if denom < 1e-10:
        return None
    return math.degrees(math.acos(max(-1, min(1, sum(x*y for x,y in zip(u,v))/denom))))

def geometry(points):
    if len(points) != 21 or not all(math.isfinite(v) for p in points for v in p):
        return None, '관절 좌표 확인 중'
    if distance(points[0], points[9]) < 1e-5:
        return None, '관절 좌표 확인 중'
    states = []
    for m,p,d,t in [(5,6,7,8),(9,10,11,12),(13,14,15,16),(17,18,19,20)]:
        pip, dip = angle(points[m],points[p],points[d]), angle(points[p],points[d],points[t])
        if pip is None or dip is None:
            states.append('?'); continue
        length = sum(distance(points[a],points[b]) for a,b in [(m,p),(p,d),(d,t)])
        reach = distance(points[m],points[t])/max(length,1e-10)
        if pip >= 155 and dip >= 150 and reach >= .86:
            states.append('E')
        elif pip <= 120 and (reach <= .78 or dip <= 130):
            states.append('F')
        else:
            states.append('?')
    pattern = ''.join(states)
    # Thumb position varies naturally in RPS; use the other four fingers.
    gesture = {'EEEE':'paper', 'FFFF':'rock', 'EEFF':'scissors'}.get(pattern)
    return gesture, '손가락 ' + pattern + ' (E:펴짐 F:접힘 ?:불명확)'

def recognize(world, model_name, model_score, threshold=.65):
    geo, detail = geometry(world)
    model = MAPPING.get(model_name) if model_score >= threshold else None
    if model and geo and model != geo:
        return None, '분류와 관절 결과가 달라 확인 중', detail
    if model:
        return model, '모델+관절' if geo else '모델', detail
    if geo:
        return geo, '관절 보완', detail
    return None, '손가락 자세 확인 중', detail
