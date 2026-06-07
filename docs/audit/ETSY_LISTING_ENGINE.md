# ETSY LISTING ENGINE v1
## IMPERIO Visual Engine — Revenue Layer
**Fecha**: 2026-06-07  
**Propósito**: Convertir assets visuales generados en listings Etsy optimizados para conversión

---

## ARQUITECTURA DEL ENGINE

```
ASSET (Google Flow output)
    │
    ├── TITLE ENGINE          → título SEO-optimizado
    ├── DESCRIPTION ENGINE    → copy de conversión
    ├── TAG ENGINE            → 13 tags máximos Etsy
    ├── PRICE ENGINE          → pricing por cluster de estilo
    └── MOCKUP SELECTOR       → tipo de mockup por categoría
```

---

## MÓDULO 1: TITLE ENGINE

### Estructura de título Etsy (máximo 140 caracteres)

```
[KEYWORD PRIMARIA] | [ESTILO] [FORMATO] | [USO FINAL] | [VARIANTE]
```

### Templates por cluster de estilo

#### BOTANICAL_WATERCOLOR
```
Botanical Watercolor Print | {{plant_type}} Wall Art | Instant Download | Printable Poster
Watercolor {{plant_type}} Print | Botanical Illustration | Home Decor | Digital Download
Herb Garden Print | Watercolor Botanical Art | Kitchen Wall Decor | Printable
```

#### COTTAGECORE
```
Cottagecore Wall Art | {{object_scene}} Print | Farmhouse Decor | Digital Download
Rustic {{object_scene}} Illustration | Cottagecore Print | Vintage Home Decor | Printable
Cozy Cottage Print | {{object_scene}} Wall Art | Farmhouse Kitchen Decor
```

#### MODERN_MINIMAL_LUXE
```
Minimalist {{concept}} Print | Modern Wall Art | Luxury Home Decor | Digital Download
Editorial {{concept}} Poster | Minimal Black and White | Aesthetic Wall Art | Printable
Modern Minimalist Print | {{concept}} Wall Art | Scandinavian Decor | Instant Download
```

#### DARK_ACADEMIA
```
Dark Academia {{subject}} Print | Moody Wall Art | Library Decor | Digital Download
Vintage {{subject}} Illustration | Dark Academia Aesthetic | Study Room Decor
Gothic {{subject}} Print | Dark Moody Art | Book Lover Gift | Instant Download
```

#### CHILDREN_EDUCATIONAL
```
{{learning_topic}} Educational Print | Kids Wall Art | Classroom Decor | Printable
Children's {{learning_topic}} Poster | Educational Nursery Art | Learning Print
Cute {{learning_topic}} Print | Kids Room Decor | Educational Wall Art | Digital
```

### REGLAS DEL TITLE ENGINE

| Regla | Aplicación |
|---|---|
| Keyword primaria SIEMPRE primero | Etsy pondera las primeras palabras |
| Pipe `\|` como separador | Más legible que comas |
| "Instant Download" o "Digital Download" incluido | Filtra intención de compra |
| Nunca exceder 140 caracteres | Hard limit de Etsy |
| Sin ALL CAPS de frases enteras | Penalizado por Etsy |

---

## MÓDULO 2: DESCRIPTION ENGINE

### Estructura de descripción (copywriting para conversión)

```
[HOOK — 1 frase]

[QUÉ RECIBES — bullet list]

[ESPECIFICACIONES TÉCNICAS]

[INSTRUCCIONES DE USO]

[GARANTÍA / PROPUESTA DE VALOR]

[KEYWORDS ADICIONALES (párrafo SEO)]
```

### Template Base (adaptable a todos los clusters)

```markdown
Transform your space with this {{style_adjective}} {{product_type}} — 
instantly printable and ready to frame.

━━━━━━━━━━━━━━━━━━
✦ WHAT YOU GET
━━━━━━━━━━━━━━━━━━
• {{file_count}} high-resolution files ({{resolution}})
• Formats included: PDF + JPG + PNG
• Ready to print at home or at any print shop
• No watermarks on final files

━━━━━━━━━━━━━━━━━━
✦ SIZES INCLUDED
━━━━━━━━━━━━━━━━━━
• 5×7" | 8×10" | 11×14" | 16×20" | A4 | A3

━━━━━━━━━━━━━━━━━━
✦ HOW TO USE
━━━━━━━━━━━━━━━━━━
1. Purchase and download instantly
2. Print at home or local print shop
3. Frame and display — no craft skills needed

━━━━━━━━━━━━━━━━━━
✦ PERFECT FOR
━━━━━━━━━━━━━━━━━━
• {{use_case_1}}
• {{use_case_2}}
• {{use_case_3}}
• Gift ideas: {{gift_context}}

━━━━━━━━━━━━━━━━━━
✦ QUALITY GUARANTEE
━━━━━━━━━━━━━━━━━━
All files are professionally designed and print-ready.
If you have any issues with your download, I'll make it right.

─────────────────────────────
KEYWORDS: {{seo_keyword_paragraph}}
─────────────────────────────
```

### Variables por cluster de estilo

| Variable | BOTANICAL | COTTAGECORE | MINIMAL_LUXE | DARK_ACADEMIA |
|---|---|---|---|---|
| `style_adjective` | botanical, organic | cozy, rustic | elegant, minimal | moody, sophisticated |
| `use_case_1` | Living room gallery wall | Kitchen wall decor | Home office decor | Study room art |
| `use_case_2` | Bedroom nature print | Dining room decor | Bedroom minimal art | Library aesthetic |
| `gift_context` | plant lovers, nature enthusiasts | farmhouse lovers | minimalist decor fans | book lovers, students |

---

## MÓDULO 3: TAG ENGINE

### Reglas Etsy tags
- Máximo 13 tags
- Máximo 20 caracteres por tag
- Usar frases, no solo palabras
- Sin repetición con palabras del título (Etsy las indexa por separado)

### Tag Sets por cluster

#### BOTANICAL_WATERCOLOR (13 tags)
```
botanical print
watercolor art
floral wall art
nature decor
plant lover gift
botanical poster
herb print
garden art
watercolor floral
printable art
wall art prints
instant download
home decor art
```

#### COTTAGECORE (13 tags)
```
cottagecore decor
farmhouse print
rustic wall art
cozy home decor
vintage illustration
cottage art print
farmhouse kitchen
rustic home art
country decor
printable poster
digital wall art
home decor print
vintage home art
```

#### MODERN_MINIMAL_LUXE (13 tags)
```
minimalist print
modern wall art
luxury home decor
minimal poster
scandinavian art
black white print
editorial art
modern decor
abstract minimal
clean aesthetic
premium wall art
contemporary art
designer print
```

#### DARK_ACADEMIA (13 tags)
```
dark academia art
moody wall decor
gothic art print
library aesthetic
vintage moody art
dark home decor
academia poster
book lover gift
dark aesthetic
moody print art
vintage gothic
study room art
cinematic poster
```

#### CHILDREN_EDUCATIONAL (13 tags)
```
kids wall art
educational print
nursery decor art
classroom poster
children learning
alphabet print
kids room decor
educational art
playroom decor
toddler art print
learning poster
nursery print
teacher gift art
```

---

## MÓDULO 4: PRICE ENGINE

### Pricing por cluster (basado en competencia Etsy)

| Cluster | Entry Price | Mid Price | Premium Price | Bundle |
|---|---|---|---|---|
| BOTANICAL_WATERCOLOR | $2.99 | $4.99 | $6.99 | $12.99 (set of 3) |
| COTTAGECORE | $2.99 | $3.99 | $5.99 | $9.99 (set of 3) |
| MODERN_MINIMAL_LUXE | $3.99 | $5.99 | $8.99 | $14.99 (set of 3) |
| DARK_ACADEMIA | $3.99 | $5.99 | $7.99 | $13.99 (set of 3) |
| CHILDREN_EDUCATIONAL | $2.49 | $3.99 | $5.99 | $14.99 (full set) |

### GBRAIN Pricing Rules

```
IF market_score >= 8 AND style_cluster == "botanical_watercolor":
    → use PREMIUM pricing
    
IF market_score >= 6 AND market_score < 8:
    → use MID pricing
    
IF market_score < 6:
    → DO NOT LIST (send back to regeneration)
    
IF bundle_size >= 3:
    → apply 25% discount to individual price
```

---

## MÓDULO 5: MOCKUP SELECTOR

### Qué mockup usar por cluster

| Cluster | Mockup Type | Ambiente | Frame |
|---|---|---|---|
| BOTANICAL_WATERCOLOR | Room scene | White wall, natural light, plants nearby | Natural wood or thin black |
| COTTAGECORE | Lifestyle | Rustic shelf, wooden table, dried flowers | Vintage wood, distressed |
| MODERN_MINIMAL_LUXE | Editorial | All-white room, minimal furniture | Thin black or frameless |
| DARK_ACADEMIA | Moody room | Dark wall, warm lamp light, books | Dark wood, brass |
| CHILDREN_EDUCATIONAL | Nursery/classroom | Pastel room, toys visible | Colorful or natural wood |

### CRITICAL RULE: Mockup calidad mínima
- Resolución mínima: 3000×3000px
- Sin watermarks visibles del mockup provider
- El arte debe ocupar 60-75% del mockup (no demasiado pequeño)

---

## MÓDULO 6: LISTING ASSEMBLY PIPELINE

### Input → Output completo

```python
# PSEUDO-CÓDIGO — lógica del engine

def generate_listing(asset, style_cluster, market_score):
    
    # GATE: calidad mínima
    if market_score < 6:
        return {"status": "REJECTED", "reason": "below_quality_threshold"}
    
    listing = {
        "title":       TitleEngine.generate(style_cluster, asset.variables),
        "description": DescriptionEngine.generate(style_cluster, asset.variables),
        "tags":        TagEngine.get_tags(style_cluster),
        "price":       PriceEngine.calculate(style_cluster, market_score),
        "mockup":      MockupSelector.get(style_cluster),
        "files":       asset.export_files(),  # PDF + JPG + PNG multitamaños
        "category":    "Digital Downloads > Printable Art",
        "shipping":    "digital_only"
    }
    
    # STORAGE
    TurboVec.store(listing, embedding_fields=["title", "tags", "style_cluster"])
    
    return listing
```

---

## MÓDULO 7: SEO KEYWORD PARAGRAPH (para description)

### Template por cluster

#### BOTANICAL_WATERCOLOR
```
This botanical watercolor print is perfect for nature-inspired home decor, 
plant lover gifts, and botanical illustration collections. Ideal for living 
room gallery walls, bedroom art, bathroom prints, and kitchen herb decor. 
A beautiful watercolor floral print that brings organic beauty to any space.
```

#### COTTAGECORE
```
This cottagecore wall art print captures the cozy farmhouse aesthetic for 
rustic home decor, cottage kitchen art, and country living spaces. Perfect 
for farmhouse dining room decor, vintage bedroom art, and cottage garden 
lovers looking for printable home decoration.
```

#### MODERN_MINIMAL_LUXE
```
This minimalist wall art print brings clean, modern elegance to home office 
decor, bedroom art, and contemporary living spaces. Ideal for Scandinavian 
interior design, luxury apartment decoration, and editorial-style gallery walls.
```

---

## SISTEMA COMPLETO — FLUJO FINAL

```
STYLE_CLUSTER (TurboVec)
    ↓
GOOGLE_FLOW → asset generado
    ↓
GBRAIN SCORE (≥6 para continuar)
    ↓
LISTING ENGINE:
    ├── Title (140 chars, SEO)
    ├── Description (conversion copy)
    ├── Tags (13 máximo)
    ├── Price (market-based)
    └── Mockup (ambiente correcto)
    ↓
ETSY EXPORT (manual o via API)
    ↓
TURBOVEC STORAGE (feedback loop)
```

---

## GAPS IDENTIFICADOS (pendientes de datos reales)

| Gap | Descripción | Necesita |
|---|---|---|
| Mockup library | ¿Tienes mockups propios o usas Placeit/Creative Market? | Inventario local |
| Google Flow API | ¿Cómo llamas al generador? ¿URL, CLI, API key? | Documentación local |
| Etsy API credentials | ¿Upload manual o automatizado via API? | Credenciales locales |
| STYLE_VECTORS.json | Los 300 estilos mencionados — ¿dónde viven? | Archivo local |
| GBRAIN scoring model | ¿Cómo evalúa "texture realism"? ¿visión computacional? | Spec local |
