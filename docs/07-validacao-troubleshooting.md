# Validacao e troubleshooting

## Validadores

Os scripts PowerShell em `scripts/` verificam se os workflows exportados mantem a estrutura esperada.

Rodar um validador:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-review-workflow.ps1
```

Rodar todos:

```powershell
Get-ChildItem scripts -Filter "validate-*.ps1" |
  ForEach-Object { powershell -ExecutionPolicy Bypass -File $_.FullName }
```

Validadores disponiveis:

- `validate-review-workflow.ps1`
- `validate-compliance-workflow.ps1`
- `validate-document-workflow.ps1`
- `validate-tests-workflow.ps1`
- `validate-pull-request-review-workflow.ps1`
- `validate-pull-request-tests-workflow.ps1`
- `validate-history-list-workflow.ps1`
- `validate-history-detail-workflow.ps1`
- `validate-analytics-usage-workflow.ps1`
- `validate-batch-workflow.ps1`
- `validate-deploy-workflow.ps1`

## Problemas comuns

### Endpoint retorna 404

Confirme:

- o workflow foi importado;
- o workflow esta ativo;
- a URL usa `/webhook/...` em producao;
- durante teste manual, a URL temporaria pode ser `/webhook-test/...`;
- o path do Webhook node corresponde ao esperado.

### Editor abre, mas webhook nao exige Basic Auth

O Basic Auth do n8n protege o editor. Os Webhook nodes exportados nao possuem autenticacao propria. Proteja `/webhook/*` via Nginx/gateway ou adicione auth diretamente nos nodes.

### Erro em nodes PostgreSQL

Verifique:

- credencial `case-n8n Postgres`;
- host `postgres` quando estiver dentro do Docker Compose;
- usuario, senha e banco iguais ao `.env`;
- container `postgres` saudavel;
- SQL bootstrap executado em `infra/sql/init`.

### Erro em nodes OpenRouter

Verifique:

- credencial `OpenRouter account`;
- chave `OPENROUTER_API_KEY`;
- modelo enviado no payload;
- disponibilidade do modelo no provedor;
- logs do node LangChain/OpenRouter no editor n8n.

### Fluxos de PR falham

Verifique:

- `github_pull_request_url` no formato `https://github.com/org/repo/pull/123`;
- credencial `GitHub account`;
- permissao para ler PR, diff e arquivos;
- limite de tamanho do diff;
- se Jira foi enviado, `jira_base_url` precisa ser HTTPS e a credencial `Jira account` deve estar configurada.

### Batch retorna erro nos itens

O batch chama os fluxos individuais por HTTP interno usando `http://127.0.0.1:5678/webhook/api/v1/...`.

Confirme:

- workflows individuais ativos;
- paths sem rewrite inesperado;
- payload de cada item valido para o fluxo;
- `continue_on_error` conforme comportamento desejado.

### History sem dados

Os dados aparecem depois que algum fluxo cria execucao em `executions`. Se apenas o `health` foi chamado, nao ha execucao persistida. Rode `review`, `tests`, `document`, `compliance` ou os fluxos de PR e consulte novamente.

### Analytics zerado

Analytics agrega `executions` e `execution_telemetry`. Se as execucoes vierem somente de cache antigo sem telemetry, alguns campos podem ficar zerados. Gere uma nova execucao sem cache para validar.

## Checklist rapido pos-importacao

1. Abrir editor n8n.
2. Confirmar credenciais.
3. Importar workflows.
4. Salvar e ativar workflows.
5. Chamar `/webhook/health`.
6. Chamar `/webhook/api/v1/review` com payload pequeno.
7. Consultar `/webhook/api/v1/history`.
8. Consultar `/webhook/api/v1/analytics/usage`.
9. Rodar validadores antes de versionar mudancas.
