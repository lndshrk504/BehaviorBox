---
name: analysis-reproducibility-audit
description: Use this skill when a task changes analysis code, preprocessing, figures, tables, randomization, saved outputs, or anything that could alter research results or reproducibility. Do not use it for pure refactors that provably do not change behavior.
---

# Analysis reproducibility audit

## Goal

Force a reproducibility check whenever scientific behavior might change.

## Required workflow

1. Identify the affected pipeline segment.
   - inputs
   - transforms
   - outputs
   - caches
   - saved artifacts
   - figures or summary tables

2. Identify reproducibility controls.
   - seeds
   - default parameters
   - file ordering
   - path assumptions
   - use of current time / randomness / temporary files

3. Decide what should stay invariant and what is allowed to change.
   Call this out before implementation.

4. Require a before/after validation path.
   - automated tests if they exist
   - otherwise a reproducible command on a small fixed dataset or fixture

5. In the handoff, report:
   - expected invariant outputs
   - outputs intentionally changed
   - validation command(s)
   - tolerance or comparison logic
   - unresolved reproducibility risks

## Do not

- do not merge behavioral edits with broad cleanup
- do not leave output changes unexplained
- do not call a task “done” if the only evidence is code inspection
