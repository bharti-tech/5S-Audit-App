-- ============================================================
-- I&QA 5S Audit — database schema + role-based access control
-- Run this once in your Supabase project's SQL Editor.
-- ============================================================

create extension if not exists "uuid-ossp";

-- ------------------------------------------------------------
-- PROFILES — one row per signed-up user, holding their role.
-- Roles: 'viewer' (read-only), 'editor' (submit audits + edit
-- the question list), 'admin' (editor + manage other users' roles).
-- ------------------------------------------------------------
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text not null default 'viewer' check (role in ('viewer','editor','admin')),
  created_at timestamptz default now()
);

-- Auto-create a profile (default role: viewer) whenever someone signs up.
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, role)
  values (new.id, new.email, 'viewer');
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ------------------------------------------------------------
-- CRITERIA_TEMPLATE — the shared, editable 5S question list.
-- ------------------------------------------------------------
create table if not exists criteria_template (
  id uuid primary key default uuid_generate_v4(),
  pillar_key text not null,
  pillar_label text not null,
  sort_order int not null default 0,
  question text not null,
  created_at timestamptz default now()
);

-- ------------------------------------------------------------
-- AUDITS — one row per completed audit.
-- ------------------------------------------------------------
create table if not exists audits (
  id uuid primary key default uuid_generate_v4(),
  created_by uuid references auth.users(id),
  area text not null,
  auditor text not null,
  owner text,
  audit_date date not null,
  overall numeric,
  pillar_scores jsonb,
  details jsonb,
  photos jsonb,
  created_at timestamptz default now()
);

-- ------------------------------------------------------------
-- ROW LEVEL SECURITY — this is the part that actually enforces
-- "who can view vs. edit". It runs in the database itself, so it
-- can't be bypassed by editing the app's frontend code.
-- ------------------------------------------------------------
alter table profiles enable row level security;
alter table criteria_template enable row level security;
alter table audits enable row level security;

-- Small helper: current user's role, or 'viewer' if no profile row yet.
create or replace function public.current_role()
returns text
language sql stable
as $$
  select coalesce((select role from profiles where id = auth.uid()), 'viewer');
$$;

-- PROFILES: everyone signed in can see the user list (needed for the
-- Admin page); only admins can change anyone's role.
create policy "profiles_select_authenticated"
  on profiles for select using (auth.role() = 'authenticated');

create policy "profiles_update_admin_only"
  on profiles for update using (public.current_role() = 'admin');

-- CRITERIA_TEMPLATE: everyone signed in can view the questions;
-- only editors/admins can add, change, or remove one.
create policy "criteria_select_authenticated"
  on criteria_template for select using (auth.role() = 'authenticated');

create policy "criteria_insert_editor_admin"
  on criteria_template for insert with check (public.current_role() in ('editor','admin'));

create policy "criteria_update_editor_admin"
  on criteria_template for update using (public.current_role() in ('editor','admin'));

create policy "criteria_delete_editor_admin"
  on criteria_template for delete using (public.current_role() in ('editor','admin'));

-- AUDITS: everyone signed in can view the log; only editors/admins
-- can submit a new audit.
create policy "audits_select_authenticated"
  on audits for select using (auth.role() = 'authenticated');

create policy "audits_insert_editor_admin"
  on audits for insert with check (public.current_role() in ('editor','admin'));

-- ------------------------------------------------------------
-- SEED DATA — the default 5S checklist (feel free to edit later
-- from the app's Manage Questions page instead of here).
-- ------------------------------------------------------------
insert into criteria_template (pillar_key, pillar_label, sort_order, question) values
('sort','1S — Sort',1,'Unnecessary documents removed from desk/workstation'),
('sort','1S — Sort',2,'Outdated files, records, and stationery discarded'),
('sort','1S — Sort',3,'Personal items limited to approved quantity'),
('sort','1S — Sort',4,'Email inbox and digital folders free of obsolete files'),
('sort','1S — Sort',5,'Required documents identified and retained'),
('sort','1S — Sort',6,'Red-tag system used for unwanted items'),
('setinorder','2S — Set in Order',1,'Files and folders clearly labeled'),
('setinorder','2S — Set in Order',2,'Cabinets and drawers identified with labels'),
('setinorder','2S — Set in Order',3,'Frequently used items easily accessible'),
('setinorder','2S — Set in Order',4,'Digital folders organized logically'),
('setinorder','2S — Set in Order',5,'Desk layout promotes efficient work flow'),
('setinorder','2S — Set in Order',6,'Common office supplies stored in designated locations'),
('setinorder','2S — Set in Order',7,'Safety equipment easy to access'),
('setinorder','2S — Set in Order',8,'Locations clearly marked'),
('shine','3S — Shine',1,'Workstations are clean and dust-free'),
('shine','3S — Shine',2,'Computer screens, keyboards, and phones cleaned regularly'),
('shine','3S — Shine',3,'Meeting rooms maintained in clean condition'),
('shine','3S — Shine',4,'Waste bins emptied regularly'),
('shine','3S — Shine',5,'No food waste or clutter around work area'),
('shine','3S — Shine',6,'Cleaning schedules are followed'),
('standardize','4S — Standardize',1,'Standard desk layout followed by all employees'),
('standardize','4S — Standardize',2,'Naming conventions used for electronic files'),
('standardize','4S — Standardize',3,'Visual controls, labels, and signs are consistent'),
('standardize','4S — Standardize',4,'Office procedures and SOPs displayed/available'),
('standardize','4S — Standardize',5,'Document control practices followed'),
('standardize','4S — Standardize',6,'Regular 5S audits conducted and records maintained'),
('sustain','5S — Sustain',1,'Employees understand 5S requirements'),
('sustain','5S — Sustain',2,'Daily housekeeping practices followed'),
('sustain','5S — Sustain',3,'Team members comply without reminders'),
('sustain','5S — Sustain',4,'Improvement suggestions are encouraged and implemented'),
('sustain','5S — Sustain',5,'Periodic 5S reviews conducted by management'),
('sustain','5S — Sustain',6,'Corrective actions closed within target dates')
on conflict do nothing;
