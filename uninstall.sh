#!/bin/bash
# repo-fresh uninstaller. Removes the agent, worker, CLI, and support files.
# Your repositories are never touched.
set -uo pipefail

LABEL="com.local.repo-fresh"
SUPPORT_DIR="$HOME/Library/Application Support/repo-fresh"
CLI_DST="$HOME/.local/bin/repo-fresh"
PLIST_DST="$HOME/Library/LaunchAgents/${LABEL}.plist"

# Show what was being tracked, in case you want to re-add it later.
if [ -s "$SUPPORT_DIR/repos" ]; then
  echo "repo-fresh was tracking:"
  sed 's/^/  /' "$SUPPORT_DIR/repos"
  echo
fi

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$PLIST_DST"
rm -f "$CLI_DST"
rm -rf "$SUPPORT_DIR"

echo "repo-fresh removed. Your repositories were left untouched."
