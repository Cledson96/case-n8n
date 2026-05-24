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
