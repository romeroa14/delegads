<script setup lang="ts">
const WHATSAPP_URL = 'https://wa.me/584242536795?text=Hola%20Delegads%2C%20quiero%20m%C3%A1s%20informaci%C3%B3n'
const INSTAGRAM_URL = 'https://instagram.com/delegads'
const EMAIL = 'info@delegads.com'

const services = [
  {
    icon: '📣',
    title: 'Publicidad Meta Ads',
    desc: 'Campañas optimizadas en Facebook e Instagram. Segmentación precisa, creativos probados y reportes claros cada semana.',
    price: 'Desde $9 · 3 días',
  },
  {
    icon: '🎨',
    title: 'Diseño Gráfico',
    desc: 'Imágenes para tu marca con IA generativa en 24h, o diseños profesionales hechos por un humano. Para posts, flyers y más.',
    price: 'IA desde $5 · Pro desde $15',
  },
  {
    icon: '📱',
    title: 'Gestión de Redes',
    desc: 'Tu Instagram y Facebook atendido por expertos. Contenido, comunidad y reportes incluidos. Vos solo ves crecer las ventas.',
    price: '$180/mes',
  },
]

const steps = [
  { num: 1, title: 'Escribinos', desc: 'Por WhatsApp o Instagram. Sin compromiso, te escuchamos.' },
  { num: 2, title: 'Asesoramos', desc: 'Nuestro agente te guía y cotiza según tu negocio y tu meta.' },
  { num: 3, title: 'Pagás fácil', desc: 'Pago Móvil, Binance, Zelle o transferencia. En BS o USD.' },
  { num: 4, title: 'Ejecutamos', desc: 'Creamos, publicamos y gestionamos. Vos te enfocas en tu negocio.' },
]

const plans = [
  {
    name: 'Plan Ads',
    price: '$9',
    cadence: '',
    desc: 'Lanzamiento rápido de una campaña Meta Ads',
    features: ['Segmentación por nicho', '1 conjunto de anuncios', 'Reporte de resultados', 'Optimización básica'],
  },
  {
    name: 'Plan Diseño',
    price: '$5',
    cadence: '/desde',
    desc: 'Piezas gráficas para tu marca',
    features: ['IA en 24h ($5)', 'Pro por humano ($15)', 'Hasta 3 revisiones', 'Archivos editables'],
  },
  {
    name: 'Plan Gestión',
    price: '$180',
    cadence: '/mes',
    desc: 'Tu comunidad atendida por expertos',
    features: ['3 posts por semana', '1 reel corto por semana', 'Historias diarias', 'Reporte mensual'],
  },
  {
    name: 'Combo Completo',
    price: '$250',
    cadence: '/mes',
    desc: 'Ads + Diseño + Gestión todo incluido',
    features: ['Todo del Plan Ads', 'Todo del Plan Diseño', 'Todo del Plan Gestión', 'Asesor dedicado'],
    featured: true,
  },
]

const testimonials = [
  {
    text: 'Delegads transformó mi negocio. Antes publicaba yo solo y no vendía. Ahora tengo campañas que sí convierten y el equipo responde siempre.',
    author: 'María G. — Negocio local, Los Teques',
    stars: 5,
  },
  {
    text: 'Vendí 3x más en 2 semanas. Los diseños llegan rápido, el plan de contenido me mantiene activo y los anuncios traen clientes nuevos cada día.',
    author: 'Carlos R. — E-commerce, Caracas',
    stars: 5,
  },
]
</script>

<template>
  <div>
    <!-- ===== HERO ===== -->
    <section class="hero">
      <div class="container hero-inner">
        <span class="hero-eyebrow">🇻🇪 Marketing para Venezuela</span>
        <h1>
          Tu agencia de marketing,
          <span>delegada</span>
        </h1>
        <p>
          Publicidad, diseño y gestión de redes — automatizado para tu negocio en
          Venezuela. Pagás en BS o USD, y nosotros nos encargamos de todo.
        </p>
        <div class="hero-ctas">
          <a :href="WHATSAPP_URL" class="btn btn-primary" target="_blank" rel="noopener">
            Empezar ahora
            <span aria-hidden="true">→</span>
          </a>
          <a href="#pricing" class="btn btn-secondary">Ver planes</a>
        </div>
        <div class="hero-stats">
          <div>
            <strong>+50</strong>
            <span>Negocios activos</span>
          </div>
          <div>
            <strong>3x</strong>
            <span>ROI promedio</span>
          </div>
          <div>
            <strong>24h</strong>
            <span>Tiempo de respuesta</span>
          </div>
        </div>
      </div>
    </section>

    <!-- ===== SERVICES ===== -->
    <section id="services" class="services">
      <div class="container">
        <div class="section-header">
          <h2>Servicios diseñados para crecer</h2>
          <p>
            Tres pilares que cubren todo lo que tu marca necesita en el mundo
            digital. Combinables, sin contratos largos.
          </p>
        </div>
        <div class="services-grid">
          <div v-for="s in services" :key="s.title" class="service-card">
            <div class="service-icon" aria-hidden="true">{{ s.icon }}</div>
            <h3>{{ s.title }}</h3>
            <p>{{ s.desc }}</p>
            <span class="price">{{ s.price }}</span>
          </div>
        </div>
      </div>
    </section>

    <!-- ===== HOW IT WORKS ===== -->
    <section id="how">
      <div class="container">
        <div class="section-header">
          <h2>Cómo trabajamos</h2>
          <p>Cuatro pasos simples. Cero tecnicismos, cero sorpresas.</p>
        </div>
        <div class="steps-grid">
          <div v-for="step in steps" :key="step.num" class="step">
            <div class="step-num">{{ step.num }}</div>
            <h3>{{ step.title }}</h3>
            <p>{{ step.desc }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- ===== PRICING ===== -->
    <section id="pricing" class="pricing">
      <div class="container">
        <div class="section-header">
          <h2>Planes y precios</h2>
          <p>Precios reales, sin letra chica. Pagás por lo que necesitás.</p>
        </div>
        <div class="pricing-grid">
          <div
            v-for="plan in plans"
            :key="plan.name"
            class="price-card"
            :class="{ featured: plan.featured }"
          >
            <h3>{{ plan.name }}</h3>
            <div class="price-value">
              {{ plan.price }}<small>{{ plan.cadence }}</small>
            </div>
            <p class="price-desc">{{ plan.desc }}</p>
            <ul>
              <li v-for="(f, i) in plan.features" :key="i">{{ f }}</li>
            </ul>
            <a :href="WHATSAPP_URL" class="btn" target="_blank" rel="noopener">
              Quiero este plan
            </a>
          </div>
        </div>
      </div>
    </section>

    <!-- ===== TESTIMONIALS ===== -->
    <section id="testimonials">
      <div class="container">
        <div class="section-header">
          <h2>Lo que dicen nuestros clientes</h2>
          <p>Resultados reales, de personas reales.</p>
        </div>
        <div class="testimonials-grid">
          <div v-for="(t, i) in testimonials" :key="i" class="testimonial">
            <div class="stars" aria-label="5 estrellas">★★★★★</div>
            <p>{{ t.text }}</p>
            <div class="author">{{ t.author }}</div>
          </div>
        </div>
      </div>
    </section>

    <!-- ===== CTA BANNER ===== -->
    <section class="cta-banner">
      <div class="container">
        <h2>¿Listo para delegar tu marketing?</h2>
        <p>
          Escribinos por WhatsApp y en menos de 24h tenés un plan claro para tu
          negocio.
        </p>
        <a :href="WHATSAPP_URL" class="btn btn-primary" target="_blank" rel="noopener">
          Hablar por WhatsApp
          <span aria-hidden="true">→</span>
        </a>
      </div>
    </section>

    <!-- ===== FOOTER ===== -->
    <footer>
      <div class="container">
        <div class="footer-grid">
          <div class="footer-brand">
            <h3>Delegads<span>.com</span></h3>
            <p>
              Tu agencia de marketing delegada. Publicidad, diseño y gestión de
              redes para negocios en Venezuela.
            </p>
          </div>
          <div class="footer-col">
            <h4>Contacto</h4>
            <ul>
              <li>
                <a :href="WHATSAPP_URL" target="_blank" rel="noopener">
                  WhatsApp: +58 424-2536795
                </a>
              </li>
              <li>
                <a :href="INSTAGRAM_URL" target="_blank" rel="noopener">
                  Instagram: @delegads
                </a>
              </li>
              <li>
                <a :href="`mailto:${EMAIL}`">{{ EMAIL }}</a>
              </li>
            </ul>
          </div>
          <div class="footer-col">
            <h4>Servicios</h4>
            <ul>
              <li><a href="#services">Meta Ads</a></li>
              <li><a href="#services">Diseño Gráfico</a></li>
              <li><a href="#services">Gestión de Redes</a></li>
            </ul>
          </div>
          <div class="footer-col">
            <h4>Empresa</h4>
            <ul>
              <li><a href="#how">Cómo trabajamos</a></li>
              <li><a href="#pricing">Planes</a></li>
              <li><a href="#testimonials">Testimonios</a></li>
            </ul>
          </div>
        </div>
        <div class="footer-bottom">
          © 2026 Delegads.com — Todos los derechos reservados.
        </div>
      </div>
    </footer>
  </div>
</template>
