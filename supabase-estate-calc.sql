-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- Creates the estate_calculator_submissions table and enables RLS

CREATE TABLE IF NOT EXISTS estate_calculator_submissions (
  id                   uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  submitted_at         timestamptz DEFAULT now(),
  name                 text,
  email                text,
  phone                text,
  gross_estate         numeric,
  has_surviving_spouse boolean DEFAULT false,
  property_value       numeric DEFAULT 0,
  executor_fee         numeric,
  estate_duty          numeric,
  masters_fee          numeric,
  advertising_cost     numeric,
  conveyancing_cost    numeric DEFAULT 0,
  total_cost           numeric,
  net_to_beneficiaries numeric,
  sa_id_number         text,
  source               text DEFAULT 'landing'
);

ALTER TABLE estate_calculator_submissions ENABLE ROW LEVEL SECURITY;

-- Allow anonymous inserts (from landing page / standalone calculator)
CREATE POLICY "anon_insert_estate_calc"
  ON estate_calculator_submissions
  FOR INSERT TO anon
  WITH CHECK (true);

-- Allow authenticated inserts (from client portal / adviser app)
CREATE POLICY "auth_insert_estate_calc"
  ON estate_calculator_submissions
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- Authenticated users can read all submissions (adviser dashboard use)
CREATE POLICY "auth_select_estate_calc"
  ON estate_calculator_submissions
  FOR SELECT TO authenticated
  USING (true);
