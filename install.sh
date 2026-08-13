#!/bin/bash
# repo-fresh installer (no sudo — everything is per-user).
#
#   Interactive:      ./install.sh
#   Non-interactive:  SCHEDULE=daily    HOUR=7     ./install.sh
#                     SCHEDULE=interval MINUTES=60 ./install.sh
#
set -euo pipefail

# --- colors (only on a real terminal; honor the NO_COLOR standard) -----------
# ACC = accent (bold bright green); GRN = success glyph; others as named.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GRN=$'\033[92m'
  YLW=$'\033[33m'; ACC=$'\033[1;92m'; RST=$'\033[0m'
else
  BOLD=; DIM=; RED=; GRN=; YLW=; ACC=; RST=
fi
err() { echo "${RED}✗${RST} $*" >&2; }

LABEL="com.local.repo-fresh"
HERE="$(cd "$(dirname "$0")" && pwd)"

SUPPORT_DIR="$HOME/Library/Application Support/repo-fresh"
WORKER_DST="$SUPPORT_DIR/repo-fresh.sh"
REPOS_FILE="$SUPPORT_DIR/repos"
CONFIG="$SUPPORT_DIR/config"
LOG="$SUPPORT_DIR/repo-fresh.log"
BIN_DIR="$HOME/.local/bin"
CLI_DST="$BIN_DIR/repo-fresh"
PLIST_DST="$HOME/Library/LaunchAgents/${LABEL}.plist"

if [ "$(id -u)" -eq 0 ]; then
  err "Don't run this with sudo — repo-fresh is a per-user tool."
  exit 1
fi

echo
echo "${ACC}repo-fresh${RST}"
echo "${DIM}keep your git repos fast-forwarded${RST}"
echo

# --- choose a schedule -------------------------------------------------------
: "${SCHEDULE:=}"
if [ -z "$SCHEDULE" ]; then
  read -r -p "${BOLD}Schedule${RST}  [d]aily / [i]nterval?  ${DIM}[d]${RST}: " ans
  case "${ans:-d}" in i*|I*) SCHEDULE=interval ;; *) SCHEDULE=daily ;; esac
fi

if [ "$SCHEDULE" = "daily" ]; then
  if [ -z "${HOUR:-}" ]; then
    read -r -p "${BOLD}Daily hour${RST} (0-23)?  ${DIM}[7]${RST}: " HOUR; HOUR="${HOUR:-7}"
  fi
  [[ "$HOUR" =~ ^([0-9]|1[0-9]|2[0-3])$ ]] || { err "HOUR must be 0-23, got '$HOUR'."; exit 1; }
  # Single line on purpose: BSD (macOS) sed can't put newlines in a replacement.
  SCHEDULE_BLOCK="<key>StartCalendarInterval</key><dict><key>Hour</key><integer>${HOUR}</integer><key>Minute</key><integer>0</integer></dict>"
  SCHEDULE_DESC="daily at $(printf '%02d:00' "$HOUR")"
elif [ "$SCHEDULE" = "interval" ]; then
  if [ -z "${MINUTES:-}" ]; then
    read -r -p "${BOLD}Every how many minutes${RST}?  ${DIM}[60]${RST}: " MINUTES; MINUTES="${MINUTES:-60}"
  fi
  [[ "$MINUTES" =~ ^[1-9][0-9]*$ ]] || { err "MINUTES must be a positive integer, got '$MINUTES'."; exit 1; }
  SCHEDULE_BLOCK="<key>StartInterval</key><integer>$((MINUTES * 60))</integer>"
  SCHEDULE_DESC="every ${MINUTES} min"
else
  err "SCHEDULE must be 'daily' or 'interval', got '$SCHEDULE'."; exit 1
fi

# --- lay down files ----------------------------------------------------------
mkdir -p "$SUPPORT_DIR" "$BIN_DIR" "$HOME/Library/LaunchAgents"
install -m 755 "$HERE/repo-fresh.sh" "$WORKER_DST"
install -m 755 "$HERE/repo-fresh"    "$CLI_DST"
touch "$REPOS_FILE"

printf 'SCHEDULE_DESC="%s"\n' "$SCHEDULE_DESC" > "$CONFIG"

# Render the plist (escape sed-significant chars in paths just in case).
esc() { printf '%s' "$1" | sed 's/[&|]/\\&/g'; }
sed -e "s|__WORKER__|$(esc "$WORKER_DST")|g" \
    -e "s|__LOG__|$(esc "$LOG")|g" \
    -e "s|__SCHEDULE_BLOCK__|$(esc "$SCHEDULE_BLOCK")|g" \
    "$HERE/com.local.repo-fresh.plist.template" > "$PLIST_DST"
chmod 644 "$PLIST_DST"

# --- (re)load the agent ------------------------------------------------------
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"

echo
echo "${GRN}✓${RST} ${BOLD}Installed${RST}"
echo "  ${ACC}schedule${RST}   $SCHEDULE_DESC"
echo "  ${ACC}worker${RST}     ${DIM}$WORKER_DST${RST}"
echo "  ${ACC}command${RST}    ${DIM}$CLI_DST${RST}"
echo

case ":$PATH:" in
  *":$BIN_DIR:"*) : ;;
  *) echo "${YLW}!${RST} ${BOLD}$BIN_DIR is not on your PATH${RST} — add to ~/.zshrc:"
     echo "     ${DIM}export PATH=\"\$HOME/.local/bin:\$PATH\"${RST}"
     echo ;;
esac

echo "${BOLD}Next${RST}"
echo "  ${ACC}repo-fresh add${RST} <path>      ${DIM}track a repo/worktree${RST}"
echo "  ${ACC}repo-fresh remove${RST} <path>   ${DIM}stop tracking one${RST}"
echo "  ${ACC}repo-fresh list${RST}            ${DIM}show tracked repos + branches${RST}"
echo "  ${ACC}repo-fresh run${RST}             ${DIM}fast-forward everything now${RST}"
echo "  ${ACC}repo-fresh status${RST}          ${DIM}schedule + repos + last run${RST}"
echo "  ${ACC}./uninstall.sh${RST}             ${DIM}remove repo-fresh entirely${RST}"
