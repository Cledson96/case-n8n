$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$workflowPath = Join-Path $root ".github/workflows/deploy-production.yml"

if (-not (Test-Path $workflowPath)) {
  throw "Deploy workflow not found: $workflowPath"
}

$workflow = Get-Content -Path $workflowPath -Raw

$requiredMarkers = @(
  "docker compose --env-file .env.production down --remove-orphans || true",
  "for container_name in case-n8n-postgres-1 case-n8n-n8n-1; do",
  "docker rm -f `"`${container_name}`" >/dev/null 2>&1 || true",
  "docker compose --env-file .env.production up -d --remove-orphans"
)

$missingMarkers = @($requiredMarkers | Where-Object { $workflow -notmatch [regex]::Escape($_) })

if ($missingMarkers.Count -gt 0) {
  throw "Missing deploy cleanup markers: $($missingMarkers -join ', ')"
}

Write-Host "deploy workflow cleanup ok"
