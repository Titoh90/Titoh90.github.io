# REFACTOR BLUEPRINT — Aether Global
**Fecha**: 2026-06-07  
**Modo**: Diseño únicamente — SIN modificar código

---

## ARQUITECTURA ACTUAL

```
hub/index.html (1,257 líneas)
└── <script> inline (929 líneas de lógica)
    ├── Data parsing (líneas 340-343)
    ├── App object con estado + métodos (líneas 347-513)
    ├── Nav UI functions (líneas 518-528)
    ├── i18n rendering (líneas 532-591)
    ├── Category rendering (líneas 594-669)
    ├── Product rendering (líneas 674-769)
    ├── Detail panel rendering (líneas 774-930)
    ├── Lazy loading (líneas 936-965)
    ├── Event setup (líneas 969-1100)
    ├── Security utilities (líneas 1105-1120)
    ├── Collections loading + rendering (líneas 1154-1200)
    └── Collection patches (líneas 1202-1254)
```

**Problemas estructurales de la arquitectura actual**:
1. Una sola unidad de código de 929 líneas sin separación
2. Lógica de negocio mezclada con renderizado
3. Estado global mutable accesible desde cualquier lugar
4. Imposible de testar sin browser completo (78% del código)
5. Código duplicado en múltiples lugares
6. Funciones privadas no testeables
7. Monkey-patching creando comportamiento no obvio

---

## ARQUITECTURA IDEAL

### Estructura de archivos propuesta

```
hub/
├── index.html              ← Solo estructura HTML + tags de datos
├── assets/
│   ├── styles.css          ← Sin cambios
│   └── app/
│       ├── main.js         ← Entry point — solo orquestación e init
│       ├── state.js        ← Estado centralizado (App state)
│       ├── filters.js      ← Toda la lógica de filtrado y sort
│       ├── i18n.js         ← Sistema de traducción y detección de idioma
│       ├── collections.js  ← Carga y gestión de colecciones
│       ├── render/
│       │   ├── render-products.js   ← Grid de productos
│       │   ├── render-detail.js     ← Panel de detalle
│       │   ├── render-collections.js← Strip de colecciones
│       │   └── render-ui.js        ← Nav, categorías, sort, i18n text
│       ├── events.js       ← Todos los event listeners
│       ├── lazy-images.js  ← IntersectionObserver
│       ├── security.js     ← _escHtml, _escAttr, validateUrl
│       └── utils/
│           ├── specs.js    ← _deriveSpecs (pura)
│           └── lang.js     ← _detectLang, _saveLang (pura)
└── data/
    ├── collections.json
    └── products.json       ← Fuente de verdad (eliminando embedded)
```

---

## MÓDULO: `security.js`

**Lo que contiene la versión actual**:
- `_escHtml(s)` — línea 1105
- `_escAttr(s)` — línea 1113

**Versión ideal**:
```javascript
// security.js
export function escHtml(s) { /* ... */ }
export function escAttr(s) { /* ... */ }
export function isSafeUrl(url) {
  // Nuevo: validar que url no comience con javascript:
  try {
    var parsed = new URL(url);
    return ['https:', 'http:'].includes(parsed.protocol);
  } catch(e) { return false; }
}
```

**Impacto en testabilidad**: De imposible (privada) a **trivialmente testeable** (módulo exportado).  
**Reducción de riesgo**: Añadir `isSafeUrl` cierra el vector de javascript: URL (hallazgo #4 del SECURITY_AUDIT).

---

## MÓDULO: `filters.js`

**Lo que contiene la versión actual** (fragmentado en 2 lugares):
- `App.getFilteredProducts()` — líneas 457–505
- Patch de colección — líneas 1224–1231

**Versión ideal**:
```javascript
// filters.js — todas funciones puras, zero side effects

export function filterByNav(products, activeNav) { ... }
export function filterByCategory(products, category) { ... }
export function filterByQuery(products, query, lang) { ... }
export function sortProducts(products, sortKey) { ... }
export function filterByCollection(products, collectionAsins) { ... }

export function getFilteredProducts(products, state) {
  if (state.collectionFilter) {
    return filterByCollection(products, state.collectionFilter);
  }
  var result = filterByNav(products, state.activeNav);
  result = filterByCategory(result, state.category);
  result = filterByQuery(result, state.query, state.lang);
  result = sortProducts(result, state.sort);
  return result;
}
```

**Impacto**:
- `getFilteredProducts` pasa de CC=13 a ser orquestador de 4 funciones de CC=2-3 cada una
- Cada sub-función es testeable de forma independiente
- El monkey-patch se elimina: la lógica de colección es una rama normal
- La referencia circular `App.category` dentro de closures se elimina (pasa como parámetro)

---

## MÓDULO: `i18n.js`

**Lo que contiene la versión actual** (fragmentado):
- `App.t(key)` — línea 354
- `_detectLang()` — línea 1071
- `_saveLang()` — línea 1080
- `_LANGS` — línea 1047

**Versión ideal**:
```javascript
// i18n.js
const SUPPORTED_LANGS = ['en', 'es', 'fr'];

export function createTranslator(i18nData) {
  return {
    t(lang, key) {
      return (i18nData[lang]?.[key]) || (i18nData['en']?.[key]) || key;
    },
    detectLang() { ... },
    saveLang(lang) { ... },
    cycleLang(current) {
      const idx = SUPPORTED_LANGS.indexOf(current);
      return SUPPORTED_LANGS[(idx + 1) % SUPPORTED_LANGS.length];
    }
  };
}
```

**Impacto**: `App.t()` pasa de depender de `I18N` global a recibir los datos como parámetro. Trivialmente testeable.

---

## MÓDULO: `state.js`

**Lo que contiene la versión actual** (mezclado dentro de App):
- `App.lang`, `App.category`, `App.query`, `App.sort`, `App.activeNav`
- `App._collectionFilter`, `App._collectionTitle`, `App._collectionStory`

**Versión ideal**:
```javascript
// state.js
export function createState(initialLang) {
  return {
    lang:             initialLang,
    category:         'all',
    query:            '',
    sort:             'default',
    activeNav:        'shop',
    collectionFilter: null,
    collectionTitle:  null,
  };
  // _collectionStory eliminado — nunca se usaba
}

export function resetState(state) {
  return { ...state, category: 'all', query: '', sort: 'default',
           activeNav: 'shop', collectionFilter: null, collectionTitle: null };
}
```

**Impacto**: Estado limpio, inmutable por convención, sin propiedades fantasma.

---

## MÓDULO: `utils/specs.js`

```javascript
// utils/specs.js — pura, ya casi lista para extraer
export function deriveSpecs(product) {
  // contenido actual de _deriveSpecs sin cambios
}
```

---

## MÓDULO: `collections.js`

**Lo que contiene la versión actual** (fragmentado en 3 secciones):
- `_loadCollections()` — línea 1154
- `_renderCollections()` — línea 1164
- `App.showCollection()`, `App.clearCollection()` — líneas 1203–1250
- Patch de getFilteredProducts — línea 1224

**Versión ideal**:
```javascript
// collections.js
export async function loadCollections(url) {
  try {
    const r = await fetch(url);
    return r.ok ? await r.json() : [];
  } catch { return []; }
}

export function getCollectionById(collections, id) {
  return collections.find(c => c.id === id) || null;
}

export function getCollectionAsins(collection) {
  return (collection.products || []).map(p => p.asin);
}
```

**Impacto**: `loadCollections` es testeable con mock de fetch. La lógica de ASIN extraction está separada y testeable de forma independiente.

---

## MODELO DE REFACTORING POR FASES

### Fase 0 — Sin cambios funcionales (preparación)
- [ ] Eliminar archivos huérfanos (`app.js`, `hub/products.json`, `hub/data/products.json`, `hub/i18n/*.json`)
- [ ] Añadir `package.json` con Vitest
- [ ] Crear estructura de directorios `assets/app/`

### Fase 1 — Extraer módulos puros (zero riesgo, máximo ROI de tests)
- [ ] Extraer `security.js` con `escHtml`, `escAttr`, `isSafeUrl`
- [ ] Extraer `utils/specs.js` con `deriveSpecs`
- [ ] Extraer `utils/lang.js` con `detectLang`, `saveLang`
- [ ] Escribir tests para estos 5 funciones → ~40% de cobertura de lógica crítica

### Fase 2 — Desacoplar lógica de filtrado
- [ ] Crear `filters.js` con funciones puras
- [ ] Eliminar monkey-patch de `getFilteredProducts`
- [ ] Corregir bug: búsqueda en `descriptionI18n` en lugar de `description`
- [ ] Corregir bug: `navShop()` y `reset()` limpian `collectionFilter`
- [ ] Escribir tests para todas las funciones de filtrado

### Fase 3 — Separar estado
- [ ] Crear `state.js`
- [ ] Eliminar `_collectionStory` (nunca se usa)
- [ ] Eliminar prefijos `_` de propiedades privadas (no tiene sentido en objeto publico)

### Fase 4 — Modularizar rendering
- [ ] Crear `render/` con sub-módulos
- [ ] Extraer `_getRelatedProducts(product, products)` de `_renderDetail`
- [ ] Eliminar duplicación de star rating (una función compartida)
- [ ] Eliminar duplicación de search debounce

### Fase 5 — Carga de datos (opcional, largo plazo)
- [ ] Pasar de datos embebidos en HTML a carga dinámica desde `data/products.json`
- [ ] Crear proceso de deploy que mantiene UN archivo de datos como fuente de verdad

---

## ESTIMACIÓN DE IMPACTO

| Métrica | Actual | Post-Fase 1 | Post-Fase 2-3 | Post-Fase 4-5 |
|---|---|---|---|---|
| Líneas testables sin DOM | ~200 (22%) | ~280 (30%) | ~400 (43%) | ~600 (65%) |
| Complejidad de función más compleja (CC) | 15 | 15 | 9 | 5 |
| Funciones con test coverage | 0 | 5 | 12 | 20+ |
| Archivos huérfanos | 6 | 0 | 0 | 0 |
| Sources of truth para productos | 3 | 3 | 3 | 1 |
| Bugs activos documentados | 8 | 8 | 5 | 1 |

La Fase 1 es la de mayor ROI: zero riesgo de regresión, elimina los archivos huérfanos, y permite empezar a testear las funciones más críticas de seguridad y lógica.
