# TESTABILITY REPORT — Aether Global
**Fecha**: 2026-06-07  
**Modo**: Read-Only Forensic Investigation (NO se crean tests)

---

## BARRERAS ESTRUCTURALES AL TESTING

Antes de analizar función por función, estas son las barreras arquitecturales que afectan a TODO el codebase:

### Barrera 1: IIFE con funciones privadas
```javascript
(function(){
  // _escHtml, _detectLang, _deriveSpecs, etc.
  // Todas inaccesibles desde fuera
  window.App = App;  // Solo App es exportado
})();
```
Ninguna función privada puede ser importada directamente en un test. Solo se puede testear `window.App.*`.

### Barrera 2: DOM coupling al momento de carga del módulo
```javascript
// Estas líneas ejecutan SINCRÓNICAMENTE al cargar el script:
var DATA     = JSON.parse(document.getElementById('products-data').textContent);
var I18N     = JSON.parse(document.getElementById('translations-data').textContent);
```
El script FALLA con TypeError si los elementos del DOM no existen. Cualquier test que importe este archivo necesita primero crear un DOM completo con esos `<script>` tags populados.

### Barrera 3: `_detectLang()` llamado antes de exportar App
```javascript
var App = {
  lang: _detectLang(),  // Se ejecuta al definir el objeto, antes de cualquier test setup
```
`_detectLang()` lee `localStorage` en el momento que se carga el script. Sin mock de localStorage, el idioma detectado puede variar según el entorno.

### Barrera 4: Código duplicado en dos archivos
El mismo código existe en `hub/assets/app.js` (archivo huérfano) y como inline script en `hub/index.html`. No hay un módulo JS importable limpio.

---

## CLASIFICACIÓN DE TESTABILIDAD

### FÁCIL — Testeable como función pura, sin DOM ni mocks

#### `_escHtml(s)` (línea 1105)
```
Tipo: Pure function
Inputs: cualquier valor (string, number, null, undefined)
Output: string HTML-escaped
Dependencias: ninguna
Mock necesario: ninguno
Acceso: ❌ privada (dentro de IIFE)
Refactoring necesario: extraer a módulo exportable
```
**Caso de test paradigmático**:
```
'<script>' → '&lt;script&gt;'
'"hello"'  → '&quot;hello&quot;'
'a & b'    → 'a &amp; b'
null       → 'null' (via String(null))
```

---

#### `_escAttr(s)` (línea 1113)
```
Tipo: Pure function
Inputs: cualquier valor
Output: string safe para atributos HTML
Dependencias: ninguna
Mock necesario: ninguno
Acceso: ❌ privada
```

---

#### `_deriveSpecs(p)` (línea 905)
```
Tipo: Pure function
Inputs: objeto producto con {rating, reviews, category, tags}
Output: array de strings (máx 5)
Dependencias: ninguna
Mock necesario: ninguno
Acceso: ❌ privada
```
**Casos de test**:
```
{category:'electronics', rating:4.5, tags:['bestseller']}
  → 5 specs incluyendo "Compatible...", "Energy efficient", "Amazon Best Seller"
{category:'unknown', rating:3.0}
  → 2 specs: "Ships and sold by Amazon", "Eligible for Amazon Prime"
{category:'beauty', reviews:1000, tags:[]}
  → slice(0,5) de specs
```

---

#### `App.t(key)` (línea 354)
```
Tipo: Casi pura (lee de I18N global)
Inputs: string key
Output: string traducción o key literal
Dependencias: I18N (global), App.lang (estado)
Mock necesario: I18N debe estar populado (se puede hacer con JSDOM + products-data)
Acceso: ✅ público (window.App.t)
```

---

### MEDIA — Testeable con JSDOM y setup de DOM básico

#### `App.getFilteredProducts()` (línea 457 + 1224)
```
Tipo: Casi pura (lee de PRODUCTS global y App state)
Inputs: ninguno directo (lee App.activeNav, App.category, App.query, App.sort, App._collectionFilter)
Output: array de productos
Dependencias: PRODUCTS[] (global), App state
Mock necesario: DOM con products-data script + translations-data script
Acceso: ✅ público
```

Este es el test más valioso del sistema. Con JSDOM:
1. Crear HTML mínimo con `<script id="products-data">` y `<script id="translations-data">`
2. Cargar el script
3. Modificar `App.category`, `App.query`, `App.sort`
4. Llamar `App.getFilteredProducts()` y verificar resultados

**Casos críticos**:
```
App.query = 'sony' → retorna solo producto Sony
App.sort = 'price-high' → productos en orden descendente de precio
App.activeNav = 'trends' → solo productos con tag 'trending'
App._collectionFilter = ['B0BDHWDR12'] → solo AirPods
App.category = 'nonexistent' → retorna []
```

---

#### `_detectLang()` (línea 1071)
```
Tipo: Casi pura (lee localStorage y navigator)
Inputs: ninguno
Output: string de idioma
Dependencias: localStorage, navigator.language, I18N
Mock necesario: JSDOM + mock de localStorage + mock de navigator.language
Acceso: ❌ privada
```

---

#### `App.filterCategory(cat)` (línea 421)
```
Tipo: State setter puro
Test: Verificar que App.category cambia, verificar que render() fue llamado
Mock necesario: DOM completo para render()
Acceso: ✅ público
```

---

#### `App.setSort(val)` (línea 426)
```
Tipo: State setter + un DOM update
Test: Verificar App.sort, verificar DOM sort-select value
Mock necesario: DOM con #sort-select
Acceso: ✅ público
```

---

#### `App.clearSearch()` (línea 410)
```
Tipo: State + DOM
Test: Verificar App.query = '', verificar inputs limpios
Mock necesario: DOM con #search-input, #search-input-desktop, #search-clear
Acceso: ✅ público
```

---

### DIFÍCIL — Requiere DOM completo con todos los elementos

#### `App.render()` (línea 507 + patch 1235)
```
Requiere: DOM completo con ~25 IDs específicos
Problema: El patch de render está después del IIFE, hace que render() tenga
          comportamiento diferente al definido originalmente
Test value: ALTO — verifica el ciclo completo filter → UI
```

---

#### `App.reset()` (línea 382)
```
Problema: Toca App._collectionFilter de forma incompleta (bug de estado)
          Verifica 4 elementos DOM adicionales
Mock: DOM completo + estado de colección activa para probar el bug
```

---

#### `_renderCard(p, idx)` (línea 703)
```
Interesante: La función retorna un string — no requiere DOM para generarlo
             PERO verificar que el HTML generado es correcto require parsear HTML
Parcialmente testeable: se puede verificar que el string contiene los valores esperados
                        con .indexOf() sin JSDOM
```

---

#### `App.openProduct(id)` / `App.closeProduct()` (líneas 360/373)
```
Requiere: DOM completo con #detail-panel, history API mock
Problema: history.pushState / history.back tienen comportamiento específico de browser
```

---

### MUY DIFÍCIL — Imposible o impractical testar actualmente

#### `_renderDetail(p)` (línea 774)
```
Razón: 130 líneas con 12 mutaciones DOM, lógica mezclada con presentación
       El inline onclick del carrusel es código JS-in-HTML que no se puede testar
       independientemente
Refactoring necesario: Extraer _getRelatedProducts(), _getDescription()
```

---

#### `_setupSearch()` (línea 969)
```
Razón: Solo registra event listeners. Para testear se necesita:
       1. Disparar eventos artificiales (fireEvent)
       2. Esperar el debounce de 220ms (fake timers)
       3. Verificar que App.query se actualizó
       Requiere: jest.useFakeTimers() o similar
```

---

#### `_loadCollections()` (línea 1154)
```
Razón: fetch() real a URL relativa. En test necesitas:
       Mock del fetch global
       O un servidor HTTP local
       O MSW (Mock Service Worker)
```

---

#### `_setupLazyImages()` (línea 936)
```
Razón: IntersectionObserver no existe en Node.js/JSDOM
       Necesita mock de IntersectionObserver
       El comportamiento real solo puede verificarse en browser
```

---

## RANKING DE TESTABILIDAD

| Función | Nivel | Razón principal |
|---|---|---|
| `_escHtml` | **FÁCIL** | Pura, zero deps — solo necesita exportarse |
| `_escAttr` | **FÁCIL** | Pura, zero deps — solo necesita exportarse |
| `_deriveSpecs` | **FÁCIL** | Pura, zero deps — solo necesita exportarse |
| `App.t` | **FÁCIL** | Pura respecto a I18N, accesible vía window.App |
| `App.getFilteredProducts` | **MEDIA** | Necesita JSDOM + data setup, pero sin side effects |
| `_detectLang` | **MEDIA** | Necesita mock de localStorage y navigator |
| `App.filterCategory` | **MEDIA** | State change simple + render() |
| `App.setSort` | **MEDIA** | State + 1 DOM element |
| `App.showCollection` | **MEDIA** | Verifica _collectionFilter + bug de state |
| `App.clearCollection` | **MEDIA** | State change simple |
| `App.render` | **DIFÍCIL** | Requiere DOM completo (~25 elements) |
| `App.reset` | **DIFÍCIL** | DOM + bug de collectionFilter |
| `_renderCard` | **DIFÍCIL** | HTML string verification |
| `App.openProduct` | **DIFÍCIL** | DOM + history API |
| `_renderDetail` | **MUY DIFÍCIL** | 130 líneas, mixed concerns |
| `_setupSearch` | **MUY DIFÍCIL** | Fake timers + eventos |
| `_loadCollections` | **MUY DIFÍCIL** | fetch mock |
| `_setupLazyImages` | **MUY DIFÍCIL** | IntersectionObserver mock |

---

## PREREQUISITOS PARA EMPEZAR A TESTAR

1. **Crear `package.json`** con Vitest + JSDOM
2. **Extraer funciones puras** del IIFE a un módulo exportable (o crear un módulo utils separado)
3. **Crear fixture de datos** de test: un subset de productos y traducciones como JSON separado
4. **Mock básico de DOM**: HTML mínimo con `<script id="products-data">` y `<script id="translations-data">`

Con solo pasos 1-2-3 se puede alcanzar ~30% de cobertura de la lógica crítica de negocio.
