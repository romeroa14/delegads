# Delegads CRM

Laravel 11 + Filament v3 admin panel for the Delegads.com monorepo. The CRM
sits on top of the shared PostgreSQL database (`fb_google` on
`laravel-postgres`) and exposes the same data that Hermes and the n8n
workflows use.

## Stack

- **Laravel 11** (PHP 8.2+)
- **Filament v3** admin panel mounted at `/crm`
- **PostgreSQL** (existing `fb_google` database)
- **Sanctum** API auth for the Flutter mobile app at `/api/v1/*`

## Local Setup

```bash
cd crm
cp .env.example .env
composer install
php artisan key:generate
php artisan serve --port=8086
```

Open <http://localhost:8086/crm/register> to create the first admin user
(Alfredo). The form is enabled on the panel provider.

## Production (Docker)

The `crm` service in `../docker-compose.yml` is currently commented out.
Uncomment the block to spin up the panel in the `railes_network` so it
shares the database with Hermes.

```yaml
crm:
  build: ./crm
  container_name: delegads-crm
  restart: unless-stopped
  ports:
    - "8086:80"
  env_file:
    - .env
  volumes:
    - ./crm:/var/www/html
  networks:
    - delegads-network
```

Inside the container set `DB_HOST=laravel-postgres` in `.env`.

## Panel

- URL: `/crm` (login, register, password reset, profile)
- Brand: **Delegads CRM**
- Registration: enabled (first user becomes admin)
- Email verification: required (toggle in `AdminPanelProvider`)

### Resources

| Resource | Table | Group |
|----------|-------|-------|
| `LeadResource` | `tenant_leads` | Sales Pipeline |
| `ConversationResource` | `tenant_messages` | Sales Pipeline |
| `CampaignResource` | `facebook_campaigns` | Marketing |
| `AdvertisingPlanResource` | `advertising_plans` | Marketing |
| `DesignJobResource` | `design_jobs` | Design Operations |
| `DesignerResource` | `designers` | Design Operations |

### Dashboard Widgets

- `TotalLeads` — total, hot, new today, active clients
- `ActiveCampaigns` — active, paused, total
- `PendingDesigns` — in progress, in review, approved, rejected
- `LeadsByStage` — doughnut chart of the pipeline
- `ConversionFunnel` — horizontal bar funnel from new → active

## API (Sanctum)

All endpoints require a `Bearer` token from
`User::createToken('mobile')->plainTextToken`.

```
GET  /api/v1/leads         ?stage=...&lead_level=...&intent=...&search=...&per_page=...
GET  /api/v1/leads/{id}
GET  /api/v1/design-jobs   ?status=...&type=...&per_page=...
GET  /api/v1/design-jobs/{id}
GET  /api/v1/campaigns     ?status=...&per_page=...
GET  /api/v1/campaigns/{id}
GET  /api/v1/metrics       # aggregated KPIs for the mobile dashboard
```

## Database Schema Notes

The CRM maps to the *current* table names. The original task brief
referenced `leads`, `conversations`, `campaigns`, `design_jobs`,
`designers`, `agent_handoff` — those names were migrated to
`tenant_leads`, `tenant_messages`, `facebook_campaigns` (plus
`design_jobs`, `designers`, `agent_handoff` which were re-applied
manually from `../shared/db/*.sql`). All models declare
`protected $table` explicitly to stay aligned with the live schema.

## Artisan helpers

```bash
php artisan migrate:status        # show migration state (does NOT migrate)
php artisan route:list            # inspect the panel + API routes
php artisan shield:install        # optional: install role/permission plugin
```
