# Visao geral

Este projeto e a versao n8n do case tecnico CPJ-Cobranca AI. A ideia e demonstrar a mesma solucao do `case-ts`, mas usando workflows exportaveis do n8n como unidade principal de entrega.

O foco do case e automatizar analises tecnicas para um contexto de cobranca/recuperacao de credito:

- revisar codigo com criterios de seguranca, clareza, tratamento de erro e manutencao;
- comparar tarefa e implementacao para medir aderencia;
- gerar documentacao tecnica ou operacional;
- gerar testes;
- analisar Pull Requests do GitHub;
- manter historico auditavel das execucoes, com steps e telemetria.

## Diferenca para o case TypeScript

No `case-ts`, a solucao e uma API Fastify/TypeScript com modulos, services, testes automatizados e painel web. Neste repositorio, a API e composta por Webhook nodes do n8n. Cada workflow contem validacao, chamada aos agentes, normalizacao da resposta e persistencia.

Essa escolha mostra outra forma de entregar a mesma capacidade:

- menor volume de codigo de aplicacao;
- fluxos visuais importaveis e editaveis no n8n;
- integracao direta com credenciais e nodes prontos;
- persistencia customizada em PostgreSQL para manter rastreabilidade;
- deploy simples em VPS com Docker Compose.

## Estado atual

Os workflows principais ja estao exportados em `workflows/`:

- `health`
- `review`
- `review/pull-request`
- `compliance`
- `document`
- `tests`
- `tests/pull-request`
- `batch`
- `history`
- `analytics/usage`

Os fluxos de IA usam OpenRouter via LangChain nodes. Os fluxos utilitarios leem ou agregam dados do PostgreSQL.

## Principios da implementacao

- **Contratos parecidos com o case TS**: payloads e respostas seguem os mesmos nomes de campos principais.
- **Cache por hash do payload**: requests repetidos reaproveitam a ultima resposta bem-sucedida do mesmo fluxo.
- **Historico auditavel**: cada execucao grava entrada, saida, status, duracao, cache hit e steps.
- **Telemetria**: os fluxos persistem modelo solicitado/usado, tokens estimados e custo estimado quando aplicavel.
- **Portabilidade**: os workflows sao JSONs versionados, importaveis em qualquer instancia n8n com as credenciais equivalentes.

## Limites e decisoes conscientes

- Os Webhook nodes exportados nao possuem autenticacao propria; a protecao deve ser feita no proxy ou adicionada nos nodes antes de exposicao publica.
- A telemetria de tokens/custos dos fluxos de codigo direto e estimada no workflow a partir do tamanho dos prompts/respostas.
- O catalogo dinamico de prompts/modelos do `case-ts` nao foi reproduzido como CRUD separado; os workflows aceitam `model` e alguns aceitam `prompt_version`, mas os prompts estao embutidos no JSON exportado.
- Nao ha painel web proprio; a operacao acontece pelo editor n8n, pelos endpoints e pelas consultas de historico/analytics.
