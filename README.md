# case-n8n

Base repository for the `n8n` version of the CPJ-Cobranca AI case.

This repository is intentionally focused on the first delivery milestone:

- project structure ready for GitHub
- `docker compose` runtime for `n8n` + `PostgreSQL`
- VPS deployment through `GitHub Actions` + `SSH`
- host `Nginx` example for `n8n.preambulo.cledson.com.br`
- SQL bootstrap for custom execution history storage
- example HTTP requests for the case endpoints

## Planned structure

- `docker-compose.yml`: runtime stack for `n8n` and `PostgreSQL`
- `.env.example`: required environment variables
- `.github/workflows/deploy-production.yml`: production deployment pipeline
- `infra/nginx/n8n.preambulo.cledson.com.br.conf`: host `Nginx` example
- `infra/sql/init/001_create_agent_runs.sql`: history table bootstrap
- `workflows/`: exported `n8n` workflows
- `examples/case.http`: sample requests for the required endpoints

## Local setup

1. Copy the environment file:

```bash
cp .env.example .env
```

2. Adjust values if needed.

3. Start the stack:

```bash
docker compose up -d
```

4. Validate the local service:

```bash
curl http://localhost:5678
```

## GitHub repository secrets

Set these repository secrets before the first production deploy:

- `VPS_HOST`
- `VPS_USER`
- `VPS_SSH_KEY`
- `PRODUCTION_VPS_APP_DIR`
- `N8N_HOST_PORT`
- `POSTGRES_PASSWORD`
- `OPENROUTER_API_KEY`
- `N8N_BASIC_AUTH_USER`
- `N8N_BASIC_AUTH_PASSWORD`
- `N8N_ENCRYPTION_KEY`

## VPS runtime model

- `GitHub Actions` runs on every push to `main`
- the workflow connects to the VPS through `SSH`
- the VPS pulls the latest repository state
- `.env.production` is regenerated on the server
- `docker compose up -d --remove-orphans` refreshes the stack
- the host `Nginx` routes `n8n.preambulo.cledson.com.br` to the local `n8n` port

## Notes

- `workflows/` is ready to receive the exported JSON files from `n8n`
- the original challenge document is kept in the repository root for reference
- this milestone does not yet implement the `n8n` workflows themselves
