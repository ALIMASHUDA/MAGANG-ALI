-- ============================================================
-- TerasOps | Fix: extraction_runs.document_id jadi nullable
-- Alasan: proses AI via /api/ai/process mengirim document_id = null
-- karena dokumen diproses langsung dari konten teks (bukan dari
-- baris documents yang disimpan). Sebelumnya kolom ini NOT NULL
-- sehingga INSERT gagal -> HTTP 500 "Gagal membuat run".
--
-- Jalankan file ini di Supabase SQL Editor JIKA database sudah
-- pernah menjalankan 0001_init_schema.sql (skema lama).
-- ============================================================

alter table public.extraction_runs
  alter column document_id drop not null;
