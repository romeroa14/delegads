// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-01-01',
  devtools: { enabled: true },
  nitro: {
    preset: 'node-server',
  },
  app: {
    head: {
      title: 'Delegads.com — Tu agencia delegada',
      htmlAttrs: { lang: 'es' },
      meta: [
        { charset: 'utf-8' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
        { name: 'description', content: 'Agencia de marketing delegada. Publicidad, diseño y gestión de redes automatizadas para Venezuela.' },
        { name: 'theme-color', content: '#7c3aed' },
        { property: 'og:title', content: 'Delegads.com — Tu agencia de marketing delegada' },
        { property: 'og:description', content: 'Publicidad, diseño y gestión de redes automatizadas para tu negocio en Venezuela.' },
        { property: 'og:type', content: 'website' },
      ],
      link: [
        { rel: 'icon', type: 'image/svg+xml', href: '/favicon.svg' },
      ],
    },
  },
  css: ['~/assets/css/main.css'],
})
