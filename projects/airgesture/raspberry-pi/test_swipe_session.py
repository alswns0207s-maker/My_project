import unittest
from gesture_controller import GestureController
from test_controls import hand, fingers

PALM = fingers('thumb','index','middle','ring','pinky')


class SwipeSessionTests(unittest.TestCase):
    def setUp(self):
        self.c=GestureController();self.c.modes.mode='MEDIA';self.now=0

    def feed(self, pose=PALM, shifts=None, frames=1, score=None):
        states=[]
        for shift in shifts if shifts is not None else [0]*frames:
            lm=hand(shift=shift)
            if pose is not None and pose['states']['thumb']:
                lm[4].x=.1;lm[4].y=.6
            states.append(self.c.update(pose,lm if pose is not None else None,
                                        volume_probability=score,now=self.now))
            self.now+=1/30
        return states

    def enter(self):
        pose=fingers('middle','ring','pinky')
        for i in range(12):
            lm=hand();lm[4].x=lm[8].x;lm[4].y=lm[8].y
            state=self.c.update(pose,lm,now=self.now)
            self.now+=1/30
            self.assertIsNone(state['command'])
        self.assertTrue(self.c.swipe.active)
        self.feed(frames=12)  # First open palm establishes neutral after OK.

    def test_palm_restores_play_and_never_arms_swipe(self):
        states=self.feed(frames=90)
        self.assertFalse(self.c.swipe.active)
        self.assertEqual([s['command'] for s in states if s['command']],['PLAY'])

    def test_ok_enters_swipe_without_play(self):
        self.enter()
        states=self.feed(shifts=[-.011*i for i in range(21)])
        self.assertEqual([s['command'] for s in states if s['command']],['VIDEO_NEXT'])

    def test_ok_geometry_rejects_volume_and_unpinched_palm(self):
        from ok_pose import is_ok_pose
        lm=hand();lm[4].x=lm[8].x;lm[4].y=lm[8].y
        self.assertTrue(is_ok_pose(fingers('middle','ring','pinky'),lm))
        self.assertFalse(is_ok_pose(fingers('thumb','index'),lm))
        lm[4].x=.1
        self.assertFalse(is_ok_pose(PALM,lm))

    def test_volume_is_blocked_in_swipe(self):
        self.enter()
        states=self.feed(fingers('thumb','index'),frames=25,score=.99)
        self.assertFalse(any(s['command'] or s['volume_lock'] for s in states))

    def ok_frames(self,count):
        result=[]
        for _ in range(count):
            lm=hand();lm[4].x=lm[8].x;lm[4].y=lm[8].y
            result.append(self.c.update(fingers('middle','ring','pinky'),lm,now=self.now))
            self.now+=1/30
        return result

    def test_fist_and_hand_loss_preserve_latch(self):
        self.enter()
        states=self.feed(fingers(),frames=60)+self.feed(None,frames=30)
        self.now+=2
        states+=self.feed(frames=30)
        self.assertTrue(self.c.swipe.active)
        self.assertFalse(any(s['command'] for s in states))

    def test_media_exit_pose_releases_without_a_media_command(self):
        self.enter()
        exit_pose = fingers('thumb', 'index', 'pinky')
        states = self.feed(exit_pose, frames=20)
        self.assertFalse(self.c.swipe.active)
        self.assertFalse(any(state['command'] for state in states))
        self.feed(pose=fingers('index'), frames=36)
        states = self.feed(frames=40)
        self.assertEqual([state['command'] for state in states if state['command']], ['PLAY'])

    def test_held_ok_and_disappearance_never_retoggle(self):
        states = self.ok_frames(90)
        self.assertTrue(self.c.swipe.active)
        self.feed(None, frames=30)
        states += self.ok_frames(90)
        self.assertTrue(self.c.swipe.active)
        self.assertFalse(any(state['command'] for state in states))
        self.feed(frames=12)
        self.ok_frames(60)
        self.assertTrue(self.c.swipe.active)

    def test_ppt_fist_exits_swipe(self):
        self.c.modes.mode = 'PPT'
        self.enter()
        states = self.feed(fingers(), frames=20)
        self.assertFalse(self.c.swipe.active)
        self.assertFalse(any(state['command'] for state in states))

    def test_partial_main_pose_preserves_latch_completed_main_clears(self):
        self.enter()
        self.feed(fingers('index','middle','ring','pinky'),frames=4)
        self.feed(frames=12)
        self.assertTrue(self.c.swipe.active)
        self.feed(fingers('index','middle','ring','pinky'),frames=45)
        self.assertEqual(self.c.modes.mode,'MAIN')
        self.assertFalse(self.c.swipe.active)

    @staticmethod
    def wave(sign):
        # A single horizontal displacement, then a return and neutral hold.
        outward = [sign * .011 * i for i in range(21)]
        return outward + [outward[-1]] * 12 + outward[::-1] + [0] * 10

    def test_ppt_alternating_displacements_after_neutral_hold(self):
        self.c.modes.mode = 'PPT'
        self.enter()
        states = self.feed(shifts=(self.wave(-1) + self.wave(1)) * 3)
        self.assertEqual([state['command'] for state in states if state['command']], ['NEXT', 'PREVIOUS'] * 3)

    def test_return_to_center_never_reverse_fires(self):
        self.c.modes.mode = 'PPT'
        self.enter()
        states = self.feed(shifts=self.wave(-1) * 3)
        self.assertEqual([state['command'] for state in states if state['command']], ['NEXT'] * 3)

    def test_jitter_and_stationary_pose_do_not_repeat(self):
        self.c.modes.mode = 'PPT'
        self.enter()
        states = self.feed(shifts=[(-1)**i * .008 for i in range(90)])
        self.assertFalse(any(state['command'] for state in states))
        shift = -.22
        states = self.feed(shifts=[shift * i / 20 for i in range(21)] + [shift] * 90)
        self.assertEqual([state['command'] for state in states if state['command']], ['NEXT'])


if __name__=='__main__':unittest.main()
