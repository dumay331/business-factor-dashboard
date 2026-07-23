-- ==============================================
-- Supabase SQL Schema for Survey Dashboard
-- 昊铂埃安营销体系关键影响因素调研
-- ==============================================

-- 1. Respondents table (survey participants)
CREATE TABLE respondents (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT DEFAULT '匿名',
  role TEXT NOT NULL CHECK (role IN ('region', 'investor', 'hq', 'store_manager')),
  region TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Ratings table (each factor score per respondent)
CREATE TABLE ratings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  respondent_id UUID REFERENCES respondents(id) ON DELETE CASCADE,
  domain_id TEXT NOT NULL,
  factor TEXT NOT NULL,
  importance NUMERIC(2,1) NOT NULL CHECK (importance >= 0.5 AND importance <= 5),
  urgency NUMERIC(2,1) NOT NULL CHECK (urgency >= 0.5 AND urgency <= 5),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Indexes for performance
CREATE INDEX idx_ratings_respondent ON ratings(respondent_id);
CREATE INDEX idx_ratings_domain ON ratings(domain_id);
CREATE INDEX idx_respondents_role ON respondents(role);
CREATE INDEX idx_respondents_region ON respondents(region);

-- 4. Row Level Security (allow anonymous submissions for survey)
ALTER TABLE respondents ENABLE ROW LEVEL SECURITY;
ALTER TABLE ratings ENABLE ROW LEVEL SECURITY;

-- Allow anyone to insert survey responses
CREATE POLICY "Allow anonymous insert" ON respondents
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow anonymous insert" ON ratings
  FOR INSERT WITH CHECK (true);

-- Allow public read access for dashboard aggregation
CREATE POLICY "Allow public read" ON respondents
  FOR SELECT USING (true);

CREATE POLICY "Allow public read" ON ratings
  FOR SELECT USING (true);

-- 5. Aggregation view for dashboard (average scores per factor per role)
CREATE VIEW factor_scores_by_role AS
SELECT
  r.domain_id,
  r.factor,
  resp.role,
  COUNT(*) AS sample_size,
  ROUND(AVG(r.importance), 1) AS avg_importance,
  ROUND(AVG(r.urgency), 1) AS avg_urgency
FROM ratings r
JOIN respondents resp ON resp.id = r.respondent_id
GROUP BY r.domain_id, r.factor, resp.role;

-- 6. Region-level aggregation view
CREATE VIEW factor_scores_by_region AS
SELECT
  r.domain_id,
  r.factor,
  resp.region,
  resp.role,
  COUNT(*) AS sample_size,
  ROUND(AVG(r.importance), 1) AS avg_importance,
  ROUND(AVG(r.urgency), 1) AS avg_urgency
FROM ratings r
JOIN respondents resp ON resp.id = r.respondent_id
WHERE resp.role IN ('region', 'investor')
GROUP BY r.domain_id, r.factor, resp.region, resp.role;

-- 7. Sample size summary view
CREATE VIEW sample_summary AS
SELECT
  resp.role,
  resp.region,
  COUNT(DISTINCT resp.id) AS respondent_count
FROM respondents resp
GROUP BY resp.role, resp.region;

-- 8. Domain-level aggregation view (domain scores = average of 5 factor scores per domain per role)
CREATE VIEW domain_scores_by_role AS
SELECT
  r.domain_id,
  resp.role,
  COUNT(DISTINCT resp.id) AS sample_size,
  ROUND(AVG(r.importance), 1) AS avg_importance,
  ROUND(AVG(r.urgency), 1) AS avg_urgency
FROM ratings r
JOIN respondents resp ON resp.id = r.respondent_id
GROUP BY r.domain_id, resp.role;
