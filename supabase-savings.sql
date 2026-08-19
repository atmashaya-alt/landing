-- ── Savings goals ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS savings_goals (
  id                uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at        timestamptz DEFAULT now(),
  updated_at        timestamptz DEFAULT now(),
  sa_id_number      text        NOT NULL,

  goal_type         text        NOT NULL DEFAULT 'CUSTOM',  -- EMERGENCY | CUSTOM
  goal_name         text        NOT NULL,
  emoji             text        DEFAULT '🎯',
  target_amount     numeric     NOT NULL DEFAULT 0,
  current_amount    numeric     NOT NULL DEFAULT 0,
  target_date       date,
  notes             text,
  status            text        NOT NULL DEFAULT 'ACTIVE',  -- ACTIVE | PAUSED | COMPLETED

  -- Emergency fund specific
  net_monthly_salary numeric                                 -- stored on the EMERGENCY row
);

ALTER TABLE savings_goals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "auth_all_savings_goals"
  ON savings_goals FOR ALL TO authenticated USING (true) WITH CHECK (true);


-- ── Savings contributions log ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS savings_contributions (
  id            uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  logged_at     timestamptz DEFAULT now(),
  sa_id_number  text        NOT NULL,
  goal_id       uuid        REFERENCES savings_goals(id) ON DELETE CASCADE,
  amount        numeric     NOT NULL,  -- positive = deposit, negative = withdrawal
  note          text
);

ALTER TABLE savings_contributions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "auth_all_savings_contributions"
  ON savings_contributions FOR ALL TO authenticated USING (true) WITH CHECK (true);
