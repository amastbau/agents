#!/usr/bin/env bash
# common-preflight.sh — Fail fast when a required host-side dependency is missing.
#
# Declared via the harness `validation_loop.preflight_check` field and run by
# fullsend on the runner BEFORE sandbox creation (fullsend PR #5192). Shared by
# all seven JSON-schema-validating harnesses so the dependency probe lives in
# one place instead of being duplicated per harness.
set -euo pipefail

# jsonschema is required to validate agent output against the harness schema
# (ADR 0022). Fail hard if it is not importable.
if ! python3 -c "import jsonschema" 2>/dev/null; then
  echo "FAIL: python3 jsonschema package is not installed (required by ADR 0022)"
  exit 1
fi
