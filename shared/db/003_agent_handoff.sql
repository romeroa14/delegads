-- ============================================================
-- 003_agent_handoff.sql
-- Multi-agent coordination: Valeria → DesignBot → ContentBot
-- ============================================================

CREATE TABLE IF NOT EXISTS agent_handoff (
    id BIGSERIAL PRIMARY KEY,
    lead_id BIGINT REFERENCES leads(id) ON DELETE CASCADE,
    from_agent VARCHAR(50) NOT NULL,                   -- valeria | design_bot | content_bot
    to_agent VARCHAR(50) NOT NULL,                     -- design_bot | content_bot | report_bot
    context JSONB NOT NULL DEFAULT '{}'::jsonb,        -- { request, preferences, history_summary }
    status VARCHAR(50) NOT NULL DEFAULT 'pending',     -- pending | picked_up | completed | failed
    result JSONB,                                      -- response from the receiving agent
    picked_up_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_agent_handoff_lead_id ON agent_handoff(lead_id);
CREATE INDEX IF NOT EXISTS idx_agent_handoff_status ON agent_handoff(status);
CREATE INDEX IF NOT EXISTS idx_agent_handoff_to_agent ON agent_handoff(to_agent, status);
