-- ============================================================
-- 004_content_calendar.sql
-- ContentBot: 30-day content calendar for $180/month clients
-- ============================================================

CREATE TABLE IF NOT EXISTS content_calendar (
    id BIGSERIAL PRIMARY KEY,
    lead_id BIGINT REFERENCES leads(id) ON DELETE SET NULL,
    post_date DATE NOT NULL,
    post_type VARCHAR(50) NOT NULL DEFAULT 'feed',  -- feed, reel, story
    content_text TEXT,
    media_url TEXT,
    media_type VARCHAR(50),                          -- image, video, carousel
    platform VARCHAR(50) DEFAULT 'instagram',        -- instagram, facebook
    status VARCHAR(50) DEFAULT 'draft',              -- draft, scheduled, published, failed
    scheduled_at TIMESTAMP,
    published_at TIMESTAMP,
    meta_post_id VARCHAR(255),                       -- ID returned by Meta API
    engagement_metrics JSONB,                        -- { likes, comments, shares }
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_content_calendar_lead_id ON content_calendar(lead_id);
CREATE INDEX IF NOT EXISTS idx_content_calendar_status ON content_calendar(status);
CREATE INDEX IF NOT EXISTS idx_content_calendar_post_date ON content_calendar(post_date);
