# Delegads.com — System Architecture Documentation

> **Version**: 1.0.0  
> **Last updated**: June 2026  
> **Repository**: [github.com/romeroa14/delegads](https://github.com/romeroa14/delegads)  
> **Status**: Production (AdsVzla workflows active, Delegads platform in development)

---

## 1. Overview

Delegads.com is a **delegated marketing agency platform** that automates the entire client lifecycle: from lead capture through WhatsApp/Instagram/Messenger, through payment validation and campaign creation on Meta Ads, to design services and social media management.

The system is built as a **monorepo** with microservices communicating through a shared PostgreSQL database and Docker network.

### Core Philosophy

- **n8n** = Orchestrator (workflows, AI agents, routing)
- **Hermes** = Executor (Meta Ads API, AI generation, multimedia processing)
- **Laravel/Filament** = CRM (admin panel, API, data management)
- **Nuxt.js** = Public web (landing page, marketing)
- **Flutter** = Mobile app (dashboard for agency owner)

---

## 2. Architecture Diagram

```
                          ┌─────────────────────────────────────────────────┐
                          │            META CLOUD API (v25.0)               │
                          │  WhatsApp  │  Instagram  │  Messenger  │  Ads   │
                          └─────┬──────┴──────┬──────┴──────┬───────┴──┬───┘
                                │             │             │          │
                    webhooks    │    webhooks │             │          │ API
                                ▼             ▼             ▼          ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                        n8n ORCHESTRATOR                                    │
│  n8n.admetricas.com (production, MCP: 27 tools)                           │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ WF1: WhatsApp Bot 🟢 (32 nodes)                                    │  │
│  │   Webhook /whabot → Parse → Audio?/Image?/Text?                    │  │
│  │   Audio → Hermes /transcribe-audio                                 │  │
│  │   Image → Hermes /validate-receipt → Validate Payment Amount       │  │
│  │   Image → Hermes /describe-image                                   │  │
│  │   AI Agent (OpenRouter gemini-2.5-flash) → Valeria                 │  │
│  │   DB: leads + conversations → Send WhatsApp                        │  │
│  ├────────────────────────────────────────────────────────────────────┤  │
│  │ WF2: Instagram DM Agent 🟢 (19 nodes)                              │  │
│  │   Webhook /igbot → Multimodal → Hermes → AI Agent → Send IG        │  │
│  ├────────────────────────────────────────────────────────────────────┤  │
│  │ WF3: Messenger Bot 🟢 (4 nodes)                                    │  │
│  │   Webhook /messenger → Parse → Auto-responder → Send Messenger     │  │
│  ├────────────────────────────────────────────────────────────────────┤  │
│  │ WF4: Instagram Comments 🟢 (10 nodes)                              │  │
│  │   Webhook → AI auto-reply                                          │  │
│  ├────────────────────────────────────────────────────────────────────┤  │
│  │ WF5: Remarketing WhatsApp 🟢 (20 nodes)                            │  │
│  │   Cron 6h → 3 levels: Cold(+48h) / Abandoned(+24h) / Renewal(2d)  │  │
│  ├────────────────────────────────────────────────────────────────────┤  │
│  │ WF6: Auto-Accept Pages ⚪ (11 nodes)                               │  │
│  │   Cron 5min → Detect new client pages → Match to leads             │  │
│  ├────────────────────────────────────────────────────────────────────┤  │
│  │ WF7: Design Handoff Handler 🟢 (11 nodes)                          │  │
│  │   Cron 2min → Check agent_handoff → DesignBot → Send result        │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────┬────────────────────────────────────────────┘
                               │ HTTP (Docker network)
                               ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                     HERMES AGENT (:8009)                                   │
│  FastAPI + Python 3.11 | Docker | Meta API v25.0                          │
│                                                                            │
│  ┌─ AI Engine ─────────────────────────────────────────────────────────┐  │
│  │ POST /transcribe-audio    ← audio URL → text (Gemini)               │  │
│  │ POST /validate-receipt    ← image → OCR JSON (amount, ref, bank)    │  │
│  │ POST /describe-image      ← image → text description                │  │
│  │ optimize_creative_copy()  ← raw copy → persuasive copy              │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│  ┌─ Meta Ads Engine ───────────────────────────────────────────────────┐  │
│  │ POST /create-campaign    ← Campaign + AdSet + AdCreative + Ad       │  │
│  │   4 destinations: instagram_profile, instagram_dm, whatsapp,       │  │
│  │                   messenger                                         │  │
│  │   WhatsApp fallback: CONVERSATIONS → IMPRESSIONS (error 2446921)   │  │
│  │   Dynamic: page_id + instagram_actor_id per client                 │  │
│  │ GET  /campaign-stats/{id}  → Meta Insights                         │  │
│  │ POST /activate-campaign/{id} → PAUSED → ACTIVE                     │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│  ┌─ DesignBot ─────────────────────────────────────────────────────────┐  │
│  │ POST /generate-design     ← prompt → AI image (OpenRouter)          │  │
│  │ POST /create-design-task  ← prompt → human designer queue           │  │
│  │ GET  /design-job/{id}     ← job status                              │  │
│  │ POST /design-job/{id}/status ← approve/reject/update                │  │
│  │ 7-day fallback: human → AI auto-switch                              │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│  ┌─ ContentBot ────────────────────────────────────────────────────────┐  │
│  │ POST /content-briefing       ← generate 5 questions for client      │  │
│  │ POST /content-briefing/answers ← process answers → strategy         │  │
│  │ POST /generate-calendar      ← 30-day content calendar              │  │
│  │ GET  /content-calendar/{lead_id} ← get calendar                     │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│  ┌─ Webhook Relay ─────────────────────────────────────────────────────┐  │
│  │ GET/POST /webhook/whatsapp  ← WhatsApp + Messenger routing          │  │
│  │ GET/POST /webhook/messenger ← Messenger direct                     │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│  20 endpoints total | 4 skills (meta_ads, ai_engine, design_bot, content_bot) │
└──────────────────────────────┬────────────────────────────────────────────┘
                               │
                               ▼
┌───────────────────────────────────────────────────────────────────────────┐
│              POSTGRESQL fb_google (laravel-postgres:5432)                 │
│                                                                            │
│  ┌─ Sales ─────────────────────────────────────────────────────────────┐  │
│  │ leads               (28 rows) — platform_id, stage, intent, plan    │  │
│  │ conversations       (172 rows) — message history                    │  │
│  │ advertising_plans   (16 rows) — pricing grid ($9-$84)              │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│  ┌─ Design ────────────────────────────────────────────────────────────┐  │
│  │ design_jobs         — AI/human design requests                     │  │
│  │ designers           (1 row) — human designer roster                │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│  ┌─ Content ───────────────────────────────────────────────────────────┐  │
│  │ content_calendar    — 30-day content schedule                      │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│  ┌─ Multi-Agent ───────────────────────────────────────────────────────┐  │
│  │ agent_handoff       — Valeria → DesignBot → ContentBot bus         │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│  ┌─ Page Access ───────────────────────────────────────────────────────┐  │
│  │ page_access_requests — client page tracking                        │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│  ┌─ CRM ───────────────────────────────────────────────────────────────┐  │
│  │ users, workspaces, facebook_accounts, campaigns, etc.              │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────┐
│              CRM PANEL (Laravel 11 + Filament 3, :8086)                   │
│                                                                            │
│  Panel: /crm (login: business@alfredoromero.io)                           │
│  Resources: Lead, Conversation, Campaign, DesignJob, Designer,            │
│             AgentHandoff, AdvertisingPlan, PageAccessRequest               │
│  Widgets: TotalLeads, LeadsByStage, ActiveCampaigns, PendingDesigns,      │
│           ConversionFunnel                                                │
│  API: /api/v1/leads, /api/v1/metrics, /api/v1/design-jobs,                │
│       /api/v1/campaigns (Sanctum auth)                                    │
└───────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────┐
│              WEB (Nuxt.js 3, :3000/:8087)                                 │
│  Landing page: hero, services, pricing, how it works, testimonials        │
│  WhatsApp deep links: wa.me/584242536795                                  │
└───────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────┐
│              MOBILE (Flutter, iOS + Android)                              │
│  Screens: Login, Dashboard, Leads, LeadDetail, Campaigns, Designs,        │
│           Settings                                                        │
│  Auth: Sanctum Bearer token                                               │
│  API: connects to CRM at configurable base URL                            │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Monorepo Structure

```
delegads/
├── hermes/                    # FastAPI executor (20 endpoints, 4 skills)
│   ├── main.py                # All endpoints + Pydantic models
│   ├── skills/
│   │   ├── meta_ads.py        # Meta Marketing API v25.0
│   │   ├── ai_engine.py       # OpenRouter multimodal (Gemini 2.5 Flash)
│   │   ├── design_bot.py      # Image generation + human designer handoff
│   │   └── content_bot.py     # Content strategy + calendar generation
│   ├── Dockerfile
│   └── requirements.txt
├── crm/                       # Laravel 11 + Filament 3 admin panel
│   ├── app/
│   │   ├── Filament/Resources/  # 6 CRUD resources
│   │   ├── Filament/Widgets/    # 5 dashboard widgets
│   │   ├── Http/Controllers/Api/# 4 API controllers (Sanctum)
│   │   └── Models/              # 12 Eloquent models
│   ├── Dockerfile
│   └── README.md
├── web/                       # Nuxt.js 3 public website
│   ├── pages/index.vue        # Landing page
│   ├── nuxt.config.ts
│   ├── Dockerfile
│   └── package.json
├── mobile/                    # Flutter app (iOS + Android)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── config/api_config.dart
│   │   ├── models/             # Lead, Campaign, DesignJob, Metrics
│   │   ├── services/api_service.dart
│   │   ├── screens/            # 7 screens
│   │   └── widgets/            # 3 reusable widgets
│   ├── pubspec.yaml
│   └── README.md
├── n8n-workflows/             # JSON exports of n8n workflows
│   └── design-handoff.json
├── shared/
│   └── db/                    # SQL migrations
│       ├── 001_design_jobs.sql
│       ├── 002_designers.sql
│       ├── 003_agent_handoff.sql
│       └── 004_content_calendar.sql
├── docker-compose.yml         # Hermes + CRM + Web services
├── .env                       # Consolidated environment (gitignored)
├── .env.example               # Template (no secrets)
├── .gitignore
└── README.md
```

---

## 4. Hermes Endpoints (20 total)

### Meta Ads Engine (6 endpoints)
| Method | Path | Purpose |
|--------|------|---------|
| POST | `/create-campaign` | Create Campaign + AdSet + AdCreative + Ad (4 destinations) |
| GET | `/campaign-stats/{campaign_id}` | Get Meta Insights (impressions, clicks, spend) |
| POST | `/activate-campaign/{campaign_id}` | Change status from PAUSED to ACTIVE |
| GET | `/health` | Health check (Meta connection status) |
| GET | `/` | Root info |

### AI Engine (3 endpoints)
| Method | Path | Purpose |
|--------|------|---------|
| POST | `/transcribe-audio` | Download audio → base64 → Gemini → transcription |
| POST | `/validate-receipt` | Download image → OCR → payment JSON (amount, ref, bank) |
| POST | `/describe-image` | Download image → Gemini → text description |

### DesignBot (4 endpoints)
| Method | Path | Purpose |
|--------|------|---------|
| POST | `/generate-design` | AI image generation via OpenRouter |
| POST | `/create-design-task` | Create human designer task |
| GET | `/design-job/{job_id}` | Get design job status |
| POST | `/design-job/{job_id}/status` | Update job (approve/reject) |

### ContentBot (4 endpoints)
| Method | Path | Purpose |
|--------|------|---------|
| POST | `/content-briefing` | Generate 5 briefing questions |
| POST | `/content-briefing/answers` | Process answers → content strategy |
| POST | `/generate-calendar` | Generate 30-day content calendar |
| GET | `/content-calendar/{lead_id}` | Get calendar for a lead |

### Webhooks (3 endpoints)
| Method | Path | Purpose |
|--------|------|---------|
| GET | `/webhook/whatsapp` | Meta webhook verification (WhatsApp) |
| POST | `/webhook/whatsapp` | Receive WhatsApp + Messenger messages, route by `object` field |
| GET/POST | `/webhook/messenger` | Messenger direct webhook |

### Campaign Destinations
| Destination | Objective | Optimization Goal | Destination Type | CTA |
|-------------|-----------|-------------------|-----------------|-----|
| instagram_profile | OUTCOME_TRAFFIC | LINK_CLICKS | (none) | (none) |
| instagram_dm | OUTCOME_TRAFFIC | CONVERSATIONS | INSTAGRAM_DIRECT | INSTAGRAM_MESSAGE |
| whatsapp | OUTCOME_TRAFFIC | CONVERSATIONS → IMPRESSIONS (fallback) | WHATSAPP | WHATSAPP_MESSAGE |
| messenger | OUTCOME_TRAFFIC | CONVERSATIONS | MESSENGER | MESSAGE_PAGE |

---

## 5. n8n Workflows (7 total)

| # | Workflow | ID | Status | Nodes | Trigger |
|---|----------|----|:---:|:---:|---------|
| 1 | Whatsap bot | 4kpsSWVohCfrvdce | 🟢 | 32 | Webhook POST /whabot |
| 2 | Instagram DM Agent - Valeria | YfLocVfdxvbDyV7w | 🟢 | 19 | Webhook POST /igbot |
| 3 | Messenger Bot | aVUvhiEvWFPtMHDt | 🟢 | 4 | Webhook POST /messenger |
| 4 | Instagram Comments | rFtOY6li7dQyQRVb | 🟢 | 10 | Webhook |
| 5 | Remarketing Whatsapp | h1EyVlTsJjUciPOz | 🟢 | 20 | Cron 6h |
| 6 | Auto-Accept Page Access | deOtlQUwertqhbcP | ⚪ | 11 | Cron 5min |
| 7 | Design Handoff Handler | IzjwQD3ed1PsMWQW | 🟢 | 11 | Cron 2min |

---

## 6. Database Schema

### Core Tables
| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `leads` | Client leads | id, phone_number, client_name, stage, intent, lead_level, selected_plan, page_id, instagram_actor_id |
| `conversations` | Message history | id, lead_id, user_id, message_text, response, timestamp |
| `advertising_plans` | Pricing grid | id, plan_name, daily_budget, duration_days, client_price, is_active |
| `campaigns` | Meta campaigns | id, lead_id, meta_campaign_id, status, duration_days |

### DesignBot Tables
| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `design_jobs` | Design requests | id, lead_id, type (ai/human), status, prompt, result_url, designer_id, price |
| `designers` | Human designers | id, name, email, phone, specialties, is_active, current_workload |

### ContentBot Tables
| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `content_calendar` | Content schedule | id, lead_id, post_date, post_type, content_text, status, scheduled_at |

### Multi-Agent Table
| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `agent_handoff` | Agent coordination | id, lead_id, from_agent, to_agent, context (JSONB), status, result |

### Page Access
| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `page_access_requests` | Client page tracking | id, lead_id, page_id, page_name, status |

---

## 7. Configuration

### Centralized Tokens (`~/.mcp-tokens.env`)
| Variable | Purpose |
|----------|---------|
| N8N_ADMETRICAS_MCP_TOKEN | n8n MCP server (27 tools) |
| N8N_ADMETRICAS_API_KEY | n8n REST API (workflow CRUD) |
| N8N_YAVINGOS_MCP_TOKEN | n8n.yavingos.com MCP |
| DB_ADMETRICAS_URL | PostgreSQL local connection string |
| DB_TECBITE_URL | PostgreSQL remote (Tecbite) |
| META_PAGE_ACCESS_TOKEN | Meta Graph API (60-day token) |
| MESSENGER_PAGE_ACCESS_TOKEN | Messenger Send API |

### Monorepo `.env` (gitignored)
Contains all Hermes + CRM + Meta + OpenRouter + Gemini + DesignBot + ContentBot configuration.

---

## 8. Deployment

### Docker Services
| Service | Container | Port | Stack |
|---------|-----------|------|-------|
| hermes | hermes | 8009:8000 | Python 3.11 / FastAPI / uvicorn |
| crm | delegads-crm | 8086:80 | PHP 8.3 / Apache / Laravel 11 |
| web | delegads-web | 8087:3000 | Node 20 / Nuxt 3 / Nitro |
| n8n | n8n (external) | 5678 | n8n (n8n.admetricas.com) |
| postgres | laravel-postgres (external) | 5432 | PostgreSQL 15 |

### Network
All services communicate via `railes_network` (Docker external network).

### Reverse Proxy
Nginx Proxy Manager (NPM) on VPS handles SSL and domain routing:
- `hermes.admetricas.com` → Hermes (port 8009)
- `n8n.admetricas.com` → n8n (port 5678)
- Future: `delegads.com` → Web, `crm.delegads.com` → CRM

---

## 9. Agent Flow — Complete Client Lifecycle

```
1. LEAD CAPTURE
   Client writes via WhatsApp / Instagram DM / Messenger
   → n8n webhook → Parse → Upsert lead in DB
   → AI Agent (Valeria) responds with pricing

2. PAYMENT
   Client sends payment receipt (image)
   → Hermes /validate-receipt → OCR (amount, ref, bank)
   → Validate Payment Amount node: compares amount vs plan price
   → If match: proceed. If mismatch: Valeria asks for correct payment

3. CAMPAIGN CREATION
   Payment verified → Valeria triggers campaign creation
   → Hermes /create-campaign with:
     - page_id (from lead, dynamic)
     - instagram_actor_id (from lead, dynamic)
     - destination (instagram_profile/dm/whatsapp/messenger)
     - creative (existing post or new with AI-optimized copy)
   → Campaign created in PAUSED status
   → Valeria notifies client

4. DESIGN SERVICE (optional)
   Client wants design → Valeria handoff via agent_handoff table
   → Design Handoff Handler workflow (cron 2min) picks up
   → DesignBot: AI generation ($5) or human designer ($15)
   → Result sent to client via WhatsApp
   → Client approves/rejects
   → 7-day fallback: if human doesn't deliver, auto-switch to AI

5. SOCIAL MEDIA MANAGEMENT (optional, $180/month)
   Client contracts → ContentBot briefing (5 questions)
   → AI generates monthly calendar (3 posts/week + 1 reel + 2 stories/day)
   → Calendar stored in DB → CRM displays it
   → Posts scheduled via Meta Graph API

6. REMARKETING
   Every 6 hours, Remarketing workflow checks:
   - Level 1: Cold leads (+48h) → re-engagement message
   - Level 2: Abandoned payments (+24h) → payment reminder
   - Level 3: Campaigns expiring (2 days) → renewal offer

7. REPORTING
   Daily: campaign stats via Hermes /campaign-stats
   Weekly: summary with recommendations
   → Sent to client via WhatsApp

8. CRM DASHBOARD
   Alfredo monitors everything from:
   - Web: crm.delegads.com (Filament panel)
   - Mobile: Delegads app (Flutter, iOS + Android)
   - Metrics: leads, conversion funnel, MRR, active campaigns, pending designs
```

---

## 10. Multi-Agent Coordination

```
                    ┌─────────────┐
                    │   VALERIA   │ (Sales + Onboarding)
                    │  n8n AI Agent│
                    └──────┬──────┘
                           │
                    detects intent
                           │
                    ┌──────▼──────┐
                    │ agent_handoff│ (DB table)
                    │   table      │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌─────────┐  ┌─────────┐  ┌─────────┐
        │DesignBot│  │ContentBot│  │ReportBot│
        │ Hermes  │  │ Hermes  │  │ Hermes  │
        │/generate│  │/briefing│  │/stats   │
        │-design  │  │/calendar│  │         │
        └─────────┘  └─────────┘  └─────────┘
              │            │            │
              ▼            ▼            ▼
         AI or Human   Calendar     Meta Insights
         Designer      + Posts      + Report
              │            │            │
              └────────────┼────────────┘
                           │
                    ┌──────▼──────┐
                    │ PostgreSQL  │
                    │  fb_google  │
                    └─────────────┘
```

---

## 11. Development Setup

### Prerequisites
- Docker + Docker Compose
- Python 3.11+ (for Hermes development)
- PHP 8.2+ + Composer (for CRM development)
- Node.js 18+ (for Nuxt development)
- Flutter SDK (for mobile development)

### Local Development
```bash
# Clone
git clone git@github.com:romeroa14/delegads.git
cd delegads

# Copy env
cp .env.example .env
# Edit .env with real values

# Start Hermes
docker compose up -d hermes
curl http://localhost:8009/health  # Should return "healthy"

# Start CRM
cd crm && php artisan serve --port=8086
# Visit http://localhost:8086/crm

# Start Web
cd web && npm run dev
# Visit http://localhost:3000

# Mobile
cd mobile && flutter pub get && flutter run
```

### VPS Deployment
```bash
ssh adminvps@158.69.215.35
cd /var/www/html/delegads
git pull origin main
docker compose up -d
```

---

## 12. Security Notes

- `.env` is gitignored — never commit real tokens
- Meta token is 60-day long-lived (regenerate via Graph API exchange)
- CRM uses Sanctum token auth for API
- Webhook verification uses `igbot` verify token
- All Meta API calls use Page Access Token (not user token)
- n8n workflows deployed via REST API with API key auth
- MCP tokens centralized in `~/.mcp-tokens.env`

---

## 13. Known Issues & Limitations

| Issue | Status | Workaround |
|-------|--------|------------|
| WhatsApp campaigns can't use CONVERSATIONS optimization | Resolved | Fallback to IMPRESSIONS (error_subcode 2446921) |
| Instagram Business not linked to Facebook Page | Pending | User needs to link in Meta Business Suite |
| Filament 5 requires Laravel 12 | Resolved | Using Filament 3.3.54 (compatible with Laravel 11) |
| No test runner | Known | Smoke tests only (curl + health check) |
| No git remote on adsvnzla_bot | Known | Delegads repo is the canonical going forward |
| OpenRouter image generation model availability | Pending | Verify google/imagen-3 or use fallback model |

---

*Documentation maintained as part of the Delegads.com monorepo.*
