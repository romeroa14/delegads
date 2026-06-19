# Delegads Web — Nuxt 4 Landing

Sitio público de **Delegads.com**. Single-page, mobile-first, optimizado para
conversión.

## Stack
- **Nuxt 4** (Vite + Nitro)
- **Vue 3** Composition API
- **CSS nativo** (sin Tailwind ni dependencias extra — más rápido, menos peso)

## Desarrollo
```bash
cd web
npm install
npm run dev          # http://localhost:3000
```

## Build
```bash
npm run build
node .output/server/index.mjs
```

## Docker
```bash
docker compose up -d web
# Disponible en http://localhost:8087
```

## Estructura
```
web/
├── app.vue                  # Root component
├── nuxt.config.ts           # Config Nuxt + Nitro (node-server)
├── package.json
├── Dockerfile
├── assets/
│   └── css/main.css         # Estilos del sitio
├── pages/
│   └── index.vue            # Landing page (single page)
└── public/
    └── favicon.svg
```

## Variables de entorno
No requiere. El sitio es estático a nivel de contenido.
