#!/usr/bin/env bash
# IMPERIO SYSTEM SNAPSHOT — Read-Only Harvest
# Corre en Mac. No modifica nada. Solo lectura.
# Uso: bash scripts/imperio_snapshot.sh
# Output: /tmp/imperio_snapshot_YYYYMMDD_HHMMSS.md

set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUT="/tmp/imperio_snapshot_${TIMESTAMP}.md"

log() { echo "$1" | tee -a "$OUT"; }
section() { log ""; log "---"; log "## $1"; log ""; }

# ── HEADER ──────────────────────────────────────────────────────────────────
cat > "$OUT" <<EOF
# IMPERIO SYSTEM SNAPSHOT
**Generado**: $(date)
**Host**: $(hostname)
**User**: $(whoami)

EOF

# ── 1. PROCESOS ACTIVOS RELEVANTES ──────────────────────────────────────────
section "1. PROCESOS ACTIVOS (IMPERIO-RELATED)"

log "### Python / Node procesos"
ps aux | grep -E "(python|node|ollama|playwright|chromium|puppeteer|hermes|gbrain|turbovec|imperio)" \
       | grep -v grep \
       | awk '{printf "%-10s %-6s %-6s %s\n", $1, $2, $3, $11}' \
       >> "$OUT" 2>/dev/null || log "(ninguno encontrado)"

log ""
log "### Top 10 procesos por CPU"
ps aux | sort -nrk 3,3 | head -10 | awk '{printf "%-10s %-6s %-6s %s\n", $1, $2, $3, $11}' >> "$OUT"

log ""
log "### Top 10 procesos por RAM"
ps aux | sort -nrk 4,4 | head -10 | awk '{printf "%-10s %-6s %-6s %s\n", $1, $2, $3, $11}' >> "$OUT"

# ── 2. LAUNCHAGENTS ─────────────────────────────────────────────────────────
section "2. LAUNCHAGENTS (~\/Library\/LaunchAgents)"

LAUNCH_DIR="$HOME/Library/LaunchAgents"
if [ -d "$LAUNCH_DIR" ]; then
    log "**Total archivos**: $(ls "$LAUNCH_DIR" | wc -l | tr -d ' ')"
    log ""
    log '```'
    ls -la "$LAUNCH_DIR" >> "$OUT" 2>/dev/null
    log '```'
    log ""
    log "### Contenido de cada .plist (Label + ProgramArguments + RunAtLoad)"
    for plist in "$LAUNCH_DIR"/*.plist; do
        [ -f "$plist" ] || continue
        label=$(defaults read "$plist" Label 2>/dev/null || echo "N/A")
        prog=$(defaults read "$plist" ProgramArguments 2>/dev/null | head -3 || echo "N/A")
        run_at_load=$(defaults read "$plist" RunAtLoad 2>/dev/null || echo "N/A")
        log "- **$(basename "$plist")**"
        log "  - Label: $label"
        log "  - RunAtLoad: $run_at_load"
        log "  - Program: $(echo "$prog" | tr '\n' ' ' | cut -c1-120)"
    done
else
    log "Directorio no existe: $LAUNCH_DIR"
fi

log ""
log "### LaunchAgents cargados actualmente (launchctl)"
launchctl list | grep -v "com.apple" | head -40 >> "$OUT" 2>/dev/null || log "(launchctl list falló o vacío)"

# ── 3. CRON JOBS ─────────────────────────────────────────────────────────────
section "3. CRON JOBS"

log '```'
crontab -l >> "$OUT" 2>/dev/null || log "(sin crontab o vacío)"
log '```'

# ── 4. OLLAMA ────────────────────────────────────────────────────────────────
section "4. OLLAMA"

if command -v ollama &>/dev/null; then
    log "**Ollama version**: $(ollama --version 2>/dev/null || echo 'N/A')"
    log ""
    log "### Modelos instalados"
    log '```'
    ollama list >> "$OUT" 2>/dev/null || log "(sin modelos o Ollama no corriendo)"
    log '```'
    log ""
    log "### Proceso Ollama"
    ps aux | grep ollama | grep -v grep >> "$OUT" 2>/dev/null || log "(no corriendo)"
else
    log "Ollama no instalado o no en PATH"
fi

# ── 5. IMPERIO_ROOT ──────────────────────────────────────────────────────────
section "5. IMPERIO_ROOT ESTRUCTURA"

IMPERIO_ROOT="$HOME/IMPERIO_ROOT"
if [ -d "$IMPERIO_ROOT" ]; then
    log "**Ruta**: $IMPERIO_ROOT"
    log "**Tamaño total**: $(du -sh "$IMPERIO_ROOT" 2>/dev/null | cut -f1)"
    log ""
    log "### Árbol (profundidad 3)"
    log '```'
    find "$IMPERIO_ROOT" -maxdepth 3 | sort >> "$OUT" 2>/dev/null
    log '```'
    log ""
    log "### Archivos modificados en últimas 48h"
    log '```'
    find "$IMPERIO_ROOT" -type f -mtime -2 | sort >> "$OUT" 2>/dev/null || log "(ninguno)"
    log '```'
else
    log "**IMPERIO_ROOT no existe** en $IMPERIO_ROOT"
    log ""
    log "### Búsqueda en HOME de directorios con 'imperio' o 'gbrain' o 'turbovec'"
    find "$HOME" -maxdepth 3 -type d \( -iname "*imperio*" -o -iname "*gbrain*" -o -iname "*turbovec*" -o -iname "*hermes*" \) 2>/dev/null >> "$OUT" || log "(ninguno encontrado)"
fi

# ── 6. HERMES / LOGS ─────────────────────────────────────────────────────────
section "6. HERMES — LOGS RECIENTES"

HERMES_CANDIDATES=(
    "$HOME/IMPERIO_ROOT/hermes"
    "$HOME/IMPERIO_ROOT/logs"
    "$HOME/.hermes"
    "$HOME/hermes"
    "/tmp/hermes"
)

HERMES_FOUND=false
for dir in "${HERMES_CANDIDATES[@]}"; do
    if [ -d "$dir" ]; then
        HERMES_FOUND=true
        log "**Encontrado en**: $dir"
        log "**Archivos**: $(ls "$dir" | wc -l | tr -d ' ')"
        log ""
        log "### Últimas 20 líneas del log más reciente"
        latest_log=$(find "$dir" -name "*.log" -type f | sort -t_ -k2 -r | head -1)
        if [ -n "$latest_log" ]; then
            log "Archivo: $latest_log"
            log '```'
            tail -20 "$latest_log" >> "$OUT" 2>/dev/null
            log '```'
        fi
        break
    fi
done

if ! $HERMES_FOUND; then
    log "Hermes no encontrado en rutas candidatas"
    log ""
    log "### Búsqueda ampliada de logs Hermes"
    find "$HOME" -maxdepth 4 -name "hermes*.log" -o -name "*_hermes_*.log" 2>/dev/null | head -5 >> "$OUT" || log "(ninguno)"
fi

# ── 7. TURBOVEC ──────────────────────────────────────────────────────────────
section "7. TURBOVEC — ESTADO"

TURBOVEC_CANDIDATES=(
    "$HOME/IMPERIO_ROOT/turbovec"
    "$HOME/IMPERIO_ROOT/memory"
    "$HOME/.turbovec"
    "$HOME/turbovec"
)

TVEC_FOUND=false
for dir in "${TURBOVEC_CANDIDATES[@]}"; do
    if [ -d "$dir" ]; then
        TVEC_FOUND=true
        log "**Encontrado en**: $dir"
        log "**Tamaño**: $(du -sh "$dir" 2>/dev/null | cut -f1)"
        log '```'
        ls -la "$dir" >> "$OUT" 2>/dev/null
        log '```'
        break
    fi
done

if ! $TVEC_FOUND; then
    log "TurboVec no encontrado en rutas candidatas"
fi

# ── 8. GBRAIN ────────────────────────────────────────────────────────────────
section "8. GBRAIN — ESTADO"

GBRAIN_CANDIDATES=(
    "$HOME/IMPERIO_ROOT/gbrain"
    "$HOME/IMPERIO_ROOT/brain"
    "$HOME/.gbrain"
)

GBRAIN_FOUND=false
for dir in "${GBRAIN_CANDIDATES[@]}"; do
    if [ -d "$dir" ]; then
        GBRAIN_FOUND=true
        log "**Encontrado en**: $dir"
        log '```'
        ls -la "$dir" >> "$OUT" 2>/dev/null
        log '```'
        break
    fi
done

if ! $GBRAIN_FOUND; then
    log "GBRAIN no encontrado en rutas candidatas"
fi

# ── 9. OUTPUTS DE ETSY / PINTEREST ──────────────────────────────────────────
section "9. OUTPUTS RECIENTES — Etsy / Pinterest"

log "### Archivos JSON con 'etsy' o 'listing' en HOME (últimos 14 días)"
find "$HOME" -maxdepth 6 -type f \( -name "*etsy*" -o -name "*listing*" -o -name "*pinterest*" \) -mtime -14 2>/dev/null | head -20 >> "$OUT" || log "(ninguno)"

log ""
log "### Imágenes generadas recientemente (últimas 48h, en HOME)"
find "$HOME" -maxdepth 6 -type f \( -name "*.png" -o -name "*.jpg" \) -mtime -2 2>/dev/null | grep -v ".Trash" | head -20 >> "$OUT" || log "(ninguna)"

# ── 10. PYTHON / NODE ENTORNOS ───────────────────────────────────────────────
section "10. ENTORNOS DE EJECUCIÓN"

log "### Python"
log "- python3: $(python3 --version 2>/dev/null || echo 'no encontrado')"
log "- pip packages relevantes:"
pip3 list 2>/dev/null | grep -iE "(playwright|turbovec|chromadb|qdrant|langchain|openai|anthropic|PIL|pillow|requests)" >> "$OUT" || log "  (pip3 no disponible)"

log ""
log "### Node"
log "- node: $(node --version 2>/dev/null || echo 'no encontrado')"
log "- npm global packages:"
npm list -g --depth=0 2>/dev/null | grep -iE "(playwright|puppeteer|browser)" >> "$OUT" || log "  (npm no disponible)"

log ""
log "### Virtual Environments activos"
echo "${VIRTUAL_ENV:-ninguno}" >> "$OUT"
echo "${CONDA_DEFAULT_ENV:-no conda}" >> "$OUT"

# ── 11. RESUMEN EJECUTIVO ────────────────────────────────────────────────────
section "11. RESUMEN EJECUTIVO"

log "| Componente | Estado |"
log "|---|---|"

# Check each component
check_component() {
    local name="$1"
    local check="$2"
    if eval "$check" &>/dev/null 2>&1; then
        log "| $name | ✅ ACTIVO |"
    else
        log "| $name | ❌ NO ENCONTRADO |"
    fi
}

check_component "Ollama"        "command -v ollama"
check_component "IMPERIO_ROOT"  "[ -d '$HOME/IMPERIO_ROOT' ]"
check_component "Playwright"    "pip3 show playwright"
check_component "LaunchAgents"  "ls '$HOME/Library/LaunchAgents'/*.plist"
check_component "Cron Jobs"     "crontab -l | grep -v '^#'"
check_component "TurboVec dir"  "[ -d '$HOME/IMPERIO_ROOT/turbovec' ] || [ -d '$HOME/.turbovec' ]"
check_component "GBRAIN dir"    "[ -d '$HOME/IMPERIO_ROOT/gbrain' ] || [ -d '$HOME/.gbrain' ]"
check_component "Hermes logs"   "find '$HOME' -maxdepth 5 -name 'hermes*.log' | head -1 | grep -q ."

# ── FOOTER ───────────────────────────────────────────────────────────────────
log ""
log "---"
log ""
log "**Snapshot completo guardado en**: \`$OUT\`"
log "**Duración**: $((SECONDS))s"

echo ""
echo "══════════════════════════════════════"
echo "  SNAPSHOT COMPLETO: $OUT"
echo "  Tamaño: $(wc -l < "$OUT") líneas"
echo "══════════════════════════════════════"
