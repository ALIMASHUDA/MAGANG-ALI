-- ============================================================
-- TerasOps | Inisialisasi skema database
-- Jalankan di Supabase SQL Editor sebelum aplikasi dijalankan.
-- ============================================================

create extension if not exists "pgcrypto";

-- ============ ENUMS ============
create type public.service_status as enum ('pending', 'in_progress', 'completed');
create type public.opname_session_status as enum ('draft', 'completed');

-- ============ PROFILES ============
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role text not null default 'staff',
  created_at timestamptz not null default now()
);

-- ============ DOCUMENTS ============
create table public.documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  storage_path text not null,
  mime_type text not null,
  size_bytes bigint,
  created_at timestamptz not null default now()
);

-- ============ EXTRACTION RUNS ============
create table public.extraction_runs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  document_id uuid references public.documents(id) on delete cascade,
  prompt text not null,
  provider_used text,
  model_used text,
  status text not null default 'pending', -- pending|processing|success|failed
  result_json jsonb,
  error_message text,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

-- ============ STOCK ============
create table public.stock_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

create table public.stock_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  code text not null,
  name text not null,
  unit text not null default 'unit',
  category_id uuid references public.stock_categories(id) on delete set null,
  system_stock numeric(15,2) not null default 0,
  min_stock numeric(15,2) not null default 0,
  created_at timestamptz not null default now(),
  unique (user_id, code)
);

create table public.opname_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  session_date date not null default current_date,
  note text,
  status public.opname_session_status not null default 'draft',
  created_at timestamptz not null default now()
);

create table public.opname_items (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.opname_sessions(id) on delete cascade,
  item_id uuid not null references public.stock_items(id) on delete cascade,
  system_stock numeric(15,2) not null default 0,
  physical_stock numeric(15,2) not null default 0,
  difference numeric(15,2) generated always as (physical_stock - system_stock) stored,
  note text,
  created_at timestamptz not null default now(),
  unique (session_id, item_id)
);

-- ============ SALES SERVICE ============
create table public.clients (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  company text,
  phone text,
  email text,
  created_at timestamptz not null default now()
);

create table public.service_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  ticket_number text not null unique,
  client_id uuid references public.clients(id) on delete set null,
  service_type text not null,
  description text,
  status public.service_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.service_ticket_updates (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.service_tickets(id) on delete cascade,
  old_status public.service_status,
  new_status public.service_status not null,
  note text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

-- ============ INDEXES ============
create index documents_user_id_idx on public.documents(user_id);
create index extraction_runs_user_id_idx on public.extraction_runs(user_id);
create index stock_items_user_id_idx on public.stock_items(user_id);
create index opname_sessions_user_id_idx on public.opname_sessions(user_id);
create index opname_items_session_id_idx on public.opname_items(session_id);
create index service_tickets_user_id_idx on public.service_tickets(user_id);
create index service_tickets_status_idx on public.service_tickets(status);

-- ============ TRIGGER updated_at ============
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger service_tickets_set_updated_at
before update on public.service_tickets
for each row execute function public.set_updated_at();

-- ============ AUTO TICKET NUMBER ============
create sequence if not exists public.service_ticket_seq;

create or replace function public.set_ticket_number()
returns trigger language plpgsql as $$
begin
  if new.ticket_number is null or new.ticket_number = '' then
    new.ticket_number := 'TKT-' || to_char(now(), 'YYYYMMDD') || '-' ||
      lpad(nextval('public.service_ticket_seq')::text, 4, '0');
  end if;
  return new;
end;
$$;

create trigger service_tickets_set_number
before insert on public.service_tickets
for each row execute function public.set_ticket_number();

-- ============ AUTO PROFILE ============
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- ============ RLS ============
alter table public.profiles enable row level security;
alter table public.documents enable row level security;
alter table public.extraction_runs enable row level security;
alter table public.stock_categories enable row level security;
alter table public.stock_items enable row level security;
alter table public.opname_sessions enable row level security;
alter table public.opname_items enable row level security;
alter table public.clients enable row level security;
alter table public.service_tickets enable row level security;
alter table public.service_ticket_updates enable row level security;

-- Master data readable by any authenticated user
create policy "categories readable by all" on public.stock_categories
  for select to authenticated using (true);

create policy "profiles owner" on public.profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

create policy "documents owner" on public.documents
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "extraction owner" on public.extraction_runs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "items owner" on public.stock_items
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "sessions owner" on public.opname_sessions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "opname_items via session" on public.opname_items
  for all using (
    exists (
      select 1 from public.opname_sessions s
      where s.id = session_id and s.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.opname_sessions s
      where s.id = session_id and s.user_id = auth.uid()
    )
  );

create policy "clients owner" on public.clients
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "tickets owner" on public.service_tickets
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "ticket_updates via ticket" on public.service_ticket_updates
  for all using (
    exists (
      select 1 from public.service_tickets t
      where t.id = ticket_id and t.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.service_tickets t
      where t.id = ticket_id and t.user_id = auth.uid()
    )
  );
