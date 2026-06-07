# TECHNICAL DEBT REPORT — Aether Global
**Fecha**: 2026-06-07  
**Modo**: Read-Only Forensic Investigation

---

## CATEGORÍAS DE DEUDA

| Categoría | Código | Descripción |
|---|---|---|
| **Huérfano** | ORF | Archivo/código que no ejecuta |
| **Duplicación** | DUP | Código idéntico o casi idéntico en 2+ lugares |
| **Parche/Hack** | HACK | Solución improvisada sobre código existente |
| **Stub vacío** | STUB | Funcionalidad prometida pero no implementada |
| **Datos divergentes** | DATA | Múltiples fuentes de verdad inconsistentes |
| **Bug latente** | BUG | Código que funciona ahora pero fallará bajo condiciones específicas |
| **Dead code** | DEAD | Rama o variable que nunca se ejecuta |

---

## DEUDA 1: app.js es un archivo fantasma
**Categoría: ORF | Severidad: ALTA**

El archivo `hub/assets/app.js` (929 líneas) no es cargado por ningún HTML. La aplicación corre desde el script inline en `hub/index.html`. Este archivo parece haber sido el master original, del cual se hizo copy-paste al HTML.

**Evidencia**: No existe ningún `<script src="assets/app.js">` en hub/index.html ni en index.html.

**Consecuencia**: Cualquier desarrollador que modifique `app.js` creerá estar modificando la aplicación pero no cambiará nada. Es una trampa de mantenimiento que garantiza divergencia.

---

## DEUDA 2: Tres fuentes de datos de productos, tres versiones
**Categoría: DATA | Severidad: ALTA**

| Archivo | Fecha generación | Categorías | ¿Vivo? |
|---|---|---|---|
| Embedded en index.html | 2026-06-05 | 5 (incl. "health & fitness") | ✅ |
| hub/data/products.json | 2026-06-02 | 4 (sin "health & fitness") | ❌ |
| hub/products.json | 2026-05-28 | 4 (nombres diferentes: "Beauty & Personal Care") | ❌ |

Los dos archivos externos están desactualizados y tienen schemas divergentes. El proceso de actualización genera una nueva versión embebida pero no limpia los archivos anteriores.

---

## DEUDA 3: Archivos i18n externos con valores distintos a los embebidos
**Categoría: DATA | Severidad: ALTA**

| Clave | hub/i18n/en.json | Embedded translations-data |
|---|---|---|
| `buyOnAmazon` | "Buy on Amazon" | "View Deal" |
| `pageTitle` | ❌ no existe | "Curated Premium Deals" |
| `heroTitle` | "Curated Premium Deals" | ❌ no existe |
| `viewGrid` | "Grid" | ❌ no existe |
| `watchVideo` | "Watch Video" | ❌ no existe |

Los archivos i18n externos son reliquias de una versión anterior con un layout diferente (tenía vistas de grid/list y modales de video).

---

## DEUDA 4: Monkey-patching de getFilteredProducts y render
**Categoría: HACK | Severidad: MEDIA**

```javascript
// El patrón original (línea 457):
App.getFilteredProducts = function() { ... };

// Luego, más abajo (línea 1223-1231):
var _origGetFiltered = App.getFilteredProducts;
App.getFilteredProducts = function() {
  if (this._collectionFilter) { ... return filtered; }
  return _origGetFiltered.call(this);
};
```

Este patrón de wrapping fue claramente añadido después como feature creep. Las colecciones fueron una adición posterior que no se integró limpiamente en el flujo existente. El resultado es:
- `getFilteredProducts` tiene comportamiento en dos lugares del archivo
- La función "real" está 770 líneas antes del patch
- Sin leer ambas secciones, no se puede entender el comportamiento completo

El mismo patrón se aplica a `App.render()` (líneas 1234–1243).

---

## DEUDA 5: navSaved() es un stub sin funcionalidad
**Categoría: STUB | Severidad: MEDIA**

```javascript
App.navSaved = function() {
  this.activeNav = 'saved';
  _updateNavUI('saved');
  this.render();  // render() no tiene lógica para 'saved'
};
```

El botón "Saved" en el nav mobile está completamente implementado en UI pero no tiene lógica de negocio. Al hacer click, simplemente muestra todos los productos (no hay filtro de "guardados"). No hay localStorage de saved, no hay feature de favoritos, nada.

El usuario ve un tab "Saved" que funciona como "Shop All" — experiencia engañosa.

---

## DEUDA 6: "Daily Deals" nav apunta a navShop()
**Categoría: STUB | Severidad: MEDIA**

```html
<!-- hub/index.html, línea 47 -->
<button onclick="App.navShop()">
  <span id="desktop-nav-deals-label">Daily Deals</span>
</button>
```

El botón "Daily Deals" en el header desktop y en el footer (línea 206) llama `App.navShop()`. No existe `App.navDeals()`. "Daily Deals" es puramente cosmético.

---

## DEUDA 7: _collectionStory se asigna pero nunca se usa
**Categoría: DEAD | Severidad: BAJA**

```javascript
// Línea 1216 — asignado:
this._collectionStory = coll.editorial_story || '';
// Línea 1248 — limpiado:
this._collectionStory = null;
// NUNCA LEÍDO entre medias
```

`editorial_story` en collections.json contiene textos narrativos de hasta 300 palabras. Son contenido valioso para la experiencia del usuario que fue preparado para una feature que nunca se implementó.

---

## DEUDA 8: p.section en schema de productos nunca se usa
**Categoría: DEAD | Severidad: BAJA**

Cada producto tiene un campo `"section": "hero" | "trending" | "evergreen" | "recent"`. Este campo nunca es leído por ninguna función en el código. Probablemente fue diseñado para una arquitectura de homepage por secciones que no llegó a implementarse.

---

## DEUDA 9: social_angle en collections.json nunca se expone
**Categoría: DEAD | Severidad: BAJA (oportunidad de negocio perdida)**

```json
"social_angle": {
  "tiktok": "POV: your desk setup after deleting everything that doesn't spark joy",
  "instagram": "The edit. Nothing extra. Everything essential.",
  "pinterest": "Minimalist tech setup inspiration — clean desk, clear mind"
}
```

Este contenido editorial de alta calidad existe en el JSON pero no se muestra en ningún lugar de la UI. Fue preparado para una feature de compartir/copiar texto para redes sociales que no se implementó.

---

## DEUDA 10: Typo 'herobage' vs 'herobadge'
**Categoría: BUG latente | Severidad: MEDIA**

```javascript
// Línea 545 — código:
heroBadge.textContent = App.t('herobage') || 'CURATED EXCELLENCE';

// JSON embebido EN:
{"herobadge": "CURATED EXCELLENCE"}  // ← 'd' incluida
// JSON embebido ES:
{"herobage": "EXCELENCIA CURADA", "herobadge": "EXCELENCIA CURADA"}  // ← ambas claves
```

El bug es: en inglés el lookup `App.t('herobage')` falla (clave no existe) y cae al hardcoded `'CURATED EXCELLENCE'`. Si alguien "corrige" el código a `'herobadge'`, rompería ES y FR (que solo tienen `herobage`). Si alguien "corrige" el JSON a solo `herobage` en EN, el badge EN mostraría el texto. En el estado actual es una bomba de tiempo para quien no conozca la historia.

---

## DEUDA 11: Duplicación de star rating en 2 funciones
**Categoría: DUP | Severidad: MEDIA**

El loop de stars HTML es virtualmente idéntico en:
- `_renderCard()` (líneas 728–734): `font-size:14px`
- `_renderDetail()` (líneas 814–820): `font-size:18px`

Cualquier fix al cálculo de estrellas (e.g., usar `Math.floor` en lugar de `Math.round`) debe aplicarse en ambos lugares.

---

## DEUDA 12: Búsqueda con debounce implementada dos veces
**Categoría: DUP | Severidad: MEDIA**

Mobile (líneas 986–993):
```javascript
var debounce;
input.addEventListener('input', function() {
  clearTimeout(debounce);
  debounce = setTimeout(function() {
    App.query = input.value.trim();
    App.render();
  }, 220);
});
```

Desktop (líneas 1015–1022): estructura casi idéntica con `debounceD`.

El 220ms de debounce está hardcoded en ambos lugares. Si se cambia la lógica (e.g., añadir un mínimo de caracteres), debe cambiarse en dos lugares.

---

## DEUDA 13: Búsqueda en campo description erróneo
**Categoría: BUG | Severidad: MEDIA**

```javascript
// Línea 476:
|| ((p.description && (p.description[App.lang] || p.description['en'])) || '')
  .toLowerCase().indexOf(q) !== -1
```

`p.description` es el string simple `"Electronics"`, `"Beauty"`, etc. — NO el objeto i18n. El código intenta hacer `"Electronics"['es']` que retorna `undefined`. La búsqueda en descripción localizada nunca funciona en los datos actuales.

El campo correcto sería `p.descriptionI18n[App.lang]`.

---

## DEUDA 14: Collections con ASINs no en el product array
**Categoría: DATA | Severidad: ALTA**

Ver DATA_FLOW_REPORT.md para el análisis completo.

**gym_gear** lista 8 productos pero 2 ASINs (Stanley Quencher, Stanley ProTour) no existen en el product array. La colección muestra 6 de 8 en silencio.

**smart_home_upgrades** lista 6 productos pero 3 ASINs (B07D5DN269, B01M16WBW1, B0C3FTCYZL) no están en el product array.

---

## DEUDA 15: Nav URL hash no restaura estado
**Categoría: STUB | Severidad: BAJA**

```javascript
// Línea 370 — se pushea al historial:
history.pushState({detailId: id}, '', '#p=' + id);
```

Pero en DOMContentLoaded no hay código que lea `window.location.hash` y abra el panel correspondiente. Si el usuario llega a `hub/#p=B0BDHWDR12`, el panel no se abre — la URL hash es un artefacto sin funcionalidad de restauración.

---

## RESUMEN DE DEUDA POR IMPACTO

| # | Deuda | Tipo | Impacto |
|---|---|---|---|
| 1 | app.js huérfano | ORF | Trampa de mantenimiento |
| 2 | 3 versiones de productos | DATA | Confusión de fuente de verdad |
| 3 | i18n externos obsoletos | DATA | Confusión de fuente de verdad |
| 4 | Monkey-patch de funciones core | HACK | Complejidad cognitiva alta |
| 10 | Typo herobage/herobadge | BUG | Bomba de tiempo en i18n |
| 13 | Búsqueda en campo incorrecto | BUG | Feature rota silenciosamente |
| 14 | ASINs de colecciones no en products | DATA | Colecciones incompletas silenciosamente |
| 5 | navSaved stub | STUB | Experiencia de usuario engañosa |
| 6 | Daily Deals = navShop | STUB | Navegación sin sentido |
| 11 | Stars duplicadas | DUP | Bug dual maintenance |
| 12 | Búsqueda duplicada | DUP | Config dual maintenance |
| 7 | _collectionStory unused | DEAD | Memory waste, confusión |
| 8 | p.section unused | DEAD | Schema inflado |
| 9 | social_angle sin renderizar | DEAD | Oportunidad perdida |
| 15 | Hash URL sin restauración | STUB | URL sharing roto |
