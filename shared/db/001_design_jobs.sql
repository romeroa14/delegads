-- ============================================================
-- 001_design_jobs.sql
-- DesignBot: tracks design requests (AI-generated or human)
-- ============================================================

CREATE TABLE IF NOT EXISTS design_jobs (
    id BIGSERIAL PRIMARY KEY,
    lead_id BIGINT REFERENCES leads(id) ON DELETE SET NULL,
    type VARCHAR(20) NOT NULL DEFAULT 'ai_generated',  -- ai_generated | human_designer
    status VARCHAR(50) NOT NULL DEFAULT 'requested',   -- requested | in_progress | review | approved | rejected | fallback_ai
    prompt TEXT NOT NULL,
    style_preferences JSONB,                           -- { colors, format, mood, etc }
    result_url TEXT,                                   -- URL of generated/delivered image
    designer_id BIGINT REFERENCES designers(id) ON DELETE SET NULL,
    price DECIMAL(10,2) DEFAULT 5.00,
    fallback_at TIMESTAMP,                             -- when 7-day timeout triggered AI fallback
    approved_at TIMESTAMP,
    rejected_reason TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_design_jobs_lead_id ON design_jobs(lead_id);
CREATE INDEX IF NOT EXISTS idx_design_jobs_status ON design_jobs(status);
CREATE INDEX IF NOT EXISTS idx_design_jobs_designer_id ON design_jobs(designer_id);
