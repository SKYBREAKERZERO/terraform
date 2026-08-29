#!/usr/bin/env bash
set - euo pipefail

PROJECT_ROOT="$(
    cd "$(dirname "${BASH_SOURCE[0]}")/.." && 
    pwd
)"

export PYTHONPATH="${PROJECT_ROOT}/python/src"

python3 \
    "${PROJECT_ROOT}/python/src/sns/show_sns.py"}"