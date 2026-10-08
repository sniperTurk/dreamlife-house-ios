#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Parallel isolated Swift binaries prevent the serial Linux smoke suite from
# exhausting short-lived CI runners. This is NOT a substitute for Xcode tests.
python3 "$ROOT/Tools/run_model_smoke_parallel.py"
