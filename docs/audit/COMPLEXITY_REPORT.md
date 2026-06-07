# COMPLEXITY REPORT — Aether Global
**Fecha**: 2026-06-07  
**Modo**: Read-Only Forensic Investigation

---

## METODOLOGÍA

Cada función fue evaluada en 5 dimensiones:

| Dimensión | Descripción |
|---|---|
| **Líneas** | Número de líneas de la función |
| **Ramas** | Número de if/else/switch/case/ternary |
| **Dependencias** | Variables externas al scope de la función |
| **Side Effects** | DOM mutations, localStorage, fetch, history |
| **Acoplamiento** | Número de otras funciones que llama |

**Complejidad Ciclomática estimada** = ramas + 1

---

## TOP 20 FUNCIONES POR COMPLEJIDAD

### #1 — `_renderDetail(p)` 
**Líneas**: 130 (774–903) | **Ramas**: 14 | **CC**: 15 | **Riesgo: ALTO**

```
Dependencias externas: App.lang, PRODUCTS[], _escHtml, _escAttr, _deriveSpecs, App.t
Side effects: Modifica 12 elementos DOM, asigna innerHTML
Acoplamiento: Llama a _deriveSpecs(), usa App.t()
```

**Por qué es compleja**: Es la función más larga y tiene más responsabilidades que cualquier otra. Maneja: imagen principal, carrusel multi-imagen, título, rating con stars, precio, descripción con fallback doble (`descriptionI18n` vs `description`), botón de compra, etiqueta "back", specs derivadas, y productos relacionados. Cada sección tiene su propia lógica condicional.

**Fragmentos de alta complejidad**:
- Líneas 834–840: Doble fallback de descripción (si descriptionI18n → usar lang, si description y es objeto → usar lang, si string → usar directo)
- Líneas 879–884: Lógica de related products (mismo category, si 0 → cualquier otro)
- Líneas 486–498: Loop de stars (duplicado del loop en _renderCard)

---

### #2 — `_renderCard(p, idx)`
**Líneas**: 67 (703–769) | **Ramas**: 8 | **CC**: 9 | **Riesgo: ALTO**

```
Dependencias externas: App.t, _escHtml, _escAttr
Side effects: Ninguno (retorna string) — ✅ relativamente pura
Acoplamiento: Llama a _escHtml, _escAttr, App.t
```

**Por qué es compleja**: Genera una cadena HTML de 25+ líneas con 4 condicionales (badge trending/bestseller/limited, precio presente/ausente, rating presente/ausente, loop de stars). La lógica de presentación y la lógica de datos están completamente entremezcladas en la concatenación de strings.

---

### #3 — `App.getFilteredProducts()` (original + patch)
**Líneas**: 49 (457–505) + 8 (1224–1231) = 57 | **Ramas**: 12 | **CC**: 13 | **Riesgo: CRÍTICO**

```
Dependencias externas: PRODUCTS[], App.activeNav, App.category, App.query, App.lang, App._collectionFilter
Side effects: Ninguno (función pura) — ✅
Acoplamiento: Ninguno
```

**Por qué es crítica**: Contiene toda la lógica de filtrado del negocio. El monkey-patch (línea 1224) añade una rama adicional que cortocircuita todo el flujo original. La separación en dos lugares hace difícil entender el comportamiento completo sin leer ambas secciones.

---

### #4 — `_updateI18nText()`
**Líneas**: 60 (532–591) | **Ramas**: 12 | **CC**: 13 | **Riesgo: MEDIO**

```
Dependencias externas: App.t, document.getElementById x 15
Side effects: Modifica textContent/placeholder de ~18 elementos DOM
Acoplamiento: App.t() x 15 llamadas
```

**Por qué es compleja**: Una función que hace 18 cosas distintas. No hay ramas de decisión — es complejidad accidental por acumulación de líneas. Cualquier cambio en el HTML (renombrar un ID) puede romper esta función sin errores visibles (solo silencia cuando el elemento no existe).

---

### #5 — `_setupSearch()`
**Líneas**: 64 (969–1032) | **Ramas**: 8 | **CC**: 9 | **Riesgo: MEDIO**

```
Dependencias externas: document.getElementById x 4, App.query, App.render, App.clearSearch
Side effects: Registra 5 event listeners, modifica classList
Acoplamiento: App.query, App.render(), App.clearSearch()
```

**Por qué es compleja**: Implementa 4 comportamientos (toggle search bar, debounced input, ESC key, clear button) multiplicados por 2 (mobile + desktop). Los closures capturan referencias a elementos DOM locales, creando dependencias no obvias.

---

### #6 — `_renderCollections()`
**Líneas**: 37 (1164–1200) | **Ramas**: 6 | **CC**: 7 | **Riesgo: MEDIO**

```
Dependencias externas: COLLECTIONS[], _escHtml, _escAttr
Side effects: Modifica innerHTML de #collections-scroll
Acoplamiento: _escHtml, _escAttr
```

**Por qué es notable**: Contiene una array de gradients hardcodeada (6 strings) que se cicla con `i % gradients.length`. El HTML generado incluye un onclick con `App.showCollection()` que toma el id de la colección.

---

### #7 — `App.reset()`
**Líneas**: 17 (382–398) | **Ramas**: 5 | **CC**: 6 | **Riesgo: MEDIO**

```
Dependencias externas: document.getElementById x 4, _updateNavUI, App.render, window.scrollTo
Side effects: Modifica 4 elementos DOM + window.scrollTo
Acoplamiento: _updateNavUI(), App.render()
```

**Bug**: No limpia `App._collectionFilter` — ver STATE_AUDIT.md.

---

### #8 — `_deriveSpecs(p)`
**Líneas**: 26 (905–930) | **Ramas**: 8 | **CC**: 9 | **Riesgo: BAJO**

```
Dependencias externas: Ninguna (función pura)
Side effects: Ninguno
Acoplamiento: Ninguno
```

**La más testeable de las complejas**. 5 ramas de categoría + 2 ramas de tags. Retorna array de strings. La única función compleja que es completamente pura e independiente del DOM.

---

### #9 — `_renderSidebarCategories()`
**Líneas**: 26 (616–640) | **Ramas**: 3 | **CC**: 4 | **Riesgo: BAJO**

```
Dependencias externas: CATEGORIES[], App.category, App.t, _escHtml, _escAttr
Side effects: Modifica innerHTML de #sidebar-categories
Acoplamiento: _escHtml, _escAttr, App.t
```

---

### #10 — `App.showCollection(collId)`
**Líneas**: 18 (1203–1220) | **Ramas**: 3 | **CC**: 4 | **Riesgo: MEDIO**

```
Dependencias externas: COLLECTIONS[], document.getElementById, window.scrollTo
Side effects: Modifica App.*, window.scrollTo
Acoplamiento: App.render()
```

**Bug**: No hay null-check para `document.getElementById('product-grid')` en línea 1219. Si el elemento no existe, `offsetTop` tira TypeError.

---

### #11 — `_renderSidebarSort()`
**Líneas**: 25 (645–669) | **Ramas**: 2 | **CC**: 3 | **Riesgo: BAJO**

---

### #12 — `App.setLang(lang)`
**Líneas**: 9 (400–408) | **Ramas**: 3 | **CC**: 4 | **Riesgo: BAJO**

---

### #13 — `App.openProduct(id)`
**Líneas**: 12 (360–371) | **Ramas**: 3 | **CC**: 4 | **Riesgo: BAJO**

---

### #14 — `App.render()` + patch
**Líneas**: 7 + 8 = 15 | **Ramas**: 3 | **CC**: 4 | **Riesgo: MEDIO**

El patch de render agrega complejidad invisible — no es obvio que `App.render()` haga más que las 6 líneas del método original.

---

### #15 — `_setupLang()`
**Líneas**: 20 (1049–1068) | **Ramas**: 2 | **CC**: 3 | **Riesgo: BAJO**

---

### #16 — `_detectLang()`
**Líneas**: 7 (1071–1077) | **Ramas**: 4 | **CC**: 5 | **Riesgo: BAJO**

Pura y testeable. 3 niveles de fallback con manejo de excepciones.

---

### #17 — `App.closeProduct()`
**Líneas**: 9 (373–381) | **Ramas**: 3 | **CC**: 4 | **Riesgo: BAJO**

---

### #18 — `App.clearSearch()`
**Líneas**: 10 (410–419) | **Ramas**: 3 | **CC**: 4 | **Riesgo: BAJO**

---

### #19 — `_setupLazyImages()`
**Líneas**: 30 (936–965) | **Ramas**: 3 | **CC**: 4 | **Riesgo: BAJO**

---

### #20 — `_renderProducts()`
**Líneas**: 27 (674–700) | **Ramas**: 3 | **CC**: 4 | **Riesgo: BAJO**

---

## RANKING RESUMIDO

| Rank | Función | CC | Líneas | Side Effects | Testeable sin DOM |
|---|---|---|---|---|---|
| 1 | `_renderDetail(p)` | 15 | 130 | 12 DOM | ❌ |
| 2 | `App.getFilteredProducts()` | 13 | 57 | 0 | ✅ |
| 3 | `_updateI18nText()` | 13 | 60 | 18 DOM | ❌ |
| 4 | `_renderCard(p, idx)` | 9 | 67 | 0 (string) | ✅ parcial |
| 5 | `_setupSearch()` | 9 | 64 | 5 listeners | ❌ |
| 6 | `_deriveSpecs(p)` | 9 | 26 | 0 | ✅ |
| 7 | `_renderCollections()` | 7 | 37 | 1 DOM | ❌ |
| 8 | `App.reset()` | 6 | 17 | 4 DOM | ❌ |
| 9 | `_detectLang()` | 5 | 7 | 0 | ✅ |
| 10 | `_renderSidebarCategories()` | 4 | 26 | 1 DOM | ❌ |

---

## DEUDA DE DUPLICACIÓN

**Star rating renderizado en 2 lugares diferentes**:
- `_renderCard()` — líneas 726–736
- `_renderDetail()` — líneas 812–820

Son casi idénticos (solo difieren en font-size: 14px vs 18px). Esta duplicación significa que un bug en la lógica de stars (e.g., cómo se calcula `fill`) debe corregirse en dos lugares.

**Búsqueda de texto con debounce implementada DOS veces**:
- Input mobile — líneas 986–993
- Input desktop — líneas 1015–1022

Son estructuralmente idénticos. Cualquier cambio en la lógica de búsqueda debe replicarse en ambos.
