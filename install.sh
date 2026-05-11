#!/bin/bash
# One-time setup for commit_motivation.
# Run with: bash install.sh

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_NAME="$(whoami)"
SUDOERS_FILE="/etc/sudoers.d/commit_motivation"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
ENV_FILE="$REPO_DIR/.env"

echo "==> commit_motivation installer"
echo "    user: $USER_NAME"
echo "    repo: $REPO_DIR"
echo ""

if [ ! -f "$ENV_FILE" ]; then
  echo "!! No .env file found at $ENV_FILE"
  echo "   Copy .env.example to .env and fill in your GITHUB_USER:"
  echo "       cp .env.example .env && \$EDITOR .env"
  exit 1
fi

# shellcheck disable=SC1090
. "$ENV_FILE"
if [ -z "${GITHUB_USER:-}" ]; then
  echo "!! GITHUB_USER is not set in .env"
  exit 1
fi
echo "    GITHUB_USER: $GITHUB_USER"

chmod +x "$REPO_DIR/commit_gate.sh"
mkdir -p "$HOME/.commit_motivation"

echo ""
echo "==> Installing sudoers rule (needs your password once)"
STAGED="$HOME/.commit_motivation/hosts.staged"
SUDOERS_CONTENT="$USER_NAME ALL=(root) NOPASSWD: /bin/cp $STAGED /etc/hosts, /usr/bin/dscacheutil -flushcache, /usr/bin/killall -HUP mDNSResponder"
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

echo ""
echo "==> Rendering and installing LaunchAgents"
mkdir -p "$LAUNCH_AGENTS_DIR"

# Clean up legacy labels from earlier versions of this project, if present.
for legacy in com.akeen.commit-gate.check com.akeen.commit-gate.reset; do
  legacy_path="$LAUNCH_AGENTS_DIR/$legacy.plist"
  if [ -f "$legacy_path" ]; then
    launchctl unload "$legacy_path" 2>/dev/null || true
    rm -f "$legacy_path"
    echo "    removed legacy $legacy"
  fi
done

render_plist() {
  local src="$1" dst="$2"
  sed -e "s|__REPO_DIR__|$REPO_DIR|g" -e "s|__HOME__|$HOME|g" "$src" > "$dst"
}

for name in check reset; do
  label="com.commit-motivation.$name"
  dst="$LAUNCH_AGENTS_DIR/$label.plist"
  render_plist "$REPO_DIR/commit-gate.$name.plist.template" "$dst"
  launchctl unload "$dst" 2>/dev/null || true
  launchctl load  "$dst"
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
