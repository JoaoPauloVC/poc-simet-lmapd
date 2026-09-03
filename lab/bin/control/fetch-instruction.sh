#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
LAB_DIR="$(cd "${PROJECT_DIR}/lab" && pwd)"

LMAPCTL="${PROJECT_DIR}/build/src/lmapctl"

INSTRUCTION_URL="http://localhost:8000/instruction.json"
CURRENT_INSTRUCTION="${LAB_DIR}/config/hello.json"
TEMPORARY_INSTRUCTION="$(mktemp "${LAB_DIR}/config/.instruction.XXXXXX")"

cleanup() {
  rm -f "${TEMPORARY_INSTRUCTION}"
}
trap cleanup EXIT

curl --fail --silent --show-error \
  --output "${TEMPORARY_INSTRUCTION}" \
  "${INSTRUCTION_URL}"

"${LMAPCTL}" \
  -j \
  -q "${LAB_DIR}/queue" \
  -r "${LAB_DIR}/run" \
  -c "${TEMPORARY_INSTRUCTION}" \
  validate

mv "${TEMPORARY_INSTRUCTION}" "${CURRENT_INSTRUCTION}"

"${LMAPCTL}" \
  -j \
  -q "${LAB_DIR}/queue" \
  -r "${LAB_DIR}/run" \
  -c "${CURRENT_INSTRUCTION}" \
  reload