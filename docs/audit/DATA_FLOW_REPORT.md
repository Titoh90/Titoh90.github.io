# DATA FLOW REPORT — Aether Global
**Fecha**: 2026-06-07  
**Modo**: Read-Only Forensic Investigation

---

## FLUJO 1: PRODUCTOS — De origen a pantalla

### ¿De dónde salen los productos?

Los productos viven embebidos directamente en `hub/index.html` como JSON dentro de un `<script>` tag:

```html
<!-- hub/index.html, línea 325 -->
<script id="products-data" type="application/json">
  { "generated_at": "2026-06-05T15:34:35.960192+00:00",
    "categories": ["beauty","electronics","fashion","health & fitness","home"],
    "products": [ ... 25 productos ... ] }
</script>
```

Este JSON es parseado síncronamente al cargar el script (ANTES de DOMContentLoaded):

```javascript
// hub/index.html, líneas 340-343
var DATA       = JSON.parse(document.getElementById('products-data').textContent);
var I18N       = JSON.parse(document.getElementById('translations-data').textContent);
var PRODUCTS   = DATA.products   || [];
var CATEGORIES = DATA.categories || [];
```

**PRODUCTS y CATEGORIES son variables globales inmutables dentro del IIFE.**  
Una vez parseados, nunca se actualizan durante la sesión.

### Estructura de un producto (schema activo)

```javascript
{
  "id":             "B0BDHWDR12",          // Amazon ASIN o ID custom
  "title":          "Apple AirPods Pro",
  "price":          199.99,                // float, puede ser null
  "image":          "https://...",         // URL principal
  "imageUrls":      ["...", "..."],        // Array para carrusel
  "rating":         4.8,                   // float 0-5
  "reviews":        89432,                 // integer
  "category":       "electronics",        // lowercase string
  "affiliateUrl":   "https://amazon.com/dp/B0BDHWDR12/?tag=aetherglobal-20",
  "description":    "Electronics",        // string simple (legacy)
  "descriptionI18n": {                     // objeto i18n (activo)
    "en": "...",
    "es": "...",
    "fr": "..."
  },
  "tags":           ["trending"],          // Array: "trending", "bestseller", "limited"
  "section":        "hero"                 // "hero","trending","evergreen","recent"
}
```

**ANOMALÍA**: 2 productos (`cb_alpilean`, `cb_leanbiome`) tienen IDs que no son ASINs de Amazon, imágenes con URLs falsas (`/images/P/cb_alpilean.01._SL1500_.jpg` — no existe), y `affiliateUrl` apuntando a dominios externos (alpilean.com, leanbiome.com con `?hop=aethervnt`, que es el formato de ClickBank, no Amazon Associates).

---

## FLUJO 2: FILTRADO DE PRODUCTOS

### Cadena de transformación

```
PRODUCTS[]  (array global, 25 items, inmutable)
    │
    ├── [Paso 1] Copia defensiva: prods = PRODUCTS.slice()
    │
    ├── [Paso 2] Filtro por activeNav (si 'trends'):
    │   prods = prods.filter(p => p.tags.includes('trending'))
    │
    ├── [Paso 3] Filtro por categoría (si ≠ 'all'):
    │   prods = prods.filter(p => p.category === App.category)
    │   ⚠️ BUG LATENTE: Usa App.category (referencia global), no this.category
    │
    ├── [Paso 4] Filtro por búsqueda (si query ≠ ''):
    │   prods = prods.filter(p =>
    │     p.title.includes(q) ||
    │     p.category.includes(q) ||
    │     p.description[App.lang].includes(q)   // ← busca en description, no descriptionI18n
    │   )
    │   ⚠️ BUG: description es un string simple ("Electronics"), no el objeto i18n
    │   ⚠️ BUG LATENTE: Usa App.lang (referencia global), no this.lang
    │
    ├── [Paso 5] Ordenamiento según App.sort:
    │   'default'    → sin cambio (orden original del JSON)
    │   'trending'   → tags.trending primero (sort no estable)
    │   'bestseller' → tags.bestseller primero (sort no estable)
    │   'rating'     → b.rating - a.rating (descendente)
    │   'price-low'  → a.price - b.price (ascendente)
    │   'price-high' → b.price - a.price (descendente)
    │   ⚠️ NOTA: p.price puede ser null/undefined. El || 0 protege el sort.
    │
    └── prods[]  (resultado filtrado y ordenado)

    ===  INTERCEPCIÓN DE COLECCIÓN  ===
    Si App._collectionFilter != null (monkey-patch, línea 1224):
        prods = PRODUCTS.filter(p => collectionAsins.includes(p.id))
        [Pasos 2-5 son IGNORADOS cuando hay colección activa]
```

### Bugs en el flujo de filtrado

| # | Línea | Bug | Severidad |
|---|---|---|---|
| 1 | 476 | Busca en `p.description` (string "Electronics") no en `p.descriptionI18n` | MEDIUM — búsqueda no localizada |
| 2 | 468 | `p.category === App.category` usa `App.category` (global) dentro de closure | LOW — funciona pero es frágil |
| 3 | 1227 | Colección filtra por `p.id` pero collections.json usa `.asin` — son el mismo valor en datos actuales, pero el schema no lo garantiza | MEDIUM — inconsistencia silenciosa |

---

## FLUJO 3: RENDERIZADO DE PRODUCTOS

```
App.getFilteredProducts()  →  prods[]
    │
    └── _renderProducts() [hub/index.html:674]
        │
        ├── Actualiza #products-count texto
        ├── Si 0 resultados: muestra #no-results, return
        │
        └── Para cada producto: _renderCard(p, idx)
            │
            ├── Construye HTML string (no template engine)
            │   ├── _escAttr(p.affiliateUrl)  → url segura
            │   ├── _escHtml(p.title)         → título seguro
            │   ├── _escHtml(p.category)      → categoría segura
            │   ├── p.price.toFixed(2)        → precio formateado
            │   ├── _escAttr(p.image)         → src de imagen seguro
            │   ├── Badge (trending/bestseller/limited) → i18n lookup
            │   └── Star rating HTML (loop 0-4)
            │
            └── retorna HTML string

        └── grid.innerHTML = html (batch DOM update)
            └── _setupLazyImages() → IntersectionObserver para todas .card-img
```

### Flujo de imagen lazy

```
Render → <img data-src="URL" class="card-img"> (sin src inicial)
    │
    └── IntersectionObserver (rootMargin: 300px)
        └── Cuando entra en viewport:
            ├── img.src = img.getAttribute('data-src')
            └── img.classList.add('loaded')  → opacity 0→1 (CSS transition)
```

**Nota**: Si IntersectionObserver no está disponible (IE11), se cargan todas las imágenes inmediatamente como fallback.

---

## FLUJO 4: TRADUCCIONES (i18n)

### Origen

Las traducciones viven embebidas en hub/index.html:

```html
<script id="translations-data" type="application/json">
  { "en": {...28 claves...}, "es": {...29 claves...}, "fr": {...29 claves...} }
</script>
```

### Lookup

```javascript
App.t(key)  →  I18N[App.lang][key]  
               || I18N['en'][key]   // fallback a inglés
               || key               // fallback al key literal
```

### Detección de idioma

```
_detectLang()
    │
    ├── 1. localStorage.getItem('aether_lang')
    │   └── Si existe Y está en I18N → usar ese idioma
    │
    ├── 2. navigator.language || navigator.userLanguage
    │   └── Parsear: 'es-MX' → 'es', 'fr-FR' → 'fr'
    │   └── Si está en I18N → usar ese idioma
    │
    └── 3. Fallback: 'en'
```

### Persistencia

```
App.setLang(lang)
    ├── App.lang = lang
    ├── _saveLang(lang) → localStorage.setItem('aether_lang', lang)
    ├── Actualiza #lang-display y #lang-display-desktop
    └── App.render() → re-renderiza TODA la UI con el nuevo idioma
```

### BUG CRÍTICO: Typo en clave de traducción

La clave del hero badge es `herobage` en el código (línea 545):
```javascript
heroBadge.textContent = App.t('herobage') || 'CURATED EXCELLENCE';
```

Pero la clave en el JSON embebido es `herobadge` (con 'd') para EN:
```json
{"en": {"herobadge": "CURATED EXCELLENCE"}, "es": {"herobage": "EXCELENCIA CURADA"}}
```

**Resultado**: En inglés, `App.t('herobage')` retorna la key literal `'herobage'` → el `|| 'CURATED EXCELLENCE'` salva la situación. En ES y FR funciona (tienen ambas claves). El bug es latente y la corrección del JS rompería ES/FR si no se sincroniza el JSON.

---

## FLUJO 5: COLECCIONES EDITORIALES

### Carga (asíncrona, post-render)

```
DOMContentLoaded
    └── _loadCollections()
        └── fetch('data/collections.json')  [relativo — requiere server]
            ├── .then(r => r.ok ? r.json() : [])
            ├── .then(data => { COLLECTIONS = data; _renderCollections(); })
            └── .catch(() => {})  ← silencioso, colecciones son opcionales
```

**Problema**: Las colecciones se cargan DESPUÉS del render inicial. En conexiones lentas, el strip de colecciones aparece vacío y luego se llena — FOUC (Flash of Unstyled Content).

### Filtrado por colección

```
App.showCollection(collId)
    ├── Busca colección en COLLECTIONS[] por id
    ├── Extrae ASINs: (coll.products || []).map(p => p.asin)
    ├── App._collectionFilter = asins[]
    ├── Resetea category, query, sort
    └── App.render()
        └── App.getFilteredProducts() [patched]
            └── Si _collectionFilter:
                └── PRODUCTS.filter(p => asins.indexOf(p.id) !== -1)
                    ⚠️ Compara p.id (ASIN del product array) con p.asin (del collection)
                    ⚠️ 2 productos de gym_gear (B0CP9YB3Q4, B0DR9S2DQR) NO están
                       en el PRODUCTS array → aparecen 0 productos para esos ASINs
```

### Inconsistencia de datos: Colección gym_gear

| ASIN en colección | En PRODUCTS? | Resultado |
|---|---|---|
| B0CP9YB3Q4 (Stanley Quencher) | ❌ NO | Silenciosamente omitido |
| B0DR9S2DQR (Stanley ProTour) | ❌ NO | Silenciosamente omitido |
| B085DTZQNZ (Owala 24oz) | ✅ SÍ | Mostrado |
| B0BZYCJK89 (Owala 40oz) | ✅ SÍ | Mostrado |
| B0D6C6GS58 (HydroJug) | ✅ SÍ | Mostrado |
| B0D9KM5SFR (Nike Pegasus) | ✅ SÍ | Mostrado |
| B087FD9DSV (Adidas Ultraboost) | ✅ SÍ | Mostrado |
| B06XW16QMS (Oakley Holbrook) | ✅ SÍ | Mostrado |

La colección promete 8 productos pero muestra 6 en silencio.

---

## FLUJO 6: BÚSQUEDA

```
Usuario escribe en #search-input o #search-input-desktop
    │
    ├── onInput event
    │   ├── Muestra/oculta #search-clear button
    │   ├── clearTimeout(debounce)
    │   └── setTimeout(fn, 220ms)  ← debounce
    │       └── App.query = input.value.trim()
    │           └── App.render()
    │
    └── onKeydown(Escape)
        ├── Oculta search bar (mobile)
        ├── Limpia input
        └── App.clearSearch()
```

**Sincronización desktop→mobile**: El input desktop sincroniza el valor al input mobile (`if (input) input.value = inputD.value`). La dirección inversa NO está implementada — si el usuario escribe en mobile y cambia a desktop, el input desktop estará vacío aunque `App.query` tenga valor.

---

## FLUJO 7: ACTUALIZACIÓN Y ELIMINACIÓN DE DATOS

### ¿Cómo se actualizan los productos?

**No hay mecanismo runtime de actualización.** Los datos son estáticos y están hardcodeados en el HTML. Para actualizar productos se debe:
1. Regenerar el JSON embebido en `products-data`
2. Hacer push al repositorio
3. GitHub Pages redeploya

### ¿Cómo se eliminan productos?

No existe funcionalidad de eliminación. Los productos son inmutables durante la sesión.

### Proceso inferido de actualización (basado en evidencia):

El campo `"generated_at": "2026-06-05T15:34:35.960192+00:00"` sugiere un script externo que genera el JSON y lo embebe en el HTML. Los archivos `hub/products.json` y `hub/data/products.json` son artifacts de generaciones anteriores con timestamps más viejos (2026-05-28 y 2026-06-02 respectivamente).

---

## FLUJO 8: PANEL DE DETALLE DE PRODUCTO

```
Usuario hace click en imagen o título de producto
    │
    └── App.openProduct(id)
        ├── Busca producto en PRODUCTS[] por id
        ├── _renderDetail(p)
        │   ├── Setea src de #detail-image (carga inmediata, no lazy)
        │   ├── Renderiza carrusel (si imageUrls.length > 1)
        │   ├── Setea título, rating, precio, descripción
        │   ├── Setea href del botón de compra
        │   ├── _deriveSpecs(p) → genera specs ficticias
        │   └── Renderiza productos relacionados (mismo category, max 6)
        │       └── Si 0 relacionados: muestra cualquier otro producto
        ├── panel.classList.remove('hidden')
        ├── document.body.style.overflow = 'hidden'
        └── history.pushState({detailId: id}, '', '#p=' + id)

Usuario presiona "Atrás" o botón de cerrar
    │
    └── App.closeProduct() / window.popstate
        ├── panel.classList.add('hidden')
        ├── document.body.style.overflow = ''
        └── history.back() (si fue pushState, no si fue popstate)
```

**Nota**: Si el usuario navega directamente a `hub/#p=B0BDHWDR12`, el panel NO se abrirá automáticamente. No hay código que lea el hash URL al inicializar.
