#!/usr/bin/env bash
# Issue-loop orchestration entrypoint — runs ON gcp-agent.
#
# Given a target issue number (or a label filter), it drives the
# issue-driven-development skill from a cold, up-to-date clone through to a
# pushed PR, then returns and lets the idle-shutdown timer power the box off.
#
# Typical invocation from a workstation (starts the VM, then runs this on it):
#   scripts/agent-session.sh -- nix/scripts/agent-run-issue.sh 169
#   scripts/agent-session.sh -- nix/scripts/agent-run-issue.sh --label agent-ready
#
# Or directly, once SSH'd into gcp-agent:
#   scripts/agent-run-issue.sh 169 170
#   scripts/agent-run-issue.sh --label architecture-review
#
# Env knobs:
#   AGENT_REPO_DIR  repo clone to operate in (default: $HOME/nix)
#   BASE_BRANCH     branch to sync to before each issue (default: main)
#
# v1 is attended: it opens PRs but never merges. You review and merge yourself.
set -euo pipefail

AGENT_REPO_DIR="${AGENT_REPO_DIR:-$HOME/nix}"
BASE_BRANCH="${BASE_BRANCH:-main}"
SESSION_LOCK="/run/agent/session.lock"

label=""
issues=()
while [[ $# -gt 0 ]]; do
  case "$1" in
  --label)
    label="${2:?--label needs a value}"
    shift 2
    ;;
  -h | --help)
    grep '^#' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  --)
    shift
    ;;
  -*)
    echo "agent-run-issue: unknown flag: $1" >&2
    exit 2
    ;;
  *)
    issues+=("$1")
    shift
    ;;
  esac
done

die() {
  echo "agent-run-issue: $*" >&2
  exit 1
}

command -v claude >/dev/null 2>&1 || die "claude CLI not found (Home Manager agent role)"
command -v gh >/dev/null 2>&1 || die "gh not found"
command -v git >/dev/null 2>&1 || die "git not found"
[[ -d $AGENT_REPO_DIR/.git ]] || die "no git clone at AGENT_REPO_DIR=$AGENT_REPO_DIR"

# Fail fast if the scoped PAT is not wired — otherwise the run would burn a
# session only to fail at push/PR time.
gh auth status >/dev/null 2>&1 || die "gh is not authenticated (provision the scoped PAT — hosts/gcp-agent/CLAUDE.md)"

# Hold the session lock for the WHOLE run so the idle-shutdown timer never powers
# the box off mid-session during claude-free gaps (offloaded builds, git ops).
# Best-effort: if /run/agent is not writable, process detection still covers the
# common case.
if (: >"$SESSION_LOCK") 2>/dev/null; then
  # shellcheck disable=SC2064
  trap "rm -f '$SESSION_LOCK'" EXIT
fi

cd "$AGENT_REPO_DIR"

sync_base() {
  echo "agent-run-issue: syncing $BASE_BRANCH with origin ..." >&2
  git fetch origin --prune
  git checkout "$BASE_BRANCH"
  git reset --hard "origin/$BASE_BRANCH"
}

# Resolve the target issue list.
if [[ -n $label ]]; then
  mapfile -t issues < <(gh issue list --state open --label "$label" --json number --jq '.[].number')
  [[ ${#issues[@]} -gt 0 ]] || die "no open issues with label '$label'"
  echo "agent-run-issue: label '$label' -> issues: ${issues[*]}" >&2
fi
[[ ${#issues[@]} -gt 0 ]] || die "no target issue(s); pass an issue number or --label <name>"

run_one() {
  local issue="$1"
  echo "agent-run-issue: ===== issue #$issue =====" >&2
  sync_base

  # Hand the issue to Claude Code in headless mode, instructing it to follow the
  # repo's issue-driven-development skill end to end. Claude picks the branch,
  # implements the smallest durable fix, validates via the nix-verification-loop,
  # pushes, and opens a PR. It must NOT merge (attended v1).
  local prompt
  prompt="Implement GitHub issue #${issue} in this repository end to end using the \
issue-driven-development skill. Work on a new branch off ${BASE_BRANCH} (never commit \
to ${BASE_BRANCH} directly). Implement the smallest durable fix, validate with the \
nix-verification-loop skill (the smallest meaningful scripts/validate.sh command for \
what you changed), then push the branch and open a pull request that links the issue \
(use 'Closes #${issue}' only if the PR fully satisfies it, otherwise 'Refs #${issue}'). \
Do NOT merge the PR and do NOT push to ${BASE_BRANCH}. If you cannot complete it, stop \
and explain what is blocked."

  if claude -p "$prompt"; then
    echo "agent-run-issue: issue #$issue session finished" >&2
  else
    echo "agent-run-issue: issue #$issue session exited non-zero — see output above; check 'gh pr list'" >&2
  fi
}

rc=0
for issue in "${issues[@]}"; do
  run_one "$issue" || rc=1
done

# Return to a clean base so the next cold start (or a human SSH) lands on
# ${BASE_BRANCH}; the idle-shutdown timer powers the box off after the window.
git checkout "$BASE_BRANCH" 2>/dev/null || true

echo "agent-run-issue: done. Open PRs:" >&2
gh pr list --state open --json number,title,headRefName \
  --jq '.[] | "  #\(.number) \(.headRefName): \(.title)"' >&2 || true
echo "agent-run-issue: review/merge from your workstation; the VM will self-power-off when idle." >&2
exit "$rc"
