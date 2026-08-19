-- ── Investment profiles (client-submitted) ────────────────────────────────
CREATE TABLE IF NOT EXISTS investment_profiles (
  id                        uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at                timestamptz DEFAULT now(),
  updated_at                timestamptz DEFAULT now(),
  sa_id_number              text        NOT NULL UNIQUE,

  -- Risk profile
  risk_score                integer,                        -- 0–100 normalised
  risk_category             text,                          -- CONSERVATIVE | MOD_CONSERVATIVE | MODERATE | MOD_AGGRESSIVE | AGGRESSIVE
  risk_answers              jsonb,                         -- [{q:1,a:3}, ...]

  -- Investment goals
  targeted_return           text,                          -- 'CPI+2' | 'CPI+4' | 'CPI+6' | '10%+' | custom
  investment_term_years     integer,
  amount_type               text,                          -- LUMP_SUM | RECURRING
  investment_amount         numeric,
  recurring_frequency       text,                          -- MONTHLY | QUARTERLY | ANNUALLY
  source_of_funds           text,                          -- SAVINGS | INHERITANCE | SALE_OF_ASSET | BONUS | BUSINESS | OTHER
  source_of_funds_detail    text,
  investment_purpose        text,                          -- RETIREMENT | EDUCATION | PROPERTY | WEALTH | INCOME | EMERGENCY | OTHER
  investment_purpose_detail text,

  -- Tax context (from FNA or client-entered)
  estimated_tax_bracket     integer                        -- 18 | 26 | 31 | 36 | 39 | 41 | 45
);

ALTER TABLE investment_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "auth_all_investment_profiles"
  ON investment_profiles FOR ALL TO authenticated USING (true) WITH CHECK (true);


-- ── Investment recommendations (adviser-submitted) ─────────────────────────
CREATE TABLE IF NOT EXISTS investment_recommendations (
  id                  uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at          timestamptz DEFAULT now(),
  updated_at          timestamptz DEFAULT now(),
  sa_id_number        text        NOT NULL,
  profile_id          uuid        REFERENCES investment_profiles(id),

  wrapper             text        NOT NULL,                -- RA | ENDOWMENT | TFSA | UNIT_TRUST | LIVING_ANNUITY | COMBINATION | OTHER
  wrapper_detail      text,                               -- e.g. "RA + TFSA combination"
  rationale           text        NOT NULL,               -- The adviser narrative
  status              text        DEFAULT 'DRAFT',        -- DRAFT | CONFIRMED | SUPERSEDED
  adviser_id          uuid,                               -- auth.users id of recommending adviser

  suggested_wrapper   text,                               -- system-generated suggestion at time of save
  suggested_rationale text                                -- system-generated narrative at time of save
);

ALTER TABLE investment_recommendations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "auth_all_investment_recs"
  ON investment_recommendations FOR ALL TO authenticated USING (true) WITH CHECK (true);


-- ── Audit / change log ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS investment_change_log (
  id             uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  logged_at      timestamptz DEFAULT now(),
  sa_id_number   text        NOT NULL,
  changed_by     text        NOT NULL,                    -- CLIENT | ADVISER
  changed_by_id  uuid,
  entity_type    text        NOT NULL,                    -- PROFILE | RECOMMENDATION
  entity_id      uuid,
  change_summary text        NOT NULL,
  snapshot       jsonb
);

ALTER TABLE investment_change_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "auth_insert_investment_log"
  ON investment_change_log FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "auth_select_investment_log"
  ON investment_change_log FOR SELECT TO authenticated USING (true);
