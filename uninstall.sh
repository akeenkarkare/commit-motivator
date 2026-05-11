#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

echo "==> Unloading LaunchAgents"
for label in com.commit-motivation.check com.commit-motivation.reset com.akeen.commit-gate.check com.akeen.commit-gate.reset; do
  plist="$LAUNCH_AGENTS_DIR/$label.plist"
  if [ -f "$plist" ]; then
    launchctl unload "$plist" 2>/dev/null || true
    rm -f "$plist"
    echo "    removed $label"
  fi
done

echo "==> Removing /etc/hosts block (if present)"
"$REPO_DIR/commit_gate.sh" unblock || true

echo "==> Removing sudoers rule"
sudo rm -f /etc/sudoers.d/commit_motivation

echo "Done."
