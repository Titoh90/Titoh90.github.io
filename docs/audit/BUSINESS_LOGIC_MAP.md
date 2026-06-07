# BUSINESS LOGIC MAP — Aether Global
**Fecha**: 2026-06-07  
**Modo**: Read-Only Forensic Investigation

---

## DEFINICIÓN: ¿Qué es lógica de negocio aquí?

En un sitio de afiliados, la lógica de negocio es todo lo que determina:
- Qué productos se muestran
- En qué orden aparecen
- Cómo se categoriza y filtra
- Cómo se vincula a links de afiliado
- Qué se muestra en cada idioma
- Cómo se agrupa en colecciones

---

## BLOQUE 1: FILTRADO DE PRODUCTOS

**Clasificación: CRITICAL**  
**Archivo**: hub/index.html — líneas 457–506 (original) + 1224–1231 (patch)  
**Complejidad**: Alta — 4 ramas de filtro encadenadas

### Descripción
Determina exactamente qué productos ve el usuario. Si falla, el usuario ve productos incorrectos o ningún producto.

### Dependencias
- `PRODUCTS[]` — array global inmutable
- `App.activeNav` — estado de navegación
- `App.category` — categoría seleccionada
- `App.query` — término de búsqueda
- `App.sort` — criterio de ordenamiento
- `App._collectionFilter` — filtro de colección (null si inactivo)
- `App.lang` — idioma activo (para búsqueda en descripción)

### Implementación (evidencia)
```javascript
// Líneas 457-505
App.getFilteredProducts = function() {
  var prods = PRODUCTS.slice();                          // copia defensiva

  // Filtro 1: activeNav (trends muestra solo trending)
  if (this.activeNav === 'trends') {
    prods = prods.filter(p => p.tags && p.tags.indexOf('trending') !== -1);
  }

  // Filtro 2: categoría
  if (this.category !== 'all') {
    prods = prods.filter(p => p.category === App.category);  // ← App (global)
  }

  // Filtro 3: búsqueda de texto
  if (this.query) {
    var q = this.query.toLowerCase();
    prods = prods.filter(p =>
      (p.title    || '').toLowerCase().indexOf(q) !== -1 ||
      (p.category || '').toLowerCase().indexOf(q) !== -1 ||
      ((p.description && (p.description[App.lang] || p.description['en'])) || '')
        .toLowerCase().indexOf(q) !== -1  // ← busca en campo description (string), no descriptionI18n
    );
  }

  // Filtro 4: ordenamiento
  switch (this.sort) {
    case 'trending':   prods.sort(...);  break;
    case 'bestseller': prods.sort(...);  break;
    case 'rating':     prods.sort(...);  break;
    case 'price-low':  prods.sort(...);  break;
    case 'price-high': prods.sort(...);  break;
    // 'default': sin sort, mantiene orden del JSON
  }
  return prods;
};
```

### Bugs conocidos en esta lógica
1. La búsqueda de texto usa `p.description` (string "Electronics") no `p.descriptionI18n` — la búsqueda no es multilingüe real.
2. Cuando `_collectionFilter` está activo, todos los filtros anteriores son ignorados.

---

## BLOQUE 2: ORDENAMIENTO

**Clasificación: CRITICAL**  
**Archivo**: hub/index.html — líneas 480–505  
**Complejidad**: Media — switch con 5 casos

### Estrategias de ordenamiento

| Criterio | Implementación | Línea | Observación |
|---|---|---|---|
| `default` | Sin ordenamiento | — | Preserva orden del JSON |
| `trending` | tags.trending first | 482-485 | Sort binario 1/0. No estable entre iguales |
| `bestseller` | tags.bestseller first | 488-491 | Sort binario 1/0. No estable entre iguales |
| `rating` | b.rating - a.rating | 493 | Descendente. `|| 0` protege nulos |
| `price-low` | a.price - b.price | 496 | Ascendente. `|| 0` protege nulos |
| `price-high` | b.price - a.price | 499 | Descendente. `|| 0` protege nulos |

**Observación**: Los sorts `trending` y `bestseller` no son estables en todos los engines. En V8 moderno, los elementos con igual score mantienen su orden relativo.

---

## BLOQUE 3: SISTEMA DE TRADUCCIÓN (i18n)

**Clasificación: CRITICAL**  
**Archivo**: hub/index.html — líneas 340–341 (carga), 354–358 (lookup)  
**Complejidad**: Baja — lookup con fallback en cascada

### Cadena de fallback
```
I18N[lang][key]  →  I18N['en'][key]  →  key literal
```

### Idiomas soportados
- `en` (Inglés) — 28 claves
- `es` (Español) — 29 claves (tiene `herobage` extra)
- `fr` (Francés) — 29 claves (tiene `herobage` extra)

### Claves ausentes por idioma (evidencia directa)

| Clave | EN | ES | FR | Impacto si falta |
|---|---|---|---|---|
| `herobage` | ❌ usa `herobadge` | ✅ | ✅ | Hero badge muestra 'CURATED EXCELLENCE' (hardcoded) en EN |
| `pageTitle` | ✅ | ✅ | ✅ | — |
| `navShop` | ✅ | ✅ | ✅ | — |

### Nota sobre los archivos i18n externos
Los archivos `hub/i18n/*.json` tienen claves como `heroTitle`, `heroCTA`, `viewGrid`, `viewList`, `watchVideo`, `closePreview`, `watchOnAmazon` que **no existen en el JSON embebido ni en el código activo**. Son residuos de una versión anterior.

---

## BLOQUE 4: DETECCIÓN Y PERSISTENCIA DE IDIOMA

**Clasificación: CRITICAL**  
**Archivo**: hub/index.html — líneas 1071–1082  
**Complejidad**: Baja — 3 niveles de fallback

### Lógica
```
_detectLang():
  1. localStorage('aether_lang') → valida que esté en I18N
  2. navigator.language → parsea prefijo ('es-MX' → 'es') → valida en I18N
  3. Fallback: 'en'

_saveLang(lang):
  localStorage.setItem('aether_lang', lang)
```

**Manejo de errores**: Ambas funciones tienen try/catch alrededor de localStorage — protegen contra navegadores en modo privado con localStorage bloqueado.

---

## BLOQUE 5: CICLO DE IDIOMAS

**Clasificación: IMPORTANT**  
**Archivo**: hub/index.html — líneas 1049–1068  
**Complejidad**: Baja

### Lógica
```javascript
var _LANGS = ['en', 'es', 'fr'];
// Click en lang button:
var idx  = _LANGS.indexOf(App.lang);
var next = _LANGS[(idx + 1) % _LANGS.length];
App.setLang(next);
// Secuencia: en → es → fr → en → ...
```

**No hay selector explícito** — el usuario no puede elegir un idioma directamente, solo ciclar. Con 3 idiomas máximo 2 clics para llegar al deseado.

---

## BLOQUE 6: GENERACIÓN DE SPECS (Producto)

**Clasificación: IMPORTANT (con riesgo de veracidad)**  
**Archivo**: hub/index.html — líneas 905–930  
**Complejidad**: Media — 7 ramas condicionales

### Lógica
```javascript
_deriveSpecs(p):
  specs = []
  if rating >= 4.0  → "Rated X/5 by customers"
  if reviews > 0    → "X verified customer reviews"
  
  switch category:
    'electronics' → ["Compatible with major platforms", "Energy efficient design"]
    'beauty'      → ["Dermatologist tested formula", "Cruelty-free certified"]
    'fashion'     → ["Premium quality materials", "Available in multiple sizes"]
    'home'        → ["Durable construction", "Easy to clean"]
    'sports'/'fitness' → ["Designed for active lifestyles", "Sweat resistant"]
  
  if tags.includes('bestseller') → "Amazon Best Seller in its category"
  
  siempre añade:
    "Ships and sold by Amazon"
    "Eligible for Amazon Prime delivery"
  
  return specs.slice(0, 5)
```

### RIESGO DE NEGOCIO ALTO
Las specs son **ficticias y genéricas**. El texto "Dermatologist tested formula" y "Cruelty-free certified" se muestra para TODOS los productos de beauty sin verificación. Esto es potencialmente falsa publicidad si el producto real no tiene esas certificaciones.

De los 25 productos activos, la categoría 'sports' o 'fitness' no existe en el schema actual (existe 'health & fitness'). Los productos de esa categoría reciben las specs genéricas de Amazon pero NO las specs de fitness.

---

## BLOQUE 7: COLECCIONES EDITORIALES

**Clasificación: IMPORTANT**  
**Archivo**: hub/index.html — líneas 1154–1254 + hub/data/collections.json  
**Complejidad**: Media — carga asíncrona + monkey-patching

### Lógica de negocio
Las colecciones son curaciones editoriales con historia narrativa. Agrupan productos por tema lifestyle. Están diseñadas para contenido de redes sociales (TikTok, Instagram, Pinterest).

### Schema de colección (evidencia de collections.json)
```json
{
  "id": "minimalist_tech",
  "title": "Minimalist Tech Essentials",
  "theme": "Clean lines. Pure function...",
  "editorial_story": "...(texto largo para redes)...",
  "hero_product": "B0BDHWDR12",
  "products": [{"asin": "B0BDHWDR12", ...}],
  "product_count": 6,
  "social_angle": {
    "tiktok": "POV: your desk setup after...",
    "instagram": "The edit. Nothing extra.",
    "pinterest": "Minimalist tech setup..."
  }
}
```

**El `social_angle` no se renderiza en la UI actual.** Es datos de negocio no expuestos.

### 5 colecciones activas
| ID | Título | Productos en JSON | En PRODUCTS array |
|---|---|---|---|
| minimalist_tech | Minimalist Tech Essentials | 6 | 4/6 presentes |
| viral_beauty | Viral TikTok Beauty Finds | 3 | 3/3 presentes |
| luxury_desk_setup | Luxury Desk Setup | 5 | 4/5 presentes |
| gym_gear | Premium Gym Gear | 8 | 6/8 presentes |
| fashion_under_200 | Fashion Essentials Under $200 | 10 | 8/10 presentes |
| smart_home_upgrades | Smart Home Upgrades | 6 | 5/6 presentes (B07D5DN269, B01M16WBW1, B0C3FTCYZL ausentes) |

**Total**: Múltiples colecciones muestran menos productos de los prometidos silenciosamente.

---

## BLOQUE 8: BÚSQUEDA DE TEXTO

**Clasificación: IMPORTANT**  
**Archivo**: hub/index.html — líneas 471–478 (lógica), 969–1032 (setup)  
**Complejidad**: Media — debounce + 3 campos

### Campos buscados
1. `p.title` — título del producto
2. `p.category` — categoría (e.g. "electronics")
3. `p.description[lang] || p.description['en']` — PERO description es un string simple como "Electronics", no el objeto i18n

**Bug**: `p.description` en los productos activos es una string simple ("Electronics", "Beauty", "Home"), no un objeto. La lógica intenta hacer `p.description[App.lang]` sobre un string — en JS esto retorna `undefined` para keys que no sean índices numéricos, cayendo silenciosamente al `|| ''`.

**Efecto real**: La búsqueda solo encuentra resultados en `title` y `category`. La descripción no se busca aunque el código lo intente.

---

## BLOQUE 9: GESTIÓN DE BADGES / ETIQUETAS

**Clasificación: IMPORTANT**  
**Archivo**: hub/index.html — líneas 712–722 (_renderCard), 586–604 (_deriveSpecs)  
**Complejidad**: Baja

### Lógica de badge (priority: trending > bestseller > limited)
```javascript
if (tags.includes('trending'))   → badge "Trending" (primary color)
else if (tags.includes('bestseller')) → badge "Top Pick" (surface color)
else if (tags.includes('limited'))    → badge "Limited" (error/red color)
```

Solo se muestra UN badge por producto. La prioridad está hardcoded.

**Observación**: El tag `'limited'` existe en el código pero **ningún producto activo lo usa**. Es una rama inalcanzable en los datos actuales.

---

## BLOQUE 10: NAVEGACIÓN Y ESTADO DE VISTAS

**Clasificación: IMPORTANT**  
**Archivo**: hub/index.html — líneas 433–455  
**Complejidad**: Baja

### Vistas disponibles
| Vista | Función | Estado cambios | Renderiza |
|---|---|---|---|
| `shop` | `App.navShop()` | activeNav='shop', category='all', query='' | Todos los productos |
| `trends` | `App.navTrends()` | activeNav='trends', category='all', query='' | Solo trending |
| `saved` | `App.navSaved()` | activeNav='saved' | STUB — muestra todos (sin filtro saved) |

**Bug de negocio**: `App.navSaved()` no tiene lógica de "guardados". Cambia `activeNav` a 'saved' pero `getFilteredProducts()` no tiene case para 'saved' — muestra todos los productos.

**Bug de navegación**: El botón "Daily Deals" en el footer (línea 206) y en el header desktop (línea 47) llama `App.navShop()` — funcionalmente idéntico a "Shop All". No hay vista de Daily Deals implementada.

---

## RESUMEN POR PRIORIDAD

### CRITICAL (debe funcionar perfectamente siempre)
1. Filtrado de productos — determina qué ve el usuario
2. Ordenamiento — determina cómo lo ve
3. Sistema de traducción — determina en qué idioma
4. Detección/persistencia de idioma — determina el estado inicial

### IMPORTANT (impacta experiencia y conversión)
5. Ciclo de idiomas — UX de cambio
6. Generación de specs — contenido del detalle (con riesgo de veracidad)
7. Colecciones editoriales — discovery de productos
8. Búsqueda de texto — actualmente parcialmente rota
9. Gestión de badges — señales visuales de valor
10. Navegación por vistas — estructura de la app

### OPTIONAL (presente pero no crítico)
11. Lazy loading de imágenes — performance
12. Reset de estado — recuperación de UX
13. Sincronización de inputs mobile/desktop — consistencia
