-- ============================================================
-- TerasOps | Fix: RLS violation pada INSERT + auto ticket_number
--
-- Masalah 1: Semua tabel "owner" memakai RLS
--   `with check (auth.uid() = user_id)`, tetapi kode client
--   (Sales Service, Stok Opname) meng-INSERT tanpa kolom user_id,
--   sehingga Postgres menolak dengan:
--     "new row violates row-level security policy"
--   Solusi: beri DEFAULT auth.uid() pada user_id, jadi baris baru
--   otomatis terisi id user yang sedang login.
--
-- Masalah 2: service_tickets.ticket_number NOT NULL tetapi tidak
--   pernah digenerate, sehingga INSERT tiket selalu gagal.
--   Solusi: sequence + trigger BEFORE INSERT untuk auto-generate
--   nomor tiket dengan format TKT-YYYYMMDD-0001.
--
-- Jalankan file ini di Supabase SQL Editor (sekali saja).
-- Aman dijalankan ulang (idempotent).
-- ============================================================

-- ---------- 1) Auto-fill user_id ----------
alter table public.documents
  alter column user_id set default auth.uid();

alter table public.extraction_runs
  alter column user_id set default auth.uid();

alter table public.stock_items
  alter column user_id set default auth.uid();

alter table public.opname_sessions
  alter column user_id set default auth.uid();

alter table public.clients
  alter column user_id set default auth.uid();

alter table public.service_tickets
  alter column user_id set default auth.uid();

-- ---------- 2) Auto-generate ticket_number ----------
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

drop trigger if exists service_tickets_set_number on public.service_tickets;

create trigger service_tickets_set_number
before insert on public.service_tickets
for each row execute function public.set_ticket_number();
