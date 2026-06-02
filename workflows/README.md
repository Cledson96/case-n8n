# Workflows n8n

Este diretorio contem os workflows exportados do n8n para o case CPJ-Cobranca AI.

## Inventario

| Arquivo | Endpoint de producao padrao | Descricao |
|---------|-----------------------------|-----------|
| `health.json` | `GET /webhook/health` | Health check simples |
| `review.json` | `POST /webhook/api/v1/review` | Review multi-agente de codigo |
| `pull-request-review.json` | `POST /webhook/api/v1/review/pull-request` | Review de Pull Request via GitHub e Jira opcional |
| `compliance.json` | `POST /webhook/api/v1/compliance` | Aderencia entre tarefa e implementacao |
| `document.json` | `POST /webhook/api/v1/document` | Documentacao tecnica ou operacional |
| `tests.json` | `POST /webhook/api/v1/tests` | Geracao de testes por codigo |
| `pull-request-tests.json` | `POST /webhook/api/v1/tests/pull-request` | Geracao de testes baseada em Pull Request |
| `batch.json` | `POST /webhook/api/v1/batch` | Execucao sequencial de fluxos |
| `history-list.json` | `GET /webhook/api/v1/history` | Lista execucoes persistidas |
| `history-detail.json` | `GET /webhook/api/v1/history/:id` | Detalhe de execucao |
| `analytics-usage.json` | `GET /webhook/api/v1/analytics/usage` | Agregacao de uso, tokens e custos |

## Credenciais esperadas

| Nome no workflow | Uso |
|------------------|-----|
| `case-n8n Postgres` | Nodes PostgreSQL |
| `OpenRouter account` | Nodes LangChain/OpenRouter |
| `GitHub account` | Fluxos de Pull Request |
| `Jira account` | Criterios Jira opcionais no review de PR |

## Importacao

1. Suba o stack com `docker compose up -d`.
2. Acesse o editor n8n.
3. Crie as credenciais esperadas.
4. Importe os JSONs deste diretorio.
5. Revise os nodes de credenciais apos importar.
6. Salve e ative os workflows.

O `batch.json` depende dos workflows individuais ativos, pois chama internamente:

- `/webhook/api/v1/review`
- `/webhook/api/v1/compliance`
- `/webhook/api/v1/document`
- `/webhook/api/v1/tests`

## Validacao estrutural

Os scripts em `scripts/` verificam os nodes, conexoes e marcadores importantes dos workflows:

```powershell
Get-ChildItem scripts -Filter "validate-*.ps1" |
  ForEach-Object { powershell -ExecutionPolicy Bypass -File $_.FullName }
```

## Observacoes

- Os paths dentro dos Webhook nodes sao `health` e `api/v1/...`.
- Em producao, o n8n publica esses paths normalmente sob `/webhook/...`.
- Durante teste manual no editor, use a URL temporaria `/webhook-test/...` exibida pelo proprio n8n.
- Os workflows exportados nao aplicam autenticacao propria nos Webhook nodes.
