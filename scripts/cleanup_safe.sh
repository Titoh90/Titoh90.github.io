#!/bin/bash
# IMPERIO SAFE CLEANUP v1
# Disables duplicate schedulers and AI runtimes without deleting anything.
# Rollback: bash scripts/cleanup_restore.sh

set -e

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP="/tmp/crontab_backup_${TIMESTAMP}.txt"

echo "=== IMPERIO SAFE CLEANUP START ==="
echo "Backup crontab → $BACKUP"

# -----------------------------
# BACKUP CRONTAB
# -----------------------------
crontab -l > "$BACKUP" 2>/dev/null || echo "No crontab found"

# -----------------------------
# DISABLE CRON WATCHDOGS (comment out)
# -----------------------------
TMP_CRON="/tmp/crontab_tmp_${TIMESTAMP}.txt"

crontab -l | sed \
  -e 's|^\(\s*\*\s*/1\s\*\s*\).*free-claude-code-watchdog.*|# DISABLED SAFE: \1 free-claude-code-watchdog|' \
  -e 's|^\(\s*\*\s*/1\s\*\s*\).*openclaw-gateway-watchdog.*|# DISABLED SAFE: \1 openclaw-gateway-watchdog|' \
  -e 's|^\(\s*\*\s*/1\s\*\s*\).*imperio_operator_gateway.*|# DISABLED SAFE: \1 imperio_operator_gateway|' \
  > "$TMP_CRON" || true

crontab "$TMP_CRON" || true

echo "[OK] Cron watchdogs disabled (safe mode)"

# -----------------------------
# LAUNCHAGENTS CLEANUP (HERMES DUPLICATION)
# -----------------------------
echo "Disabling Hermes duplicate LaunchAgent..."

launchctl unload ~/Library/LaunchAgents/com.hermes.executive-loop.plist 2>/dev/null || true

echo "[OK] Hermes executive-loop unloaded (duplicate layer removed)"

# -----------------------------
# FREE-CLAUDE-CODE DISABLE
# -----------------------------
echo "Stopping free-claude-code process..."

pkill -f free-claude-code 2>/dev/null || true

launchctl unload ~/Library/LaunchAgents/ai.imperio.free-claude-code.plist 2>/dev/null || true

echo "[OK] free-claude-code stopped"

# -----------------------------
# SAFETY VERIFICATION OUTPUT
# -----------------------------
echo ""
echo "=== POST-CLEANUP STATE ==="
echo "Crontab:"
crontab -l || true

echo ""
echo "Hermes LaunchAgents:"
launchctl list | grep hermes || echo "No hermes agents found"

echo ""
echo "free-claude-code processes:"
ps aux | grep free-claude-code | grep -v grep || echo "None running"

echo ""
echo "=== CLEANUP COMPLETE ==="
echo "Rollback available via: bash scripts/cleanup_restore.sh"
echo "Backup: $BACKUP"
