# Review Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild `workflows/review.json` so it mirrors the TypeScript review flow with cache, persistence, language routing, deterministic tools, five specialist agents, final aggregation, telemetry, and optional webhook-compatible history data.

**Architecture:** Keep n8n as the runtime orchestrator. The workflow receives `POST /api/v1/review`, creates or reuses an execution record in Postgres, runs deterministic checks, dispatches five OpenRouter-backed specialist agents, aggregates their outputs into the same public `ReviewResponse` contract, records steps and telemetry estimates, then returns the structured result.

**Tech Stack:** n8n exported workflow JSON, Postgres 16 SQL bootstrap, PowerShell validation script.

---

### Task 1: Structural Validation

**Files:**
- Create: `scripts/validate-review-workflow.ps1`
- Read: `workflows/review.json`
- Read: `infra/sql/init/001_create_agent_runs.sql`

- [ ] **Step 1: Add a failing structural test**

Create a PowerShell script that checks the workflow has these required nodes: webhook, preparation, cache lookup, language/tools, five specialist agents, merge, aggregator, persistence, telemetry, and response. It must also check the SQL bootstrap has `executions`, `execution_steps`, and `execution_telemetry`.

- [ ] **Step 2: Run the test and confirm it fails**

Run: `powershell -ExecutionPolicy Bypass -File scripts/validate-review-workflow.ps1`

Expected: failure mentioning missing faithful review nodes in the current single-agent workflow.

### Task 2: Postgres Bootstrap

**Files:**
- Modify: `infra/sql/init/001_create_agent_runs.sql`

- [ ] **Step 1: Add the TypeScript-compatible execution tables**

Add `executions`, `execution_steps`, `execution_telemetry`, and indexes. Keep `agent_runs` for backward compatibility.

- [ ] **Step 2: Validate SQL text through the structural test**

Run: `powershell -ExecutionPolicy Bypass -File scripts/validate-review-workflow.ps1`

Expected: the SQL part passes once workflow JSON is updated.

### Task 3: Faithful Review Workflow

**Files:**
- Replace: `workflows/review.json`

- [ ] **Step 1: Replace single-agent flow with faithful orchestration**

Include nodes for `cache_lookup`, `language_router`, `deterministic_tools`, `naming_clarity_agent`, `error_handling_agent`, `resource_leak_agent`, `complexity_agent`, `security_agent`, and `review_aggregator_agent`.

- [ ] **Step 2: Preserve credentials**

Use `OpenRouter account` for OpenRouter model nodes and `case-n8n Postgres` for Postgres nodes.

- [ ] **Step 3: Match public contract**

Return exactly `overall_quality`, `score`, `issues`, `positives`, and `summary`.

### Task 4: Verification

**Files:**
- Read: `workflows/review.json`
- Read: `infra/sql/init/001_create_agent_runs.sql`

- [ ] **Step 1: Run structural validation**

Run: `powershell -ExecutionPolicy Bypass -File scripts/validate-review-workflow.ps1`

Expected: pass.

- [ ] **Step 2: Parse workflow JSON**

Run: `Get-Content workflows/review.json -Raw | ConvertFrom-Json | Out-Null`

Expected: no JSON parse error.
