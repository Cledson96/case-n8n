$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$workflowPath = Join-Path $root "workflows/batch.json"
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
  "POST /api/v1/batch",
  "Prepare Batch Request",
  "Ensure Batch Database Schema",
  "Restore Prepared Batch Items",
  "Loop Over Batch Items",
  "Execute Flow Webhook",
  "Normalize Batch Item Result",
  "Continue Batch Loop?",
  "Collect Batch Results",
  "Persist Batch Summary",
  "Respond Batch"
)

$missingNodes = @($requiredNodes | Where-Object { $nodeNames -notcontains $_ })
if ($missingNodes.Count -gt 0) {
  throw "Missing batch workflow nodes: $($missingNodes -join ', ')"
}

$nodeTypeRequirements = @{
  "POST /api/v1/batch" = "n8n-nodes-base.webhook"
  "Prepare Batch Request" = "n8n-nodes-base.code"
  "Ensure Batch Database Schema" = "n8n-nodes-base.postgres"
  "Restore Prepared Batch Items" = "n8n-nodes-base.code"
  "Loop Over Batch Items" = "n8n-nodes-base.splitInBatches"
  "Execute Flow Webhook" = "n8n-nodes-base.httpRequest"
  "Normalize Batch Item Result" = "n8n-nodes-base.code"
  "Continue Batch Loop?" = "n8n-nodes-base.if"
  "Collect Batch Results" = "n8n-nodes-base.code"
  "Persist Batch Summary" = "n8n-nodes-base.postgres"
  "Respond Batch" = "n8n-nodes-base.code"
}

foreach ($entry in $nodeTypeRequirements.GetEnumerator()) {
  if ($nodeTypesByName[$entry.Key] -ne $entry.Value) {
    throw "Node '$($entry.Key)' must be type '$($entry.Value)'."
  }
}

$connectionsJson = $workflow.connections | ConvertTo-Json -Depth 100
$requiredConnectionMarkers = @(
  "Ensure Batch Database Schema",
  "Restore Prepared Batch Items",
  "Loop Over Batch Items",
  "Execute Flow Webhook",
  "Normalize Batch Item Result",
  "Continue Batch Loop?",
  "Collect Batch Results",
  "Persist Batch Summary",
  "Respond Batch"
)

$missingConnectionMarkers = @($requiredConnectionMarkers | Where-Object { $connectionsJson -notmatch [regex]::Escape($_) })
if ($missingConnectionMarkers.Count -gt 0) {
  throw "Missing expected batch connection markers: $($missingConnectionMarkers -join ', ')"
}

$workflowJson = $workflow | ConvertTo-Json -Depth 100
$requiredMarkers = @(
  "continue_on_error",
  "function createUuid()",
  "notify",
  "batch_executions",
  "batch_id",
  "flow_type",
  "error_message",
  "/webhook/api/v1/",
  "review",
  "compliance",
  "document",
  "tests"
)

$missingMarkers = @($requiredMarkers | Where-Object { $workflowJson -notmatch [regex]::Escape($_) })
if ($missingMarkers.Count -gt 0) {
  throw "Missing batch workflow markers: $($missingMarkers -join ', ')"
}

if ($workflowJson -match [regex]::Escape(".item.json")) {
  throw "Workflow code must avoid .item.json because paired item data is not stable across Postgres and loop nodes."
}

$ensureSchemaNode = $workflow.nodes | Where-Object { $_.name -eq "Ensure Batch Database Schema" } | Select-Object -First 1
$ensureSchemaQuery = $ensureSchemaNode.parameters.query
if ($ensureSchemaQuery -notmatch [regex]::Escape("CREATE TABLE IF NOT EXISTS batch_executions")) {
  throw "Ensure Batch Database Schema must create batch_executions."
}

Write-Host "batch workflow structure ok"
