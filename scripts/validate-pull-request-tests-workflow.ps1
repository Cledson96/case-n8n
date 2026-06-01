$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$workflowPath = Join-Path $root "workflows/pull-request-tests.json"

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
  "POST /api/v1/tests/pull-request",
  "Prepare Pull Request Tests",
  "Ensure Pull Request Tests Schema",
  "Restore Prepared Pull Request Tests",
  "Cache Lookup",
  "Use Cached Pull Request Tests?",
  "Respond Cached Pull Request Tests",
  "Prepare Pending Execution",
  "Create Pending Execution",
  "Fetch GitHub Pull Request",
  "Fetch GitHub Diff",
  "Fetch GitHub Changed Files",
  "Prepare Changed Code + Critical Functions",
  "Pull Request Tests Agent",
  "OpenRouter Chat Model",
  "Normalize Pull Request Tests",
  "Persist Pull Request Tests",
  "Restore Pull Request Tests Telemetry Query",
  "Record Pull Request Tests Telemetry",
  "Respond Pull Request Tests"
)

$missingNodes = @($requiredNodes | Where-Object { $nodeNames -notcontains $_ })
if ($missingNodes.Count -gt 0) {
  throw "Missing pull request tests workflow nodes: $($missingNodes -join ', ')"
}

$postgresNodes = @(
  "Ensure Pull Request Tests Schema",
  "Cache Lookup",
  "Create Pending Execution",
  "Persist Pull Request Tests",
  "Record Pull Request Tests Telemetry"
)

foreach ($nodeName in $postgresNodes) {
  if ($nodeTypesByName[$nodeName] -ne "n8n-nodes-base.postgres") {
    throw "Node '$nodeName' must be a Postgres node."
  }
}

$httpNodes = @("Fetch GitHub Pull Request", "Fetch GitHub Diff", "Fetch GitHub Changed Files")
foreach ($nodeName in $httpNodes) {
  if ($nodeTypesByName[$nodeName] -ne "n8n-nodes-base.httpRequest") {
    throw "Node '$nodeName' must be an HTTP Request node."
  }
}

if ($nodeTypesByName["Pull Request Tests Agent"] -ne "@n8n/n8n-nodes-langchain.agent") {
  throw "Node 'Pull Request Tests Agent' must be an n8n LangChain agent."
}

$workflowJson = $workflow | ConvertTo-Json -Depth 100
$requiredMarkers = @(
  "github_pull_request_url",
  "test_framework",
  "pull_request_tests",
  "critical_functions",
  "coverage_hints",
  "telemetry_query",
  "GitHub account",
  "OpenRouter account",
  "case-n8n Postgres",
  "Responda integralmente em portugues brasileiro",
  "codigo-fonte completo",
  "test_file deve conter"
)

$missingMarkers = @($requiredMarkers | Where-Object { $workflowJson -notmatch [regex]::Escape($_) })
if ($missingMarkers.Count -gt 0) {
  throw "Missing pull request tests markers: $($missingMarkers -join ', ')"
}

if ($workflowJson -match [regex]::Escape("digest(")) {
  throw "Pull request tests cache lookup must not depend on Postgres pgcrypto digest()."
}

if ($workflowJson -match [regex]::Escape(".item.json")) {
  throw "Workflow code must avoid .item.json because paired item data is not stable across Postgres and HTTP nodes."
}

$requiredSequentialEdges = @(
  @("Create Pending Execution", "Fetch GitHub Pull Request"),
  @("Fetch GitHub Pull Request", "Fetch GitHub Diff"),
  @("Fetch GitHub Diff", "Fetch GitHub Changed Files"),
  @("Fetch GitHub Changed Files", "Prepare Changed Code + Critical Functions"),
  @("Prepare Changed Code + Critical Functions", "Pull Request Tests Agent"),
  @("Pull Request Tests Agent", "Normalize Pull Request Tests"),
  @("Persist Pull Request Tests", "Restore Pull Request Tests Telemetry Query"),
  @("Restore Pull Request Tests Telemetry Query", "Record Pull Request Tests Telemetry")
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

Write-Host "pull request tests workflow structure ok"
