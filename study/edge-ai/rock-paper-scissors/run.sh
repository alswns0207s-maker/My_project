#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
if [[ ! -x .venv/bin/python ]]; then
  echo 'Run bash setup.sh first.'
  exit 1
fi
echo 'Open http://localhost:8501 on this Pi, or http://<Pi-IP>:8501 from another PC.'
echo 'Space: start / next round. R: reset score. Ctrl+C: stop server.'
exec .venv/bin/python main.py --classifier custom "$@"
