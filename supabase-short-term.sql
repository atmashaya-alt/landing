-- Short-term assets table
CREATE TABLE IF NOT EXISTS short_term_assets (
  id            uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at    timestamptz DEFAULT now(),
  sa_id_number  text        NOT NULL,
  category      text        NOT NULL,
  description   text        NOT NULL,
  estimated_value numeric   NOT NULL DEFAULT 0,
  is_insured    boolean     DEFAULT false,
  insurer       text,
  notes         text
);

ALTER TABLE short_term_assets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "auth_insert_st_assets"
  ON short_term_assets FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "auth_select_st_assets"
  ON short_term_assets FOR SELECT TO authenticated USING (true);

CREATE POLICY "auth_delete_st_assets"
  ON short_term_assets FOR DELETE TO authenticated USING (true);

-- Storage bucket for policy schedule uploads
INSERT INTO storage.buckets (id, name, public)
VALUES ('policy-schedules', 'policy-schedules', false)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "auth_upload_policy_schedules"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'policy-schedules');

CREATE POLICY "auth_read_policy_schedules"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'policy-schedules');

CREATE POLICY "auth_delete_policy_schedules"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'policy-schedules');
