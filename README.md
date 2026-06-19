# Delegads.com

Delegated marketing agency platform — multi-agent system for automated marketing services in Venezuela.

## Structure

| Directory | Service | Stack | Status |
|-----------|---------|-------|--------|
| `hermes/` | Executor agent | Python 3.11 / FastAPI | Active |
| `crm/` | Admin panel | Laravel 11 / Filament PHP 5 | Pending |
| `web/` | Public website | Nuxt.js 4 | Pending |
| `mobile/` | Mobile app | Flutter / Dart | Pending |
| `n8n-workflows/` | Workflow exports | n8n JSON | Pending |
| `shared/db/` | DB migrations | SQL | Pending |

## Infrastructure

- **Database**: PostgreSQL `fb_google` (shared, external)
- **Orchestrator**: n8n (n8n.admetricas.com, external)
- **Network**: `railes_network` (Docker external network)
- **Deployment**: Docker Compose

## Development

```bash
# Start Hermes
docker compose up -d hermes

# Health check
curl http://localhost:8009/health
```

## License

Proprietary — Delegads.com
