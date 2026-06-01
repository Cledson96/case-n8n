$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$workflowPath = Join-Path $root "workflows/tests.json"
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
  "POST /api/v1/tests",
  "Prepare Tests Request",
  "Ensure Tests Database Schema",
  "Restore Prepared Tests Request",
  "Cache Lookup",
  "Use Cached Tests?",
  "Prepare Pending Execution",
  "Create Pending Execution",
  "Prepare Cache Lookup Step",
  "Record Cache Lookup Step",
  "Tests Signal Extractor",
  "Tests Agent",
  "OpenRouter Chat Model",
  "Normalize Tests Output",
  "Persist Tests Success",
  "Restore Tests Telemetry Query",
  "Record Tests Telemetry",
  "Respond Structured Tests",
  "Respond Cached Tests"
)

$missingNodes = @($requiredNodes | Where-Object { $nodeNames -notcontains $_ })
if ($missingNodes.Count -gt 0) {
  throw "Missing tests workflow nodes: $($missingNodes -join ', ')"
}

$postgresNodes = @(
  "Ensure Tests Database Schema",
  "Cache Lookup",
  "Create Pending Execution",
  "Record Cache Lookup Step",
  "Persist Tests Success",
  "Record Tests Telemetry"
)

foreach ($postgresNode in $postgresNodes) {
  if ($nodeTypesByName[$postgresNode] -ne "n8n-nodes-base.postgres") {
    throw "Node '$postgresNode' must be a Postgres node."
  }
}

$codeNodes = @(
  "Prepare Tests Request",
  "Restore Prepared Tests Request",
  "Prepare Pending Execution",
  "Prepare Cache Lookup Step",
  "Tests Signal Extractor",
  "Normalize Tests Output",
  "Restore Tests Telemetry Query",
  "Respond Structured Tests"
)

foreach ($codeNode in $codeNodes) {
  if ($nodeTypesByName[$codeNode] -ne "n8n-nodes-base.code") {
    throw "Node '$codeNode' must be a Code node."
  }
}

if ($nodeTypesByName["Tests Agent"] -ne "@n8n/n8n-nodes-langchain.agent") {
  throw "Node 'Tests Agent' must be an n8n LangChain agent."
}

$connectionsJson = $workflow.connections | ConvertTo-Json -Depth 100
$requiredConnectionMarkers = @(
  "Ensure Tests Database Schema",
  "Restore Prepared Tests Request",
  "Tests Signal Extractor",
  "Tests Agent",
  "Restore Tests Telemetry Query",
  "ai_languageModel"
)

$missingConnectionMarkers = @($requiredConnectionMarkers | Where-Object { $connectionsJson -notmatch [regex]::Escape($_) })
if ($missingConnectionMarkers.Count -gt 0) {
  throw "Missing expected tests connection markers: $($missingConnectionMarkers -join ', ')"
}

$workflowJson = $workflow | ConvertTo-Json -Depth 100
$requiredMarkers = @(
  "function createPayloadHash(text)",
  "const requestHash = createPayloadHash(normalizedPayloadText)",
  "test_framework",
  "tests_signal_extractor",
  "tests_agent",
  "behaviorCandidates",
  "test_file",
  "coverage_hints",
  "telemetry_query"
)

$missingMarkers = @($requiredMarkers | Where-Object { $workflowJson -notmatch [regex]::Escape($_) })
if ($missingMarkers.Count -gt 0) {
  throw "Missing tests workflow markers: $($missingMarkers -join ', ')"
}

if ($workflowJson -match [regex]::Escape("digest(")) {
  throw "Tests cache lookup must not depend on Postgres pgcrypto digest()."
}

if ($workflowJson -match [regex]::Escape(".item.json")) {
  throw "Workflow code must avoid .item.json because paired item data is not stable across Postgres and merge nodes."
}

$ensureSchemaNode = $workflow.nodes | Where-Object { $_.name -eq "Ensure Tests Database Schema" } | Select-Object -First 1
if (-not $ensureSchemaNode) {
  throw "Missing Ensure Tests Database Schema node."
}

$ensureSchemaQuery = $ensureSchemaNode.parameters.query
$requiredSchemaMarkers = @(
  "CREATE TABLE IF NOT EXISTS executions",
  "CREATE TABLE IF NOT EXISTS execution_steps",
  "CREATE TABLE IF NOT EXISTS execution_telemetry"
)

$missingSchemaMarkers = @($requiredSchemaMarkers | Where-Object { $ensureSchemaQuery -notmatch [regex]::Escape($_) })
if ($missingSchemaMarkers.Count -gt 0) {
  throw "Ensure Tests Database Schema is missing SQL markers: $($missingSchemaMarkers -join ', ')"
}

Write-Host "tests workflow structure ok"
