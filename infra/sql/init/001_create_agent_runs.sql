CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    flow_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    input_payload JSONB NOT NULL,
    output_payload JSONB,
    duration_ms INTEGER NOT NULL DEFAULT 0,
    request_hash TEXT NOT NULL,
    cache_hit BOOLEAN NOT NULL DEFAULT FALSE,
    source_execution_id UUID REFERENCES executions (id),
    error_message TEXT
);

CREATE INDEX IF NOT EXISTS idx_executions_created_at
    ON executions (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_executions_flow_status
    ON executions (flow_type, status);

CREATE INDEX IF NOT EXISTS idx_executions_flow_hash_status
    ON executions (flow_type, request_hash, status);

CREATE TABLE IF NOT EXISTS execution_steps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    execution_id UUID NOT NULL REFERENCES executions (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    node_name TEXT NOT NULL,
    kind TEXT NOT NULL,
    status TEXT NOT NULL,
    input_payload JSONB,
    output_payload JSONB,
    duration_ms INTEGER NOT NULL DEFAULT 0,
    error_message TEXT
);

CREATE INDEX IF NOT EXISTS idx_execution_steps_execution_created
    ON execution_steps (execution_id, created_at);

CREATE TABLE IF NOT EXISTS execution_telemetry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    execution_id UUID NOT NULL UNIQUE REFERENCES executions (id) ON DELETE CASCADE,
    provider TEXT NOT NULL,
    model_requested TEXT NOT NULL,
    model_used TEXT,
    openrouter_generation_id TEXT,
    prompt_tokens INTEGER,
    completion_tokens INTEGER,
    total_tokens INTEGER,
    cost_usd NUMERIC(12, 8),
    input_cost_usd NUMERIC(12, 8),
    output_cost_usd NUMERIC(12, 8),
    cache_read_tokens INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS batch_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status TEXT NOT NULL,
    item_count INTEGER NOT NULL,
    success_count INTEGER NOT NULL,
    failed_count INTEGER NOT NULL,
    duration_ms INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS agent_runs (
    id UUID PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    flow_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'completed',
    input_payload JSONB NOT NULL,
    output_payload JSONB,
    duration_ms INTEGER NOT NULL DEFAULT 0,
    model_used TEXT
);

CREATE INDEX IF NOT EXISTS idx_agent_runs_created_at
    ON agent_runs (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_agent_runs_flow_type
    ON agent_runs (flow_type);
