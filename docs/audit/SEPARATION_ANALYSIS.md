# SEPARATION ANALYSIS — UI vs Business Logic
**Fecha**: 2026-06-07  
**Archivo analizado**: hub/index.html (script inline, líneas 327–1255)

---

## CLASIFICACIÓN POR FUNCIÓN

Cada función fue clasificada según su naturaleza primaria:

| Categoría | Código | Definición |
|---|---|---|
| **A — Business Logic** | BL | Determina QUÉ mostrar, reglas de negocio |
| **B — UI Logic** | UI | Manipula el DOM, genera HTML |
| **C — State Management** | SM | Lee/escribe el estado de la aplicación |
| **D — Utility Functions** | UT | Funciones puras sin side effects |
| **E — Security Functions** | SEC | Protección contra inyección |
| **F — Legacy/Dead Code** | LEGACY | Código que no ejecuta o está huérfano |

---

## TABLA COMPLETA DE FUNCIONES

| Función | Líneas | Categoría | Mixtura | Notas |
|---|---|---|---|---|
| `App.t(key)` | 354–358 | **BL** | Pura BL | Lookup de traducción con fallback |
| `App.openProduct(id)` | 360–371 | **SM + UI** | Fuertemente mixto | Busca producto (BL), renderiza (UI), modifica DOM y history (UI) |
| `App.closeProduct()` | 373–381 | **SM + UI** | Fuertemente mixto | Historia del browser + DOM |
| `App.reset()` | 382–398 | **SM + UI** | Fuertemente mixto | Resetea estado + toca 6 elementos DOM |
| `App.setLang(lang)` | 400–408 | **SM + UI** | Fuertemente mixto | Guarda estado + actualiza DOM |
| `App.clearSearch()` | 410–419 | **SM + UI** | Fuertemente mixto | Limpia estado + 3 elementos DOM |
| `App.filterCategory(cat)` | 421–423 | **SM** | Limpio | Solo estado, delega a render() |
| `App.setSort(val)` | 426–430 | **SM + UI** | Ligero mix | Estado + un elemento DOM |
| `App.navShop()` | 433–440 | **SM + UI** | Fuertemente mixto | Estado + navUI + scroll |
| `App.navTrends()` | 442–449 | **SM + UI** | Fuertemente mixto | Estado + navUI + scroll |
| `App.navSaved()` | 451–455 | **SM + UI** | Stub | Llama a render() sin lógica saved |
| `App.getFilteredProducts()` | 457–505 | **BL** | Pura BL | La función más importante del sistema |
| `App.render()` | 507–513 | **UI** | Pura UI | Orquestador de renderizado |
| `_updateNavUI(active)` | 518–528 | **UI** | Pura UI | Modifica clases CSS nav |
| `_updateI18nText()` | 532–264 | **UI** | Pura UI | Actualiza ~18 elementos DOM |
| `_renderCategories()` | 594–611 | **UI** | Pura UI | Genera HTML chips |
| `_renderSidebarCategories()` | 616–640 | **UI** | Pura UI | Genera HTML sidebar |
| `_renderSidebarSort()` | 645–669 | **UI** | Pura UI | Genera HTML sort options |
| `_renderProducts()` | 674–700 | **UI** | UI + BL | Llama getFilteredProducts() y renderiza |
| `_renderCard(p, idx)` | 703–743 | **UI** | Pura UI | Genera HTML string de tarjeta |
| `_renderDetail(p)` | 774–903 | **UI + BL** | Mixto | UI pesada + contiene lógica de related products |
| `_deriveSpecs(p)` | 905–930 | **BL** | Pura BL | Genera specs por categoría/tags |
| `_setupLazyImages()` | 936–965 | **UI** | Pura UI | Browser API |
| `_setupSearch()` | 969–1032 | **UI** | Pura UI | Event listeners |
| `_setupSort()` | 1036–1042 | **UI** | Pura UI | Event listeners |
| `_setupLang()` | 1049–1068 | **UI + BL** | Ligero mix | Ciclo de idiomas |
| `_detectLang()` | 1071–1077 | **BL** | Pura BL | Detecta idioma óptimo |
| `_saveLang(lang)` | 1080–1082 | **SM** | Side effect | Persiste en localStorage |
| `_setupBrandLink()` | 1086–1100 | **UI** | Pura UI | Event listeners |
| `_loadCollections()` | 1154–1161 | **BL** | Async I/O | Carga datos externos |
| `_renderCollections()` | 1164–1200 | **UI** | Pura UI | Genera HTML strip |
| `App.showCollection()` | 1203–1220 | **SM + BL** | Mixto | Extrae ASINs (BL) + setea estado |
| `App.clearCollection()` | 1245–1250 | **SM** | Limpio | Solo limpia estado |
| `_escHtml(s)` | 1105–1111 | **SEC** | Pura SEC | Sin side effects |
| `_escAttr(s)` | 1113–1120 | **SEC** | Pura SEC | Sin side effects |
| `App.getFilteredProducts()` (patch) | 1224–1231 | **BL** | Monkeypatch | Sobreescribe función original |
| `App.render()` (patch) | 1235–1242 | **UI** | Monkeypatch | Añade lógica de collection header |

---

## DISTRIBUCIÓN POR CATEGORÍA

| Categoría | Funciones | Líneas estimadas | % del código |
|---|---|---|---|
| **UI Logic** | 16 | ~470 | ~51% |
| **Business Logic** | 7 | ~185 | ~20% |
| **State Management** | 4 | ~80 | ~9% |
| **Mixed (inseparable)** | 8 | ~120 | ~13% |
| **Security** | 2 | ~16 | ~2% |
| **Utility/Setup** | 4 | ~55 | ~5% |

---

## ANÁLISIS DE MEZCLA

### Funciones con mayor contaminación (BL dentro de UI o viceversa)

#### `_renderDetail(p)` — líneas 774–903 (130 líneas)
Esta es la función más contaminada del codebase. Contiene:
- **UI pura**: setea ~12 elementos DOM
- **Business logic mezclada**: lógica de related products (líneas 879–884) — decide qué productos mostrar basado en categoría y fallback
- **Business logic mezclada**: lectura de descripción con fallback entre `descriptionI18n` y `description` (líneas 834–840)

Si se refactorizara, la lógica de "qué productos son relacionados" debería estar en una función separada `_getRelatedProducts(p)`.

#### `App.openProduct(id)` — líneas 360–371
Mezcla:
- **Business**: búsqueda del producto por id en PRODUCTS (línea 361)
- **UI**: ocultar/mostrar panel, scroll, body overflow
- **Browser API**: history.pushState

#### `App.reset()` — líneas 382–398
Mezcla:
- **State**: 4 asignaciones a `this.*`
- **DOM**: toca `sort-select`, `search-input`, `search-input-desktop`, `search-clear`
- **UI**: llama `_updateNavUI` y `window.scrollTo`

---

## DEUDA DE SEPARACIÓN

### Lo que está bien
- `App.t(key)` — perfectamente pura
- `_deriveSpecs(p)` — perfectamente pura
- `_detectLang()` — casi pura (solo lee, no escribe)
- `App.getFilteredProducts()` — pura (salvo la referencia a `App.category` global)
- `_escHtml()` / `_escAttr()` — perfectamente puras

### Lo que está mal

#### Problema 1: Las funciones `reset()`, `setLang()`, `openProduct()`, `navShop()` hacen demasiado
Cada una resetea estado Y manipula DOM. Si el DOM cambia (e.g., se renombra un ID), estas funciones se rompen aunque la lógica de negocio sea correcta.

#### Problema 2: La lógica de "related products" vive dentro de una función de renderizado
`_renderDetail(p)` toma decisiones de negocio (qué mostrar) y de presentación (cómo mostrarlo) en el mismo lugar. Líneas 879–884 son lógica pura que debería ser separable.

#### Problema 3: App.render() (patch) mezcla UI y datos de colección
El patch de `App.render()` en línea 1235 inyecta HTML con un botón (`innerHTML`) basado en estado de negocio. La mezcla de estado → decisión → HTML está comprimida en 4 líneas.

---

## MÉTRICAS DE SEPARACIÓN

| Métrica | Valor |
|---|---|
| Funciones puras (testables sin DOM) | 7 de 36 (19%) |
| Funciones con DOM mixto | 20 de 36 (56%) |
| Funciones puramente DOM/UI | 9 de 36 (25%) |
| Líneas de lógica pura testable | ~200 de ~928 (22%) |
| Líneas de DOM manipulation | ~520 de ~928 (56%) |
| Líneas de setup/glue | ~200 de ~928 (22%) |

**Conclusión**: El 78% del código es DOM-dependent o mixed, lo que hace imposible testar la mayoría de funciones sin JSDOM o un browser completo. Solo el 22% (~200 líneas) es lógica pura que se puede testar con Node.js puro.
