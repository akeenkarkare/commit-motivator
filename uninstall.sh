#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

echo "==> Unloading LaunchAgents"
for label in com.akeen.commit-gate.check com.akeen.commit-gate.reset; do
  launchctl unload "$LAUNCH_AGENTS_DIR/$label.plist" 2>/dev/null || true
  rm -f "$LAUNCH_AGENTS_DIR/$label.plist"
  echo "    removed $label"
done

echo "==> Removing /etc/hosts block (if present)"
"$REPO_DIR/commit_gate.sh" unblock || true

echo "==> Removing sudoers rule"
sudo rm -f /etc/sudoers.d/commit_motivation

echo "Done."
