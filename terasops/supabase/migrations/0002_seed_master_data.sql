-- ============================================================
-- TerasOps | Data master awal
-- ============================================================

insert into public.stock_categories (name) values
  ('Semen'),
  ('Besi & Baja'),
  ('Pasir'),
  ('Keramik'),
  ('Cat'),
  ('Kayu'),
  ('Alat Listrik'),
  ('Pipa & Fitting')
on conflict (name) do nothing;
