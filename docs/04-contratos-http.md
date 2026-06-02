# Contratos HTTP

Base de producao padrao:

```text
https://n8n.preambulo.cledson.com.br/webhook
```

As rotas abaixo sao relativas a essa base. Por exemplo, `POST /api/v1/review` significa `POST https://n8n.preambulo.cledson.com.br/webhook/api/v1/review`.

## Linguagens suportadas

Os fluxos de codigo aceitam:

- `typescript`
- `javascript`
- `python`
- `php`

## POST /api/v1/review

Request:

```json
{
  "code": "function sum(a, b) { return a + b; }",
  "language": "javascript",
  "context": "Contexto opcional",
  "model": "openai/gpt-4o-mini",
  "prompt_version": 1
}
```

Campos obrigatorios: `code`, `language`.

Response:

```json
{
  "overall_quality": "needs_improvement",
  "score": 7,
  "issues": [
    {
      "severity": "medium",
      "line_hint": "linha 1",
      "description": "Descricao objetiva do problema.",
      "suggestion": "Sugestao acionavel."
    }
  ],
  "positives": ["Ponto positivo observado."],
  "summary": "Resumo do review."
}
```

## POST /api/v1/review/pull-request

Request:

```json
{
  "github_pull_request_url": "https://github.com/org/repo/pull/123",
  "base_branch": "main",
  "jira_issue_key": "CPJ-123",
  "jira_base_url": "https://empresa.atlassian.net",
  "model": "openai/gpt-4o-mini",
  "prompt_version": 1
}
```

Obrigatorio: `github_pull_request_url`.

`jira_issue_key` e `jira_base_url` sao opcionais em conjunto. Quando `jira_issue_key` for enviado, `jira_base_url` precisa ser HTTPS.

Response:

```json
{
  "verdict": "needs_attention",
  "score": 75,
  "summary": "Resumo consolidado da analise do PR.",
  "pull_request": {
    "owner": "org",
    "repo": "repo",
    "number": 123,
    "title": "Pull request #123",
    "base_branch": "main",
    "head_sha": "abc123",
    "changed_files": 4
  },
  "jira": null,
  "sections": {
    "code_standard": { "status": "warning", "findings": [] },
    "project_consistency": { "status": "warning", "findings": [] },
    "security": { "status": "warning", "findings": [] },
    "jira_criteria": { "status": "skipped", "criteria": [] }
  },
  "positives": [],
  "recommendations": []
}
```

## POST /api/v1/compliance

Request:

```json
{
  "task_description": "Registrar tentativa de contato com devedor.",
  "code": "app.post('/contatos', async (req, res) => res.status(201).json({ ok: true }));",
  "language": "javascript",
  "model": "openai/gpt-4o-mini"
}
```

Campos obrigatorios: `task_description`, `code`, `language`.

Response:

```json
{
  "compliant": false,
  "compliance_score": 60,
  "covered_requirements": [],
  "missing_requirements": ["Nao ha evidencia de persistencia da tentativa de contato."],
  "partial_requirements": [],
  "verdict": "A implementacao cobre apenas parte da tarefa."
}
```

## POST /api/v1/document

Request:

```json
{
  "code": "export function charge(amount: number) { return amount > 0; }",
  "language": "typescript",
  "doc_type": "technical",
  "model": "openai/gpt-4o-mini"
}
```

Campos obrigatorios: `code`, `language`, `doc_type`.

`doc_type` aceita `technical` ou `operational`.

Response:

```json
{
  "doc_type": "technical",
  "title": "Servico de cobranca",
  "description": "Descricao da rotina analisada.",
  "inputs": [
    {
      "name": "amount",
      "type": "number",
      "description": "Valor da cobranca."
    }
  ],
  "outputs": [
    {
      "name": "return",
      "type": "boolean",
      "description": "Indica se o valor e positivo."
    }
  ],
  "side_effects": [],
  "usage_example": "charge(100)",
  "notes": null
}
```

## POST /api/v1/tests

Request:

```json
{
  "code": "export function charge(amount: number) { return amount > 0; }",
  "language": "typescript",
  "test_framework": "vitest",
  "model": "openai/gpt-4o-mini"
}
```

Campos obrigatorios: `code`, `language`, `test_framework`.

Response:

```json
{
  "framework": "vitest",
  "test_file": "import { expect, it } from 'vitest';\n\nit('valida valor positivo', () => {\n  expect(charge(100)).toBe(true);\n});",
  "test_cases": [
    {
      "name": "valida valor positivo",
      "type": "happy_path",
      "description": "Cobre o caminho principal."
    }
  ],
  "coverage_hints": []
}
```

## POST /api/v1/tests/pull-request

Request:

```json
{
  "github_pull_request_url": "https://github.com/org/repo/pull/123",
  "base_branch": "main",
  "test_framework": "vitest",
  "model": "openai/gpt-4o-mini"
}
```

Campos obrigatorios: `github_pull_request_url`, `test_framework`.

Response: mesmo contrato do `/api/v1/tests`. O campo `test_file` deve conter o codigo-fonte completo do teste, nao apenas um caminho.

## POST /api/v1/batch

Request:

```json
{
  "continue_on_error": true,
  "notify": false,
  "items": [
    {
      "flow_type": "review",
      "payload": {
        "code": "function sum(a, b) { return a + b; }",
        "language": "javascript"
      }
    },
    {
      "flow_type": "tests",
      "payload": {
        "code": "export function charge(amount: number) { return amount > 0; }",
        "language": "typescript",
        "test_framework": "vitest"
      }
    }
  ]
}
```

`flow_type` aceita `review`, `compliance`, `document` e `tests`.

Response:

```json
{
  "batch_id": "uuid",
  "status": "success",
  "results": [
    {
      "index": 0,
      "flow_type": "review",
      "status": "success",
      "output": {}
    }
  ]
}
```

## GET /api/v1/history

Query params:

- `limit`: inteiro de 1 a 100, default `20`
- `cursor`: id da ultima execucao da pagina anterior
- `flow_type`: `review`, `compliance`, `document`, `tests`, `batch`, `pull_request_review`, `pull_request_tests`
- `status`: `pending`, `success`, `failed`
- `model`: modelo solicitado
- `from`: data inicial
- `to`: data final
- `cache_hit`: `true` ou `false`

Response:

```json
{
  "items": [],
  "page": {
    "limit": 20,
    "next_cursor": null
  }
}
```

## GET /api/v1/history/:id

Retorna input, output, telemetria e steps de uma execucao. IDs invalidos retornam erro `bad_request`; IDs validos nao encontrados retornam `not_found`.

## GET /api/v1/analytics/usage

Query params opcionais:

- `flow_type`
- `model`
- `from`
- `to`

Response:

```json
{
  "totals": {
    "executions": 0,
    "successful": 0,
    "failed": 0,
    "cache_hits": 0,
    "prompt_tokens": 0,
    "completion_tokens": 0,
    "total_tokens": 0,
    "cache_read_tokens": 0,
    "cost_total_usd": 0,
    "cost_input_usd": 0,
    "cost_output_usd": 0,
    "average_duration_ms": 0
  },
  "by_day": [],
  "by_flow": [],
  "by_model": []
}
```
