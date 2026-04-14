#!/usr/bin/env bash

set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <summary.json>"
  exit 1
fi

python3 "$(dirname "$0")/export_sweep_artifacts.py" "$1"
