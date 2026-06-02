# Deploy e operacao

## Runtime

O `docker-compose.yml` sobe:

- `postgres`: PostgreSQL 16 Alpine;
- `n8n`: imagem oficial `docker.n8n.io/n8nio/n8n:latest`.

O n8n usa PostgreSQL como banco interno e monta `./.n8n` em `/home/node/.n8n` para persistir configuracoes locais, credenciais criptografadas e estado do editor.

## Variaveis de ambiente

Principais variaveis:

| Variavel | Uso |
|----------|-----|
| `N8N_HOST_PORT` | Porta local exposta em `127.0.0.1` |
| `POSTGRES_DB` | Banco PostgreSQL |
| `POSTGRES_USER` | Usuario PostgreSQL |
| `POSTGRES_PASSWORD` | Senha PostgreSQL |
| `N8N_HOST` | Host publico |
| `N8N_PROTOCOL` | `http` ou `https` |
| `WEBHOOK_URL` | Base publica usada pelos webhooks |
| `N8N_EDITOR_BASE_URL` | Base publica do editor |
| `N8N_BASIC_AUTH_ACTIVE` | Liga Basic Auth no editor |
| `N8N_BASIC_AUTH_USER` | Usuario do editor |
| `N8N_BASIC_AUTH_PASSWORD` | Senha do editor |
| `N8N_ENCRYPTION_KEY` | Chave de criptografia das credenciais |
| `OPENROUTER_API_KEY` | Chave do provedor LLM |
| `LANGSMITH_*` / `LANGCHAIN_*` | Tracing opcional |

`N8N_ENCRYPTION_KEY` deve ser estavel entre deploys. Trocar essa chave sem migrar credenciais pode impedir o n8n de descriptografar credenciais antigas.

## Deploy por GitHub Actions

O arquivo `.github/workflows/deploy-production.yml` roda no push para `main`.

Fluxo:

1. Faz checkout do repositorio.
2. Valida arquivos obrigatorios.
3. Conecta na VPS por SSH.
4. Clona ou atualiza o repositorio no diretorio de producao.
5. Gera `.env.production` a partir de secrets.
6. Ajusta permissao da pasta `.n8n`.
7. Recria os containers com Docker Compose.
8. Instala/configura Nginx e Certbot se necessario.
9. Valida HTTP local e HTTPS publico.

Secrets esperados:

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

## Nginx

O exemplo em `infra/nginx/n8n.preambulo.cledson.com.br.conf` encaminha todo trafego para o n8n local:

```text
https://n8n.preambulo.cledson.com.br -> http://127.0.0.1:5678
```

O workflow de deploy tambem cria uma configuracao Nginx equivalente e habilita TLS com Certbot.

Se quiser expor endpoints sem `/webhook`, e necessario adicionar uma regra explicita de rewrite/proxy. A configuracao atual nao faz essa remocao; portanto os endpoints padrao continuam em `/webhook/...`.

## Rotina operacional

Comandos uteis na VPS:

```bash
docker compose --env-file .env.production ps
docker compose --env-file .env.production logs -f n8n
docker compose --env-file .env.production logs -f postgres
docker compose --env-file .env.production pull
docker compose --env-file .env.production up -d --remove-orphans
```

Health check:

```bash
curl -i https://n8n.preambulo.cledson.com.br
curl -i https://n8n.preambulo.cledson.com.br/webhook/health
```

## Backup

Para preservar uma instalacao:

- backup do volume `postgres-data`;
- backup da pasta `.n8n`;
- backup seguro dos secrets usados no deploy;
- export periodico dos workflows atualizados pelo editor.

## Atualizacao de workflows

Quando alterar workflows pelo editor n8n:

1. exporte o JSON atualizado;
2. substitua o arquivo correspondente em `workflows/`;
3. rode o script de validacao;
4. versione a mudanca no Git;
5. importe/ative no ambiente alvo quando necessario.
