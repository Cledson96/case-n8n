# CPJ-Cobranca AI - n8n

Implementacao do case tecnico CPJ-Cobranca usando `n8n` como orquestrador dos fluxos de IA.

Este repositorio entrega a mesma proposta funcional do `case-ts`, mas em formato low-code: os endpoints sao Webhook nodes do n8n, os agentes rodam com LangChain/OpenRouter dentro dos workflows, e o historico fica persistido em PostgreSQL.

## Funcionalidades

- **Review de codigo** multi-linguagem com agentes especialistas de naming, error handling, resource leak, complexity, security e agregador final.
- **Review de Pull Request** via GitHub, com avaliacao de padroes, consistencia do projeto, seguranca e Jira opcional.
- **Compliance** entre tarefa e codigo implementado.
- **Documentacao** tecnica ou operacional a partir de codigo.
- **Geracao de testes** a partir de codigo ou Pull Request.
- **Batch** para executar `review`, `compliance`, `document` e `tests` em sequencia.
- **Historico, cache e telemetria** em PostgreSQL, com lista, detalhe e agregacao de uso/custos.
- **Deploy em VPS** via GitHub Actions, Docker Compose, PostgreSQL e Nginx.

## Como acessar

### Editor n8n

- Local: `http://localhost:5678`
- Producao: `https://n8n.preambulo.cledson.com.br`

O acesso ao editor usa Basic Auth pelas variaveis `N8N_BASIC_AUTH_USER` e `N8N_BASIC_AUTH_PASSWORD`.

### Webhooks da API

No n8n, os Webhook nodes expostos em producao usam a base `/webhook`. Como os workflows foram exportados com paths `api/v1/...`, as URLs padrao ficam assim:

| Metodo | URL |
|--------|-----|
| GET | `/webhook/health` |
| POST | `/webhook/api/v1/review` |
| POST | `/webhook/api/v1/review/pull-request` |
| POST | `/webhook/api/v1/compliance` |
| POST | `/webhook/api/v1/document` |
| POST | `/webhook/api/v1/tests` |
| POST | `/webhook/api/v1/tests/pull-request` |
| POST | `/webhook/api/v1/batch` |
| GET | `/webhook/api/v1/history` |
| GET | `/webhook/api/v1/history/:id` |
| GET | `/webhook/api/v1/analytics/usage` |

Durante testes manuais dentro do editor, o n8n pode expor a variante `/webhook-test/...` enquanto o workflow estiver em modo de teste. Para uso real, ative o workflow e use `/webhook/...`.

> Observacao de seguranca: os workflows exportados nao configuram autenticacao individual nos Webhook nodes. O Basic Auth do editor protege a interface do n8n; para expor os webhooks publicamente, use autenticacao no proxy/Nginx, adicione auth nos Webhook nodes ou mantenha o endpoint restrito.

## Quick Start local

```bash
cp .env.example .env
# Edite .env e informe OPENROUTER_API_KEY, N8N_ENCRYPTION_KEY e senhas fortes
docker compose up -d
```

Depois acesse `http://localhost:5678`, crie ou configure as credenciais abaixo e importe os JSONs de `workflows/`:

| Credencial no workflow | Uso |
|------------------------|-----|
| `case-n8n Postgres` | Nos nodes PostgreSQL de cache, historico, steps, batch e analytics |
| `OpenRouter account` | Nos nodes LangChain/OpenRouter dos agentes de IA |
| `GitHub account` | Nos fluxos de Pull Request |
| `Jira account` | Apenas quando `jira_issue_key` e `jira_base_url` forem enviados |

Ative os workflows importados antes de chamar as URLs de producao.

## Exemplo de request

```http
POST https://n8n.preambulo.cledson.com.br/webhook/api/v1/review
Content-Type: application/json

{
  "code": "export function sum(a: number, b: number) { return a + b; }",
  "language": "typescript",
  "context": "Funcao utilitaria do modulo financeiro",
  "model": "openai/gpt-4o-mini"
}
```

Resposta esperada:

```json
{
  "overall_quality": "good",
  "score": 9,
  "issues": [],
  "positives": ["Codigo simples e facil de entender."],
  "summary": "Review concluido."
}
```

Exemplos completos ficam em `examples/case.http`.

## Stack

| Camada | Tecnologia |
|--------|------------|
| Orquestracao | n8n |
| Banco | PostgreSQL 16 |
| IA | n8n LangChain nodes + OpenRouter |
| Runtime | Docker Compose |
| Deploy | GitHub Actions + SSH + Nginx |
| Persistencia customizada | Tabelas `executions`, `execution_steps`, `execution_telemetry`, `batch_executions` |

## Estrutura do projeto

```text
.
├── workflows/                       # Workflows n8n exportados em JSON
├── docs/                            # Documentacao do case n8n
├── examples/case.http               # Requests manuais
├── infra/sql/init/                  # Bootstrap SQL do PostgreSQL
├── infra/nginx/                     # Exemplo de reverse proxy
├── scripts/                         # Validadores estruturais dos workflows
├── .github/workflows/deploy-production.yml
├── docker-compose.yml
└── .env.example
```

## Documentacao

- `docs/01-visao-geral.md`: contexto, objetivos e diferencas para o case TypeScript.
- `docs/02-acesso-e-setup.md`: acesso local/producao, importacao dos workflows e credenciais.
- `docs/03-workflows-e-arquitetura.md`: arquitetura, inventario de workflows e fluxo interno.
- `docs/04-contratos-http.md`: contratos de entrada/saida dos endpoints.
- `docs/05-dados-cache-telemetria.md`: PostgreSQL, cache, historico, steps e analytics.
- `docs/06-deploy-e-operacao.md`: deploy na VPS, secrets, Nginx e rotina operacional.
- `docs/07-validacao-troubleshooting.md`: validadores e problemas comuns.

## Validacao

Os scripts em `scripts/` verificam a estrutura dos workflows exportados. Exemplo:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-review-workflow.ps1
powershell -ExecutionPolicy Bypass -File scripts/validate-tests-workflow.ps1
powershell -ExecutionPolicy Bypass -File scripts/validate-deploy-workflow.ps1
```

Para validar todos os workflows:

```powershell
Get-ChildItem scripts -Filter "validate-*.ps1" |
  ForEach-Object { powershell -ExecutionPolicy Bypass -File $_.FullName }
```

## Deploy

O deploy de producao roda no push para `main` usando `.github/workflows/deploy-production.yml`.

Secrets esperados no GitHub:

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
- `LETSENCRYPT_EMAIL`
- `LANGSMITH_API_KEY`

O workflow conecta na VPS por SSH, atualiza o repositorio, recria `.env.production`, sobe `n8n` + `postgres` com Docker Compose, configura Nginx e emite/valida certificado TLS com Certbot.
