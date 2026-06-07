# EXECUTIVE SUMMARY — Forensic Architecture Audit
## Aether Global — Informe Ejecutivo
**Fecha**: 2026-06-07  
**Basado en**: Análisis directo de 11 archivos, 2,700 líneas de código

---

## 1. ¿QUÉ TAN SANO ESTÁ REALMENTE EL PROYECTO?

**Salud: 4/10**

La aplicación funciona en condiciones normales, pero tiene una deuda técnica significativa que crea riesgos ocultos. El núcleo (filtrado, renderizado, i18n) funciona, pero está construido de una forma que hace imposible confiar en que seguirá funcionando cuando el sistema crezca o cuando ocurran cambios de datos.

**Lo que funciona bien**:
- Filtrado de productos (lógica correcta en condiciones normales)
- Renderizado sin XSS en la mayoría de rutas
- Lazy loading con fallback
- Detección de idioma con fallback robusto
- Diseño visual (Tailwind bien aplicado)

**Lo que está roto silenciosamente**:
- Búsqueda en descripción (usa campo incorrecto)
- Colecciones con productos faltantes
- Estado no se limpia al navegar desde colección a shop
- Archivos huérfanos que crean trampa de mantenimiento
- Fuente de verdad de datos fracturada en 3 copias divergentes

---

## 2. ¿CUÁL ES EL MAYOR RIESGO TÉCNICO?

**La ausencia total de tests + el código duplicado en 2 archivos**

Hay código idéntico en `hub/assets/app.js` (huérfano, no ejecuta) y en el script inline de `hub/index.html` (el que realmente corre). No hay tests que detecten cuándo los dos divergen, ni cuándo se introduce un bug.

El mayor riesgo técnico concreto es el **JSON parse sin error handling** (línea 340):
```javascript
var DATA = JSON.parse(document.getElementById('products-data').textContent);
```
Si el JSON embebido tiene un error de sintaxis (muy posible con un proceso de generación externo), la aplicación lanza una excepción no capturada y el sitio queda completamente en blanco. Con $100K/mes en juego, esto es tiempo de inactividad catastrófico sin alerta.

---

## 3. ¿CUÁL ES EL MAYOR RIESGO COMERCIAL?

**La mezcla de productos Amazon Associates con productos ClickBank**

El sitio incluye `cb_alpilean` y `cb_leanbiome` con links `?hop=aethervnt` (formato ClickBank), mezclados con productos Amazon (`?tag=aetherglobal-20`). Esta mezcla puede violar los TOS de Amazon Associates.

Adicionalmente, los specs autogenerados (`_deriveSpecs`) dicen "Ships and sold by Amazon" y "Eligible for Amazon Prime delivery" para productos que NO se venden en Amazon — lo cual es publicidad falsa.

Si Amazon Associates suspende la cuenta `aetherglobal-20`, el 100% de las comisiones del catálogo principal desaparecen en horas.

---

## 4. ¿CUÁL ES EL MAYOR RIESGO DE SEGURIDAD?

**URL injection via esquema `javascript:` en affiliateUrl**

```javascript
'<a href="' + _escAttr(p.affiliateUrl || '#') + '">'
```

`_escAttr` escapa caracteres HTML pero no valida el esquema de URL. Si `affiliateUrl` fuera `"javascript:alert(1)"`, el link sería ejecutable. Con un proceso de generación externo de datos, si esa fuente se compromete, un attacker puede inyectar JS ejecutable en cada link de producto.

**Segundo en importancia**: Tailwind cargado desde CDN sin Subresource Integrity hash. Un supply chain attack al CDN tendría acceso completo a `window.App`, datos de usuarios, y podría modificar todos los affiliate links.

---

## 5. ¿QUÉ NO DEBERÍA TOCARSE?

**Los siguientes elementos funcionan y son críticos — no tocar sin tests previos**:

1. **`App.getFilteredProducts()`** (líneas 457–505) — el corazón del sistema de filtrado
2. **`_escHtml()` / `_escAttr()`** (líneas 1105–1120) — protección XSS activa
3. **`_detectLang()`** (líneas 1071–1077) — funciona bien con localStorage y fallbacks
4. **El JSON embebido en `products-data`** — fuente de verdad de los productos, cualquier error aquí rompe todo
5. **La estructura de Tailwind config** (línea 14 de index.html) — contiene el design system completo; un cambio aquí afecta TODA la apariencia visual

---

## 6. ¿QUÉ DEBERÍA REFACTORIZARSE PRIMERO?

**Por orden de ROI (menor riesgo, mayor impacto):**

1. **Eliminar archivos huérfanos** (`app.js`, `hub/products.json`, `hub/data/products.json`, `hub/i18n/*.json`) — cero riesgo de regresión, elimina la confusión de fuente de verdad

2. **Corregir el bug de `navShop()` / `reset()` que no limpia `_collectionFilter`** — 3 líneas de código, impacto directo en conversión (bug activo que muestra catálogo reducido)

3. **Corregir la búsqueda** (campo `descriptionI18n` en lugar de `description`) — fix trivial, mejora directa del discovery de productos

4. **Añadir validación de URL scheme** en la ruta de `affiliateUrl` — cierra el mayor vector de seguridad

---

## 7. ¿QUÉ DEBERÍA PROBARSE PRIMERO?

**Por orden de impacto en el negocio:**

1. **`getFilteredProducts()`** con los 6 criterios de filtrado — es el core del negocio
2. **`_escHtml()` / `_escAttr()`** — son la barrera XSS
3. **`_deriveSpecs()`** — genera contenido que aparece en el panel de detalle
4. **`App.t(key)`** — traducción en cascada con sus fallbacks
5. **Integración: activar colección → navShop() → verificar que muestra todos los productos** — testear el bug de estado activo

---

## 8. ¿QUÉ DEBERÍA ELIMINARSE?

| Archivo/Elemento | Razón |
|---|---|
| `hub/assets/app.js` | Huérfano, nunca cargado, crea confusión |
| `hub/products.json` | Huérfano, versión de 2026-05-28, 10 días desactualizado |
| `hub/data/products.json` | Huérfano, versión de 2026-06-02, 3 días desactualizado |
| `hub/i18n/en.json`, `es.json`, `fr.json` | Huérfanos, valores divergentes del live |
| `App._collectionStory` | Estado que se setea pero nunca se lee |
| `p.section` en schema de productos | Campo nunca leído por el código |
| Productos `cb_alpilean`, `cb_leanbiome` | Riesgo de compliance Amazon Associates + specs falsas |

---

## 9. ¿QUÉ DEBERÍA MODULARIZARSE?

**Por orden de facilidad y ROI:**

1. **`security.js`** — `escHtml`, `escAttr`, `isSafeUrl` → zero riesgo, permite tests de seguridad
2. **`utils/specs.js`** — `deriveSpecs` → función pura, ya casi lista
3. **`utils/lang.js`** — `detectLang`, `saveLang`, `cycleLang` → funciones puras
4. **`filters.js`** — lógica de filtrado + sort → el módulo más valioso para testear
5. **`collections.js`** — carga + gestión de colecciones → permite eliminar el monkey-patch
6. **`render/*.js`** — separar rendering de lógica → largo plazo

---

## 10. ROADMAP IDEAL DE 30 DÍAS

### Semana 1: Limpieza y Seguridad (días 1-7)
- **Día 1-2**: Eliminar los 6 archivos huérfanos (git rm)
- **Día 3**: Corregir bug de `_collectionFilter` en `navShop()` y `reset()`
- **Día 4**: Corregir búsqueda de descripción (`descriptionI18n` vs `description`)
- **Día 5**: Añadir validación de URL scheme para `affiliateUrl`
- **Día 6-7**: Evaluar compliance de productos ClickBank, remover o segregar

### Semana 2: Infraestructura de Tests (días 8-14)
- **Día 8-9**: Añadir `package.json` con Vitest + JSDOM
- **Día 10-11**: Extraer `security.js` + `utils/specs.js` + `utils/lang.js`
- **Día 12-13**: Escribir tests para las funciones extraídas (~15 tests)
- **Día 14**: Configurar CI/CD en GitHub Actions para correr tests en cada push

### Semana 3: Lógica de Negocio (días 15-21)
- **Día 15-17**: Extraer `filters.js` con funciones puras, eliminar monkey-patch
- **Día 18-20**: Escribir tests para todos los filtros y sorts (~20 tests)
- **Día 21**: Corregir typo `herobage`/`herobadge` con coordinación en JSON + código

### Semana 4: SEO y Datos (días 22-30)
- **Día 22-23**: Añadir `<meta og:*>` para social sharing
- **Día 24-25**: Añadir Schema.org/JSON-LD para productos (Google Shopping)
- **Día 26-27**: Unificar fuentes de datos — elegir UNA fuente de verdad
- **Día 28-29**: Añadir error handling alrededor del JSON parse inicial
- **Día 30**: Implementar `social_angle` de collections en UI (ROI de contenido existente)

### Resultado esperado al día 30:
- ✅ 0 archivos huérfanos
- ✅ 4 bugs activos corregidos
- ✅ ~35 tests automatizados cubriendo lógica crítica
- ✅ CI/CD ejecutando tests en cada PR
- ✅ Riesgo de compliance reducido
- ✅ SEO básico implementado
- ✅ Una sola fuente de verdad para datos

---

## RESUMEN DE UNA LÍNEA

**El sitio funciona pero está construido sobre arenas movedizas: 6 archivos que no se cargan, 3 versiones de datos divergentes, 8 bugs silenciosos, 0 tests, y riesgos de compliance activos que podrían terminar el negocio. La buena noticia: los problemas son conocidos, el código es pequeño, y 2 semanas de trabajo disciplinado transformarían el nivel de confianza del sistema.**
