#!/bin/bash
# repo-fresh — fast-forward a curated list of git repos/worktrees to their
# upstreams. Read-only-safe: it only ever runs `git fetch` and
# `git merge --ff-only`. It NEVER commits, resets, switches branches, or forces
# anything, and it skips any repo whose tree is dirty or whose branch can't
# fast-forward. Runs as you (a per-user LaunchAgent) — no root.
#
# Reads the repo list from:  ~/Library/Application Support/repo-fresh/repos
# Prints a timestamped report to stdout (the LaunchAgent captures it to the log;
# `repo-fresh run` tees it to your terminal too).

# NOTE: no `set -e` — one bad repo must not abort the whole sweep.
set -uo pipefail

# launchd hands us a minimal environment; make sure git is findable.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

SUPPORT_DIR="$HOME/Library/Application Support/repo-fresh"
REPOS_FILE="$SUPPORT_DIR/repos"

echo "===== $(date '+%Y-%m-%d %H:%M:%S') ====="

if [ ! -f "$REPOS_FILE" ]; then
  echo "no repo list at $REPOS_FILE — nothing to do (add one with: repo-fresh add <path>)"
  exit 0
fi

count=0
while IFS= read -r line || [ -n "$line" ]; do
  # Skip blank lines and comments.
  case "$line" in ''|\#*) continue ;; esac
  dir="$line"
  count=$((count + 1))

  name="$(basename "$dir")"

  if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "[$name] SKIP: not a git repo/worktree ($dir)"
    continue
  fi

  branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"

  # Dirty tree → leave it completely alone.
  if [ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]; then
    echo "[$name] SKIP ($branch): working tree not clean"
    continue
  fi

  # No upstream configured → nothing to fast-forward toward.
  if ! upstream="$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
    echo "[$name] SKIP ($branch): no upstream set"
    continue
  fi

  before="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)"

  if ! git -C "$dir" fetch --quiet 2>/dev/null; then
    echo "[$name] FETCH FAILED ($branch): check network / git credentials"
    continue
  fi

  if git -C "$dir" merge --ff-only '@{u}' >/dev/null 2>&1; then
    after="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)"
    if [ "$before" = "$after" ]; then
      echo "[$name] up to date ($branch @ $after)"
    else
      echo "[$name] updated ($branch: $before -> $after, tracking $upstream)"
    fi
  else
    echo "[$name] SKIP ($branch): not fast-forwardable — needs manual attention"
  fi
done < "$REPOS_FILE"

if [ "$count" -eq 0 ]; then
  echo "no repos configured — add one with: repo-fresh add <path>"
fi
