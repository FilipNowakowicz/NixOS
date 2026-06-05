---
name: review-learning-candidates
description: Use when reviewing accumulated .agents/learning candidates, deduplicating them, rejecting weak ones, or promoting strong ones into executable checks, hooks, skills, or docs.
---

# Review Learning Candidates

Review compact learning candidates under `.agents/learning/candidates/`.
Candidate review is explicit, batch-oriented work. Do not run it as part of
normal task wrap-up.

## Goal

Turn candidate proposals into the strongest useful repo artifact:

1. assertion / test / CI gate
2. hook
3. skill
4. doc
5. rejection

Prefer executable enforcement over prose. A candidate that can become a check,
test, or invariant should not be promoted to `CLAUDE.md`.

## Workflow

1. Run `bash .agents/learning/scripts/validate-candidates.sh`.
2. Run `bash .agents/learning/scripts/review-candidates.sh`.
3. Choose a small batch by `route`, `best_form`, or related `targets`.
4. Open only the candidate files in that selected batch.
5. For each candidate, decide one outcome:
   - `implement-fix`: implement the repo fix or leave it as explicit backlog if
     the user only asked for triage.
   - `promote-hook`: update a hook and validate it with direct hook tests.
   - `promote-skill`: update or create a skill and validate any helper scripts.
   - `promote-doc`: update the smallest relevant doc only if no stronger form
     fits.
   - `promote-memory`: use only for low-drift repo navigation or preference
     facts that are too broad for a skill or check.
   - `reject`: mark stale, duplicate, unsupported, or low-signal candidates.
6. Update candidate `status` after the decision:
   - `promoted` when the promotion is implemented in the same branch.
   - `rejected` when no durable action should be taken.
   - `superseded` when another candidate or artifact covers it.
   - keep `open` when the candidate still needs later work.

## Guardrails

- Do not scan the whole candidate directory before choosing a batch from the
  metadata index.
- Do not promote more than one unrelated batch at once unless the user asks.
- Do not put secrets, host credentials, or transient session facts into docs or
  memory.
- If promotion changes repo behavior, use the `nix-verification-loop` skill to
  pick the smallest meaningful validation.
