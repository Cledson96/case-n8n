$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$workflowPath = Join-Path $root "workflows/history-list.json"

if (-not (Test-Path $workflowPath)) {
  throw "Workflow file not found: $workflowPath"
}

$workflow = Get-Content -Path $workflowPath -Raw | ConvertFrom-Json
$nodeNames = @($workflow.nodes | ForEach-Object { $_.name })
$nodesByName = @{}
foreach ($node in $workflow.nodes) {
  $nodesByName[$node.name] = $node
}

$requiredNodes = @(
  "GET /api/v1/history",
  "Validate History List Query",
  "Fetch History List",
  "Respond History List"
)

$missingNodes = @($requiredNodes | Where-Object { $nodeNames -notcontains $_ })
if ($missingNodes.Count -gt 0) {
  throw "Missing history list workflow nodes: $($missingNodes -join ', ')"
}

$webhook = $nodesByName["GET /api/v1/history"]
if ($webhook.type -ne "n8n-nodes-base.webhook" -or $webhook.parameters.httpMethod -ne "GET" -or $webhook.parameters.path -ne "api/v1/history") {
  throw "History list webhook must expose GET /api/v1/history."
}

$postgres = $nodesByName["Fetch History List"]
if ($postgres.type -ne "n8n-nodes-base.postgres") {
  throw "Node 'Fetch History List' must be a Postgres node."
}

if ($postgres.credentials.postgres.name -ne "case-n8n Postgres") {
  throw "Node 'Fetch History List' must use the case-n8n Postgres credential."
}

$query = [string]$postgres.parameters.query
$requiredQueryMarkers = @(
  '$1::integer',
  '$2::text',
  '$3::text',
  '$4::text',
  '$5::text',
  '$6::timestamptz',
  '$7::timestamptz',
  '$8::boolean',
  'execution_telemetry',
  'execution_steps',
  "'telemetry'",
  "'steps'"
)

$missingQueryMarkers = @($requiredQueryMarkers | Where-Object { $query -notmatch [regex]::Escape($_) })
if ($missingQueryMarkers.Count -gt 0) {
  throw "Missing history list query markers: $($missingQueryMarkers -join ', ')"
}

if ([string]$postgres.parameters.options.queryReplacement -notmatch "query_parameters") {
  throw "History list query must use sanitized Postgres query parameters."
}

$workflowJson = $workflow | ConvertTo-Json -Depth 100
$requiredMarkers = @(
  "limit",
  "cursor",
  "flow_type",
  "status",
  "model",
  "from",
  "to",
  "cache_hit",
  "next_cursor",
  "pull_request_review",
  "pull_request_tests"
)

$missingMarkers = @($requiredMarkers | Where-Object { $workflowJson -notmatch [regex]::Escape($_) })
if ($missingMarkers.Count -gt 0) {
  throw "Missing history list markers: $($missingMarkers -join ', ')"
}

if ($workflowJson -match [regex]::Escape(".item.json")) {
  throw "Workflow code must avoid .item.json because paired item data is not stable across Postgres nodes."
}

if ($query -match '\$\{') {
  throw "History list SQL must not interpolate request values directly."
}

if ($query -match [regex]::Escape("t.openrouter_generation_id")) {
  throw "History list SQL must not depend on the optional openrouter_generation_id column."
}

$requiredSequentialEdges = @(
  @("GET /api/v1/history", "Validate History List Query"),
  @("Validate History List Query", "Fetch History List"),
  @("Fetch History List", "Respond History List")
)

foreach ($edge in $requiredSequentialEdges) {
  $source = $edge[0]
  $target = $edge[1]
  $sourceConnections = $workflow.connections.PSObject.Properties[$source].Value
  $connectedNodes = @($sourceConnections.main | ForEach-Object { $_ } | ForEach-Object { $_.node })
  if ($connectedNodes -notcontains $target) {
    throw "Expected sequential connection '$source' -> '$target'."
  }
}

Write-Host "history list workflow structure ok"
