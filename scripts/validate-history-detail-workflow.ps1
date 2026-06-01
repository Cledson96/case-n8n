$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$workflowPath = Join-Path $root "workflows/history-detail.json"

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
  "GET /api/v1/history/:id",
  "Prepare History Detail Request",
  "Valid History UUID?",
  "Fetch History Detail",
  "Format History Detail Response",
  "History Detail Found?",
  "Respond History Detail",
  "Respond History Detail Not Found",
  "Respond Invalid History UUID"
)

$missingNodes = @($requiredNodes | Where-Object { $nodeNames -notcontains $_ })
if ($missingNodes.Count -gt 0) {
  throw "Missing history detail workflow nodes: $($missingNodes -join ', ')"
}

if ($nodeTypesByName["Fetch History Detail"] -ne "n8n-nodes-base.postgres") {
  throw "Node 'Fetch History Detail' must be a Postgres node."
}

$workflowJson = $workflow | ConvertTo-Json -Depth 100
$requiredMarkers = @(
  "api/v1/history/:id",
  "case-n8n Postgres",
  "execution_steps",
  "execution_telemetry",
  "source_execution_id",
  "openrouter_generation_id",
  "cost_total_usd",
  "input_payload",
  "output_payload",
  "error_message",
  "America/Sao_Paulo",
  "Parametro de historico invalido.",
  "Execucao nao encontrada.",
  '$1::uuid',
  "queryReplacement"
)

$missingMarkers = @($requiredMarkers | Where-Object { $workflowJson -notmatch [regex]::Escape($_) })
if ($missingMarkers.Count -gt 0) {
  throw "Missing history detail markers: $($missingMarkers -join ', ')"
}

$fetchNode = $workflow.nodes | Where-Object { $_.name -eq "Fetch History Detail" }
if ($fetchNode.parameters.query -notmatch [regex]::Escape('$1::uuid')) {
  throw "History detail SQL must use a UUID query placeholder."
}

if (-not $fetchNode.parameters.options.queryReplacement) {
  throw "History detail SQL must define queryReplacement."
}

if ($fetchNode.parameters.query -match '\$\{') {
  throw "History detail SQL must not interpolate user-controlled values."
}

if ($fetchNode.parameters.query -match [regex]::Escape("t.openrouter_generation_id")) {
  throw "History detail SQL must not depend on the optional openrouter_generation_id column."
}

$requiredSequentialEdges = @(
  @("GET /api/v1/history/:id", "Prepare History Detail Request"),
  @("Prepare History Detail Request", "Valid History UUID?"),
  @("Fetch History Detail", "Format History Detail Response"),
  @("Format History Detail Response", "History Detail Found?")
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

Write-Host "history detail workflow structure ok"
