# IMPERIO PIPELINE v1
## Visual Engine v2 → Etsy Listing Engine v1 — Integración End-to-End
**Fecha**: 2026-06-07  
**Propósito**: Documento de contrato entre los dos engines — define los handoffs, los formatos de datos, y los puntos de decisión entre generación de arte y publicación en Etsy

---

## ARQUITECTURA COMPLETA DEL PIPELINE

```
┌─────────────────────────────────────────────────────────┐
│                    IMPERIO PIPELINE v1                  │
│                                                         │
│  ENTRADA           VISUAL ENGINE v2         SALIDA      │
│  ─────────         ────────────────         ───────     │
│  Trigger      →   TurboVec Query        →   GBRAIN      │
│  (manual/         StyleVector Select        Score       │
│   auto)           Google Flow Prompt        Asset       │
│                   PIL Composition           Files       │
│                        │                               │
│                        ↓                               │
│                   GBRAIN GATE                          │
│                   (score ≥ 6.0?)                       │
│                        │                               │
│              ┌─────────┴──────────┐                    │
│              ↓                    ↓                    │
│           REJECT              CONTINUE                 │
│        (regenerate)               │                    │
│                                   ↓                    │
│                        ETSY LISTING ENGINE v1          │
│                        Title + Description             │
│                        Tags + Price + Mockup           │
│                             │                          │
│                             ↓                          │
│                        GBRAIN GATE                     │
│                        (score ≥ 7.0?)                  │
│                             │                          │
│              ┌──────────────┴───────────┐              │
│              ↓                          ↓              │
│           REWORK                    PUBLISH            │
│        (copy ajuste)            Etsy Export            │
│                                 TurboVec Store         │
└─────────────────────────────────────────────────────────┘
```

---

## FASE 1: TRIGGER → VISUAL ENGINE v2

### Input del pipeline

```json
{
  "trigger_type": "manual | scheduled | demand_signal",
  "style_cluster": "BOTANICAL_WATERCOLOR | COTTAGECORE | MODERN_MINIMAL_LUXE | DARK_ACADEMIA | CHILDREN_EDUCATIONAL",
  "quantity_requested": 1,
  "priority": "high | normal",
  "constraints": {
    "exclude_themes": [],
    "force_theme": null
  }
}
```

### TurboVec Query (paso 1 del Visual Engine)

```python
# Consulta semántica para evitar duplicados
query = {
  "cluster": trigger.style_cluster,
  "action": "find_unused_themes",
  "filters": {
    "status": "not_in": ["published", "in_review"],
    "days_since_generated": ">": 0
  },
  "limit": 5  # candidatos para GBRAIN seleccionar
}
# Resultado: lista de themes disponibles con scores de originalidad
```

### Google Flow Prompt Selection

```python
# VISUAL ENGINE v2 selecciona el prompt template por cluster
PROMPT_TEMPLATES = {
  "BOTANICAL_WATERCOLOR": {
    "base": "delicate watercolor botanical illustration, {plant_subject}, "
            "soft paper texture, muted earth tones, {color_palette}, "
            "loose organic brushwork, white background, studio lighting, "
            "printable wall art style, high resolution",
    "variables": {
      "plant_subject": ["herb bundle", "wildflower meadow", "fern frond", 
                        "eucalyptus branch", "lavender sprig", "poppy field"],
      "color_palette": ["sage green and cream", "dusty rose and terracotta",
                        "navy and gold", "soft ochre and olive"]
    }
  },
  "COTTAGECORE": {
    "base": "cozy cottagecore illustration, {scene_subject}, warm golden light, "
            "rustic farmhouse aesthetic, vintage hand-drawn style, "
            "soft watercolor textures, muted warm tones, printable art",
    "variables": {
      "scene_subject": ["cottage garden with wildflowers", "kitchen herbs in mason jars",
                        "bread and butter on wooden table", "cat by fireplace",
                        "mushroom forest floor", "morning tea with flowers"]
    }
  },
  "MODERN_MINIMAL_LUXE": {
    "base": "minimalist editorial art print, {concept_subject}, "
            "clean geometric composition, {color_scheme}, "
            "luxury magazine aesthetic, Swiss design influence, "
            "negative space, premium wall art",
    "variables": {
      "concept_subject": ["single architectural line drawing", "abstract organic form",
                          "typographic composition", "geometric botanical silhouette"],
      "color_scheme": ["black and white", "warm cream and charcoal",
                       "dusty sage monochrome", "terracotta on white"]
    }
  },
  "DARK_ACADEMIA": {
    "base": "dark academia aesthetic art print, {subject_matter}, "
            "moody atmospheric lighting, vintage illustration style, "
            "sepia and deep tones, library aesthetic, "
            "gothic romanticism, scholarly mood",
    "variables": {
      "subject_matter": ["antique books and candlelight", "skull with flowers",
                         "celestial map and compass", "vintage botanical specimens",
                         "architectural ruins", "quill and inkwell"]
    }
  },
  "CHILDREN_EDUCATIONAL": {
    "base": "cute educational children's illustration, {learning_topic}, "
            "bright cheerful colors, simple bold shapes, "
            "Montessori-inspired design, nursery wall art style, "
            "friendly and playful, high contrast for children",
    "variables": {
      "learning_topic": ["alphabet letters with animals", "numbers 1-10 with fruits",
                         "world map for kids", "solar system planets",
                         "vegetable garden guide", "ocean animals ABC"]
    }
  }
}
```

---

## FASE 2: GBRAIN GATE v1 — Asset Quality Check

### Score de entrada (Visual Engine output → GBRAIN)

```python
# GBRAIN evalúa el asset generado por Google Flow
def gbrain_score_asset(asset_image, style_cluster, prompt_used):
    
    score_components = {
        # Criterio 1: Coherencia con el cluster de estilo
        "style_match":     _score_style_match(asset_image, style_cluster),  # 0-3
        
        # Criterio 2: Calidad técnica (resolución, nitidez, artefactos)
        "technical_quality": _score_technical(asset_image),  # 0-2
        
        # Criterio 3: Potencial de conversión Etsy (composición, claridad)
        "market_appeal":   _score_market_appeal(asset_image, style_cluster),  # 0-3
        
        # Criterio 4: Originalidad vs. assets previos en TurboVec
        "originality":     _score_originality(asset_image),  # 0-2
    }
    
    total = sum(score_components.values())  # 0-10
    
    return {
        "score": total,
        "components": score_components,
        "decision": "PASS" if total >= 6.0 else "REJECT",
        "reason": _generate_reason(score_components) if total < 6.0 else None
    }
```

### GBRAIN Gate Thresholds

| Score | Decisión | Acción |
|---|---|---|
| ≥ 8.0 | PREMIUM PASS | → Etsy Engine con precio PREMIUM |
| 7.0 – 7.9 | STANDARD PASS | → Etsy Engine con precio MID |
| 6.0 – 6.9 | MARGINAL PASS | → Etsy Engine con precio ENTRY |
| < 6.0 | REJECT | → Regenerar con prompt variante |

### Regeneration Loop

```python
MAX_ATTEMPTS = 3

for attempt in range(MAX_ATTEMPTS):
    asset = google_flow.generate(prompt)
    result = gbrain.score_asset(asset, style_cluster)
    
    if result["decision"] != "REJECT":
        break
    
    # Modificar prompt para siguiente intento
    prompt = _adjust_prompt(prompt, result["reason"], attempt)
    
    if attempt == MAX_ATTEMPTS - 1:
        # Después de 3 intentos: escalar a revisión manual
        notify_operator(asset, result, "manual_review_required")
        return {"status": "ESCALATED"}
```

---

## FASE 3: HANDOFF PACKET — Visual Engine → Etsy Engine

### El contrato de datos entre los dos engines

```json
{
  "handoff_version": "1.0",
  "pipeline_id": "UUID",
  "timestamp": "ISO8601",
  
  "asset": {
    "file_paths": {
      "source_png": "path/to/asset_source.png",
      "export_jpg": "path/to/export.jpg",
      "export_pdf": "path/to/export.pdf",
      "export_png_web": "path/to/export_web.png"
    },
    "dimensions": {
      "width_px": 3000,
      "height_px": 3000,
      "dpi": 300
    },
    "sizes_included": ["5x7", "8x10", "11x14", "16x20", "A4", "A3"]
  },
  
  "style": {
    "cluster": "BOTANICAL_WATERCOLOR",
    "theme": "herb_bundle_sage_cream",
    "prompt_used": "delicate watercolor botanical illustration...",
    "variables_used": {
      "plant_subject": "herb bundle",
      "color_palette": "sage green and cream"
    }
  },
  
  "gbrain_result": {
    "score": 7.8,
    "tier": "STANDARD",
    "components": {
      "style_match": 2.5,
      "technical_quality": 1.8,
      "market_appeal": 2.2,
      "originality": 1.3
    }
  },
  
  "listing_hints": {
    "suggested_use_cases": ["kitchen decor", "herb garden theme", "natural home"],
    "gift_contexts": ["plant lovers", "home cooks", "nature enthusiasts"],
    "dominant_colors": ["#9CAF88", "#F5F0E8", "#8B7355"]
  }
}
```

---

## FASE 4: ETSY ENGINE — Listing Generation

### Cómo el Etsy Engine consume el handoff

```python
def generate_listing(handoff_packet):
    
    cluster    = handoff_packet["style"]["cluster"]
    score      = handoff_packet["gbrain_result"]["score"]
    tier       = handoff_packet["gbrain_result"]["tier"]
    variables  = handoff_packet["style"]["variables_used"]
    hints      = handoff_packet["listing_hints"]
    
    # TITLE ENGINE
    title = TitleEngine.generate(
        cluster=cluster,
        variables=variables,
        max_chars=140
    )
    
    # DESCRIPTION ENGINE
    description = DescriptionEngine.generate(
        cluster=cluster,
        style_adjective=CLUSTER_VARS[cluster]["style_adjective"],
        use_cases=hints["suggested_use_cases"],
        gift_context=hints["gift_contexts"][0],
        file_count=len(handoff_packet["asset"]["sizes_included"]),
        resolution="300 DPI"
    )
    
    # TAG ENGINE
    tags = TagEngine.get_tags(cluster)  # 13 tags pre-definidos por cluster
    
    # PRICE ENGINE
    price = PriceEngine.calculate(
        cluster=cluster,
        tier=tier,  # PREMIUM | STANDARD | ENTRY
        bundle=False
    )
    
    # MOCKUP SELECTOR
    mockup_spec = MockupSelector.get(cluster)
    
    return {
        "title":       title,
        "description": description,
        "tags":        tags,
        "price":       price,
        "mockup_spec": mockup_spec,
        "files":       handoff_packet["asset"]["file_paths"],
        "metadata": {
            "pipeline_id":  handoff_packet["pipeline_id"],
            "gbrain_score": score,
            "cluster":      cluster,
            "theme":        handoff_packet["style"]["theme"]
        }
    }
```

---

## FASE 5: GBRAIN GATE v2 — Listing Quality Check

### Segunda evaluación: ¿el listing está listo para publicar?

```python
def gbrain_score_listing(listing, handoff_packet):
    
    checks = {
        # Verificaciones del title
        "title_length":    len(listing["title"]) <= 140,
        "title_has_keyword": _starts_with_primary_keyword(listing["title"]),
        "title_has_download_signal": any(
            word in listing["title"].lower() 
            for word in ["instant download", "digital download", "printable"]
        ),
        
        # Verificaciones del description
        "description_has_hook":     len(listing["description"]) > 200,
        "description_has_specs":    "300 DPI" in listing["description"] or "high-resolution" in listing["description"].lower(),
        "description_has_use_cases": listing["description"].count("•") >= 3,
        
        # Verificaciones de tags
        "tags_count":      len(listing["tags"]) == 13,
        "tags_max_chars":  all(len(t) <= 20 for t in listing["tags"]),
        
        # Verificaciones de precio
        "price_valid":     listing["price"] > 0,
        
        # Asset check
        "asset_min_size":  handoff_packet["asset"]["dimensions"]["width_px"] >= 3000,
    }
    
    passed = sum(checks.values())
    total  = len(checks)
    score  = (passed / total) * 10
    
    failed_checks = [k for k, v in checks.items() if not v]
    
    return {
        "score":         score,
        "passed":        passed,
        "total":         total,
        "decision":      "PUBLISH" if score >= 7.0 else "REWORK",
        "failed_checks": failed_checks
    }
```

---

## FASE 6: EXPORT + TURBOVEC STORAGE

### Etsy Export Packet

```json
{
  "export_format": "etsy_v3",
  "listing": {
    "title":        "Botanical Watercolor Print | Herb Bundle Wall Art | Instant Download | Printable Poster",
    "description":  "Transform your space with this botanical, organic art print...",
    "tags":         ["botanical print", "watercolor art", "floral wall art", "..."],
    "price":        4.99,
    "currency":     "USD",
    "quantity":     999,
    "digital":      true,
    "category_id":  "DIGITAL_PRINTS",
    "files": [
      {"name": "herb_bundle_5x7.pdf",  "type": "PDF"},
      {"name": "herb_bundle_8x10.jpg", "type": "JPG"},
      {"name": "herb_bundle_A4.pdf",   "type": "PDF"}
    ],
    "images": [
      {"type": "mockup",  "path": "mockup_room_natural_light.jpg"},
      {"type": "preview", "path": "asset_preview_flat.jpg"},
      {"type": "detail",  "path": "asset_closeup.jpg"}
    ]
  }
}
```

### TurboVec Storage Schema

```python
# Solo se almacena si GBRAIN listing score ≥ 7.5 o si fue publicado
turbovec.store({
    "id":            pipeline_id,
    "type":          "listing",
    "cluster":       cluster,
    "theme":         theme,
    "gbrain_score":  final_score,
    "status":        "published | staged | rejected",
    "embedding_fields": ["title", "tags", "theme", "cluster"],
    "metadata": {
        "price":      price,
        "etsy_id":    etsy_listing_id,  # null si no publicado aún
        "created_at": timestamp
    }
})
# Propósito: feedback loop — próximas generaciones evitan themes similares
# y favorecen clusters/estilos con mejor performance histórico
```

---

## PIPELINE COMPLETO — REFERENCIA RÁPIDA

```
INPUT TRIGGER
    │
    ▼
[TurboVec] → Query themes disponibles para el cluster
    │
    ▼
[Visual Engine v2]
    ├── Seleccionar theme/variables
    ├── Construir Google Flow prompt
    ├── Generar asset (Google Flow)
    └── Componer con PIL (layout, tamaños)
    │
    ▼
[GBRAIN Gate v1] ──REJECT──→ Regenerar (max 3 intentos)
    │ PASS
    ▼
[HANDOFF PACKET] → JSON estandarizado con asset + metadata
    │
    ▼
[Etsy Listing Engine v1]
    ├── Title Engine (140 chars, SEO)
    ├── Description Engine (hook + value + specs)
    ├── Tag Engine (13 tags)
    ├── Price Engine (tier-based)
    └── Mockup Selector
    │
    ▼
[GBRAIN Gate v2] ──REWORK──→ Ajuste copy (max 2 intentos)
    │ PUBLISH
    ▼
[Etsy Export Packet] → Manual upload o API
    │
    ▼
[TurboVec Store] → Feedback loop para próximas generaciones
```

---

## GAPS PENDIENTES PARA OPERACIONALIZAR

| Gap | Impacto | Necesita |
|---|---|---|
| Google Flow API interface | BLOQUEANTE | URL + auth + rate limits documentados |
| GBRAIN scoring impl. | BLOQUEANTE | ¿Computer vision local (Ollama)? ¿API externa? |
| TurboVec write interface | BLOQUEANTE | Schema real + método de inserción |
| PIL composition templates | MEDIO | Tamaños de export + canvas config por cluster |
| Etsy API credentials | MEDIO | API key + OAuth flow para auto-upload |
| Mockup library inventory | MEDIO | ¿Local files? ¿Placeit API? ¿Creative Market? |
| Regeneration prompt variants | BAJO | Templates de ajuste cuando GBRAIN rechaza |

---

## SIGUIENTE CAPA RECOMENDADA

Con el pipeline end-to-end definido, las 3 opciones restantes se priorizan así:

| Opción | Por qué ahora |
|---|---|
| **Opción 3 — Execution Hub** | Define QUIÉN ejecuta cada fase del pipeline (Playwright MCP, Python script, manual) — sin esto el pipeline es solo diseño |
| Opción 2 — Revenue Dashboard | Necesita datos reales de Etsy primero — prematuro sin listings publicados |
| Opción 4 — Migration Plan | Aplica cuando existe un sistema legacy que migrar — aún no hay |
