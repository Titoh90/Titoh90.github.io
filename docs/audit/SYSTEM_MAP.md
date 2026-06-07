# SYSTEM MAP — Aether Global
**Fecha**: 2026-06-07  
**Modo**: Read-Only Forensic Investigation  
**Fuente**: Evidencia directa del código. Cero suposiciones.

---

## 1. TIPO DE PROYECTO

| Propiedad | Valor |
|---|---|
| Tipo | Sitio estático — HTML/CSS/JS vanilla |
| Propósito | Vitrina de productos Amazon con links de afiliado |
| Framework JS | Ninguno |
| Framework CSS | Tailwind CSS v3 (CDN runtime) |
| Build system | Ninguno — sin `package.json` |
| Package manager | Ninguno |
| Test runner | Ninguno — 0% coverage |
| CI/CD | GitHub Pages (deploy automático en push a main) |
| Total archivos | 11 (excluyendo .git) |
| Líneas totales | ~2,700 (HTML + JS + CSS + JSON) |

---

## 2. MAPA DE DIRECTORIOS

```
Titoh90.github.io/
│
├── index.html                    ← Landing "Coming Soon" — identidad: "Alexander Aether"
├── README.md                     ← 2 líneas vacías
│
└── hub/
    ├── index.html                ← ★ APLICACIÓN PRINCIPAL (1,257 líneas)
    │                               Contiene: HTML + datos embebidos + script inline
    │
    ├── products.json             ← ⚠️ HUÉRFANO — generado 2026-05-28, nunca cargado
    │
    ├── assets/
    │   ├── app.js                ← ⚠️ HUÉRFANO CRÍTICO — 929 líneas, NUNCA cargado por HTML
    │   └── styles.css            ← Estilos custom (59 líneas) — SÍ cargado
    │
    ├── data/
    │   ├── products.json         ← ⚠️ HUÉRFANO — generado 2026-06-02, nunca referenciado
    │   └── collections.json      ← ✅ Cargado vía fetch() al iniciar — 5 colecciones
    │
    └── i18n/
        ├── en.json               ← ⚠️ HUÉRFANO — 28 claves, nunca cargado
        ├── es.json               ← ⚠️ HUÉRFANO — 28 claves, nunca cargado
        └── fr.json               ← ⚠️ HUÉRFANO — 28 claves, nunca cargado
```

### HALLAZGO CRÍTICO #1: app.js es un archivo fantasma

`hub/index.html` NO contiene `<script src="assets/app.js">` en ninguna línea.  
El código JS vivo es el `<script>` inline en hub/index.html (líneas 327–1255).  
`app.js` es una copia desincronizada que NO controla la aplicación.

### HALLAZGO CRÍTICO #2: Los archivos i18n son fantasmas

La app lee traducciones del `<script id="translations-data">` embebido en el HTML.  
Los archivos `hub/i18n/*.json` nunca se cargan. Sus valores DIFIEREN de los embebidos.  
Ejemplo: `en.json` tiene `"buyOnAmazon": "Buy on Amazon"`, el live tiene `"View Deal"`.

---

## 3. FUENTES DE DATOS — MAPA COMPLETO

| Fuente | Generado | ¿Cargado? | Productos | Categorías |
|---|---|---|---|---|
| `<script id="products-data">` en hub/index.html | 2026-06-05 | ✅ SÍ (inline) | 25 | 5 (incl. "health & fitness") |
| `hub/data/products.json` | 2026-06-02 | ❌ NO | ~20 | 4 (sin "health & fitness") |
| `hub/products.json` | 2026-05-28 | ❌ NO | Desconocido | 4 (diferentes nombres) |
| `hub/data/collections.json` | N/A | ✅ SÍ (fetch async) | 5 colecciones | N/A |

### Versiones divergentes en product schema:
- `hub/products.json` usa categorías `"Beauty & Personal Care"`, `"Home & Kitchen"` 
- `hub/data/products.json` usa `"beauty"`, `"home"` 
- Embedded usa `"beauty"`, `"home"`, `"health & fitness"` (nuevo)

---

## 4. DEPENDENCIAS EXTERNAS (CDN — todas sin lock de versión)

```
hub/index.html
├── fonts.googleapis.com/css2?family=Inter           → Fuente tipográfica
├── fonts.googleapis.com/css2?family=Material+Symbols → Iconos
├── fonts.gstatic.com                                 → Assets de fuentes (preconnect)
├── cdn.tailwindcss.com                               → Tailwind CSS v3 (runtime sin build)
└── m.media-amazon.com                                → Imágenes de productos (preconnect)
```

**Riesgo**: Ninguna dependencia tiene versión fija. Un cambio en cdn.tailwindcss.com puede romper el layout sin aviso.

---

## 5. PUNTOS DE ENTRADA

| URL | Archivo | Descripción |
|---|---|---|
| `titoh90.github.io/` | `index.html` | Página "Coming Soon" — identidad "Alexander Aether" |
| `titoh90.github.io/hub/` | `hub/index.html` | Aplicación Aether Global activa |

Las dos páginas tienen **marcas diferentes** entre sí: "Alexander Aether" vs "Aether Global".

---

## 6. CATÁLOGO COMPLETO DE FUNCIONES

### App Object — API Pública (`window.App`)

| Función | Línea (hub/index.html) | Tipo | Descripción |
|---|---|---|---|
| `App.t(key)` | 354 | Pure Logic | Lookup de traducción con fallback en cascada |
| `App.openProduct(id)` | 360 | State + DOM | Abre panel de detalle de producto |
| `App.closeProduct()` | 373 | State + DOM | Cierra panel de detalle |
| `App.reset()` | 382 | State + DOM | Resetea todo el estado a valores iniciales |
| `App.setLang(lang)` | 400 | State + DOM | Cambia idioma activo y persiste |
| `App.clearSearch()` | 410 | State + DOM | Limpia búsqueda activa |
| `App.filterCategory(cat)` | 421 | State | Filtra productos por categoría |
| `App.setSort(val)` | 426 | State + DOM | Cambia criterio de ordenamiento |
| `App.navShop()` | 433 | State + DOM | Activa vista "Shop" |
| `App.navTrends()` | 442 | State + DOM | Activa vista "Trends" |
| `App.navSaved()` | 451 | State + DOM | Activa vista "Saved" (STUB sin funcionalidad) |
| `App.getFilteredProducts()` | 457 → patched 1224 | Pure Logic | Retorna productos filtrados y ordenados |
| `App.render()` | 507 → patched 1235 | DOM Orchestration | Re-renderiza toda la interfaz |
| `App.showCollection(id)` | 1203 | State + DOM | Activa filtro de colección editorial |
| `App.clearCollection()` | 1245 | State | Limpia filtro de colección |

### Funciones Privadas (inaccesibles desde fuera del IIFE)

| Función | Línea | Tipo | Descripción |
|---|---|---|---|
| `_detectLang()` | 1071 | Pure Logic | Detecta idioma: localStorage → navigator → 'en' |
| `_saveLang(lang)` | 1080 | Side Effect | Persiste idioma en localStorage |
| `_updateNavUI(active)` | 518 | DOM | Actualiza clases CSS de botones de nav |
| `_updateI18nText()` | 532 | DOM | Actualiza ~18 elementos de texto traducibles |
| `_renderCategories()` | 594 | DOM | Renderiza chips de filtro (mobile) |
| `_renderSidebarCategories()` | 616 | DOM | Renderiza sidebar de categorías (desktop) |
| `_renderSidebarSort()` | 645 | DOM | Renderiza sidebar de sort (desktop) |
| `_renderProducts()` | 674 | DOM | Orquesta grid de productos |
| `_renderCard(p, idx)` | 703 | DOM | Genera HTML string de tarjeta |
| `_renderDetail(p)` | 774 | DOM | Renderiza panel de detalle completo |
| `_deriveSpecs(p)` | 905 | Pure Logic | Genera specs ficticias por categoría/tags |
| `_setupLazyImages()` | 936 | DOM + Browser API | Configura IntersectionObserver |
| `_setupSearch()` | 969 | DOM + Events | Registra listeners de búsqueda |
| `_setupSort()` | 1036 | DOM + Events | Registra listener de sort select |
| `_setupLang()` | 1049 | DOM + Events | Registra listeners de cambio de idioma |
| `_setupBrandLink()` | 1086 | DOM + Events | Registra listeners del logo |
| `_loadCollections()` | 1154 | Async/Fetch | Carga colecciones.json |
| `_renderCollections()` | 1164 | DOM | Renderiza strip de colecciones |
| `_escHtml(s)` | 1105 | Security/Utility | Escapa caracteres HTML |
| `_escAttr(s)` | 1113 | Security/Utility | Escapa atributos HTML |

---

## 7. SECUENCIA DE INICIALIZACIÓN

```
Carga del script (inline, síncronamente)
│
├── [L340-343] Parse products-data JSON  →  PRODUCTS[], CATEGORIES[]
├── [L341]     Parse translations-data JSON  →  I18N{}
├── [L349]     App.lang = _detectLang()  →  lee localStorage → navigator → 'en'
└── App state inicializado: { lang, category:'all', query:'', sort:'default', activeNav:'shop' }

DOMContentLoaded event
│
├── Actualiza #lang-display, #lang-display-desktop
├── _setupSearch()   → registra 5 event listeners
├── _setupSort()     → registra 1 event listener
├── _setupLang()     → registra 2 event listeners
├── _setupBrandLink() → registra 2 event listeners
├── window.popstate listener
├── _loadCollections() ──→ [ASYNC] fetch('data/collections.json')
│                              └─→ _renderCollections() cuando completa
└── App.render()  [SÍNCRONO — primera renderización]
    ├── _updateI18nText()
    ├── _renderCategories()
    ├── _renderSidebarCategories()
    ├── _renderSidebarSort()
    └── _renderProducts()
        ├── App.getFilteredProducts()
        └── _setupLazyImages()
```

---

## 8. CAPA DE PERSISTENCIA

| Storage | Clave | Valor | Escrito por | Leído por |
|---|---|---|---|---|
| `localStorage` | `aether_lang` | `'en'|'es'|'fr'` | `_saveLang()` | `_detectLang()` |

No hay cookies, sessionStorage, ni IndexedDB. La única persistencia es el idioma.

---

## 9. ARQUITECTURA DUAL MOBILE/DESKTOP

La app tiene implementaciones paralelas para mobile y desktop, siempre renderizadas, visibilidad controlada por Tailwind:

| Elemento | Mobile ID | Desktop ID | Control CSS |
|---|---|---|---|
| Search input | `#search-input` | `#search-input-desktop` | `md:hidden` / `hidden md:flex` |
| Lang button | `#lang-cycle` | `#lang-cycle-desktop` | ídem |
| Lang display | `#lang-display` | `#lang-display-desktop` | ídem |
| Brand link | `#brand-link` | `#brand-link-desktop` | ídem |
| Category filter | Filter chips bar | Sidebar `#sidebar-categories` | `lg:hidden` / `hidden lg:block` |
| Sort control | `#sort-select` | `#sidebar-sort` | ídem |
| Nav | Bottom nav (fixed) | Header nav | ídem |

---

## 10. ARCHIVO QUE CONTROLA CADA FUNCIÓN

| Función del sistema | Controlado por |
|---|---|
| Layout y estructura HTML | hub/index.html |
| Lógica de negocio (filtros, sort, búsqueda) | hub/index.html (inline script, líneas 457-605) |
| Datos de productos (fuente de verdad) | hub/index.html (`<script id="products-data">`) |
| Traducciones activas (fuente de verdad) | hub/index.html (`<script id="translations-data">`) |
| Renderizado de UI | hub/index.html (inline script, líneas 518-903) |
| Seguridad / escape XSS | hub/index.html (líneas 1105-1120) |
| Lazy loading de imágenes | hub/index.html (líneas 936-965) |
| Colecciones editoriales | hub/data/collections.json + hub/index.html (líneas 1150-1254) |
| Estilos custom | hub/assets/styles.css |
| Estilos framework | cdn.tailwindcss.com (CDN) |
| Landing page | index.html (raíz) |

---

## RESUMEN EJECUTIVO DEL MAPA

El sistema es una **SPA estática vanilla** con toda la lógica concentrada en un único archivo HTML de 1,257 líneas. Existen 6 archivos que forman parte del repositorio pero **nunca son cargados** por la aplicación en producción: `app.js`, `hub/products.json`, `hub/data/products.json`, `hub/i18n/en.json`, `hub/i18n/es.json`, `hub/i18n/fr.json`. Esto crea una falsa sensación de modularidad y tres fuentes de verdad divergentes para los datos de productos.
