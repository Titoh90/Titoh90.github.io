# IMPERIO EXECUTION HUB v1
## Runtime Orchestration Layer
**Fecha**: 2026-06-07  
**Propósito**: Orquestador operativo único — define QUIÉN ejecuta cada etapa del pipeline en el mundo real

---

## 1. PROBLEMA QUE RESUELVE

### Estado actual del stack

```
ACTUAL:                          RESULTADO:
──────────────────               ──────────────────────────────
Playwright MCP                   Sin coordinator central
Puppeteer MCP          →         Lógica dispersa entre ejecutores
browser-use agent                Sin sistema de retry consistente
Python executors                 Sin control de estado global
Telegram bot triggers            Sin pipeline único
LaunchAgents legacy
cron jobs independientes
```

**No existe un "runtime coordinator" — solo ejecutores sueltos.**

---

## 2. PRINCIPIO CORE

```
"One pipeline, one orchestrator, multiple stateless tools"
```

El Execution Hub no ejecuta código directamente.  
El Execution Hub **decide qué tool ejecuta** y **valida el resultado**.

---

## 3. ARQUITECTURA EN CAPAS

```
┌─────────────────────────────────────────────────────────────┐
│                   EXECUTION HUB v1                          │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  LAYER 1: ORCHESTRATOR CORE                         │   │
│  │  • Recibe jobs (Etsy Engine / Visual Engine)        │   │
│  │  • Valida schema de entrada                         │   │
│  │  • Consulta estado GBRAIN                           │   │
│  │  • Decide ruta de ejecución                         │   │
│  │  • Asigna tool correspondiente                      │   │
│  └─────────────────────────────────────────────────────┘   │
│                          │                                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  LAYER 2: TOOL ROUTER                               │   │
│  │                                                     │   │
│  │  Task                  Tool                         │   │
│  │  ─────────────────     ────────────────────────     │   │
│  │  Image generation   →  Google Flow / Vertex API     │   │
│  │  Browser research   →  Playwright MCP               │   │
│  │  Etsy scraping      →  Playwright MCP               │   │
│  │  Posting listings   →  Playwright MCP               │   │
│  │  File operations    →  Python FS module             │   │
│  │  Embeddings         →  TurboVec                     │   │
│  │  Quality decisions  →  GBRAIN                       │   │
│  └─────────────────────────────────────────────────────┘   │
│                          │                                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  LAYER 3: EXECUTION AGENTS (STATELESS)              │   │
│  │  • Playwright Agent    — browser tasks              │   │
│  │  • Python Worker       — file I/O, data transform   │   │
│  │  • API Caller          — Google Flow, Etsy API      │   │
│  │  • File Writer         — asset export, JSON output  │   │
│  │                                                     │   │
│  │  REGLA: ningún agent tiene lógica de negocio propia │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. JOB CONTRACT — Formato de entrada estándar

Todo job que entra al Execution Hub debe cumplir este schema:

```json
{
  "job_id":    "etsy_generate_001",
  "pipeline":  "etsy_visual_v2",
  "stage":     "asset_generation | listing_creation | research | publication",
  "priority":  "high | normal | low",
  
  "input": {
    "style_cluster": "botanical_watercolor",
    "prompt":        "delicate watercolor botanical illustration...",
    "variables":     {}
  },
  
  "constraints": {
    "max_retries":      3,
    "gbrain_min_score": 7.0,
    "timeout_seconds":  120
  },
  
  "context": {
    "pipeline_id":    "UUID",
    "parent_job_id":  null,
    "triggered_by":   "scheduler | manual | demand_signal"
  }
}
```

### Validación del schema (ORCHESTRATOR CORE)

```python
REQUIRED_FIELDS = ["job_id", "pipeline", "stage", "input", "constraints"]

def validate_job(job: dict) -> tuple[bool, str | None]:
    for field in REQUIRED_FIELDS:
        if field not in job:
            return False, f"missing_field:{field}"
    
    if job["constraints"]["gbrain_min_score"] < 6.0:
        return False, "gbrain_threshold_too_low"
    
    if job["stage"] not in VALID_STAGES:
        return False, f"unknown_stage:{job['stage']}"
    
    return True, None
```

---

## 5. EXECUTION FLOW — Los 5 pasos

```
STEP 1 — INTAKE
    Recibe job → valida schema → asigna pipeline_type
    Si inválido: rechazar con error_code, NO procesar
         │
         ▼
STEP 2 — ROUTING
    Consulta TOOL_ROUTER por (pipeline, stage)
    Determina: Visual Engine call | Etsy Engine call | Browser task | Hybrid
         │
         ▼
STEP 3 — EXECUTION
    Invoca tool asignado (Playwright MCP | API call | Python script)
    Registra start_time, tool_used, input_hash
         │
         ▼
STEP 4 — VALIDATION
    GBRAIN Gate v1 (si stage == asset_generation)
    GBRAIN Gate v2 (si stage == listing_creation)
    Si PASS: continuar │ Si FAIL: → retry con prompt adaptation
         │
         ▼
STEP 5 — FEEDBACK
    TurboVec storage (si score ≥ 7.5)
    Failure log (si rejected)
    Job status update → completed | failed | escalated
```

---

## 6. EXECUTION TYPES

### TYPE A — Visual Generation Job

```
INPUT:      style_cluster + prompt + variables
TOOL:       Google Flow API (via API Caller)
OUTPUT:     image assets (PNG 3000×3000px)
VALIDATION: GBRAIN Gate v1 (score ≥ 6.0 para continuar)
ON FAIL:    adjust prompt → retry (max 3) → escalate
```

### TYPE B — Etsy Listing Job

```
INPUT:      handoff_packet (asset + GBRAIN result + hints)
TOOL:       Etsy Listing Engine (Python logic)
OUTPUT:     listing payload (title + description + tags + price)
VALIDATION: GBRAIN Gate v2 (10 boolean checks, score ≥ 7.0)
ON FAIL:    adjust copy → retry (max 2) → escalate
```

### TYPE C — Research Job

```
INPUT:      keyword | category | competitor_url
TOOL:       Playwright MCP (browser automation)
OUTPUT:     structured dataset (JSON)
VALIDATION: schema check (required fields present)
ON FAIL:    retry with different selector → escalate
```

### TYPE D — Publication Job

```
INPUT:      validated listing payload + asset files
TOOL:       Playwright MCP (Etsy seller dashboard) | Etsy API
OUTPUT:     etsy_listing_id + published_url
VALIDATION: URL returned + listing_id non-null
ON FAIL:    log + manual review queue (never auto-retry publication)
```

---

## 7. SYSTEM STATE

El Execution Hub mantiene estado en memoria (no persistido entre reinicios, TurboVec para historial):

```python
HUB_STATE = {
    "active_jobs":    [],   # jobs en ejecución ahora mismo
    "retry_queue":    [],   # jobs fallidos pendientes de reintento
    "failed_jobs":    [],   # jobs agotaron retries → escalados
    "completed_jobs": [],   # completados en esta sesión
    
    "tool_status": {
        "playwright_mcp":  "available | busy | error",
        "google_flow_api": "available | rate_limited | error",
        "turbovec":        "available | error",
        "gbrain":          "available | error"
    },
    
    "session_metrics": {
        "jobs_processed":   0,
        "jobs_passed_gate": 0,
        "jobs_rejected":    0,
        "avg_gbrain_score": 0.0
    }
}
```

---

## 8. FAILURE HANDLING

### Reglas de retry

```python
RETRY_POLICY = {
    "asset_generation": {
        "max_retries":  3,
        "strategy":     "adaptive_prompt",  # modifica el prompt en cada intento
        "backoff_sec":  [5, 15, 30]
    },
    "listing_creation": {
        "max_retries":  2,
        "strategy":     "copy_adjustment",  # ajusta title/description
        "backoff_sec":  [5, 10]
    },
    "research": {
        "max_retries":  2,
        "strategy":     "selector_fallback",  # intenta selectores alternativos
        "backoff_sec":  [3, 10]
    },
    "publication": {
        "max_retries":  0,          # NUNCA auto-retry publicaciones
        "strategy":     "escalate", # directo a cola manual
        "backoff_sec":  []
    }
}
```

### Prompt adaptation (TYPE A failures)

```python
def adapt_prompt(original_prompt: str, gbrain_result: dict, attempt: int) -> str:
    failed_component = min(gbrain_result["components"], key=gbrain_result["components"].get)
    
    adaptations = {
        "style_match":      lambda p: p + ", stronger {cluster} aesthetic elements",
        "technical_quality": lambda p: p + ", ultra high resolution, no artifacts, crisp details",
        "market_appeal":    lambda p: p + ", professional printable wall art composition, centered",
        "originality":      lambda p: p.replace("{theme}", _get_variant_theme(attempt))
    }
    
    return adaptations[failed_component](original_prompt)
```

---

## 9. TOOL ABSTRACTION — Reglas críticas

### PROHIBIDO en los execution agents

```
✗ Lógica de negocio (qué publicar, qué precio)
✗ Decisiones de routing (qué tool usar)
✗ Acceso directo a TurboVec o GBRAIN
✗ Estado propio entre ejecuciones
✗ Retry logic propia
✗ Cron jobs independientes del Hub
```

### PERMITIDO en los execution agents

```
✓ Ejecutar exactamente lo que el Hub indica
✓ Reportar resultado (éxito/error + output)
✓ Wrappear APIs y MCPs de forma uniforme
✓ Logging de ejecución (tool, input_hash, duration)
```

---

## 10. TOOL WRAPPERS — Interface estándar

Todos los tools exponen la misma interface hacia el Hub:

```python
class ToolWrapper:
    def execute(self, task: dict) -> ToolResult:
        ...
    
    def health_check(self) -> bool:
        ...

class ToolResult:
    success:    bool
    output:     dict | None
    error_code: str | None
    duration_ms: int
    tool_name:  str

# Implementaciones:
class PlaywrightMCPWrapper(ToolWrapper): ...
class GoogleFlowAPIWrapper(ToolWrapper): ...
class PythonWorkerWrapper(ToolWrapper):  ...
class EtsyAPIWrapper(ToolWrapper):       ...
```

---

## 11. END-TO-END FLOW FINAL

```
USER INPUT (manual trigger / scheduler / demand signal)
    │
    ▼
EXECUTION HUB — INTAKE
    validate_job() → assign pipeline_type
    │
    ▼
EXECUTION HUB — ROUTING
    route_to_tool() → select execution agent
    │
    ▼
GBRAIN — Pre-execution decision
    should_proceed() → check capacity, rate limits, dedup
    │
    ▼
VISUAL ENGINE v2 — Asset generation
    google_flow.generate() → PIL composition → file export
    │
    ▼
GBRAIN GATE v1 — Asset quality
    score ≥ 6.0 → PASS | < 6.0 → retry/escalate
    │
    ▼
ETSY ENGINE v1 — Listing creation
    title + description + tags + price + mockup_spec
    │
    ▼
GBRAIN GATE v2 — Listing quality
    score ≥ 7.0 → PASS | < 7.0 → copy adjustment/escalate
    │
    ▼
TOOL EXECUTION — Publication
    Playwright MCP → Etsy seller dashboard
    │
    ▼
TURBOVEC — Feedback storage
    store(listing, score, theme, cluster, status)
    │
    ▼
REVENUE OUTPUT
    etsy_listing_id + published_url + session_metrics
```

---

## 12. LO QUE ESTO ELIMINA

| Antes | Después |
|---|---|
| 7 executores independientes | 1 Execution Hub |
| Lógica de negocio dispersa | Solo en Orchestrator Core |
| Sin retry consistente | Retry Policy por tipo de job |
| Sin control de estado | HUB_STATE centralizado |
| Puppeteer redundante | Eliminado — Playwright MCP es primario |
| browser-use con decisiones propias | Degradado a fallback experimental sin routing |
| LaunchAgents legacy | Reemplazados por Hub scheduler |
| cron jobs aislados | Internalizados como scheduled jobs en Hub |

---

## 13. GAPS PARA OPERACIONALIZAR

| Gap | Impacto | Necesita |
|---|---|---|
| Hub implementation language | BLOQUEANTE | Python (recomendado) vs. Node.js |
| Playwright MCP interface spec | BLOQUEANTE | Comandos exactos para Etsy seller panel |
| Google Flow rate limits | BLOQUEANTE | Cuota diaria/hora para planificar throughput |
| GBRAIN scoring implementation | BLOQUEANTE | Computer vision local o API externa |
| Hub persistence | MEDIO | Estado sobrevive reinicios (SQLite / Redis) |
| Demand signal source | MEDIO | ¿Qué trigger inicia un nuevo job? |

---

## STATUS DEL SISTEMA COMPLETO

```
✅ Visual Engine v2         — DISEÑADO (templates, prompts, PIL role, clusters)
✅ Etsy Listing Engine v1   — DISEÑADO (title, description, tags, price, mockups)
✅ Pipeline v1              — DISEÑADO (handoff packet, GBRAIN gates, TurboVec)
✅ Execution Hub v1         — DISEÑADO (orchestrator, tool router, failure handling)

⬜ Observability Layer      — PENDIENTE (Revenue Dashboard)
⬜ Memory Layer             — PENDIENTE (GBRAIN vs TurboVec overlap resolution)
⬜ Production Deployment    — PENDIENTE (infrastructure + credentials)
```
