$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$workflowPath = Join-Path $root "workflows/document.json"
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
  "POST /api/v1/document",
  "Prepare Document Request",
  "Ensure Document Database Schema",
  "Restore Prepared Document Request",
  "Cache Lookup",
  "Use Cached Document?",
  "Prepare Pending Execution",
  "Create Pending Execution",
  "Prepare Cache Lookup Step",
  "Record Cache Lookup Step",
  "Document Signal Extractor",
  "Document Agent",
  "OpenRouter Chat Model",
  "Normalize Document Output",
  "Persist Document Success",
  "Restore Document Telemetry Query",
  "Record Document Telemetry",
  "Respond Structured Document",
  "Respond Cached Document"
)

$missingNodes = @($requiredNodes | Where-Object { $nodeNames -notcontains $_ })
if ($missingNodes.Count -gt 0) {
  throw "Missing document workflow nodes: $($missingNodes -join ', ')"
}

$postgresNodes = @(
  "Ensure Document Database Schema",
  "Cache Lookup",
  "Create Pending Execution",
  "Record Cache Lookup Step",
  "Persist Document Success",
  "Record Document Telemetry"
)

foreach ($postgresNode in $postgresNodes) {
  if ($nodeTypesByName[$postgresNode] -ne "n8n-nodes-base.postgres") {
    throw "Node '$postgresNode' must be a Postgres node."
  }
}

$codeNodes = @(
  "Prepare Document Request",
  "Restore Prepared Document Request",
  "Prepare Pending Execution",
  "Prepare Cache Lookup Step",
  "Document Signal Extractor",
  "Normalize Document Output",
  "Restore Document Telemetry Query",
  "Respond Structured Document"
)

foreach ($codeNode in $codeNodes) {
  if ($nodeTypesByName[$codeNode] -ne "n8n-nodes-base.code") {
    throw "Node '$codeNode' must be a Code node."
  }
}

if ($nodeTypesByName["Document Agent"] -ne "@n8n/n8n-nodes-langchain.agent") {
  throw "Node 'Document Agent' must be an n8n LangChain agent."
}

$connectionsJson = $workflow.connections | ConvertTo-Json -Depth 100
$requiredConnectionMarkers = @(
  "Ensure Document Database Schema",
  "Restore Prepared Document Request",
  "Document Signal Extractor",
  "Document Agent",
  "Restore Document Telemetry Query",
  "ai_languageModel"
)

$missingConnectionMarkers = @($requiredConnectionMarkers | Where-Object { $connectionsJson -notmatch [regex]::Escape($_) })
if ($missingConnectionMarkers.Count -gt 0) {
  throw "Missing expected document connection markers: $($missingConnectionMarkers -join ', ')"
}

$workflowJson = $workflow | ConvertTo-Json -Depth 100
$requiredMarkers = @(
  "function createPayloadHash(text)",
  "const requestHash = createPayloadHash(normalizedPayloadText)",
  "doc_type",
  "document_signal_extractor",
  "document_agent",
  "publicApiCandidates",
  "side_effects",
  "telemetry_query"
)

$missingMarkers = @($requiredMarkers | Where-Object { $workflowJson -notmatch [regex]::Escape($_) })
if ($missingMarkers.Count -gt 0) {
  throw "Missing document workflow markers: $($missingMarkers -join ', ')"
}

if ($workflowJson -match [regex]::Escape("digest(")) {
  throw "Document cache lookup must not depend on Postgres pgcrypto digest()."
}

if ($workflowJson -match [regex]::Escape(".item.json")) {
  throw "Workflow code must avoid .item.json because paired item data is not stable across Postgres and merge nodes."
}

$ensureSchemaNode = $workflow.nodes | Where-Object { $_.name -eq "Ensure Document Database Schema" } | Select-Object -First 1
if (-not $ensureSchemaNode) {
  throw "Missing Ensure Document Database Schema node."
}

$ensureSchemaQuery = $ensureSchemaNode.parameters.query
$requiredSchemaMarkers = @(
  "CREATE TABLE IF NOT EXISTS executions",
  "CREATE TABLE IF NOT EXISTS execution_steps",
  "CREATE TABLE IF NOT EXISTS execution_telemetry"
)

$missingSchemaMarkers = @($requiredSchemaMarkers | Where-Object { $ensureSchemaQuery -notmatch [regex]::Escape($_) })
if ($missingSchemaMarkers.Count -gt 0) {
  throw "Ensure Document Database Schema is missing SQL markers: $($missingSchemaMarkers -join ', ')"
}

Write-Host "document workflow structure ok"
