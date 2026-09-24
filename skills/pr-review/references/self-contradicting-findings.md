# Self-contradicting findings

A finding is self-contradicting when its own description or
remediation concedes that the flagged behavior is not a regression
introduced by this PR, follows an established pattern, matches
existing code, or is acceptable, intentional, or correct.

Incidental mentions of "pattern" or "existing" are not a match. The
finding must concede that the flagged behavior itself is acceptable,
pre-existing, or intentional.

## Disposition

1. **No concrete improvement** (empty/absent `remediation`, or text
   that only restates the current state): drop it. Do not mention it
   in the review body.
2. **Concrete improvement despite accepting the current state:** keep
   as `info` / `enhancement-opportunity` with `actionable: false`.
   Leave the suggested improvement in `remediation`.
3. **Genuine defect** that mentions existing patterns only as context
   (without conceding the flagged behavior is fine): leave unchanged.

Skip `protected-path`, `sub-agent-failure`, and `provenance-warning`.
Process findings are not self-contradicting analysis; human approval
is still required for protected paths.

After disposition, apply `$REVIEW_FINDING_SEVERITY_THRESHOLD`. An
`info` enhancement below the threshold is omitted from the review
body and the `findings` array.

This filter still runs when the challenger was skipped, so 6e
findings and unchallenged sets are covered.
