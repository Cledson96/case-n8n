$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$workflowPath = Join-Path $root "workflows/review.json"
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
  "POST /api/v1/review",
  "Prepare Review Request",
  "Ensure Review Database Schema",
  "Cache Lookup",
  "Use Cached Review?",
  "Create Pending Execution",
  "Record Cache Lookup Step",
  "Language Router + Deterministic Tools",
  "Naming Clarity Agent",
  "Error Handling Agent",
  "Resource Leak Agent",
  "Complexity Agent",
  "Security Agent",
  "OpenRouter Chat Model",
  "Merge Specialist Outputs",
  "Review Aggregator Agent",
  "Persist Review Success",
  "Record Review Telemetry",
  "Respond Structured Review",
  "Respond Cached Review"
)

$missingNodes = @($requiredNodes | Where-Object { $nodeNames -notcontains $_ })
if ($missingNodes.Count -gt 0) {
  throw "Missing faithful review workflow nodes: $($missingNodes -join ', ')"
}

$agentNodes = @(
  "Naming Clarity Agent",
  "Error Handling Agent",
  "Resource Leak Agent",
  "Complexity Agent",
  "Security Agent",
  "Review Aggregator Agent"
)

foreach ($agentNode in $agentNodes) {
  if ($nodeTypesByName[$agentNode] -ne "@n8n/n8n-nodes-langchain.agent") {
    throw "Node '$agentNode' must be an n8n LangChain agent."
  }
}

$postgresNodes = @(
  "Ensure Review Database Schema",
  "Cache Lookup",
  "Create Pending Execution",
  "Record Cache Lookup Step",
  "Persist Review Success",
  "Record Review Telemetry"
)

foreach ($postgresNode in $postgresNodes) {
  if ($nodeTypesByName[$postgresNode] -ne "n8n-nodes-base.postgres") {
    throw "Node '$postgresNode' must be a Postgres node."
  }
}

$connectionsJson = $workflow.connections | ConvertTo-Json -Depth 100
$requiredConnectionMarkers = @(
  "Ensure Review Database Schema",
  "Language Router + Deterministic Tools",
  "Naming Clarity Agent",
  "Error Handling Agent",
  "Resource Leak Agent",
  "Complexity Agent",
  "Security Agent",
  "Review Aggregator Agent",
  "ai_languageModel"
)

$missingConnectionMarkers = @($requiredConnectionMarkers | Where-Object { $connectionsJson -notmatch [regex]::Escape($_) })
if ($missingConnectionMarkers.Count -gt 0) {
  throw "Missing expected workflow connection markers: $($missingConnectionMarkers -join ', ')"
}

$workflowJson = $workflow | ConvertTo-Json -Depth 100
$requiredCacheMarkers = @(
  "function createPayloadHash(text)",
  "const requestHash = createPayloadHash(normalizedPayloadText)"
)

$missingCacheMarkers = @($requiredCacheMarkers | Where-Object { $workflowJson -notmatch [regex]::Escape($_) })
if ($missingCacheMarkers.Count -gt 0) {
  throw "Missing cache lookup portability markers: $($missingCacheMarkers -join ', ')"
}

if ($workflowJson -match [regex]::Escape("digest(")) {
  throw "Cache lookup must not depend on Postgres pgcrypto digest()."
}

$ensureSchemaNode = $workflow.nodes | Where-Object { $_.name -eq "Ensure Review Database Schema" } | Select-Object -First 1
if (-not $ensureSchemaNode) {
  throw "Missing Ensure Review Database Schema node."
}

$ensureSchemaQuery = $ensureSchemaNode.parameters.query
$requiredSchemaMarkers = @(
  "CREATE TABLE IF NOT EXISTS executions",
  "CREATE TABLE IF NOT EXISTS execution_steps",
  "CREATE TABLE IF NOT EXISTS execution_telemetry"
)

$missingSchemaMarkers = @($requiredSchemaMarkers | Where-Object { $ensureSchemaQuery -notmatch [regex]::Escape($_) })
if ($missingSchemaMarkers.Count -gt 0) {
  throw "Ensure Review Database Schema is missing SQL markers: $($missingSchemaMarkers -join ', ')"
}

$sql = Get-Content -Path $sqlPath -Raw
$requiredSqlMarkers = @(
  "CREATE TABLE IF NOT EXISTS executions",
  "CREATE TABLE IF NOT EXISTS execution_steps",
  "CREATE TABLE IF NOT EXISTS execution_telemetry",
  "CREATE INDEX IF NOT EXISTS idx_executions_flow_hash_status",
  "CREATE INDEX IF NOT EXISTS idx_execution_steps_execution_created"
)

$missingSqlMarkers = @($requiredSqlMarkers | Where-Object { $sql -notmatch [regex]::Escape($_) })
if ($missingSqlMarkers.Count -gt 0) {
  throw "Missing expected SQL bootstrap markers: $($missingSqlMarkers -join ', ')"
}

Write-Host "review workflow structure ok"
