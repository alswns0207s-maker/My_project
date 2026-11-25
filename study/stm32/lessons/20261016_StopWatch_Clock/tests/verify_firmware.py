"""Exercise the built Cortex-M4 firmware using a GPIO/timer register mock.

Requires Python packages unicorn and pyelftools. No separate test firmware is used.
Usage: python tests/verify_firmware.py [--deps path/to/python/packages]
"""
import argparse
from pathlib import Path
import struct
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--deps', type=Path)
parser.add_argument('--elf', type=Path)
args = parser.parse_args()
if args.deps:
    sys.path.insert(0, str(args.deps))
from elftools.elf.elffile import ELFFile
from unicorn import Uc, UC_ARCH_ARM, UC_MODE_THUMB, UC_MODE_MCLASS, UC_HOOK_MEM_WRITE
from unicorn.arm_const import (
    UC_ARM_REG_R0, UC_ARM_REG_R1, UC_ARM_REG_R2, UC_ARM_REG_R3,
    UC_ARM_REG_SP, UC_ARM_REG_LR, UC_ARM_REG_PC, UC_ARM_REG_XPSR,
    UC_ARM_REG_PRIMASK,
)

root = Path(__file__).resolve().parents[1]
elf_path = args.elf or root / 'Debug' / (root.name + '.elf')
with elf_path.open('rb') as stream:
    elf = ELFFile(stream)
    segments = [(s['p_vaddr'], s.data()) for s in elf.iter_segments()
                if s['p_type'] == 'PT_LOAD' and s['p_filesz']]
    symbols = {s.name: s['st_value'] for s in elf.get_section_by_name('.symtab').iter_symbols()
               if s.name}

GPIOA, GPIOB, GPIOC = 0x40020000, 0x40020400, 0x40020800
TIM2, TIM3 = 0x40000000, 0x40000400
DIGITS = [(GPIOA, 1 << 5), (GPIOB, 1 << 6), (GPIOC, 1 << 7), (GPIOA, 1 << 10)]
SEGMENTS = [(GPIOA, 1 << 6), (GPIOA, 1 << 9), (GPIOB, 1 << 5), (GPIOB, 1 << 10),
            (GPIOA, 1 << 8), (GPIOA, 1 << 7), (GPIOB, 1 << 3), (GPIOB, 1 << 4)]
FONT = [0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F]
STOP, RUN = 0, 1
NONE, PUSH, RELEASE = 0, 1, 2


class Firmware:
    def __init__(self):
        self.uc = Uc(UC_ARCH_ARM, UC_MODE_THUMB | UC_MODE_MCLASS)
        for address, size in [(0x08000000, 0x80000), (0x20000000, 0x20000),
                              (0x40000000, 0x30000), (0xE000E000, 0x2000)]:
            self.uc.mem_map(address, size)
        for address, data in segments:
            self.uc.mem_write(address, data)
        self.capture = False
        self.trace = []
        self.enabledIrqs = 0
        self.uc.hook_add(UC_HOOK_MEM_WRITE, self.gpio_write,
                         begin=GPIOA, end=GPIOC + 0x3FF)
        self.uc.hook_add(UC_HOOK_MEM_WRITE, self.nvic_write,
                         begin=0xE000E100, end=0xE000E183)
        self.write(GPIOC + 0x10, 0xFFFF)

    def read(self, address):
        return struct.unpack('<I', self.uc.mem_read(address, 4))[0]

    def write(self, address, value):
        self.uc.mem_write(address, struct.pack('<I', value & 0xFFFFFFFF))

    def get(self, name):
        return self.read(symbols[name])

    def set(self, name, value):
        self.write(symbols[name], value)

    def gpio_write(self, uc, access, address, size, value, userdata):
        port = address & ~0x3FF
        if address - port == 0x18:  # GPIO BSRR -> ODR hardware side effect
            odr = (self.read(port + 0x14) | (value & 0xFFFF)) & ~(value >> 16)
            self.write(port + 0x14, odr)
            if self.capture:
                self.trace.append((port, value & 0xFFFF, value >> 16))

    def nvic_write(self, uc, access, address, size, value, userdata):
        # ISER/ICER are write-one-to-set/clear registers, not ordinary RAM.
        if address == 0xE000E100:
            self.enabledIrqs |= value
        elif address == 0xE000E180:
            self.enabledIrqs &= ~value

    def call(self, name, *values):
        for reg, value in zip([UC_ARM_REG_R0, UC_ARM_REG_R1, UC_ARM_REG_R2, UC_ARM_REG_R3], values):
            self.uc.reg_write(reg, value)
        self.uc.reg_write(UC_ARM_REG_SP, 0x2001FFF0)
        self.uc.reg_write(UC_ARM_REG_LR, 0x0807F001)
        self.uc.reg_write(UC_ARM_REG_XPSR, 1 << 24)
        self.uc.emu_start(symbols[name] | 1, 0x0807F000, count=200000)
        assert self.uc.reg_read(UC_ARM_REG_PC) == 0x0807F000, name + ' did not return'
        return self.uc.reg_read(UC_ARM_REG_R0)

    def init(self):
        self.call('MX_GPIO_Init')
        self.call('MX_TIM2_Init')
        self.call('MX_TIM3_Init')
        self.call('ap_init')

    def irq(self, timer):
        self.write(timer + 0x10, self.read(timer + 0x10) | 1)  # SR.UIF
        self.call('TIM2_IRQHandler' if timer == TIM2 else 'TIM3_IRQHandler')

    def advance(self, ms):
        for _ in range(ms):
            self.set('uwTick', self.get('uwTick') + 1)
            self.irq(TIM2)

    def input(self, pin, high):
        value = self.read(GPIOC + 0x10)
        self.write(GPIOC + 0x10, value | pin if high else value & ~pin)
        self.call('ap_task')
        self.advance(20)
        self.call('ap_task')

    def tap(self, pin):
        self.input(pin, False)
        self.input(pin, True)

    def clock_display(self):
        address = 0x2001F000
        self.call('Clock_getDisplay', address, address + 4)
        return struct.unpack('<H', self.uc.mem_read(address, 2))[0], self.uc.mem_read(address + 4, 1)[0]

    def led(self, port, pin):
        return bool(self.read(port + 0x14) & pin)


fw = Firmware()
fw.init()
for timer, irq in [(TIM2, 28), (TIM3, 29)]:
    assert fw.read(timer + 0x28) == 99, 'PSC'
    assert fw.read(timer + 0x2C) == 999, 'ARR'
    assert fw.read(timer) & 1 and fw.read(timer + 0x0C) & 1, 'counter/IRQ enable'
    assert not fw.read(timer + 0x10) & 1, 'initial update flag'
    assert fw.enabledIrqs & (1 << irq), 'NVIC enable'
assert fw.read(0x40023840) & 3 == 3, 'TIM2/TIM3 peripheral clocks'
for pin in [0, 1, 3]:
    assert (fw.read(GPIOC) >> (2 * pin)) & 3 == 0
    assert (fw.read(GPIOC + 0x0C) >> (2 * pin)) & 3 == 1
assert fw.clock_display() == (0, 2)
assert fw.led(GPIOB, 1 << 15) and not fw.led(GPIOB, (1 << 14) | (1 << 13))
assert not fw.led(GPIOC, 1 << 4)
print('PASS: actual GPIO/timer initialization, PSC/ARR, RCC, NVIC, startup mode/LEDs')

# Timing and rollover boundaries, with a running IRQ dispatched through HAL.
for ms, expected in [(499, (0, 2)), (500, (0, 0)), (999, (0, 0)),
                     (1000, (1, 2)), (59999, (59, 0)), (60000, (100, 2)),
                     (3599999, (5959, 0)), (3600000, (0, 2))]:
    fw.set('clockMs', ms - 1)
    fw.irq(TIM2)
    assert fw.clock_display() == expected, (ms, fw.clock_display())
fw.set('clockMs', 0)
fw.advance(1000)
assert fw.clock_display() == (1, 2)
assert fw.call('StopWatch_getCounter') == 0
print('PASS: 500 ms blink, 1 second, minute carry, 59:59 -> 00:00, clock in STOP')

fw.call('StopWatch_init')
fw.call('StopWatch_task', PUSH, NONE)
fw.advance(99)
assert fw.call('StopWatch_getCounter') == 0
fw.advance(1)
assert fw.call('StopWatch_getCounter') == 1
fw.advance(37)
fw.call('StopWatch_task', PUSH, NONE)
fw.advance(1000)
assert fw.get('elapsedMs') == 137
fw.call('StopWatch_task', PUSH, NONE)
fw.advance(63)
assert fw.call('StopWatch_getCounter') == 2
fw.call('StopWatch_task', NONE, PUSH)
fw.call('StopWatch_task', NONE, RELEASE)
assert fw.call('StopWatch_getState') == RUN and fw.call('StopWatch_getCounter') == 2
fw.set('elapsedMs', 999999)
fw.irq(TIM2)
assert fw.call('StopWatch_getCounter') == 0
fw.call('StopWatch_task', PUSH, NONE)
fw.set('elapsedMs', 123400)
fw.call('StopWatch_task', NONE, PUSH)
assert fw.call('StopWatch_getCounter') == 1234  # wait for release
fw.call('StopWatch_task', PUSH, RELEASE)  # simultaneous: clear wins
assert fw.call('StopWatch_getCounter') == 0 and fw.call('StopWatch_getState') == STOP
fw.uc.reg_write(UC_ARM_REG_PRIMASK, 1)
fw.call('StopWatch_task', NONE, NONE)
assert fw.uc.reg_read(UC_ARM_REG_PRIMASK) == 1
fw.uc.reg_write(UC_ARM_REG_PRIMASK, 0)
print('PASS: 100 ms steps, pause/resume fraction, clear-on-release, RUN clear ignored, wrap, IRQ mask')

# Debouncing uses actual HAL GPIO reads and the uint32_t SysTick counter.
fw = Firmware()
button = 0x2001E000
pin = 1 << 1
fw.call('button_init', button, GPIOC, pin)
fw.write(GPIOC + 0x10, 0xFFFF & ~pin)
assert fw.call('button_getState', button) == NONE
fw.set('uwTick', 10)
fw.write(GPIOC + 0x10, 0xFFFF)
assert fw.call('button_getState', button) == NONE
fw.set('uwTick', 12)
fw.write(GPIOC + 0x10, 0xFFFF & ~pin)
assert fw.call('button_getState', button) == NONE
fw.set('uwTick', 31)
assert fw.call('button_getState', button) == NONE
fw.set('uwTick', 32)
assert fw.call('button_getState', button) == PUSH
fw.set('uwTick', 5000)
assert fw.call('button_getState', button) == NONE
fw.set('uwTick', 0xFFFFFFF0)
fw.write(GPIOC + 0x10, 0xFFFF)
assert fw.call('button_getState', button) == NONE
fw.set('uwTick', 4)
assert fw.call('button_getState', button) == RELEASE
assert fw.call('button_getState', button) == NONE
print('PASS: contact bounce, exact 20 ms threshold, hold, release, uint32 tick wrap')

fw = Firmware()
fw.init()
fw.tap(1 << 0)  # clock -> stopwatch
assert fw.led(GPIOB, 1 << 14) and fw.led(GPIOB, 1 << 13)
fw.tap(1 << 1)  # start
fw.advance(100)
fw.call('ap_task')
assert fw.call('StopWatch_getState') == RUN and fw.led(GPIOC, 1 << 4)
before = fw.get('elapsedMs')
fw.tap(1 << 0)  # clock, stopwatch still running
fw.advance(1000)
fw.tap(1 << 1)  # ignored while viewing clock
fw.tap(1 << 3)  # ignored while viewing clock
fw.tap(1 << 0)
assert fw.call('StopWatch_getState') == RUN and fw.get('elapsedMs') >= before + 1000
fw.tap(1 << 1)  # stop
saved = fw.get('elapsedMs')
fw.advance(1000)
assert fw.get('elapsedMs') == saved
fw.input(1 << 3, False)
assert fw.get('elapsedMs') == saved
fw.input(1 << 3, True)
assert fw.get('elapsedMs') == 0
fw.set('elapsedMs', 4500)
fw.input(1 << 3, False)
fw.tap(1 << 0)  # cancel armed clear by switching away
fw.input(1 << 3, True)
fw.tap(1 << 0)
assert fw.get('elapsedMs') == 4500 and fw.call('StopWatch_getState') == STOP
fw.write(GPIOC + 0x10, 0xFFFF & ~((1 << 0) | (1 << 1)))
fw.call('ap_task')
fw.advance(20)
fw.call('ap_task')
assert fw.call('StopWatch_getState') == STOP  # mode has priority
print('PASS: real buttons, mode/status LEDs, background timing, stale edges, mode priority')

# Scan all fonts, decimal masks, leading zeros, blanking and a mid-frame update.
fw = Firmware()
fw.init()
for digit in range(10):
    fw.call('fnd_init')
    fw.call('fnd_set_frame', digit * 1111, 0x0A)
    for position in range(4):
        fw.trace = []
        fw.capture = True
        fw.irq(TIM3)
        fw.capture = False
        expected = FONT[digit] | (0x80 if position in [1, 3] else 0)
        actual = sum((1 << i) for i, (port, pin) in enumerate(SEGMENTS)
                     if fw.read(port + 0x14) & pin)
        assert actual == expected, (digit, position, actual, expected)
        assert [not bool(fw.read(port + 0x14) & pin) for port, pin in DIGITS] == [i == position for i in range(4)]
        assert len(fw.trace) == 13
        assert fw.trace[:4] == [(port, pin, 0) for port, pin in DIGITS], 'blank first'
fw.call('fnd_init')
fw.call('fnd_set_frame', 1234, 2)
fw.irq(TIM3)
fw.call('fnd_set_frame', 9876, 4)
for position, digit, dot in [(1, 2, True), (2, 3, False), (3, 4, False), (0, 9, False),
                             (1, 8, False), (2, 7, True), (3, 6, False)]:
    fw.irq(TIM3)
    actual = sum((1 << i) for i, (port, pin) in enumerate(SEGMENTS) if fw.read(port + 0x14) & pin)
    assert actual == FONT[digit] | (0x80 if dot else 0)
fw.call('fnd_set_frame', 65535, 0)
assert fw.get('pendingFrame') == 5535
fw.call('fnd_init')
fw.irq(TIM3)
assert all(fw.read(port + 0x14) & pin for port, pin in SEGMENTS[:6])
assert not fw.read(GPIOB + 0x14) & ((1 << 3) | (1 << 4))
print('PASS: FND 0..9, D1..D4, dots, leading zero, blanking, coherent frame, range clamp')
print('All firmware checks passed. Register mock only; physical board not exercised.')
