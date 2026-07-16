import argparse
import socket
import struct
import time
from pathlib import Path

import cv2
import numpy as np

MAGIC_WRITE = b"MBWR"
MAGIC_READ = b"MBRD"


def get_frame_from_airsim(vehicle: str, camera: str) -> np.ndarray:
    import airsim
    client = airsim.MultirotorClient()
    client.confirmConnection()
    responses = client.simGetImages([
        airsim.ImageRequest(camera, airsim.ImageType.Scene, False, False)
    ], vehicle_name=vehicle)
    if not responses or responses[0].height == 0:
        raise RuntimeError("AirSim image response is empty")
    r = responses[0]
    img = np.frombuffer(r.image_data_uint8, dtype=np.uint8).reshape(r.height, r.width, 3)
    # AirSim returns RGB; keep RGB byte order unless --bgr is requested.
    return img


def load_image(path: str, resize: str | None, bgr: bool) -> np.ndarray:
    img_bgr = cv2.imread(path, cv2.IMREAD_COLOR)
    if img_bgr is None:
        raise FileNotFoundError(path)
    if resize:
        w, h = map(int, resize.lower().split("x"))
        img_bgr = cv2.resize(img_bgr, (w, h), interpolation=cv2.INTER_AREA)
    return img_bgr if bgr else cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)


def pad4(data: bytes) -> bytes:
    return data + b"\x00" * ((4 - len(data) % 4) % 4)


def mbwr(sock: socket.socket, addr: int, data: bytes, fpga_ip: str, port: int, seq: int, words_per_packet: int, ack: bool):
    data = pad4(data)
    max_bytes = words_per_packet * 4
    offset = 0
    while offset < len(data):
        chunk = data[offset:offset + max_bytes]
        words = len(chunk) // 4
        pkt = MAGIC_WRITE + struct.pack(">I I H H", seq & 0xffffffff, addr + offset, words, 0) + chunk
        sock.sendto(pkt, (fpga_ip, port))
        if ack:
            try:
                resp, _ = sock.recvfrom(2048)
                if not resp.startswith(b"ACK!"):
                    print("WARN: non-ACK response", resp[:16])
            except socket.timeout:
                print(f"WARN: ACK timeout at addr=0x{addr+offset:08x}")
        seq += 1
        offset += len(chunk)
        # Small throttle keeps FPGA write FIFO safer during early tests.
        time.sleep(0.0002)
    return seq


def main():
    ap = argparse.ArgumentParser(description="Send AirSim/image frame to VC707 DDR3 through existing MBWR UDP protocol")
    ap.add_argument("--fpga-ip", default="192.168.1.10")
    ap.add_argument("--port", type=int, default=5005)
    ap.add_argument("--base", type=lambda x: int(x, 0), default=0x00000100, help="DDR3 byte base address for pixel/GFB data")
    ap.add_argument("--header", type=lambda x: int(x, 0), default=0x00000000, help="DDR3 byte address for frame header")
    ap.add_argument("--image", default=None)
    ap.add_argument("--resize", default="640x480")
    ap.add_argument("--vehicle", default="Tracker")
    ap.add_argument("--camera", default="front_center")
    ap.add_argument("--bgr", action="store_true", help="Send BGR order instead of RGB")
    ap.add_argument("--words-per-packet", type=int, default=256, help="256 words = 1024-byte payload")
    ap.add_argument("--no-ack", action="store_true")
    args = ap.parse_args()

    if args.image:
        frame = load_image(args.image, args.resize, args.bgr)
    else:
        frame = get_frame_from_airsim(args.vehicle, args.camera)
        if args.resize:
            w, h = map(int, args.resize.lower().split("x"))
            frame = cv2.resize(frame, (w, h), interpolation=cv2.INTER_AREA)
        if args.bgr:
            frame = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)

    h, w, c = frame.shape
    payload = frame.astype(np.uint8).tobytes(order="C")
    header = b"FRM0" + struct.pack(">IIIIII", 1, w, h, c, len(payload), args.base)
    header = header.ljust(256, b"\x00")

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(0.3)
    seq = 1
    print(f"Sending header to 0x{args.header:08x}, frame {w}x{h}x{c}, bytes={len(payload)}")
    seq = mbwr(sock, args.header, header, args.fpga_ip, args.port, seq, args.words_per_packet, not args.no_ack)
    print(f"Sending pixels to 0x{args.base:08x}")
    seq = mbwr(sock, args.base, payload, args.fpga_ip, args.port, seq, args.words_per_packet, not args.no_ack)
    print("done")


if __name__ == "__main__":
    main()
