-- ============================================================
-- 002_designers.sql
-- DesignBot: human designers roster
-- ============================================================

CREATE TABLE IF NOT EXISTS designers (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(50),
    whatsapp_number VARCHAR(50),                       -- for WhatsApp notifications
    specialties JSONB DEFAULT '[]'::jsonb,             -- ["logo", "social media", "print", ...]
    is_active BOOLEAN DEFAULT true,
    current_workload INT DEFAULT 0,                    -- active jobs count
    max_workload INT DEFAULT 3,                        -- max concurrent jobs
    rating DECIMAL(3,2) DEFAULT 5.00,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Seed: Alfredo's real designer (to be updated with real details)
INSERT INTO designers (name, email, phone, specialties, is_active, max_workload)
VALUES (
    'Diseñador Principal',
    'designer@delegads.com',
    '',
    '["logo", "social media", " flyers", "branding"]'::jsonb,
    true,
    3
)
ON CONFLICT DO NOTHING;
