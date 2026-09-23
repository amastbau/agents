#!/usr/bin/env bash
# pr-review-skill-test.sh — Lock the missing-sub-agent failure protocol.
#
# Prompt-only regression for fullsend-ai/agents#285: when pr-review
# sub-agent definition files cannot be loaded, the orchestrator must
# record sub-agent-failure findings and request-changes, not fall back
# to a single-pass code-review approval.
#
# Run from the repo root: bash scripts/pr-review-skill-test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKILL="${REPO_ROOT}/skills/pr-review/SKILL.md"
PREFLIGHT="${REPO_ROOT}/skills/pr-review/references/missing-sub-agents.md"
AGENT="${REPO_ROOT}/agents/review.md"
CODE_REVIEW="${REPO_ROOT}/skills/code-review/SKILL.md"

FAILURES=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 — $2"; FAILURES=$((FAILURES + 1)); }

require_file() {
  local name="$1"
  local file="$2"
  if [[ -f "${file}" ]]; then
    pass "${name}"
  else
    fail "${name}" "missing ${file}"
  fi
}

# Collapse wrapping so assertions match the protocol, not line breaks.
file_text() {
  tr '\n' ' ' < "$1" | tr -s ' '
}

require_grep() {
  local name="$1"
  local file="$2"
  local pattern="$3"
  if file_text "${file}" | grep -qE "${pattern}"; then
    pass "${name}"
  else
    fail "${name}" "pattern not found in ${file}: ${pattern}"
  fi
}

forbid_grep() {
  local name="$1"
  local file="$2"
  local pattern="$3"
  if file_text "${file}" | grep -qE "${pattern}"; then
    fail "${name}" "forbidden pattern in ${file}: ${pattern}"
  else
    pass "${name}"
  fi
}

require_file "skill-present" "${SKILL}"
require_file "preflight-present" "${PREFLIGHT}"
require_file "agent-present" "${AGENT}"
require_file "code-review-present" "${CODE_REVIEW}"

# --- pr-review skill: pointer, step 5, and no failure-for-missing-files ---

require_grep "skill-links-preflight" "${SKILL}" \
  'references/missing-sub-agents.md'

require_grep "skill-missing-files-step-5" "${SKILL}" \
  'Missing files: step 5'

require_grep "skill-step5-covers-missing-file" "${SKILL}" \
  'empty response, missing file'

# --- pre-flight reference: the protocol the issue requires ---

require_grep "preflight-pipeline-is-the-review" "${PREFLIGHT}" \
  'The sub-agent pipeline is the review'

require_grep "preflight-no-switch-to-code-review" "${PREFLIGHT}" \
  'Switch to the `code-review` skill'

require_grep "preflight-opus-tier-high" "${PREFLIGHT}" \
  'Opus-tier.*high'

require_grep "preflight-category" "${PREFLIGHT}" \
  '"category": "sub-agent-failure"'

require_grep "preflight-request-changes" "${PREFLIGHT}" \
  'makes the outcome `request-changes`'

require_grep "preflight-bounded-lookup" "${PREFLIGHT}" \
  'Stop after those two lookups'

require_grep "preflight-no-approve-single-pass" "${PREFLIGHT}" \
  'Approve because a single-pass'

# --- review agent: routing and constraints ---

require_grep "agent-stays-on-pr-review" "${AGENT}" \
  'stays on `pr-review` and follows that skill'\''s missing-file protocol'

require_grep "agent-code-review-not-fallback" "${AGENT}" \
  'Do not use it as a fallback when `pr-review` sub-agent files are missing'

require_grep "agent-missing-files-completed-review" "${AGENT}" \
  'Missing sub-agent definition files are a completed review'

require_grep "agent-high-severity-opus" "${AGENT}" \
  'high severity for Opus-tier `correctness` and `security`'

require_grep "agent-request-changes-on-gap" "${AGENT}" \
  'set `action` to `request-changes`'

require_grep "agent-no-single-pass-code-review" "${AGENT}" \
  'Do not fall back to a single-pass `code-review`'

require_grep "agent-no-invent-prompt" "${AGENT}" \
  'do not invent a prompt and do not switch skills'

# Routing must not treat missing files as a reason to use code-review.
require_grep "agent-routing-unchanged-when-missing" "${AGENT}" \
  'Missing sub-agent files do not change that routing'

# --- code-review: do not invite pr-review to delegate here ---

forbid_grep "code-review-no-pr-review-delegate-example" "${CODE_REVIEW}" \
  'e\.g\., pr-review'

echo ""
if [[ "${FAILURES}" -gt 0 ]]; then
  echo "${FAILURES} test(s) failed"
  exit 1
fi
echo "All tests passed"
