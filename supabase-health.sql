-- Health product disclosures table
CREATE TABLE IF NOT EXISTS health_disclosures (
  id           uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at   timestamptz DEFAULT now(),
  updated_at   timestamptz DEFAULT now(),
  sa_id_number text        NOT NULL,
  product_type text        NOT NULL,   -- MEDICAL_AID | MEDICAL_INSURANCE | HOSPITAL_PLAN | GAP_COVER | ACCIDENT_COVER
  provider     text,
  dependants   integer     DEFAULT 0,
  payment_type text        DEFAULT '', -- EMPLOYER | INDIVIDUAL
  UNIQUE(sa_id_number, product_type)
);

ALTER TABLE health_disclosures ENABLE ROW LEVEL SECURITY;

CREATE POLICY "auth_insert_health_disclosures"
  ON health_disclosures FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "auth_select_health_disclosures"
  ON health_disclosures FOR SELECT TO authenticated USING (true);

CREATE POLICY "auth_update_health_disclosures"
  ON health_disclosures FOR UPDATE TO authenticated USING (true);

CREATE POLICY "auth_delete_health_disclosures"
  ON health_disclosures FOR DELETE TO authenticated USING (true);
