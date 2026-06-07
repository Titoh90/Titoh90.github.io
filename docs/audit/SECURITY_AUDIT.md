# SECURITY AUDIT — Aether Global
**Fecha**: 2026-06-07  
**Modo**: Read-Only Forensic Investigation

---

## RESUMEN EJECUTIVO

El codebase implementa protecciones básicas de XSS para la mayoría de las rutas de datos. Sin embargo, existen varios vectores de riesgo que deben evaluarse cuidadosamente, incluyendo inconsistencias en la aplicación de las funciones de escape, datos no confiables en el producto array, y exposición innecesaria del estado de la aplicación.

**Nivel de riesgo global: MEDIUM**  
No se encontró evidencia de vulnerabilidades CRÍTICAS activas, pero hay varios hallazgos HIGH que deben corregirse.

---

## HALLAZGO 1: _escHtml — Implementación y Cobertura

**Severidad: INFORMATIONAL (implementación correcta)**

```javascript
// hub/index.html, líneas 1105-1111
function _escHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
```

**Análisis**:
- Escapa los 4 caracteres esenciales para HTML text nodes
- `String(s)` — coerce defensivo, protege contra null/undefined/numbers
- El orden importa: `&` primero, correcto — evita doble-escape

**Limitación**: No escapa `'` (comilla simple). Para innerHTML textual esto es correcto — las comillas simples no son peligrosas en texto HTML. Sin embargo, si este valor se usara dentro de un atributo delimitado por comillas simples, sería un vector. En la práctica, todos los atributos del código usan comillas dobles (`"`).

---

## HALLAZGO 2: _escAttr — Implementación y Cobertura

**Severidad: INFORMATIONAL (implementación correcta)**

```javascript
// hub/index.html, líneas 1113-1120
function _escAttr(s) {
  return String(s)
    .replace(/&/g,  '&amp;')
    .replace(/"/g,  '&quot;')
    .replace(/'/g,  '&#39;')
    .replace(/</g,  '&lt;')
    .replace(/>/g,  '&gt;');
}
```

**Análisis**: Escapa 5 caracteres incluyendo `'` — correcta para valores en atributos HTML. Cubre tanto atributos con `"` como con `'`.

---

## HALLAZGO 3: innerHTML con datos de productos

**Severidad: MEDIUM**

El código utiliza `innerHTML` para inyectar HTML generado a partir de datos de productos. Las funciones `_escHtml` y `_escAttr` se aplican correctamente en la mayoría de los puntos:

```javascript
// _renderCard — correctamente escapado:
var url   = _escAttr(p.affiliateUrl || '#');   // ✅
var title = _escHtml(p.title || '');           // ✅
var category = _escHtml(p.category || '');    // ✅
var imgSrc = _escAttr(p.image || '');         // ✅
var pid   = _escAttr(p.id || '');             // ✅
```

**Sin embargo, hay valores NO escapados:**

```javascript
// Línea 742 — animation-delay inyectado sin escape:
'style="animation-delay:' + delay + 's"'
// delay = (Math.min(idx, 10) * 0.04).toFixed(2)
// OK aquí: delay es computado puramente de idx (integer), no de datos externos
```

```javascript
// Línea 707 — price NO escapado:
var price = p.price ? '$' + p.price.toFixed(2) : '';
// Línea 761: '<div class="...">' + _escHtml(price) + '</div>'
// OK: price está escapado con _escHtml antes de insertar
```

```javascript
// _renderCollections, línea 1188:
'<p class="...">' + count + ' products</p>'
// count = c.product_count || 0
// count viene de collections.json (externo). Si un atacante modifica collections.json
// podría inyectar HTML aquí.
// ⚠️ count NO está escapado — aunque es un número en los datos actuales
```

```javascript
// _renderCollections, línea 1186:
'<div class="absolute inset-0 bg-gradient-to-br ' + grad + '"></div>'
// grad viene de array hardcoded gradients[] — NO de datos externos
// ✅ Seguro
```

---

## HALLAZGO 4: URL Injection / Affiliate URL

**Severidad: HIGH**

```javascript
// _renderCard, línea 761:
'<a href="' + url + '" target="_blank" rel="noopener noreferrer sponsored">'
// url = _escAttr(p.affiliateUrl || '#')
```

`_escAttr` escapa `"`, `'`, `<`, `>`, `&`. Esto previene romper el atributo HTML.

**PERO**: No previene URLs con el esquema `javascript:`:
```javascript
// Si p.affiliateUrl = 'javascript:alert(1)'
// _escAttr('javascript:alert(1)') = 'javascript:alert(1)'  ← sin cambios
// El href resultante sería: href="javascript:alert(1)"
// Al hacer click, ejecuta JavaScript
```

**Evidencia de riesgo real**: En los datos actuales, todas las `affiliateUrl` son `https://www.amazon.com/...` o `https://alpilean.com/...`. Sin embargo, los datos se generan externamente (hay un proceso de generación implícito). Si ese proceso importa datos de fuentes no confiables o es comprometido, un `affiliateUrl` malicioso podría inyectar JS.

**Severidad aumentada porque**: Hay 2 productos (`cb_alpilean`, `cb_leanbiome`) con URLs de dominios externos no-Amazon, lo que demuestra que los datos no son exclusivamente de Amazon. El dominio `alpilean.com` y `leanbiome.com` son externos y su control es incierto.

---

## HALLAZGO 5: innerHTML en el carousel (detail panel)

**Severidad: MEDIUM**

```javascript
// _renderDetail, líneas 791-797:
carousel.innerHTML = urls.map(function(u, i) {
  return '<img src="' + _escAttr(u) + '" alt="' + _escHtml(p.title || '') + ' ' + (i+1) + '" '
       + 'class="..." '
       + 'onclick="document.getElementById(\'detail-image\').src=this.src;'   // ⚠️
       + 'this.parentElement.querySelectorAll(\'img\').forEach(function(x){x.className=...});'
       + 'this.className=this.className.replace(...);">'
```

El atributo `onclick` inline contiene JavaScript que referencia `this.src`. Si `this.src` de una imagen fuera a un origen malicioso, el `src` se asignaría al `detail-image`. No es un vector de ejecución de código en sí mismo, pero es un patrón que hace el código difícil de inspeccionar.

---

## HALLAZGO 6: innerHTML para el collection header (patch render)

**Severidad: MEDIUM**

```javascript
// hub/index.html, líneas 1240-1241:
countEl.innerHTML = '<button onclick="App.clearCollection()" class="...">&larr; All</button> '
  + '<span class="font-semibold">' + _escHtml(this._collectionTitle || '') + '</span>';
```

`_collectionTitle` SÍ está escapado con `_escHtml`. ✅  
El `onclick` inline es hardcoded y no deriva de datos externos. ✅

---

## HALLAZGO 7: localStorage — Abuse Potential

**Severidad: LOW**

```javascript
// _detectLang, líneas 1073-1075:
var stored = localStorage.getItem('aether_lang');
if (stored && I18N[stored]) return stored;
```

**Análisis**: El valor leído de localStorage se valida contra `I18N[stored]` antes de usarse. Si un atacante pone `localStorage.aether_lang = '__proto__'`, el check `I18N['__proto__']` retornaría el prototype de Object, que es truthy. **El valor retornado sería `'__proto__'`** y se asignaría a `App.lang`.

Consecuencia: `App.t(key)` haría `I18N['__proto__'][key]`, que probablemente retorne `undefined`, cayendo al fallback de inglés. No es una vulnerabilidad de ejecución de código, pero puede producir comportamiento inesperado.

**Mitigación actual**: La validación `I18N[stored]` bloquea valores no reconocidos normalmente.

---

## HALLAZGO 8: Prototype Pollution via Object property access

**Severidad: LOW**

```javascript
// App.t(), líneas 354-358:
return (I18N[this.lang] && I18N[this.lang][key])
  || (I18N['en'] && I18N['en'][key])
  || key;
```

`I18N[this.lang]` es lookup por índice en un objeto parseado de JSON. Si `this.lang` fuera `'__proto__'` o `'constructor'`, podría acceder a propiedades del prototype. Combinado con el hallazgo #7, existe un vector teórico.

En la práctica, `this.lang` solo puede ser `'en'`, `'es'`, o `'fr'` porque el ciclo de idiomas está hardcoded a `_LANGS = ['en','es','fr']`.

---

## HALLAZGO 9: Productos con IDs no-Amazon y datos falsos

**Severidad: HIGH (riesgo de negocio y compliance)**

```javascript
// Productos activos con IDs custom:
{"id": "cb_alpilean",  "affiliateUrl": "https://alpilean.com/?hop=aethervnt"}
{"id": "cb_leanbiome", "affiliateUrl": "https://leanbiome.com/?hop=aethervnt"}
```

**Problemas**:

1. **Imágenes falsas**: Las URLs de imagen son `https://m.media-amazon.com/images/P/cb_alpilean.01._SL1500_.jpg` — este patrón de URL no existe en Amazon S3 (las imágenes reales tienen ASINs como prefijo). Las imágenes no cargarán (404).

2. **Links no-Amazon con parámetro ClickBank**: `?hop=aethervnt` es el formato de ClickBank, no de Amazon Associates. Mezclar Amazon Associates con ClickBank en el mismo sitio puede violar los TOS de Amazon Associates.

3. **Categoría "health & fitness" con suplementos**: Alpilean es un suplemento de pérdida de peso controversial. Leanbiome es similar. La FTC regula estrictamente las afirmaciones de salud en sitios de afiliados.

---

## HALLAZGO 10: Tailwind desde CDN sin Subresource Integrity

**Severidad: MEDIUM**

```html
<script src="https://cdn.tailwindcss.com"></script>
```

No hay atributo `integrity="sha384-..."`. Si el CDN de Tailwind es comprometido (supply chain attack), se ejecutará JavaScript arbitrario en contexto completo de la página, con acceso a `window.App`, localStorage, y todos los links de afiliado.

---

## HALLAZGO 11: Google Fonts sin Subresource Integrity

**Severidad: LOW**

Los tags de Google Fonts tampoco tienen SRI hashes. Google Fonts solo sirve CSS+fuentes (sin JS), por lo que el riesgo es principalmente de redireccionamiento de tráfico, no de ejecución de código.

---

## MAPA DE PUNTOS DE ENTRADA DE DATOS EXTERNOS

| Origen | Campo | Escapado? | Ruta de inyección |
|---|---|---|---|
| `products-data` JSON | `p.title` | ✅ `_escHtml` | _renderCard, _renderDetail |
| `products-data` JSON | `p.category` | ✅ `_escHtml` | _renderCard, _renderCategories |
| `products-data` JSON | `p.affiliateUrl` | ✅ `_escAttr` (pero no scheme-safe) | _renderCard href |
| `products-data` JSON | `p.image` | ✅ `_escAttr` | _renderCard data-src |
| `products-data` JSON | `p.id` | ✅ `_escAttr` | _renderCard onclick arg |
| `products-data` JSON | `p.price` | ✅ `.toFixed(2)` + `_escHtml` | _renderCard |
| `products-data` JSON | `p.descriptionI18n` | ✅ `textContent` (no innerHTML) | _renderDetail |
| `collections.json` | `c.title` | ✅ `_escHtml` | _renderCollections |
| `collections.json` | `c.theme` | ✅ `_escHtml` | _renderCollections |
| `collections.json` | `c.id` | ✅ `_escAttr` | _renderCollections onclick arg |
| `collections.json` | `c.hero_image` | ✅ `_escAttr` | _renderCollections img src |
| `collections.json` | `c.product_count` | ⚠️ **SIN ESCAPE** | _renderCollections (número esperado) |

---

## CLASIFICACIÓN FINAL

| # | Hallazgo | Severidad | Estado |
|---|---|---|---|
| 4 | URL injection via `javascript:` scheme en affiliateUrl | **HIGH** | Activo |
| 9 | Productos no-Amazon con datos falsos, riesgo de compliance | **HIGH** | Activo |
| 10 | CDN Tailwind sin SRI hash | **MEDIUM** | Activo |
| 3 | `c.product_count` no escapado en innerHTML | **MEDIUM** | Activo |
| 5 | inline onclick en carousel con JS complejo | **MEDIUM** | Activo |
| 7 | localStorage abuse con clave `__proto__` | **LOW** | Teórico |
| 8 | Prototype pollution via `I18N[lang]` | **LOW** | Teórico |
| 11 | Google Fonts sin SRI | **LOW** | Activo |
| 1 | `_escHtml` no escapa `'` | **INFORMATIONAL** | No aplica en contexto actual |
| 2 | `_escAttr` — cobertura completa | **INFORMATIONAL** | Correcto |
