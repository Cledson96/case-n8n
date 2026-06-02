# Dados, cache e telemetria

## Banco de dados

O PostgreSQL e usado pelo proprio n8n e tambem por tabelas customizadas do case.

O bootstrap fica em:

```text
infra/sql/init/001_create_agent_runs.sql
```

Tabelas principais:

| Tabela | Papel |
|--------|-------|
| `executions` | Registro principal de cada chamada de fluxo |
| `execution_steps` | Passos internos da execucao, como cache, tools e agentes |
| `execution_telemetry` | Modelo, tokens e custo estimado por execucao |
| `batch_executions` | Resumo das execucoes em lote |
| `agent_runs` | Compatibilidade com uma versao anterior do bootstrap |

## Modelo de execucao

Cada fluxo de IA cria uma linha em `executions` com:

- `flow_type`
- `status`
- `input_payload`
- `output_payload`
- `duration_ms`
- `request_hash`
- `cache_hit`
- `source_execution_id`
- `error_message`

Quando ha cache hit, o workflow cria uma nova execucao marcada como `cache_hit=true` e aponta `source_execution_id` para a execucao original.

## Cache

Os fluxos `review`, `compliance`, `document`, `tests`, `pull_request_review` e `pull_request_tests` calculam hash do payload normalizado.

Processo:

1. normaliza campos relevantes do request;
2. calcula `request_hash`;
3. busca a ultima execucao `success` do mesmo `flow_type` e hash;
4. se existir, retorna `output_payload` persistido;
5. se nao existir, cria execucao `pending` e roda os agentes.

Esse cache evita custo repetido em requests identicos e deixa a origem rastreavel pelo `source_execution_id`.

## Steps

Os fluxos gravam steps para explicar o que aconteceu internamente.

Exemplos:

- `cache_lookup`
- `language_router`
- `deterministic_tools`
- `requirements_extractor`
- `document_signal_extractor`
- `tests_signal_extractor`
- `review_aggregator_agent`
- `compliance_agent`
- `document_agent`
- `tests_agent`

Cada step armazena tipo (`kind`), status, payload de entrada/saida, duracao e erro quando houver.

## Telemetria

A tabela `execution_telemetry` guarda:

- `provider`
- `model_requested`
- `model_used`
- `prompt_tokens`
- `completion_tokens`
- `total_tokens`
- `cost_usd`
- `input_cost_usd`
- `output_cost_usd`
- `cache_read_tokens`

Nos fluxos de codigo direto, tokens e custos sao estimados no proprio workflow. A estimativa atual usa uma aproximacao simples de caracteres por token e os valores de referencia usados no case para `openai/gpt-4o-mini`.

Nos fluxos de Pull Request, a telemetria registra provedor/modelo e pode ser expandida para persistir tokens reais quando a integracao do node fornecer essa informacao diretamente.

## Historico

`GET /webhook/api/v1/history` lista execucoes com filtros por:

- fluxo;
- status;
- modelo;
- intervalo de datas;
- cache hit;
- paginacao por cursor.

`GET /webhook/api/v1/history/:id` retorna o detalhe da execucao com input, output, telemetry e steps.

## Analytics

`GET /webhook/api/v1/analytics/usage` agrega:

- total de execucoes;
- sucesso/falha;
- cache hits;
- tokens;
- custos;
- duracao media;
- agrupamento por dia;
- agrupamento por fluxo;
- agrupamento por modelo.

Filtros opcionais:

- `flow_type`
- `model`
- `from`
- `to`
