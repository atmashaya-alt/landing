-- ═══════════════════════════════════════════════════════════════════
-- PARTRIDG3 — Master Database Schema
-- Run once in Supabase SQL editor (project: ukwvmnddeacixfslkfsa)
-- All tables use IF NOT EXISTS — safe to re-run
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────
-- HELPER: auto-stamp updated_at on every row change
-- ─────────────────────────────────────────────────────────────────
create or replace function public.handle_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 1. CLIENTS — master client register
--    Agent 6 reads DOB here for birthday touchpoints.
--    portal_user_id links a client to their Wealth Shield login.
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.clients (
  id                    uuid primary key default gen_random_uuid(),
  full_name             text not null,
  id_number             text,
  date_of_birth         date,
  cellphone             text not null,
  email                 text,
  province              text,
  address               text,
  employment_status     text,
  adviser_id            uuid references public.profiles(id),
  adviser_name          text,
  portal_user_id        uuid references auth.users(id),
  source                text,
  status                text not null default 'active'
                          check (status in ('active','inactive','deceased')),
  notes                 text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create trigger clients_updated_at before update on public.clients
  for each row execute function public.handle_updated_at();

alter table public.clients enable row level security;

create policy "Adviser sees own clients" on public.clients
  for select using (auth.uid() = adviser_id or public.is_owner());

create policy "Client sees own record" on public.clients
  for select using (auth.uid() = portal_user_id);

create policy "Owner manages clients" on public.clients
  for all using (public.is_owner());

-- ═══════════════════════════════════════════════════════════════════
-- 2. LEADS — unified: social / website / referral
--    Hard separation via lead_type (architecture principle).
--    Agent 1 reads and writes here.
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.leads (
  id                    uuid primary key default gen_random_uuid(),
  lead_type             text not null
                          check (lead_type in ('social','website','referral')),
  date_captured         timestamptz not null default now(),
  full_name             text not null,
  cellphone             text,
  email                 text,
  occupation            text,
  age_range             text,
  province              text,
  what_they_need        text,
  how_they_heard        text,
  source                text,
  referrer_id           uuid references public.clients(id),
  qualification_score   integer,
  contact_priority      text check (contact_priority in ('high','medium','low')),
  assigned_adviser_id   uuid references public.profiles(id),
  assigned_adviser      text,
  status                text not null default 'new'
                          check (status in ('new','contacted','qualified',
                                            'appointment_booked','converted',
                                            'lost','unresponsive')),
  first_contact_context text,
  notes                 text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create trigger leads_updated_at before update on public.leads
  for each row execute function public.handle_updated_at();

alter table public.leads enable row level security;

create policy "Adviser sees own leads" on public.leads
  for select using (auth.uid() = assigned_adviser_id or public.is_owner());

create policy "Owner manages leads" on public.leads
  for all using (public.is_owner());

-- ═══════════════════════════════════════════════════════════════════
-- 3. APPOINTMENTS — diary
--    Agent 1 books. Agent 5 schedules reviews. Adviser reads own.
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.appointments (
  id                    uuid primary key default gen_random_uuid(),
  appointment_date      date not null,
  appointment_time      time,
  booked_date           date,
  client_id             uuid references public.clients(id),
  client_name           text not null,
  cellphone             text,
  adviser_id            uuid references public.profiles(id),
  adviser_name          text,
  lead_id               uuid references public.leads(id),
  type                  text check (type in ('first_meeting','review','follow_up',
                                             'claims','fna','other')),
  location              text,
  status                text not null default 'scheduled'
                          check (status in ('scheduled','completed','cancelled',
                                            'rescheduled','no_show')),
  outcome               text,
  outcome_notes         text,
  quote_done            boolean default false,
  fna_done              boolean default false,
  notes                 text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create trigger appointments_updated_at before update on public.appointments
  for each row execute function public.handle_updated_at();

alter table public.appointments enable row level security;

create policy "Adviser sees own appointments" on public.appointments
  for select using (auth.uid() = adviser_id or public.is_owner());

create policy "Owner manages appointments" on public.appointments
  for all using (public.is_owner());

-- ═══════════════════════════════════════════════════════════════════
-- 4. POLICIES — live policy book
--    164 real records migrate from Policy Book tab + Policy Book.xlsx.
--    six_month_review_due and eleven_month_review_due auto-derived
--    from start_date during migration.
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.policies (
  id                      uuid primary key default gen_random_uuid(),
  policy_number           text unique not null,
  client_id               uuid references public.clients(id),
  client_name             text not null,
  id_number               text,
  cellphone               text,
  email                   text,
  product                 text not null,
  insurer                 text not null,
  adviser_id              uuid references public.profiles(id),
  adviser_name            text,
  monthly_premium         numeric(10,2),
  annual_premium          numeric(10,2),
  start_date              date,
  end_date                date,
  collection_channel      text check (collection_channel in
                            ('DebiCheck','RMS','Normal Debit Order','N/A')),
  status                  text not null default 'pending_initial_payment'
                            check (status in ('active','pending_initial_payment',
                                              'cancelled','lapsed','paid_out',
                                              'surrendered')),
  six_month_review_due    date,
  eleven_month_review_due date,
  notes                   text,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

create trigger policies_updated_at before update on public.policies
  for each row execute function public.handle_updated_at();

alter table public.policies enable row level security;

create policy "Adviser sees own policies" on public.policies
  for select using (auth.uid() = adviser_id or public.is_owner());

create policy "Client sees own policies" on public.policies
  for select using (
    exists (
      select 1 from public.clients c
      where c.id = client_id and c.portal_user_id = auth.uid()
    )
  );

create policy "Owner manages policies" on public.policies
  for all using (public.is_owner());

-- ═══════════════════════════════════════════════════════════════════
-- 5. NEW BUSINESS — submission pipeline
--    Tracks every policy from submission to issuance.
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.new_business (
  id                uuid primary key default gen_random_uuid(),
  date_submitted    date not null default current_date,
  client_id         uuid references public.clients(id),
  client_name       text not null,
  product           text,
  insurer           text,
  adviser_id        uuid references public.profiles(id),
  adviser_name      text,
  stage             text not null default 'submitted'
                      check (stage in ('submitted','underwriting','approved',
                                       'issued','declined','cancelled')),
  monthly_premium   numeric(10,2),
  annual_premium    numeric(10,2),
  policy_number     text,
  policy_id         uuid references public.policies(id),
  compliance_done   boolean default false,
  notes             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create trigger new_business_updated_at before update on public.new_business
  for each row execute function public.handle_updated_at();

alter table public.new_business enable row level security;

create policy "Adviser sees own new business" on public.new_business
  for select using (auth.uid() = adviser_id or public.is_owner());

create policy "Owner manages new business" on public.new_business
  for all using (public.is_owner());

-- ═══════════════════════════════════════════════════════════════════
-- 6. ACTIVATIONS — policy activation milestone
--    Agent 3 reads here for T-7 referral ask trigger.
--    Agent 5 reads here for 6-month drive calendar.
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.activations (
  id                        uuid primary key default gen_random_uuid(),
  activation_date           date not null,
  client_id                 uuid references public.clients(id),
  client_name               text not null,
  policy_id                 uuid references public.policies(id),
  policy_number             text,
  product                   text,
  insurer                   text,
  adviser_id                uuid references public.profiles(id),
  adviser_name              text,
  monthly_premium           numeric(10,2),
  annual_premium            numeric(10,2),
  commission_type           text,
  commission_amount         numeric(10,2),
  first_premium_confirmed   boolean default false,
  first_premium_date        date,
  t7_referral_sent          boolean default false,
  t7_referral_date          date,
  notes                     text,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now()
);

create trigger activations_updated_at before update on public.activations
  for each row execute function public.handle_updated_at();

alter table public.activations enable row level security;

create policy "Adviser sees own activations" on public.activations
  for select using (auth.uid() = adviser_id or public.is_owner());

create policy "Owner manages activations" on public.activations
  for all using (public.is_owner());

-- ═══════════════════════════════════════════════════════════════════
-- 7. CLAIMS — 10-stage lifecycle
--    Agent 7 manages. Daily 18:00 report reads open claims.
--    claimant_is_client = false triggers non-client consent pathway.
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.claims (
  id                    uuid primary key default gen_random_uuid(),
  date_lodged           date not null default current_date,
  client_id             uuid references public.clients(id),
  client_name           text not null,
  claim_type            text not null
                          check (claim_type in ('death','disability','severe_illness',
                                                'income_protection','funeral',
                                                'retrenchment','other')),
  insurer               text,
  policy_id             uuid references public.policies(id),
  policy_number         text,
  adviser_id            uuid references public.profiles(id),
  adviser_name          text,
  claimant_name         text,
  claimant_phone        text,
  claimant_is_client    boolean default true,
  non_client_consent    boolean default false,
  stage                 text not null default 'lodged'
                          check (stage in (
                            'lodged',
                            'documents_requested',
                            'documents_received',
                            'assessment_in_progress',
                            'awaiting_insurer_decision',
                            'decision_received',
                            'approved_payment_pending',
                            'paid_out',
                            'declined',
                            'escalated'
                          )),
  sla_due               date,
  sla_breached          boolean default false,
  status                text not null default 'open'
                          check (status in ('open','closed','escalated')),
  outcome               text,
  payout_amount         numeric(10,2),
  notes                 text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create trigger claims_updated_at before update on public.claims
  for each row execute function public.handle_updated_at();

alter table public.claims enable row level security;

create policy "Adviser sees own claims" on public.claims
  for select using (auth.uid() = adviser_id or public.is_owner());

create policy "Owner manages claims" on public.claims
  for all using (public.is_owner());

-- ═══════════════════════════════════════════════════════════════════
-- 8. TASKS
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.tasks (
  id              uuid primary key default gen_random_uuid(),
  title           text not null,
  category        text,
  priority        text not null default 'medium'
                    check (priority in ('high','medium','low')),
  assigned_to_id  uuid references public.profiles(id),
  assigned_to     text,
  due_date        date,
  status          text not null default 'open'
                    check (status in ('open','in_progress','completed','cancelled')),
  client_id       uuid references public.clients(id),
  client_name     text,
  agent_source    text,
  notes           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create trigger tasks_updated_at before update on public.tasks
  for each row execute function public.handle_updated_at();

alter table public.tasks enable row level security;

create policy "User sees own tasks" on public.tasks
  for select using (auth.uid() = assigned_to_id or public.is_owner());

create policy "Owner manages tasks" on public.tasks
  for all using (public.is_owner());

-- ═══════════════════════════════════════════════════════════════════
-- 9. COMPLIANCE DOCS
--    Agent 2 writes here. Tracks FAIS document status.
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.compliance_docs (
  id              uuid primary key default gen_random_uuid(),
  date            date not null default current_date,
  client_id       uuid references public.clients(id),
  client_name     text not null,
  adviser_id      uuid references public.profiles(id),
  adviser_name    text,
  document_type   text not null,
  status          text not null default 'pending'
                    check (status in ('pending','submitted','approved',
                                      'rejected','expired')),
  due_date        date,
  completed_date  date,
  notes           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create trigger compliance_docs_updated_at before update on public.compliance_docs
  for each row execute function public.handle_updated_at();

alter table public.compliance_docs enable row level security;

create policy "Adviser sees own compliance docs" on public.compliance_docs
  for select using (auth.uid() = adviser_id or public.is_owner());

create policy "Owner manages compliance docs" on public.compliance_docs
  for all using (public.is_owner());

-- ═══════════════════════════════════════════════════════════════════
-- 10. FNA — Financial Needs Analysis
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.fna (
  id                uuid primary key default gen_random_uuid(),
  date              date not null default current_date,
  client_id         uuid references public.clients(id),
  client_name       text not null,
  adviser_id        uuid references public.profiles(id),
  adviser_name      text,
  appointment_id    uuid references public.appointments(id),
  stage             text not null default 'initiated'
                      check (stage in ('initiated','in_progress',
                                       'completed','signed_off')),
  needs_identified  text,
  recommended       text,
  status            text not null default 'open'
                      check (status in ('open','completed','archived')),
  notes             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create trigger fna_updated_at before update on public.fna
  for each row execute function public.handle_updated_at();

alter table public.fna enable row level security;

create policy "Adviser sees own FNAs" on public.fna
  for select using (auth.uid() = adviser_id or public.is_owner());

create policy "Owner manages FNAs" on public.fna
  for all using (public.is_owner());

-- ═══════════════════════════════════════════════════════════════════
-- 11. CONSENTS — POPIA audit trail
--    Every agent checks here before communicating with a non-client.
--    evidence_ref stores a WhatsApp message ID or form submission ID.
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.consents (
  id              uuid primary key default gen_random_uuid(),
  date            date not null default current_date,
  client_id       uuid references public.clients(id),
  client_name     text not null,
  phone           text,
  consent_type    text not null
                    check (consent_type in (
                      'popia_general','marketing','whatsapp_communication',
                      'transfer_consent','non_client_claims','policy_review'
                    )),
  granted         boolean not null,
  channel         text check (channel in ('whatsapp','email','in_person',
                                           'phone','form')),
  evidence_ref    text,
  notes           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create trigger consents_updated_at before update on public.consents
  for each row execute function public.handle_updated_at();

alter table public.consents enable row level security;

create policy "Adviser sees own consents" on public.consents
  for select using (
    exists (
      select 1 from public.clients c
      where c.id = client_id and c.adviser_id = auth.uid()
    )
    or public.is_owner()
  );

create policy "Owner manages consents" on public.consents
  for all using (public.is_owner());

-- ═══════════════════════════════════════════════════════════════════
-- 12. COMMISSION REGISTER
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.commission (
  id                  uuid primary key default gen_random_uuid(),
  policy_id           uuid references public.policies(id),
  policy_number       text,
  client_id           uuid references public.clients(id),
  client_name         text,
  adviser_id          uuid references public.profiles(id),
  adviser_name        text,
  insurer             text,
  product             text,
  annual_premium      numeric(10,2),
  comm_type           text check (comm_type in ('initial','as_and_when',
                                                 'renewal','clawback')),
  comm_rate_pct       numeric(5,2),
  gross_commission    numeric(10,2),
  adviser_split_pct   numeric(5,2),
  adviser_commission  numeric(10,2),
  commission_date     date,
  clawback_expiry     date,
  status              text not null default 'pending'
                        check (status in ('pending','paid','clawback',
                                          'written_off')),
  notes               text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create trigger commission_updated_at before update on public.commission
  for each row execute function public.handle_updated_at();

alter table public.commission enable row level security;

create policy "Adviser sees own commission" on public.commission
  for select using (auth.uid() = adviser_id or public.is_owner());

create policy "Owner manages commission" on public.commission
  for all using (public.is_owner());

-- ═══════════════════════════════════════════════════════════════════
-- 13. WHATSAPP LOGS — backbone of all agent communications
--    Every message sent or received by any agent is logged here.
--    POPIA-compliant audit trail. SIL routes inbound messages via this.
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.whatsapp_logs (
  id                uuid primary key default gen_random_uuid(),
  direction         text not null check (direction in ('outbound','inbound')),
  agent_source      text not null
                      check (agent_source in (
                        'agent_1_lead_intake','agent_2_compliance',
                        'agent_3_onboarding','agent_4_social',
                        'agent_5_retention','agent_6_relationship',
                        'agent_7_claims','sil','manual'
                      )),
  recipient_name    text,
  recipient_phone   text not null,
  client_id         uuid references public.clients(id),
  lead_id           uuid references public.leads(id),
  adviser_id        uuid references public.profiles(id),
  message_type      text check (message_type in ('text','template','document',
                                                   'image','audio','interactive')),
  template_name     text,
  message_body      text,
  delivery_status   text not null default 'sent'
                      check (delivery_status in ('sent','delivered','read',
                                                  'replied','failed','pending')),
  reply_body        text,
  replied_at        timestamptz,
  requires_action   boolean default false,
  action_taken      text,
  sent_at           timestamptz not null default now(),
  created_at        timestamptz not null default now()
);

alter table public.whatsapp_logs enable row level security;

create policy "Adviser sees own whatsapp logs" on public.whatsapp_logs
  for select using (auth.uid() = adviser_id or public.is_owner());

create policy "Owner manages whatsapp logs" on public.whatsapp_logs
  for all using (public.is_owner());

-- ═══════════════════════════════════════════════════════════════════
-- 14. MEETING SUMMARIES — Agent 2 FAIS Compliance
--    Adviser reviews summary via WhatsApp APPROVE/REJECT.
--    approval_status updated by SIL when reply is received.
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.meeting_summaries (
  id                      uuid primary key default gen_random_uuid(),
  meeting_date            date not null,
  client_id               uuid references public.clients(id),
  client_name             text not null,
  adviser_id              uuid references public.profiles(id),
  adviser_name            text,
  appointment_id          uuid references public.appointments(id),
  summary                 text,
  products_discussed      text,
  recommendations         text,
  next_steps              text,
  approval_status         text not null default 'pending'
                            check (approval_status in ('pending','approved',
                                                       'rejected')),
  approved_at             timestamptz,
  rejected_reason         text,
  whatsapp_sent_at        timestamptz,
  compliance_pack_sent    boolean default false,
  compliance_pack_date    timestamptz,
  notes                   text,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

create trigger meeting_summaries_updated_at before update on public.meeting_summaries
  for each row execute function public.handle_updated_at();

alter table public.meeting_summaries enable row level security;

create policy "Adviser sees own meeting summaries" on public.meeting_summaries
  for select using (auth.uid() = adviser_id or public.is_owner());

create policy "Owner manages meeting summaries" on public.meeting_summaries
  for all using (public.is_owner());

-- ═══════════════════════════════════════════════════════════════════
-- 15. ONBOARDING TRACKER — Agent 3
--    One row per policy activation. Tracks every milestone.
--    t7_referral_sent fires at Day 7 post-activation.
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.onboarding_tracker (
  id                          uuid primary key default gen_random_uuid(),
  client_id                   uuid references public.clients(id),
  client_name                 text not null,
  policy_id                   uuid references public.policies(id),
  policy_number               text,
  adviser_id                  uuid references public.profiles(id),
  adviser_name                text,
  activation_date             date,
  welcome_msg_sent            boolean default false,
  welcome_msg_date            timestamptz,
  compliance_pack_sent        boolean default false,
  compliance_pack_date        timestamptz,
  first_premium_confirmed     boolean default false,
  first_premium_date          date,
  t7_referral_sent            boolean default false,
  t7_referral_date            timestamptz,
  t7_referral_converted       boolean default false,
  six_month_review_scheduled  boolean default false,
  onboarding_complete         boolean default false,
  completed_at                timestamptz,
  notes                       text,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now()
);

create trigger onboarding_tracker_updated_at before update on public.onboarding_tracker
  for each row execute function public.handle_updated_at();

alter table public.onboarding_tracker enable row level security;

create policy "Adviser sees own onboarding" on public.onboarding_tracker
  for select using (auth.uid() = adviser_id or public.is_owner());

create policy "Owner manages onboarding" on public.onboarding_tracker
  for all using (public.is_owner());

-- ═══════════════════════════════════════════════════════════════════
-- 16. CONTENT SCHEDULE — Agent 4 Social Media
--    Covers all 5 platforms including WhatsApp channel.
--    safety_check_passed must be true before status moves to published.
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.content_schedule (
  id                    uuid primary key default gen_random_uuid(),
  scheduled_date        date not null,
  scheduled_time        time,
  platform              text not null
                          check (platform in ('whatsapp','facebook','instagram',
                                              'linkedin','tiktok','twitter')),
  content_pillar        text,
  content_type          text check (content_type in ('post','story','reel',
                                                      'carousel','article',
                                                      'message')),
  caption               text,
  media_url             text,
  hashtags              text,
  safety_check_passed   boolean default false,
  safety_check_notes    text,
  status                text not null default 'draft'
                          check (status in ('draft','scheduled','published',
                                            'failed','cancelled')),
  published_at          timestamptz,
  engagement_likes      integer default 0,
  engagement_comments   integer default 0,
  engagement_shares     integer default 0,
  engagement_reach      integer default 0,
  created_by_id         uuid references public.profiles(id),
  notes                 text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create trigger content_schedule_updated_at before update on public.content_schedule
  for each row execute function public.handle_updated_at();

alter table public.content_schedule enable row level security;

create policy "Collaborator and owner manage content" on public.content_schedule
  for all using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.role in ('collaborator','owner')
    )
  );

-- ═══════════════════════════════════════════════════════════════════
-- 17. AGENT LOGS — SIL: every agent action recorded
--    Master View Agent Status section reads from here.
--    requires_human = true surfaces in the escalation feed.
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.agent_logs (
  id              uuid primary key default gen_random_uuid(),
  agent           text not null
                    check (agent in (
                      'agent_1_lead_intake','agent_2_compliance',
                      'agent_3_onboarding','agent_4_social',
                      'agent_5_retention','agent_6_relationship',
                      'agent_7_claims','sil'
                    )),
  action          text not null,
  trigger_type    text,
  entity_type     text,
  entity_id       uuid,
  client_id       uuid references public.clients(id),
  adviser_id      uuid references public.profiles(id),
  status          text not null default 'success'
                    check (status in ('success','failed','pending','escalated')),
  output_summary  text,
  error_message   text,
  requires_human  boolean default false,
  human_actioned  boolean default false,
  actioned_by     uuid references public.profiles(id),
  actioned_at     timestamptz,
  created_at      timestamptz not null default now()
);

alter table public.agent_logs enable row level security;

create policy "Owner sees all agent logs" on public.agent_logs
  for select using (public.is_owner());

create policy "Adviser sees own agent logs" on public.agent_logs
  for select using (auth.uid() = adviser_id);

-- ═══════════════════════════════════════════════════════════════════
-- 18. ESCALATIONS — SIL triage queue
--    Feeds the Master View escalation feed in real time.
--    priority = 'high' appears at the top of the feed.
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.escalations (
  id                uuid primary key default gen_random_uuid(),
  agent_log_id      uuid references public.agent_logs(id),
  agent_source      text not null,
  priority          text not null default 'medium'
                      check (priority in ('high','medium','low')),
  category          text check (category in (
                      'compliance','claims_sla','lead_uncontacted',
                      'payment_missed','fais_breach','system_error','other'
                    )),
  title             text not null,
  description       text,
  client_id         uuid references public.clients(id),
  adviser_id        uuid references public.profiles(id),
  assigned_to       uuid references public.profiles(id),
  status            text not null default 'open'
                      check (status in ('open','in_progress',
                                        'resolved','dismissed')),
  resolved_at       timestamptz,
  resolution_notes  text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create trigger escalations_updated_at before update on public.escalations
  for each row execute function public.handle_updated_at();

alter table public.escalations enable row level security;

create policy "Owner manages escalations" on public.escalations
  for all using (public.is_owner());

create policy "Adviser sees own escalations" on public.escalations
  for select using (
    auth.uid() = adviser_id or auth.uid() = assigned_to
  );

-- ═══════════════════════════════════════════════════════════════════
-- 19. WELLNESS SCORES — Wealth Shield portal
--    One row per client per assessment date.
--    Client reads own scores. Adviser reads own clients.
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.wellness_scores (
  id                        uuid primary key default gen_random_uuid(),
  client_id                 uuid not null references public.clients(id),
  assessed_date             date not null default current_date,
  adviser_id                uuid references public.profiles(id),
  life_cover_score          integer check (life_cover_score between 0 and 100),
  disability_score          integer check (disability_score between 0 and 100),
  income_protection_score   integer check (income_protection_score between 0 and 100),
  severe_illness_score      integer check (severe_illness_score between 0 and 100),
  savings_score             integer check (savings_score between 0 and 100),
  overall_score             integer check (overall_score between 0 and 100),
  notes                     text,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now()
);

create trigger wellness_scores_updated_at before update on public.wellness_scores
  for each row execute function public.handle_updated_at();

alter table public.wellness_scores enable row level security;

create policy "Client sees own wellness" on public.wellness_scores
  for select using (
    exists (
      select 1 from public.clients c
      where c.id = client_id and c.portal_user_id = auth.uid()
    )
  );

create policy "Adviser sees own client wellness" on public.wellness_scores
  for select using (auth.uid() = adviser_id or public.is_owner());

create policy "Owner manages wellness" on public.wellness_scores
  for all using (public.is_owner());

-- ═══════════════════════════════════════════════════════════════════
-- INDEXES — performance for the Master View's most frequent queries
-- ═══════════════════════════════════════════════════════════════════
create index if not exists idx_clients_adviser_id        on public.clients(adviser_id);
create index if not exists idx_clients_date_of_birth     on public.clients(date_of_birth);
create index if not exists idx_leads_status              on public.leads(status);
create index if not exists idx_leads_adviser             on public.leads(assigned_adviser_id);
create index if not exists idx_leads_type                on public.leads(lead_type);
create index if not exists idx_appointments_date         on public.appointments(appointment_date);
create index if not exists idx_appointments_adviser      on public.appointments(adviser_id);
create index if not exists idx_policies_adviser          on public.policies(adviser_id);
create index if not exists idx_policies_client           on public.policies(client_id);
create index if not exists idx_policies_status           on public.policies(status);
create index if not exists idx_policies_six_month        on public.policies(six_month_review_due);
create index if not exists idx_claims_stage              on public.claims(stage);
create index if not exists idx_claims_sla_due            on public.claims(sla_due);
create index if not exists idx_claims_adviser            on public.claims(adviser_id);
create index if not exists idx_commission_adviser        on public.commission(adviser_id);
create index if not exists idx_whatsapp_logs_phone       on public.whatsapp_logs(recipient_phone);
create index if not exists idx_whatsapp_logs_agent       on public.whatsapp_logs(agent_source);
create index if not exists idx_whatsapp_logs_client      on public.whatsapp_logs(client_id);
create index if not exists idx_agent_logs_agent          on public.agent_logs(agent);
create index if not exists idx_agent_logs_created        on public.agent_logs(created_at desc);
create index if not exists idx_agent_logs_requires_human on public.agent_logs(requires_human) where requires_human = true;
create index if not exists idx_escalations_status        on public.escalations(status);
create index if not exists idx_escalations_priority      on public.escalations(priority);
create index if not exists idx_content_schedule_date     on public.content_schedule(scheduled_date);
create index if not exists idx_content_schedule_platform on public.content_schedule(platform);
create index if not exists idx_onboarding_t7             on public.onboarding_tracker(t7_referral_sent) where t7_referral_sent = false;
create index if not exists idx_wellness_client           on public.wellness_scores(client_id);

-- ═══════════════════════════════════════════════════════════════════
-- DONE
-- 19 tables created. Run the CSV imports next.
-- ═══════════════════════════════════════════════════════════════════
