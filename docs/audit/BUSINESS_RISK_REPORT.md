# BUSINESS RISK REPORT — Aether Global
**Fecha**: 2026-06-07  
**Hipótesis**: Sitio generando $100,000/mes en comisiones de afiliado

---

## LAS 10 COSAS QUE PODRÍAN ROMPER EL NEGOCIO

---

### RIESGO #1: Suspensión de la cuenta Amazon Associates
**Probabilidad: MEDIA | Impacto: CATASTRÓFICO | Prioridad: URGENTE**

**Evidencia**: El sitio mezcla productos de Amazon Associates (`?tag=aetherglobal-20`) con productos de ClickBank (`?hop=aethervnt` — alpilean.com, leanbiome.com).

Los TOS de Amazon Associates prohíben:
- Presentar links de afiliado de forma engañosa
- Mezclar el programa Amazon Associates con otros programas de afiliado en la misma página sin disclosure claro

Adicionalmente, los specs generados automáticamente por `_deriveSpecs()` afirman cosas como "Dermatologist tested formula" y "Cruelty-free certified" para TODOS los productos de beauty sin verificación. Para suplementos de salud como los ClickBank, esto puede ser considerado publicidad engañosa por la FTC.

**Escenario de quiebra**: Amazon detecta el patrón, suspende `aetherglobal-20`, se pierden el 100% de las comisiones de Amazon en horas.

---

### RIESGO #2: Un CDN externo se cae o es comprometido
**Probabilidad: BAJA | Impacto: CATASTRÓFICO | Prioridad: ALTA**

**Evidencia**: 
```html
<script src="https://cdn.tailwindcss.com"></script>
```
Sin este script, el sitio pierde TODOS los estilos. La UI es completamente inutilizable. No hay fallback.

Si `cdn.tailwindcss.com` tiene un outage (ha pasado en el pasado con CDNs populares), el sitio no puede mostrar productos durante el downtime — cero conversiones.

Si el CDN fuera comprometido (supply chain attack), código malicioso tendría acceso completo a `window.App`, podrían modificar los links de afiliado para redirigir comisiones.

**Escenario de quiebra**: Outage de 4 horas en horario pico = $0 en conversiones + potencial modificación de affiliate tags.

---

### RIESGO #3: Colecciones muestran productos incorrectos (silenciosamente)
**Probabilidad: ALTA | Impacto: ALTO | Prioridad: ALTA**

**Evidencia**: `gym_gear` promete 8 productos (incluyendo Stanley Quencher viral) pero muestra 6. `smart_home_upgrades` promete 6 pero muestra 3 (varios ASINs no están en el product array).

Las colecciones son probablemente el driver de conversión más alto (producto curado con narrativa = mayor intención de compra). Si las colecciones con mayor AOV (como gadgets premium de $100-280) muestran productos vacíos, se pierden conversiones directamente.

**Escenario**: Un visitante llega por SEO/redes al contenido de "Luxury Desk Setup", hace click en la colección, ve menos productos de los prometidos, no encuentra el producto que buscaba específicamente — rebota.

---

### RIESGO #4: La búsqueda está rota (silenciosamente)
**Probabilidad: ALTA (ya ocurre) | Impacto: MEDIO | Prioridad: ALTA**

**Evidencia**: 
```javascript
// Línea 476 — busca en p.description
p.description[App.lang]  // p.description = "Electronics" (string)
// Resultado: undefined → ''
```

La búsqueda en descripción nunca funciona. Si el usuario busca términos como "wireless", "noise canceling", "kitchen" — términos que aparecerían en descripciones pero no en títulos/categorías — no encontrará nada o encontrará resultados incompletos.

**Escenario**: Usuario busca "noise canceling" → 0 resultados aunque hay Sony WH-1000XM5 y AirPods Pro → abandona el sitio.

---

### RIESGO #5: Estado corrupto por navegación a colección + uso de nav
**Probabilidad: ALTA | Impacto: ALTO | Prioridad: ALTA**

**Evidencia (STATE_AUDIT.md)**:
```javascript
// App.navShop() NO limpia _collectionFilter:
App.navShop = function() {
  this.activeNav = 'shop';
  this.category = 'all';
  this.query = '';  // ← pero no: this._collectionFilter = null
  this.render();
};
```

**Escenario exacto**: 
1. Usuario ve colección "Minimalist Tech" (4 productos)
2. Hace click en "Shop" en el nav
3. El nav muestra "Shop" activo
4. La app sigue mostrando los 4 productos de la colección
5. Usuario piensa que solo hay 4 productos en la tienda → abandona

Con 25 productos en el catálogo, este bug reduce artificialmente el catálogo visible a una fracción. En términos de conversión: menos productos vistos = menos conversiones.

---

### RIESGO #6: Cambio en el schema de datos rompe la app completamente
**Probabilidad: MEDIA | Impacto: CATASTRÓFICO | Prioridad: ALTA**

**Evidencia**: El script se ejecuta sincrónicamente con:
```javascript
var DATA = JSON.parse(document.getElementById('products-data').textContent);
```

Si el JSON embebido tiene un error de sintaxis (una coma extra, comilla sin cerrar), la app entera lanza un SyntaxError y no inicializa. La página muestra el HTML base sin productos ni funcionalidad.

Con el proceso de generación implícito (hay scripts externos que actualizan el JSON), cualquier bug en ese proceso que genere JSON inválido hace el sitio 100% inoperativo hasta el próximo deploy.

No hay validación, no hay fallback, no hay error handling alrededor del parse inicial.

---

### RIESGO #7: Duplicación de datos genera deploy de versión incorrecta
**Probabilidad: MEDIA | Impacto: MEDIO | Prioridad: MEDIA**

**Evidencia**: Existen 3 versiones del catálogo de productos con fechas diferentes (2026-05-28, 2026-06-02, 2026-06-05). El proceso de update no elimina los archivos anteriores.

**Escenario**: Un desarrollador ve `hub/data/products.json` (la más obvia por estar en `/data/`), la modifica para actualizar precios, hace deploy. Pero la app lee del JSON embebido en `index.html`. Los precios en el sitio no cambian. El desarrollador piensa el precio está actualizado. Los usuarios ven precios incorrectos.

---

### RIESGO #8: Specs falsas generan chargeback o queja FTC
**Probabilidad: BAJA | Impacto: CATASTRÓFICO | Prioridad: URGENTE**

**Evidencia**: `_deriveSpecs()` afirma "Cruelty-free certified" y "Dermatologist tested formula" para TODOS los productos de beauty. Para "Alpilean Alpine Ice Hack" (categoría "health & fitness"), afirma "Eligible for Amazon Prime delivery" y "Ships and sold by Amazon" — pero Alpilean se vende por su propio dominio, no en Amazon.

Si la FTC o Amazon revisa el sitio, encontrarán:
1. Afirmaciones de salud no verificadas sobre suplementos
2. Claims de certificaciones no verificadas
3. "Ships and sold by Amazon" para productos no vendidos en Amazon

El riesgo regulatorio de un sitio de afiliados con $100K/mes es significativo.

---

### RIESGO #9: Sin SSL, SEO, ni metadata estructurada
**Probabilidad: N/A (ya ocurre) | Impacto: ALTO | Prioridad: MEDIA**

**Evidencia**:
- No hay `<meta property="og:*">` para redes sociales
- No hay Schema.org/JSON-LD para productos (Google Shopping)
- No hay sitemap.xml
- No hay robots.txt
- El `<title>` de hub/index.html es genérico: "Aether Global — Premium Deals"

Un sitio de afiliados de $100K/mes vive o muere por el tráfico orgánico. Sin metadata estructurada, los productos no aparecen en Google Shopping ni en rich snippets. Sin og:image, las comparticiones en redes no tienen preview visual.

---

### RIESGO #10: Identidad de marca fracturada
**Probabilidad: ALTA (ya ocurre) | Impacto: MEDIO | Prioridad: MEDIA**

**Evidencia**:
- `index.html` (raíz): `<h1>Alexander Aether</h1>` — "AI Tools & Digital Products", "Coming Soon"
- `hub/index.html`: "Aether Global" — sitio de afiliados activo
- `hub/assets/app.js` (huérfano): "AffilioLux client app" — tercer nombre

El sitio raíz tiene un coming soon de una persona/empresa diferente. Si un visitante llega al dominio raíz (desde un link directo, SEO, social) verá "Coming Soon" y no encontrará la tienda. Todo el tráfico al dominio raíz se pierde.

---

## MATRIZ DE RIESGO

| Riesgo | Probabilidad | Impacto | Score |
|---|---|---|---|
| #1 Suspensión Amazon Associates | Media | Catastrófico | 🔴 CRÍTICO |
| #8 Specs falsas + FTC | Baja | Catastrófico | 🔴 CRÍTICO |
| #2 CDN down/comprometido | Baja | Catastrófico | 🔴 CRÍTICO |
| #6 JSON inválido rompe app | Media | Catastrófico | 🔴 CRÍTICO |
| #5 Estado corrupto por colección | Alta | Alto | 🟠 ALTO |
| #3 Colecciones incompletas | Alta | Alto | 🟠 ALTO |
| #4 Búsqueda rota | Alta | Medio | 🟡 MEDIO |
| #7 Deploy versión incorrecta | Media | Medio | 🟡 MEDIO |
| #9 Sin SEO estructurado | N/A | Alto | 🟡 MEDIO |
| #10 Identidad fracturada | Alta | Medio | 🟡 MEDIO |
