import unittest
from game import Game, winner

class Rules(unittest.TestCase):
    def test_all_nine_pairs(self):
        for a,b,c in [('rock','scissors','paper'), ('scissors','paper','rock'), ('paper','rock','scissors')]:
            self.assertEqual(winner(a,a),'draw')
            self.assertEqual(winner(a,b),'left')
            self.assertEqual(winner(a,c),'right')

    def test_stability_and_single_score(self):
        g=Game();g.start(0)
        for t in [3,3.1,3.2,3.3,3.5,3.6,4]:g.update(t,('rock','scissors'))
        self.assertEqual(g.phase,'result');self.assertEqual(g.score['left'],1)

    def test_missing_hand_resets(self):
        g=Game();g.start(0)
        for t in [3,3.1,3.2]:g.update(t,('rock','paper'))
        g.update(3.3,None);g.update(3.5,('rock','paper'))
        self.assertEqual(g.phase,'judging')
        g.update(5.1,None);self.assertEqual(g.phase,'retry');self.assertEqual(sum(g.score.values()),0)

    def test_changed_gesture_and_long_gap(self):
        g=Game();g.start(0)
        for t in [3,3.1,3.2,3.3]:g.update(t,('paper','rock'))
        g.update(3.5,('scissors','rock'));self.assertEqual(g.phase,'judging')
        g.update(4.1,('scissors','rock'));self.assertEqual(len(g.samples),1)

    def test_countdown_and_duplicate_start(self):
        g=Game();g.start(0);self.assertFalse(g.start(1))
        g.update(2.9,('rock','paper'));self.assertEqual(g.phase,'countdown')

if __name__=='__main__':unittest.main()
