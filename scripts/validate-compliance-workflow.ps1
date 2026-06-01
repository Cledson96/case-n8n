$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$workflowPath = Join-Path $root "workflows/compliance.json"
$sqlPath = Join-Path $root "infra/sql/init/001_create_agent_runs.sql"

if (-not (Test-Path $workflowPath)) {
  throw "Workflow file not found: $workflowPath"
}

if (-not (Test-Path $sqlPath)) {
  throw "SQL bootstrap file not found: $sqlPath"
}

$workflow = Get-Content -Path $workflowPath -Raw | ConvertFrom-Json
$nodeNames = @($workflow.nodes | ForEach-Object { $_.name })
$nodeTypesByName = @{}
foreach ($node in $workflow.nodes) {
  $nodeTypesByName[$node.name] = $node.type
}

$requiredNodes = @(
  "POST /api/v1/compliance",
  "Prepare Compliance Request",
  "Ensure Compliance Database Schema",
  "Restore Prepared Compliance Request",
  "Cache Lookup",
  "Use Cached Compliance?",
  "Prepare Pending Execution",
  "Create Pending Execution",
  "Prepare Cache Lookup Step",
  "Record Cache Lookup Step",
  "Requirements Extractor",
  "Compliance Agent",
  "OpenRouter Chat Model",
  "Normalize Compliance Output",
  "Persist Compliance Success",
  "Restore Compliance Telemetry Query",
  "Record Compliance Telemetry",
  "Respond Structured Compliance",
  "Respond Cached Compliance"
)

$missingNodes = @($requiredNodes | Where-Object { $nodeNames -notcontains $_ })
if ($missingNodes.Count -gt 0) {
  throw "Missing compliance workflow nodes: $($missingNodes -join ', ')"
}

$postgresNodes = @(
  "Ensure Compliance Database Schema",
  "Cache Lookup",
  "Create Pending Execution",
  "Record Cache Lookup Step",
  "Persist Compliance Success",
  "Record Compliance Telemetry"
)

foreach ($postgresNode in $postgresNodes) {
  if ($nodeTypesByName[$postgresNode] -ne "n8n-nodes-base.postgres") {
    throw "Node '$postgresNode' must be a Postgres node."
  }
}

$codeNodes = @(
  "Prepare Compliance Request",
  "Restore Prepared Compliance Request",
  "Prepare Pending Execution",
  "Prepare Cache Lookup Step",
  "Requirements Extractor",
  "Normalize Compliance Output",
  "Restore Compliance Telemetry Query",
  "Respond Structured Compliance"
)

foreach ($codeNode in $codeNodes) {
  if ($nodeTypesByName[$codeNode] -ne "n8n-nodes-base.code") {
    throw "Node '$codeNode' must be a Code node."
  }
}

if ($nodeTypesByName["Compliance Agent"] -ne "@n8n/n8n-nodes-langchain.agent") {
  throw "Node 'Compliance Agent' must be an n8n LangChain agent."
}

$connectionsJson = $workflow.connections | ConvertTo-Json -Depth 100
$requiredConnectionMarkers = @(
  "Ensure Compliance Database Schema",
  "Restore Prepared Compliance Request",
  "Requirements Extractor",
  "Compliance Agent",
  "Restore Compliance Telemetry Query",
  "ai_languageModel"
)

$missingConnectionMarkers = @($requiredConnectionMarkers | Where-Object { $connectionsJson -notmatch [regex]::Escape($_) })
if ($missingConnectionMarkers.Count -gt 0) {
  throw "Missing expected compliance connection markers: $($missingConnectionMarkers -join ', ')"
}

$workflowJson = $workflow | ConvertTo-Json -Depth 100
$requiredMarkers = @(
  "function createPayloadHash(text)",
  "const requestHash = createPayloadHash(normalizedPayloadText)",
  "task_description",
  "requirements_extractor",
  "compliance_agent",
  "compliance_score",
  "telemetry_query"
)

$missingMarkers = @($requiredMarkers | Where-Object { $workflowJson -notmatch [regex]::Escape($_) })
if ($missingMarkers.Count -gt 0) {
  throw "Missing compliance workflow markers: $($missingMarkers -join ', ')"
}

if ($workflowJson -match [regex]::Escape("digest(")) {
  throw "Compliance cache lookup must not depend on Postgres pgcrypto digest()."
}

if ($workflowJson -match [regex]::Escape(".item.json")) {
  throw "Workflow code must avoid .item.json because paired item data is not stable across Postgres and merge nodes."
}

$ensureSchemaNode = $workflow.nodes | Where-Object { $_.name -eq "Ensure Compliance Database Schema" } | Select-Object -First 1
if (-not $ensureSchemaNode) {
  throw "Missing Ensure Compliance Database Schema node."
}

$ensureSchemaQuery = $ensureSchemaNode.parameters.query
$requiredSchemaMarkers = @(
  "CREATE TABLE IF NOT EXISTS executions",
  "CREATE TABLE IF NOT EXISTS execution_steps",
  "CREATE TABLE IF NOT EXISTS execution_telemetry"
)

$missingSchemaMarkers = @($requiredSchemaMarkers | Where-Object { $ensureSchemaQuery -notmatch [regex]::Escape($_) })
if ($missingSchemaMarkers.Count -gt 0) {
  throw "Ensure Compliance Database Schema is missing SQL markers: $($missingSchemaMarkers -join ', ')"
}

Write-Host "compliance workflow structure ok"
