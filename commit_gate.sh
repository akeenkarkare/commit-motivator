#!/bin/bash
# Blocks mail.google.com in /etc/hosts until akeenkarkare has made a GitHub commit today (local TZ).

set -u

GITHUB_USER="akeenkarkare"
HOSTS_FILE="/etc/hosts"
MARKER_BEGIN="# >>> commit_motivation >>>"
MARKER_END="# <<< commit_motivation <<<"
BLOCKED_HOSTS=("mail.google.com" "www.mail.google.com" "gmail.com" "www.gmail.com")
STATE_DIR="$HOME/.commit_motivation"
LOG_FILE="$STATE_DIR/gate.log"
STAGED_HOSTS="$STATE_DIR/hosts.staged"

mkdir -p "$STATE_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

today_local() {
  date '+%Y-%m-%d'
}

has_commit_today() {
  local today
  today=$(today_local)
  local response
  response=$(curl -fsS --max-time 10 \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/users/${GITHUB_USER}/events/public?per_page=100" 2>/dev/null) || {
    log "GitHub API unreachable — failing open (not blocking)"
    return 0
  }

  echo "$response" | /usr/bin/python3 -c "
import json, sys, datetime
today = '$today'
try:
    events = json.load(sys.stdin)
except Exception:
    sys.exit(2)
for e in events:
    if e.get('type') != 'PushEvent':
        continue
    created = e.get('created_at', '')
    try:
        utc = datetime.datetime.strptime(created, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=datetime.timezone.utc)
    except Exception:
        continue
    local_date = utc.astimezone().strftime('%Y-%m-%d')
    if local_date == today:
        sys.exit(0)
sys.exit(1)
"
  return $?
}

is_blocked() {
  grep -q "$MARKER_BEGIN" "$HOSTS_FILE"
}

flush_dns() {
  sudo -n /usr/bin/dscacheutil -flushcache 2>/dev/null
  sudo -n /usr/bin/killall -HUP mDNSResponder 2>/dev/null
}

apply_block() {
  if is_blocked; then
    return 0
  fi
  cat "$HOSTS_FILE" > "$STAGED_HOSTS"
  {
    echo ""
    echo "$MARKER_BEGIN"
    for h in "${BLOCKED_HOSTS[@]}"; do
      echo "127.0.0.1 $h"
      echo "::1 $h"
    done
    echo "$MARKER_END"
  } >> "$STAGED_HOSTS"
  sudo -n /bin/cp "$STAGED_HOSTS" "$HOSTS_FILE"
  local rc=$?
  flush_dns
  log "block applied (rc=$rc)"
  return $rc
}

remove_block() {
  if ! is_blocked; then
    return 0
  fi
  awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
    $0==b {skip=1; next}
    $0==e {skip=0; next}
    !skip {print}
  ' "$HOSTS_FILE" > "$STAGED_HOSTS"
  sudo -n /bin/cp "$STAGED_HOSTS" "$HOSTS_FILE"
  local rc=$?
  flush_dns
  log "block removed (rc=$rc)"
  return $rc
}

case "${1:-check}" in
  check)
    if has_commit_today; then
      log "commit found today — unblocking"
      remove_block
    else
      log "no commit today — blocking"
      apply_block
    fi
    ;;
  reset)
    log "daily reset — re-engaging block"
    apply_block
    ;;
  unblock)
    remove_block
    ;;
  status)
    if is_blocked; then echo "BLOCKED"; else echo "UNBLOCKED"; fi
    ;;
  *)
    echo "usage: $0 {check|reset|unblock|status}" >&2
    exit 2
    ;;
esac
