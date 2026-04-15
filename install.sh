#!/bin/bash
# One-time setup for commit_motivation.
# Run with: bash install.sh

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_NAME="$(whoami)"
SUDOERS_FILE="/etc/sudoers.d/commit_motivation"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

echo "==> commit_motivation installer"
echo "    user: $USER_NAME"
echo "    repo: $REPO_DIR"
echo ""

chmod +x "$REPO_DIR/commit_gate.sh"

echo "==> Installing sudoers rule (needs your password once)"
SUDOERS_CONTENT="$USER_NAME ALL=(root) NOPASSWD: /bin/cp /*/hosts /etc/hosts, /usr/bin/dscacheutil -flushcache, /usr/bin/killall -HUP mDNSResponder"
TMP_SUDO=$(mktemp)
echo "$SUDOERS_CONTENT" > "$TMP_SUDO"
if ! sudo visudo -cf "$TMP_SUDO" >/dev/null; then
  echo "!! sudoers rule failed validation. Aborting."
  rm -f "$TMP_SUDO"
  exit 1
fi
sudo cp "$TMP_SUDO" "$SUDOERS_FILE"
sudo chmod 440 "$SUDOERS_FILE"
rm -f "$TMP_SUDO"
echo "    wrote $SUDOERS_FILE"

echo "==> Installing LaunchAgents"
mkdir -p "$LAUNCH_AGENTS_DIR"
cp "$REPO_DIR/com.akeen.commit-gate.check.plist" "$LAUNCH_AGENTS_DIR/"
cp "$REPO_DIR/com.akeen.commit-gate.reset.plist" "$LAUNCH_AGENTS_DIR/"

for label in com.akeen.commit-gate.check com.akeen.commit-gate.reset; do
  launchctl unload "$LAUNCH_AGENTS_DIR/$label.plist" 2>/dev/null || true
  launchctl load  "$LAUNCH_AGENTS_DIR/$label.plist"
  echo "    loaded $label"
done

echo ""
echo "==> Done. Running initial check..."
"$REPO_DIR/commit_gate.sh" check
echo ""
echo "Status: $("$REPO_DIR/commit_gate.sh" status)"
echo ""
echo "Logs:   ~/.commit_motivation/gate.log"
echo "Manual: $REPO_DIR/commit_gate.sh {check|reset|unblock|status}"
