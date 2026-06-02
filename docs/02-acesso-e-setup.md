# Acesso e setup

## URLs

Editor n8n:

- Local: `http://localhost:5678`
- Producao: `https://n8n.preambulo.cledson.com.br`

Webhooks em producao:

- Base local: `http://localhost:5678/webhook`
- Base producao: `https://n8n.preambulo.cledson.com.br/webhook`

Exemplo:

```http
POST https://n8n.preambulo.cledson.com.br/webhook/api/v1/review
Content-Type: application/json
```

Durante execucao de teste pelo editor, o n8n pode gerar URLs temporarias com `/webhook-test/...`. Para consumo externo estavel, ative o workflow e use `/webhook/...`.

## Subindo localmente

```bash
cp .env.example .env
docker compose up -d
```

Antes de subir em um ambiente compartilhado, ajuste no `.env`:

- `POSTGRES_PASSWORD`
- `N8N_BASIC_AUTH_USER`
- `N8N_BASIC_AUTH_PASSWORD`
- `N8N_ENCRYPTION_KEY`
- `OPENROUTER_API_KEY`

Depois confira:

```bash
docker compose ps
docker compose logs -f n8n
```

## Credenciais no n8n

Crie as credenciais com os mesmos nomes usados pelos workflows exportados:

| Nome | Tipo esperado | Uso |
|------|---------------|-----|
| `case-n8n Postgres` | PostgreSQL | Cache, historico, steps, batch e analytics |
| `OpenRouter account` | OpenRouter/LangChain | Chamadas LLM |
| `GitHub account` | GitHub API | Fluxos de Pull Request |
| `Jira account` | Jira API | Criterios Jira opcionais no review de PR |

Para o PostgreSQL no Docker Compose:

- host: `postgres`
- port: `5432`
- database: valor de `POSTGRES_DB`
- user: valor de `POSTGRES_USER`
- password: valor de `POSTGRES_PASSWORD`

## Importando workflows

1. Acesse o editor n8n.
2. Crie as credenciais acima.
3. Importe os arquivos JSON de `workflows/`.
4. Confirme se os nodes de credencial apontam para as credenciais corretas.
5. Salve e ative cada workflow que sera consumido.
6. Use as URLs de producao exibidas pelo Webhook node, normalmente em `/webhook/...`.

Ordem sugerida:

1. `health.json`
2. `review.json`
3. `compliance.json`
4. `document.json`
5. `tests.json`
6. `pull-request-review.json`
7. `pull-request-tests.json`
8. `history-list.json`
9. `history-detail.json`
10. `analytics-usage.json`
11. `batch.json`

O `batch` chama internamente `/webhook/api/v1/review`, `/webhook/api/v1/compliance`, `/webhook/api/v1/document` e `/webhook/api/v1/tests`; por isso esses workflows precisam estar ativos antes do batch.

## Testando

Use `examples/case.http` ou qualquer cliente HTTP.

```http
POST http://localhost:5678/webhook/api/v1/tests
Content-Type: application/json

{
  "code": "export function calcularJurosSimples(principal, taxaMensal, meses) { return principal * (1 + taxaMensal * meses); }",
  "language": "typescript",
  "test_framework": "vitest"
}
```

## Autenticacao dos webhooks

O Basic Auth configurado por `N8N_BASIC_AUTH_ACTIVE=true` protege o editor n8n. Os Webhook nodes deste repositorio nao declaram autenticacao propria no JSON exportado.

Para ambiente publico, use uma das estrategias:

- proteger `/webhook/*` no Nginx com Basic Auth ou outra politica;
- adicionar autenticacao diretamente nos Webhook nodes;
- expor os webhooks apenas em rede privada/VPN;
- colocar um gateway autenticado na frente do n8n.
