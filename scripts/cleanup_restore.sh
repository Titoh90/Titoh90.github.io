#!/bin/bash
# IMPERIO SAFE RESTORE v1
# Rolls back all changes made by cleanup_safe.sh.
# Uses the most recent crontab backup from /tmp.

set -e

echo "=== IMPERIO SAFE RESTORE START ==="

# -----------------------------
# FIND LATEST BACKUP
# -----------------------------
BACKUP=$(ls -t /tmp/crontab_backup_*.txt 2>/dev/null | head -n 1)

if [ -z "$BACKUP" ]; then
  echo "ERROR: No crontab backup found in /tmp"
  exit 1
fi

echo "Restoring crontab from: $BACKUP"

# -----------------------------
# RESTORE CRONTAB
# -----------------------------
crontab "$BACKUP"

echo "[OK] Crontab restored"

# -----------------------------
# RELOAD LAUNCHAGENTS
# -----------------------------
echo "Reloading Hermes LaunchAgents..."

launchctl load ~/Library/LaunchAgents/com.hermes.executive-loop.plist 2>/dev/null || true
launchctl load ~/Library/LaunchAgents/ai.imperio.free-claude-code.plist 2>/dev/null || true

echo "[OK] LaunchAgents restored"

# -----------------------------
# VERIFICATION
# -----------------------------
echo ""
echo "=== RESTORE STATE ==="

crontab -l || true

launchctl list | grep hermes || true

ps aux | grep free-claude-code | grep -v grep || true

echo ""
echo "=== RESTORE COMPLETE ==="
