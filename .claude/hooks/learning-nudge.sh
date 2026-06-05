#!/usr/bin/env bash
# Shared Stop hook: a one-time, non-binding nudge after high-signal work that
# may have produced a reusable lesson worth recording as a learning candidate
# (see .agents/learning/ and the capture-learning-candidate skill).
#
# It is a *nudge*, not a mandate. It never requires a candidate to be written;
# it only asks the agent to consider it once, and to just stop if nothing in the
# session qualifies. Design constraints, so it neither loops nor nags:
#
#   - fires at most ONCE per session   (per-session sentinel file)
#   - only after high-signal work      (edit + failure/correction/bypass/etc.)
#   - never on a pure Q&A turn         (no edits -> silent exit 0)
#   - never on routine success         (edit only -> silent exit 0)
#   - never recurses                   (honours stop_hook_active)
#
# Output contract (Stop hook): exit 0 silently to allow the stop; or print
# {"decision":"block","reason":...} to feed the reason back to the agent for one
# more turn. We block exactly once to deliver the reflection prompt.
set -uo pipefail

input=$(cat)

field() { # $1=jq-path  $2=grep-fallback-key
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r "$1 // empty"
  else
    printf '%s' "$input" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
  fi
}

# Already continued by a stop hook this cycle — let it stop, no loop.
stop_active=$(field '.stop_hook_active' 'stop_hook_active')
[ "$stop_active" = "true" ] && exit 0

session_id=$(field '.session_id' 'session_id')
transcript=$(field '.transcript_path' 'transcript_path')

# One nudge per session.
sentinel="${TMPDIR:-/tmp}/agent-learning-nudge-${session_id:-unknown}"
[ -e "$sentinel" ] && exit 0

# Only nudge after real work: the transcript must show a file-editing tool.
# A pure-conversation session has nothing to learn from, so stay silent.
[ -n "${transcript:-}" ] && [ -f "$transcript" ] || exit 0
if ! grep -Eq '"name"[[:space:]]*:[[:space:]]*"(Edit|Write|MultiEdit|NotebookEdit|apply_patch)"' "$transcript"; then
  exit 0
fi

# Keep token cost near zero: routine successful edits do not get a reflection
# turn. These transcript patterns cover cases worth learning from: failed
# checks, CI/deploy breakage, merge conflicts, explicit hook bypasses, and user
# corrections. Avoid broad words such as "error", "CI", or "deploy" because
# static project instructions can contain them in every transcript.
if ! grep -Eiq \
  'Process exited with code [1-9]|exit code [1-9]|fatal:|ERRO |traceback|exception|merge conflict|CONFLICT \(|No \.pre-commit-config\.yaml|--no-verify|PRE_COMMIT_ALLOW_NO_CONFIG|user correction|you missed|not what I asked|fix the issues|merge-gate.*red|red.*merge-gate' \
  "$transcript"; then
  exit 0
fi

# Mark this session nudged before emitting, so a re-entry can't double-fire.
: >"$sentinel" 2>/dev/null || true

reason='Before stopping: high-signal work was detected. If it produced a reusable, evidence-backed repo improvement, file ONE compact candidate with the capture-learning-candidate skill. Use .agents/learning/scripts/query-candidates.sh first; do not scan candidate bodies. If nothing qualifies, say so briefly and stop.'

printf '{"decision":"block","reason":"%s"}\n' "$reason"
exit 0
