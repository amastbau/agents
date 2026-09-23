# Rebase-only short-circuit

Referenced from `SKILL.md` step 2a-1. Read this file in full before
deciding whether to skip sub-agent dispatch.

When a push rewrites commits without changing the tree (identical file
content to the prior reviewed commit), skip sub-agent dispatch and
reuse the prior review. Parent chain and timestamps change; file
content does not.

## Detection

Use the forge-specific skill's "Tree identity (rebase-only)" commands.
The three-dot compare in step 2a is merge-base-to-HEAD
(`changed_since_prior`). After a same-tree rebase rewrite it lists the
full PR diff, not zero files, so it cannot detect identical content.

## Conditions

Short-circuit only when every condition holds:

1. `PRIOR_REVIEW_SHA` is non-empty.
2. `PRIOR_REVIEW_PROVENANCE` is exactly `app-verified`.
3. `/sandbox/workspace/prior-review.txt` is non-empty.
4. Tree-identity commands succeeded (no 404, no timeout) and printed
   `TREES_IDENTICAL=true`.
5. Base-branch file count is unchanged and trusted:
   - Run the forge-specific skill's "Base-branch file count
     (rebase-only)" commands.
   - `PRIOR_BASE_FILE_COUNT` equals `FILE_COUNT` from step 2.
   - `PRIOR_BASE_FILE_COUNT` is less than 300 (GitHub's compare
     `files` array truncates at 300; a count of 300 is untrusted).
   - GitHub: `PRIOR_BASE_TOTAL_COMMITS` does not exceed 250.
   - GitLab: `compare_timeout` is not `true`.

If any condition fails, continue to step 3. Fall-through cases:
force-push or missing SHA (404), provenance not `app-verified`,
different trees (code changed), untrusted or unequal base-branch file
counts.

A rebase that drops a fix commit changes the tree, so this path does
not fire. That fall-through is required so a later review can still
see the content regression.

## Result

Skip steps 3–6 (no dimension sub-agents, no security-triage, no
risk-assessment, no challenger). Produce the result in step 7:

1. Parse prior findings from the current section of
   `/sandbox/workspace/prior-review.txt` (same extraction as step 2a).
   Treat a finding as `actionable: true` when the prior body includes a
   Remediation line for it.
2. Derive the verdict from those findings using step 6f. If the
   derived action requires `findings[]` (`request-changes` or
   `reject`) and required finding fields cannot be parsed
   (`severity`, `category`, `file`, `description`), continue to
   step 3 instead of short-circuiting.
3. Compose the body: the hidden SHA comment from step 7 using the
   current HEAD SHA, then:

   ```markdown
   ## Review — rebase only

   The branch was rebased with no code changes (identical tree at
   `<PRIOR_REVIEW_SHA>` and `<HEAD_SHA>`). Base-branch file count
   is unchanged.

   All prior findings remain as-is.
   ```

   If prior findings exist, append them in the step 7 severity format.

4. Write the result with `action` (derived verdict), `head_sha`
   (current HEAD SHA), `body` (composed above), and `findings` when
   the action requires them (step 7 table). Omit `risk_assessment`.

Do not dispatch sub-agents. Go to step 7.
