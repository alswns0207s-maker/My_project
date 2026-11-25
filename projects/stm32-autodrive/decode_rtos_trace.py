#!/usr/bin/env python3
"""Decode a raw GDB dump of rtos_trace_capture and summarize task timing."""

from argparse import ArgumentParser
from collections import defaultdict
import csv
from pathlib import Path
from statistics import mean
from struct import Struct

HEADER = Struct("<4I")
EVENT = Struct("<IBBH")
TASKS = ("Idle/System", "MotorTask", "ControlTask", "BluetoothTask", "ButtonTask",
         "UltrasonicTask", "defaultTask")
KINDS = ("", "switch_in", "job_start", "job_end", "range", "skipped_releases")
SENSORS = ("front", "left", "right")


def read_capture(path):
    data = path.read_bytes()
    if len(data) < HEADER.size:
        raise ValueError("Capture header is missing.")
    magic, hclk, count, complete = HEADER.unpack_from(data)
    if magic != 0x52544F53 or not hclk or not 0 < count <= 1024:
        raise ValueError("Capture header is invalid. Resume the board before dumping it.")
    end = HEADER.size + count * EVENT.size
    if len(data) < end:
        raise ValueError("The dump ended before the last recorded event.")
    return hclk, complete, EVENT.iter_unpack(data[HEADER.size:end])


def decode_capture(hclk, records, output):
    starts = {}
    last_job = {}
    scheduled = defaultdict(int)
    periods = defaultdict(list)
    wall_times = defaultdict(list)
    scheduled_times = defaultdict(list)
    switch_count = defaultdict(int)
    skipped = defaultdict(int)
    active = 0
    previous_cycles = None
    elapsed = 0

    def us(cycles):
        return cycles * 1_000_000 / hclk

    with output.open("w", newline="", encoding="utf-8-sig") as file:
        writer = csv.writer(file)
        writer.writerow(("time_us", "task", "event", "detail", "job_wall_us", "job_scheduled_us"))
        for cycles, task, kind, value in records:
            if not 0 <= task < len(TASKS) or not 0 < kind < len(KINDS):
                raise ValueError(f"Invalid event: task={task}, kind={kind}.")
            if previous_cycles is not None:
                delta = (cycles - previous_cycles) & 0xFFFFFFFF
                elapsed += delta
                scheduled[active] += delta
            previous_cycles = cycles
            detail = ""
            wall_us = ""
            scheduled_us = ""
            if kind == 1:
                active = task
                switch_count[task] += 1
            elif kind == 2:
                if task in last_job:
                    periods[task].append(us(elapsed - last_job[task]))
                last_job[task] = elapsed
                starts[task] = elapsed, scheduled[task]
            elif kind == 3 and task in starts:
                job_start, scheduled_at_start = starts.pop(task)
                wall_value = us(elapsed - job_start)
                scheduled_value = us(scheduled[task] - scheduled_at_start)
                wall_times[task].append(wall_value)
                scheduled_times[task].append(scheduled_value)
                wall_us, scheduled_us = f"{wall_value:.2f}", f"{scheduled_value:.2f}"
            elif kind == 4:
                index, distance = value >> 10, value & 0x3FF
                if index >= len(SENSORS):
                    raise ValueError(f"Invalid ultrasonic sensor index: {index}.")
                detail = f"{SENSORS[index]}: {distance} cm" if distance else f"{SENSORS[index]}: invalid"
            elif kind == 5:
                skipped[task] += value
                detail = str(value)
            writer.writerow((f"{us(elapsed):.2f}", TASKS[task], KINDS[kind], detail,
                             wall_us, scheduled_us))
    return us(elapsed), switch_count, periods, wall_times, scheduled_times, skipped


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("-o", "--output", type=Path, default=Path("rtos_trace.csv"))
    args = parser.parse_args()
    if args.capture.resolve() == args.output.resolve():
        parser.error("The CSV path must differ from the capture path.")
    try:
        hclk, complete, records = read_capture(args.capture)
        duration, switches, periods, wall, scheduled, skipped = decode_capture(
            hclk, records, args.output
        )
    except (OSError, ValueError) as exc:
        parser.error(str(exc))
    print(f"{'Complete' if complete else 'Partial'} capture: {duration / 1000:.3f} ms")
    print("Start interval columns show min / mean / max (ms).")
    print("Job elapsed/scheduled averages include interrupts while that task was current.")
    for index, name in enumerate(TASKS):
        row = periods[index]
        interval = (
            f"{min(row)/1000:.3f} / {mean(row)/1000:.3f} / {max(row)/1000:.3f}"
            if row else "-"
        )
        job = f"{mean(wall[index]):.2f} / {mean(scheduled[index]):.2f} us" if wall[index] else "-"
        print(f"{name:15} switches={switches[index]:4}  interval={interval:27}  "
              f"job={job:23}  skipped={skipped[index]}")
    print(args.output)


if __name__ == "__main__":
    main()
