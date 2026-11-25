"""Time-based, simultaneous two-hand judging, independent of camera and UI."""
from collections import deque
import math

BEATS = {'rock': 'scissors', 'scissors': 'paper', 'paper': 'rock'}

def winner(left, right):
    if left not in BEATS or right not in BEATS:
        raise ValueError('Invalid gesture')
    return 'draw' if left == right else ('left' if BEATS[left] == right else 'right')

class Game:
    def __init__(self):
        self.score = {'left': 0, 'right': 0, 'draw': 0}
        self.phase = 'ready'
        self.result = None
        self.deadline = 0.0
        self.samples = deque()
        self.message = '양손을 펼쳐 화면에 보여주세요'
        self.history = deque(maxlen=8)

    def start(self, now):
        if self.phase in ('countdown', 'judging'):
            return False
        self.phase, self.deadline = 'countdown', now + 3
        self.result = None
        self.samples.clear()
        self.message = '카운트다운이 끝나면 양손 동작을 유지하세요'
        return True

    def update(self, now, pair):
        if self.phase == 'countdown' and now >= self.deadline:
            self.phase, self.deadline = 'judging', now + 2
            self.samples.clear()
        if self.phase != 'judging':
            return
        if now >= self.deadline:
            self.phase = 'retry'
            self.message = '양손을 떨어뜨리고 같은 동작을 잠시 유지한 뒤 다시 시도하세요'
            self.samples.clear()
            return
        if pair is None:
            self.samples.clear()
            return
        # A missing frame, long processing gap, or gesture change resets stability.
        if self.samples and (self.samples[-1][1] != pair or now-self.samples[-1][0] > .35):
            self.samples.clear()
        self.samples.append((now, pair))
        if len(self.samples) >= 4 and now-self.samples[0][0] >= .45:
            outcome = winner(*pair)
            self.score[outcome] += 1
            self.result = {'left': pair[0], 'right': pair[1], 'winner': outcome}
            self.history.appendleft(dict(self.result))
            self.phase = 'result'
            self.message = {'left': '왼손 승리!', 'right': '오른손 승리!', 'draw': '무승부!'}[outcome]

    def snapshot(self, now):
        return {'phase': self.phase, 'countdown': max(1, math.ceil(self.deadline-now)) if self.phase == 'countdown' else None,
                'message': self.message, 'score': dict(self.score), 'result': self.result,
                'history': list(self.history)}
