#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
LAB_DIR="$(cd "${PROJECT_DIR}/lab" && pwd)"

LMAPCTL="${PROJECT_DIR}/build/src/lmapctl"

AGENT_ID="test-ma"
CONTROLLER_URL="http://localhost:4000/v1/agents/${AGENT_ID}"

STATE_URL="${CONTROLLER_URL}/reported-state"
INSTRUCTION_URL="${CONTROLLER_URL}/required-config"

CAPABILITIES="${LAB_DIR}/capabilities"
CURRENT_INSTRUCTION="${LAB_DIR}/config/config.json"
QUEUE="${LAB_DIR}/queue"
RUN="${LAB_DIR}/run"

TEMPORARY_STATE="$(mktemp "${LAB_DIR}/config/.reported-state.XXXXXX")"
TEMPORARY_INSTRUCTION="$(mktemp "${LAB_DIR}/config/.instruction.XXXXXX")"

# Cleanup temporary files on exit
cleanup() {
  rm -f "${TEMPORARY_STATE}"
  rm -f "${TEMPORARY_INSTRUCTION}"
}

trap cleanup EXIT

# Generate current LMAP state
"${PROJECT_DIR}/build/src/lmapd" \
  -j \
  -s \
  -b "${CAPABILITIES}" \
  -c "${CURRENT_INSTRUCTION}" \
  -q "${QUEUE}" \
  -r "${RUN}" \
  > "${TEMPORARY_STATE}" || true

# Validate generated state JSON
jq empty "${TEMPORARY_STATE}"

# Report current state to Controller
curl --fail --silent --show-error \
  -X PUT \
  -H "Content-Type: application/json" \
  --data-binary @"${TEMPORARY_STATE}" \
  "${STATE_URL}"

# GET desired Instruction from Controller
curl --fail --silent --show-error \
  --output "${TEMPORARY_INSTRUCTION}" \
  "${INSTRUCTION_URL}"

# Validate received JSON
jq empty "${TEMPORARY_INSTRUCTION}"

# Validate received LMAP Instruction
"${LMAPCTL}" \
  -j \
  -q "${QUEUE}" \
  -r "${RUN}" \
  -c "${TEMPORARY_INSTRUCTION}" \
  validate

# Replace current Instruction
mv "${TEMPORARY_INSTRUCTION}" "${CURRENT_INSTRUCTION}"

# Reload lmapd
"${LMAPCTL}" \
  -j \
  -q "${QUEUE}" \
  -r "${RUN}" \
  -c "${CURRENT_INSTRUCTION}" \
  reload