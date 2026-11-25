#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
if [[ "$(uname -m)" != "aarch64" ]]; then
  echo 'This submission targets Raspberry Pi 5 / 64-bit Linux (aarch64).'
  exit 1
fi
/usr/bin/python3 -c 'import sys; assert sys.version_info[:2] == (3,11), "Python 3.11 required (Debian 12 Bookworm)"'
sudo apt update
sudo apt install -y python3-venv libgl1 libglib2.0-0 libportaudio2
/usr/bin/python3 -m venv .venv
.venv/bin/python -m pip install --upgrade pip
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m pip check
.venv/bin/python model_utils.py
.venv/bin/python check_runtime.py
.venv/bin/python check_custom_model.py
echo 'Setup complete. Run: bash run.sh'
