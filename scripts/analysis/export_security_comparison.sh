#!/usr/bin/env bash

set -Eeuo pipefail

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <output-dir> <summary.csv> <summary.csv> <summary.csv> [summary.csv ...]"
  exit 1
fi

python3 "$(dirname "$0")/export_security_comparison.py" "$@"
