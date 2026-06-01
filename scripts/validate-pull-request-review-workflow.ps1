$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$workflowPath = Join-Path $root "workflows/pull-request-review.json"

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
  "POST /api/v1/review/pull-request",
  "Prepare Pull Request Review",
  "Ensure Pull Request Review Schema",
  "Restore Prepared Pull Request Review",
  "Cache Lookup",
  "Use Cached Pull Request Review?",
  "Create Pending Execution",
  "Fetch GitHub Pull Request",
  "Fetch GitHub Diff",
  "Fetch GitHub Changed Files",
  "Build Pull Request Source",
  "Has Jira Issue?",
  "Fetch Jira Issue",
  "Prepare Jira Issue",
  "Skip Jira Issue",
  "Merge Jira Branch",
  "Prepare Pull Request Analysis",
  "Code Standard Agent",
  "Project Consistency Agent",
  "Security Agent",
  "Jira Criteria Agent",
  "OpenRouter Chat Model",
  "Build Pull Request Aggregator Prompt",
  "Pull Request Review Aggregator",
  "Normalize Pull Request Review",
  "Persist Pull Request Review",
  "Restore Pull Request Telemetry Query",
  "Record Pull Request Telemetry",
  "Respond Pull Request Review",
  "Respond Cached Pull Request Review"
)

$missingNodes = @($requiredNodes | Where-Object { $nodeNames -notcontains $_ })
if ($missingNodes.Count -gt 0) {
  throw "Missing pull request review workflow nodes: $($missingNodes -join ', ')"
}

$postgresNodes = @(
  "Ensure Pull Request Review Schema",
  "Cache Lookup",
  "Create Pending Execution",
  "Persist Pull Request Review",
  "Record Pull Request Telemetry"
)

foreach ($postgresNode in $postgresNodes) {
  if ($nodeTypesByName[$postgresNode] -ne "n8n-nodes-base.postgres") {
    throw "Node '$postgresNode' must be a Postgres node."
  }
}

$agentNodes = @(
  "Code Standard Agent",
  "Project Consistency Agent",
  "Security Agent",
  "Jira Criteria Agent",
  "Pull Request Review Aggregator"
)

foreach ($agentNode in $agentNodes) {
  if ($nodeTypesByName[$agentNode] -ne "@n8n/n8n-nodes-langchain.agent") {
    throw "Node '$agentNode' must be an n8n LangChain agent."
  }
}

$httpNodes = @(
  "Fetch GitHub Pull Request",
  "Fetch GitHub Diff",
  "Fetch GitHub Changed Files",
  "Fetch Jira Issue"
)

foreach ($httpNode in $httpNodes) {
  if ($nodeTypesByName[$httpNode] -ne "n8n-nodes-base.httpRequest") {
    throw "Node '$httpNode' must be an HTTP Request node."
  }
}

$jiraNode = $workflow.nodes | Where-Object { $_.name -eq "Fetch Jira Issue" }
if ($jiraNode.parameters.nodeCredentialType -ne "httpHeaderAuth") {
  throw "Node 'Fetch Jira Issue' must use Header Auth because Jira Basic Auth is not reliable in this deployment."
}

$connectionsJson = $workflow.connections | ConvertTo-Json -Depth 100
$requiredConnectionMarkers = @(
  "Fetch GitHub Pull Request",
  "Fetch GitHub Diff",
  "Fetch GitHub Changed Files",
  "Merge Jira Branch",
  "Code Standard Agent",
  "Project Consistency Agent",
  "Security Agent",
  "Jira Criteria Agent",
  "Pull Request Review Aggregator",
  "Restore Pull Request Telemetry Query",
  "ai_languageModel"
)

$missingConnectionMarkers = @($requiredConnectionMarkers | Where-Object { $connectionsJson -notmatch [regex]::Escape($_) })
if ($missingConnectionMarkers.Count -gt 0) {
  throw "Missing expected pull request review connection markers: $($missingConnectionMarkers -join ', ')"
}

$workflowJson = $workflow | ConvertTo-Json -Depth 100
$requiredMarkers = @(
  "github_pull_request_url",
  "jira_issue_key",
  "jira_base_url",
  "pull_request_review",
  "code_standard",
  "jira_criteria",
  "project_consistency",
  "security",
  "aggregator",
  "telemetry_query",
  "GitHub account",
  "Jira account",
  "Responda integralmente em portugues brasileiro"
)

$missingMarkers = @($requiredMarkers | Where-Object { $workflowJson -notmatch [regex]::Escape($_) })
if ($missingMarkers.Count -gt 0) {
  throw "Missing pull request review markers: $($missingMarkers -join ', ')"
}

if ($workflowJson -match [regex]::Escape("digest(")) {
  throw "Pull request review cache lookup must not depend on Postgres pgcrypto digest()."
}

if ($workflowJson -match [regex]::Escape(".item.json")) {
  throw "Workflow code must avoid .item.json because paired item data is not stable across Postgres, HTTP and merge nodes."
}

$requiredSequentialEdges = @(
  @("Create Pending Execution", "Fetch GitHub Pull Request"),
  @("Fetch GitHub Pull Request", "Fetch GitHub Diff"),
  @("Fetch GitHub Diff", "Fetch GitHub Changed Files"),
  @("Fetch GitHub Changed Files", "Build Pull Request Source"),
  @("Prepare Pull Request Analysis", "Code Standard Agent"),
  @("Code Standard Agent", "Project Consistency Agent"),
  @("Project Consistency Agent", "Security Agent"),
  @("Security Agent", "Jira Criteria Agent"),
  @("Jira Criteria Agent", "Build Pull Request Aggregator Prompt")
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

Write-Host "pull request review workflow structure ok"
