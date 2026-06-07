# STATE AUDIT — Aether Global
**Fecha**: 2026-06-07  
**Modo**: Read-Only Forensic Investigation

---

## 1. INVENTARIO COMPLETO DE ESTADO

### 1.1 Estado en el objeto App (public state)

| Variable | Tipo | Valor inicial | Modificado por | Leído por |
|---|---|---|---|---|
| `App.lang` | string | `_detectLang()` | `App.setLang()` | `App.t()`, `_detectLang()`, filtro de búsqueda, `_renderDetail()` |
| `App.category` | string | `'all'` | `App.filterCategory()`, `App.reset()`, `App.navShop()`, `App.navTrends()`, `App.showCollection()` | `App.getFilteredProducts()` |
| `App.query` | string | `''` | `_setupSearch()` (vía eventos), `App.clearSearch()`, `App.reset()`, `App.navShop()`, `App.navTrends()`, `App.showCollection()` | `App.getFilteredProducts()` |
| `App.sort` | string | `'default'` | `App.setSort()`, `App.reset()`, `App.showCollection()` | `App.getFilteredProducts()` |
| `App.activeNav` | string | `'shop'` | `App.navShop()`, `App.navTrends()`, `App.navSaved()`, `App.reset()` | `App.getFilteredProducts()` |
| `App._collectionFilter` | array\|null | `undefined` | `App.showCollection()`, `App.clearCollection()` | `App.getFilteredProducts()` (patch) |
| `App._collectionTitle` | string\|null | `undefined` | `App.showCollection()`, `App.clearCollection()` | `App.render()` (patch) |
| `App._collectionStory` | string\|null | `undefined` | `App.showCollection()`, `App.clearCollection()` | **NUNCA leído en UI** |

### 1.2 Variables globales del IIFE (estado privado)

| Variable | Tipo | Valor inicial | Modificado por | Leído por |
|---|---|---|---|---|
| `DATA` | object | JSON.parse al load | Nunca | Inicialización de PRODUCTS/CATEGORIES |
| `PRODUCTS` | array | `DATA.products \|\| []` | **Nunca** (inmutable post-init) | `App.getFilteredProducts()`, `_renderDetail()` |
| `CATEGORIES` | array | `DATA.categories \|\| []` | **Nunca** (inmutable post-init) | `_renderCategories()`, `_renderSidebarCategories()` |
| `I18N` | object | JSON.parse al load | Nunca | `App.t()`, `_detectLang()` |
| `_LANGS` | array | `['en','es','fr']` | Nunca | `_setupLang()` (ciclo) |
| `_observer` | IntersectionObserver\|null | `null` | `_setupLazyImages()` | `_setupLazyImages()` |
| `COLLECTIONS` | array | `[]` | `_loadCollections()` (async) | `App.showCollection()`, `_renderCollections()` |

### 1.3 Estado en localStorage (persistido)

| Clave | Valor | Escrito por | Leído por |
|---|---|---|---|
| `aether_lang` | `'en'|'es'|'fr'` | `_saveLang()` | `_detectLang()` |

---

## 2. DIAGRAMA DE FLUJO DE ESTADO

```
Eventos de usuario
│
├── Click filtro categoría → App.category → getFilteredProducts() → render()
├── Escribir en search → [debounce 220ms] → App.query → getFilteredProducts() → render()
├── Cambiar sort → App.sort → getFilteredProducts() → render()
├── Click nav → App.activeNav + App.category + App.query → getFilteredProducts() → render()
├── Click lang → App.lang → localStorage → render() (full re-render)
├── Click colección → App._collectionFilter → getFilteredProducts (patch) → render()
├── Click reset/logo → todos los campos → render()
└── Click producto → _renderDetail(p) [NO modifica estado del listing]
```

---

## 3. ANÁLISIS DE RIESGOS

### RIESGO 1: _collectionStory nunca se lee
**Severidad: LOW**  
`App._collectionStory` se asigna en `showCollection()` y se nullea en `clearCollection()`, pero **ningún código lo lee o renderiza**. Es estado muerto que ocupa memoria y confunde al lector.

```javascript
// Línea 1216 — se asigna
this._collectionStory = coll.editorial_story || '';
// Línea 1248 — se nullea
this._collectionStory = null;
// NUNCA se usa entre medias
```

### RIESGO 2: _collectionFilter inicializado como undefined, no null
**Severidad: MEDIUM**  
`App._collectionFilter` no existe en la definición inicial del objeto App. Se crea dinámicamente en `showCollection()`. El check en el patch usa `if (this._collectionFilter)`, lo cual funciona para `undefined` (falsy) y `null` (falsy), pero es inconsistente: `clearCollection()` lo setea a `null` mientras que al inicio es `undefined`.

Si alguien agrega lógica que distingue entre `null` y `undefined` (e.g., `_collectionFilter === null`), el comportamiento inicial divergirá.

### RIESGO 3: Estado duplicado entre App y DOM
**Severidad: HIGH**  
Varios elementos del estado tienen representación tanto en el objeto App como en el DOM:

| Estado App | Representación DOM | Quién puede desincronicarlos |
|---|---|---|
| `App.sort` | `#sort-select.value` | `App.setSort()` sincroniza, pero si el DOM se manipula directamente... |
| `App.query` | `#search-input.value`, `#search-input-desktop.value` | `_setupSearch()` no sincroniza desktop→mobile en todos los casos |
| `App.lang` | `#lang-display.textContent`, `#lang-display-desktop.textContent` | Solo se actualiza en `App.setLang()` y DOMContentLoaded |

**Escenario de desincronización real (evidencia)**:  
Si el usuario escribe en el input mobile, luego cierra la barra de búsqueda y abre la de escritorio, el input desktop estará vacío pero `App.query` tendrá el valor de la búsqueda previa. Los resultados filtrados serán correctos pero el input desktop no lo refleja.

### RIESGO 4: COLLECTIONS cargado asíncronamente en variable global mutable
**Severidad: MEDIUM**  
`COLLECTIONS` empieza como `[]` y se popula después de un `fetch()`. Durante el tiempo entre DOMContentLoaded y la resolución del fetch, `App.showCollection()` puede ser llamado (e.g., por URL, por script externo) y recibirá `COLLECTIONS = []`, fallando silenciosamente.

### RIESGO 5: App accesible globalmente como window.App
**Severidad: MEDIUM**  
```javascript
window.App = App;  // línea 1252
```
Todo el estado de la aplicación es modificable desde la consola del browser o desde cualquier script en la página. Un script de terceros (analytics, Tailwind CDN malicioso) podría modificar `App.lang`, `App._collectionFilter`, etc.

### RIESGO 6: Referencia circular App → App dentro de closures
**Severidad: LOW (funcional pero frágil)**  
En `getFilteredProducts()`, los callbacks de `.filter()` usan `App.category` y `App.lang` en lugar de `this.category` y `this.lang`:

```javascript
// Línea 468 — usa App (global) no this
prods = prods.filter(function(p) { return p.category === App.category; });
```

Si `App` fuera reasignado o si `getFilteredProducts` fuera llamado con un `this` diferente al objeto App original, los filtros usarían el estado global incorrecto. En el estado actual funciona porque `App` es el mismo objeto que `this`, pero es una dependencia frágil.

---

## 4. ESTADOS POTENCIALMENTE INCONSISTENTES

| Escenario | Estado resultante | Consecuencia |
|---|---|---|
| Usuario activa una colección y luego cambia idioma | `_collectionFilter` activo + `App.lang` cambiado | La colección se mantiene pero los textos de UI cambian. OK, funciona. |
| Usuario activa una colección y luego hace navShop() | `_collectionFilter` NO se limpia | ⚠️ `navShop()` resetea `category`, `query`, `sort` pero NO limpia `_collectionFilter`. El getFilteredProducts patch seguirá usando la colección. |
| Usuario activa una colección y luego hace reset() | `_collectionFilter` NO se limpia | ⚠️ Mismo problema. `reset()` no conoce `_collectionFilter`. |
| Usuario activa colección, cierra browser y vuelve | Estado perdido, colección no persiste | OK, esperado. |

**BUG CRÍTICO de estado identificado**: `App.navShop()` y `App.reset()` no limpian `_collectionFilter`. Una vez que el usuario activa una colección, las únicas formas de salir son:
1. Hacer click en el botón "← All" en el count display (llama `App.clearCollection()`)
2. Recargar la página

Si el usuario hace click en "Shop" en el nav, visualmente parece que está en la vista normal, pero los productos siguen siendo los de la colección activa.

---

## 5. VARIABLES SIN USO O CON USO MÍNIMO

| Variable | Problema |
|---|---|
| `App._collectionStory` | Asignada, nunca leída |
| `DATA` | Solo se usa para inicializar PRODUCTS/CATEGORIES, podría eliminarse después |
| `App.activeNav = 'saved'` | El estado se setea pero `getFilteredProducts()` no lo usa |
| `p.section` (en schema de producto) | Campo en datos ("hero", "trending", "recent", "evergreen") que nunca se lee en el código |
| `social_angle` en collections.json | Datos de negocio valiosos que nunca se exponen en la UI |
