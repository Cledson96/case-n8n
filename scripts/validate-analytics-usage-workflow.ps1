$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$workflowPath = Join-Path $root "workflows/analytics-usage.json"

if (-not (Test-Path $workflowPath)) {
  throw "Workflow file not found: $workflowPath"
}

$workflow = Get-Content -Path $workflowPath -Raw | ConvertFrom-Json
$nodeNames = @($workflow.nodes | ForEach-Object { $_.name })
$nodeTypesByName = @{}
foreach ($node in $workflow.nodes) {
  $nodeTypesByName[$node.name] = $node.type
}

$requiredNodes = @(
  "GET /api/v1/analytics/usage",
  "Prepare Analytics Query",
  "Ensure Analytics Schema",
  "Restore Prepared Analytics Query",
  "Aggregate Analytics Usage",
  "Respond Analytics Usage"
)

$missingNodes = @($requiredNodes | Where-Object { $nodeNames -notcontains $_ })
if ($missingNodes.Count -gt 0) {
  throw "Missing analytics usage workflow nodes: $($missingNodes -join ', ')"
}

if ($nodeTypesByName["GET /api/v1/analytics/usage"] -ne "n8n-nodes-base.webhook") {
  throw "Analytics usage endpoint must be a Webhook node."
}

$webhookNode = $workflow.nodes | Where-Object { $_.name -eq "GET /api/v1/analytics/usage" } | Select-Object -First 1
if ($webhookNode.parameters.httpMethod -ne "GET") {
  throw "Analytics usage endpoint must use GET."
}

$postgresNodes = @("Ensure Analytics Schema", "Aggregate Analytics Usage")
foreach ($nodeName in $postgresNodes) {
  if ($nodeTypesByName[$nodeName] -ne "n8n-nodes-base.postgres") {
    throw "Node '$nodeName' must be a Postgres node."
  }

  $node = $workflow.nodes | Where-Object { $_.name -eq $nodeName } | Select-Object -First 1
  if ($node.credentials.postgres.name -ne "case-n8n Postgres") {
    throw "Node '$nodeName' must use case-n8n Postgres."
  }
}

$workflowJson = $workflow | ConvertTo-Json -Depth 100
$requiredMarkers = @(
  "flow_type",
  "model",
  "from",
  "to",
  "pull_request_review",
  "pull_request_tests",
  "replaceAll",
  "America/Sao_Paulo",
  "executions",
  "successful",
  "failed",
  "cache_hits",
  "prompt_tokens",
  "completion_tokens",
  "total_tokens",
  "cache_read_tokens",
  "cost_total_usd",
  "cost_input_usd",
  "cost_output_usd",
  "average_duration_ms",
  "by_day",
  "by_flow",
  "by_model",
  "case-n8n Postgres"
)

$missingMarkers = @($requiredMarkers | Where-Object { $workflowJson -notmatch [regex]::Escape($_) })
if ($missingMarkers.Count -gt 0) {
  throw "Missing analytics usage markers: $($missingMarkers -join ', ')"
}

if ($workflowJson -match [regex]::Escape(".item.json")) {
  throw "Workflow code must avoid .item.json because paired item data is not stable across Postgres nodes."
}

$prepareNode = $workflow.nodes | Where-Object { $_.name -eq "Prepare Analytics Query" } | Select-Object -First 1
$prepareCode = $prepareNode.parameters.jsCode
$requiredPrepareMarkers = @(
  "const supportedFlows = new Set(",
  "Number.isNaN(Date.parse(value))",
  "function sql(value)",
  "replaceAll(",
  "WITH filtered AS",
  "ORDER BY date",
  "ORDER BY flow_type",
  "ORDER BY model"
)

$missingPrepareMarkers = @($requiredPrepareMarkers | Where-Object { $prepareCode -notmatch [regex]::Escape($_) })
if ($missingPrepareMarkers.Count -gt 0) {
  throw "Prepare Analytics Query is missing markers: $($missingPrepareMarkers -join ', ')"
}

$ensureSchemaNode = $workflow.nodes | Where-Object { $_.name -eq "Ensure Analytics Schema" } | Select-Object -First 1
$ensureSchemaQuery = $ensureSchemaNode.parameters.query
$requiredSchemaMarkers = @(
  "CREATE TABLE IF NOT EXISTS executions",
  "CREATE TABLE IF NOT EXISTS execution_telemetry"
)

$missingSchemaMarkers = @($requiredSchemaMarkers | Where-Object { $ensureSchemaQuery -notmatch [regex]::Escape($_) })
if ($missingSchemaMarkers.Count -gt 0) {
  throw "Ensure Analytics Schema is missing markers: $($missingSchemaMarkers -join ', ')"
}

$connectionsJson = $workflow.connections | ConvertTo-Json -Depth 100
$requiredConnectionMarkers = @(
  "Prepare Analytics Query",
  "Ensure Analytics Schema",
  "Restore Prepared Analytics Query",
  "Aggregate Analytics Usage",
  "Respond Analytics Usage"
)

$missingConnectionMarkers = @($requiredConnectionMarkers | Where-Object { $connectionsJson -notmatch [regex]::Escape($_) })
if ($missingConnectionMarkers.Count -gt 0) {
  throw "Missing analytics usage connection markers: $($missingConnectionMarkers -join ', ')"
}

Write-Host "analytics usage workflow structure ok"
