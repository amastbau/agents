#!/usr/bin/env bash
# pr-review-body-format-test.sh — Lock the review-body formatting contract
# in skills/pr-review/SKILL.md (issue #1366).
#
# The review agent builds `body` from that skill's template and
# Formatting rules. This test asserts the approve-with-findings fold
# and the omit-empty-section rules stay in the prompt.
#
# Run from the repo root:
#   bash scripts/pr-review-body-format-test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKILL="${REPO_ROOT}/skills/pr-review/SKILL.md"

FAILURES=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 — $2"; FAILURES=$((FAILURES + 1)); }

if [[ ! -f "${SKILL}" ]]; then
  echo "FAIL: skill missing at ${SKILL}"
  exit 1
fi

SKILL_TEXT="$(cat "${SKILL}")"

# Extract the "Formatting rules" bullet list through the next heading so
# assertions target the contract, not incidental mentions elsewhere.
FORMAT_RULES="$(python3 - "${SKILL}" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
start = text.find("**Formatting rules:**")
if start < 0:
    sys.stderr.write("FAIL: Formatting rules heading not found\n")
    sys.exit(2)
rest = text[start:]
# Next markdown heading at column 0 after the rules block.
idx = rest.find("\nIf `PRIOR_REVIEW_PROVENANCE`")
if idx < 0:
    sys.stderr.write("FAIL: could not bound Formatting rules section\n")
    sys.exit(2)
print(rest[:idx])
PY
)"

FLAT_RULES="$(python3 -c 'import re,sys; print(re.sub(r"\s+", " ", sys.stdin.read()))' <<< "${FORMAT_RULES}")"

# --- Approve-with-findings fold ---
if grep -qF '<summary>Findings</summary>' <<< "${SKILL_TEXT}"; then
  pass "skill-has-findings-summary"
else
  fail "skill-has-findings-summary" "missing <summary>Findings</summary> wrapper"
fi

if grep -qF '<details><summary>Findings</summary>' <<< "${FORMAT_RULES}"; then
  pass "format-rules-fold-approve-findings"
else
  fail "format-rules-fold-approve-findings" \
    "Formatting rules must wrap ### Findings in a details/summary block"
fi

if printf '%s' "${FLAT_RULES}" | grep -q 'When `action`' \
  && printf '%s' "${FLAT_RULES}" | grep -q 'is `approve`'; then
  pass "format-rules-gated-on-approve"
else
  fail "format-rules-gated-on-approve" \
    "fold instruction must be gated on action approve"
fi

# Non-approve outcomes stay unfolded.
if grep -q 'request-changes' <<< "${FORMAT_RULES}" \
  && grep -q '`comment`' <<< "${FORMAT_RULES}" \
  && grep -q '`reject`' <<< "${FORMAT_RULES}"; then
  pass "format-rules-non-approve-stay-unfolded"
else
  fail "format-rules-non-approve-stay-unfolded" \
    "Formatting rules must keep request-changes/comment/reject unfolded"
fi

# Zero-findings short-circuit is unchanged (no wrapper).
if grep -q 'Looks good to me' <<< "${FORMAT_RULES}"; then
  pass "format-rules-lgtm-short-circuit"
else
  fail "format-rules-lgtm-short-circuit" \
    "Formatting rules missing Looks good to me short-circuit"
fi

if printf '%s' "${FLAT_RULES}" | grep -qi 'zero findings' \
  && printf '%s' "${FLAT_RULES}" | grep -q 'no wrapper'; then
  pass "format-rules-zero-findings-no-wrapper"
else
  fail "format-rules-zero-findings-no-wrapper" \
    "zero-findings path must say no wrapper"
fi

# --- Omit empty sections / placeholders ---
if grep -q 'Only include sections that have content' <<< "${FORMAT_RULES}"; then
  pass "format-rules-omit-empty-sections"
else
  fail "format-rules-omit-empty-sections" \
    "must instruct omitting empty sections, not only empty severity headings"
fi

if grep -q '"None"' <<< "${FORMAT_RULES}" \
  && grep -q '"N/A"' <<< "${FORMAT_RULES}"; then
  pass "format-rules-forbid-placeholders"
else
  fail "format-rules-forbid-placeholders" \
    "must forbid None/N/A placeholders for empty sections"
fi

# Approve formatting shows the details wrapper around ### Findings.
if printf '%s' "${FLAT_RULES}" | grep -q '<details><summary>Findings</summary>' \
  && printf '%s' "${FLAT_RULES}" | grep -q '### Findings'; then
  pass "skill-template-approve-wraps-findings"
else
  fail "skill-template-approve-wraps-findings" \
    "formatting rules must wrap ### Findings in a Findings details block"
fi

if [[ "${FAILURES}" -ne 0 ]]; then
  echo "${FAILURES} test(s) failed"
  exit 1
fi
echo "All tests passed"
