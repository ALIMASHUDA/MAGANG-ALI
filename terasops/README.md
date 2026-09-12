# TerasOps

Aplikasi web terpadu untuk perusahaan dagang/distributor material: **Otomasi Data** (berbantuan AI), **Stok Opname Material**, dan **Sales Service** dalam satu sistem.

Dibangun dengan **Next.js 15 (App Router, TypeScript)** + **Supabase** (PostgreSQL + Auth + Storage) + **Tailwind CSS**.

## Fitur

- **Otomasi Data** — upload Excel/PDF, ekstraksi teks di server, proses via AI (OpenRouter → Gemini) dengan fallback berantai, output terstruktur yang bisa diunduh.
- **Stok Opname Material** — hitung fisik vs sistem, selisih otomatis, ekspor Excel.
- **Sales Service** — pencatatan tiket layanan dengan status Pending / Diproses / Selesai + riwayat perubahan.

## Prasyarat

- Node.js 18.18+ (disarankan 20+)
- Akun [Supabase](https://supabase.com) (gratis)
- Akun [OpenRouter](https://openrouter.ai) untuk OpenRouter API key
- Akun [Google AI Studio](https://aistudio.google.com) untuk Gemini API key (fallback)

---

## 1. Setup Supabase dari Nol

### 1.1 Buat Project

1. Buka [https://supabase.com/dashboard](https://supabase.com/dashboard) lalu login.
2. Klik **New project**.
3. Isi formulir:
   - **Name**: bebas, misalnya `terasops` (nama project = nama subdomain database).
   - **Database Password**: buat password kuat, simpan (dipakai saat perlu akses langsung DB).
   - **Region**: pilih yang terdekat, misalnya `Southeast Asia (Singapore)`.
   - **Plan**: `Free` sudah cukup untuk prototype.
4. Klik **Create new project** dan tunggu ±1–2 menit sampai status `Active`.

### 1.2 Ambil Kredensial

Setelah project aktif, buka **Project Settings → API**:

- **Project URL** → isi ke `NEXT_PUBLIC_SUPABASE_URL`
- **anon / public key** → isi ke `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- **service_role key** (secret, server-only) → isi ke `SUPABASE_SERVICE_ROLE_KEY`

> ⚠️ `service_role` key **melewati** Row Level Security. Jangan pernah pakai prefix `NEXT_PUBLIC_` untuk key ini, dan jangan pernah letakkan di kode client.

### 1.3 Jalankan Migrasi (SQL)

1. Buka menu **SQL Editor** di dashboard Supabase.
2. Klik **New query**.
3. Buka file `supabase/migrations/0001_init_schema.sql` di project ini, salin seluruh isinya, tempel ke editor, lalu **Run**.
4. Ulangi langkah 2–3 untuk `supabase/migrations/0002_seed_master_data.sql` (ini mengisi 8 kategori stok master).

> Alternatif (via Supabase CLI): `supabase db push`. Dokumentasi ini memakai SQL Editor agar tidak butuh install CLI tambahan.

### 1.4 Buat Storage Bucket

1. Buka menu **Storage**.
2. Klik **New bucket**.
3. Nama bucket: **`documents`** (harus persis, lowercase).
4. Centang **Private** (jangan public) → **Create bucket**.

### 1.5 Aktifkan Auth (Email + Password)

1. Buka **Authentication → Providers**.
2. Pastikan **Email** aktif (defaultnya aktif).
3. (Opsional) Matikan **Confirm email** saat development: **Authentication → Providers → Email → Confirm email → OFF**, supaya user bisa langsung login setelah daftar.

### 1.6 Buat User Pertama

- Lewat UI aplikasi: buka halaman **Login → Daftar/Sign Up**.
- **Atau** lewat dashboard: **Authentication → Users → Add user → Create new user**, isi email + password, centang **Auto Confirm User**.

---

## 2. Setup AI Provider

Sistem memakai **fallback berantai**: provider `AI_PROVIDER_1_*` dicoba pertama; jika gagal/error/limit, otomatis pindah ke `AI_PROVIDER_2_*`, dst. Urutan = prioritas.

Routing didasarkan pada **nama provider** (`AI_PROVIDER_*_NAME`):

| `AI_PROVIDER_*_NAME` | Adapter yang dipakai |
| --- | --- |
| `openrouter` | OpenAI-compatible (OpenAI SDK) |
| `gemini` | Google Gemini (`@google/generative-ai`) |
| nama lain | OpenAI-compatible (OpenAI SDK) |

### 2.1 OpenRouter (Primary)

[OpenRouter](https://openrouter.ai) adalah gateway AI **kompatibel API OpenAI** yang mengumpulkan banyak model (OpenAI, Anthropic, Google, Llama, dll.) dalam satu akun.

**Cara dapat API key:**
1. Buka [https://openrouter.ai](https://openrouter.ai) lalu **Sign up/Login**.
2. Buka [https://openrouter.ai/keys](https://openrouter.ai/keys).
3. Klik **Create Key**, beri nama (mis. `terasops`), lalu **Create**.
4. Salin key-nya — format selalu diawali **`sk-or-v1-`**.

**Cara pilih model gratis:**
1. Buka [https://openrouter.ai/models](https://openrouter.ai/models).
2. Cari model yang berlabel **`$0`** / **Free**.
3. Salin **ID** model (mis. `stealth/ox-alpha`).

Konfigurasi di `.env.local`:

```
AI_PROVIDER_1_NAME=openrouter
AI_PROVIDER_1_BASE_URL=https://openrouter.ai/api/v1
AI_PROVIDER_1_API_KEY=sk-or-v1-...
AI_PROVIDER_1_MODEL=stealth/ox-alpha
```

> `BASE_URL` wajib `https://openrouter.ai/api/v1`. Model gratis di OpenRouter kadang punya rate-limit; jika kena limit, sistem otomatis pindah ke provider berikutnya (Gemini).

### 2.2 Gemini (Fallback)

**Kenapa Gemini sering "gagal"?** Hampir selalu karena **API key salah** atau **model tidak valid**. Gemini (Google AI Studio) punya aturan ketat:

1. **Key harus diawali `AIza`** — misalnya `AIzaSy...`. Jika key kamu diawali `AQ.`, `sk-`, atau lainnya, itu **bukan** key Gemini dan pasti ditolak (401).
2. **Model harus nama resmi** yang tercantum di dokumentasi Gemini (lihat langkah di bawah), bukan nama karangan.

**Cara dapat API key yang benar:**
1. Buka [https://aistudio.google.com/apikey](https://aistudio.google.com/apikey).
2. Login dengan akun Google.
3. Klik **Create API key** → pilih project Google Cloud (atau biarkan default) → **Create**.
4. Salin key-nya — **pastikan diawali `AIza`**. Jangan salin token OAuth/refresh (`AQ.` dsb.) dari tempat lain.

**Cara pilih model yang valid:**
1. Buka [https://ai.google.dev/gemini-api/docs/models](https://ai.google.dev/gemini-api/docs/models).
2. Salin nama model dari tabel **Gemini API** (mis. `gemini-3.6-flash` atau `gemini-2.5-flash`).

Konfigurasi di `.env.local`:

```
AI_PROVIDER_2_NAME=gemini
AI_PROVIDER_2_BASE_URL=https://generativelanguage.googleapis.com
AI_PROVIDER_2_API_KEY=AIza...
AI_PROVIDER_2_MODEL=gemini-3.6-flash
```

> `AI_PROVIDER_2_NAME` **harus persis `gemini`** (huruf kecil) supaya diarahkan ke adapter Gemini. `BASE_URL` pada provider `gemini` hanya referensi — adapter Gemini tidak memakainya.

---

## 3. Setup Environment

```bash
# 1. Install dependencies
npm install

# 2. Salin template env ke .env.local
cp .env.example .env.local
```

Isi `.env.local`:

```
# Supabase (public)
NEXT_PUBLIC_SUPABASE_URL=https://<nama-project>.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=<anon-key>

# Supabase (server-only)
SUPABASE_SERVICE_ROLE_KEY=<service-role-key>

# AI — OpenRouter (primary)
AI_PROVIDER_1_NAME=openrouter
AI_PROVIDER_1_BASE_URL=https://openrouter.ai/api/v1
AI_PROVIDER_1_API_KEY=sk-or-v1-...
AI_PROVIDER_1_MODEL=stealth/ox-alpha

# AI — Gemini (fallback)
AI_PROVIDER_2_NAME=gemini
AI_PROVIDER_2_BASE_URL=https://generativelanguage.googleapis.com
AI_PROVIDER_2_API_KEY=AIza...
AI_PROVIDER_2_MODEL=gemini-3.6-flash

EXTRACTION_MAX_ROWS=200
```

> ⚠️ Jangan beri prefix `NEXT_PUBLIC_` pada `SUPABASE_SERVICE_ROLE_KEY` maupun `AI_PROVIDER_*`. Prefix tersebut membuat nilainya terbaca oleh browser.

---

## Menjalankan

```bash
npm run dev
```

Buka http://localhost:3000

Perintah lain:

```bash
npm run build      # build produksi
npm run start      # jalankan build produksi
npm run typecheck  # cek tipe TypeScript
npm run lint       # cek lint
```

---

## Struktur

```
src/
├─ app/
│  ├─ (auth)/login        # login Supabase Auth
│  ├─ (dashboard)/        # shell + 3 modul + dashboard
│  └─ api/                # route handlers (server-only)
├─ components/
│  ├─ ui/                 # komponen atomik
│  ├─ layout/             # sidebar, topbar, app-shell
│  ├─ otomasi/            # modul otomasi data
│  ├─ stok/               # modul stok opname
│  └─ sales/              # modul sales service
├─ lib/
│  ├─ supabase/           # client browser + server
│  ├─ ai/                 # providers, extract, fallback chain
│  └─ utils.ts            # helper
└─ types/                 # tipe database
supabase/
└─ migrations/            # 0001_init_schema.sql, 0002_seed_master_data.sql
```

---

## Troubleshooting

| Gejala | Solusi |
| --- | --- |
| Error `Tidak ada AI provider yang dikonfigurasi` | Pastikan `AI_PROVIDER_1_NAME`, `_API_KEY`, dan `_MODEL` terisi di `.env.local`, lalu restart `npm run dev`. |
| Error `Semua AI provider gagal` | Cek API key & model OpenRouter (`sk-or-v1-...` + model di https://openrouter.ai/models), dan key Gemini (`AIza...` + model di https://ai.google.dev/gemini-api/docs/models). Log server menampilkan detail per provider. |
| Error Gemini `401` / `API key not valid` | Key kamu **bukan** key Gemini — harus diawali `AIza`. Buat ulang di https://aistudio.google.com/apikey. |
| Error Gemini `404` model | Nama model tidak valid — salin nama persis dari https://ai.google.dev/gemini-api/docs/models. |
| Login gagal / user tidak ada | Pastikan migrasi `0001` dijalankan dan user dibuat di Auth (lihat §1.6). |
| Upload gagal | Pastikan bucket `documents` sudah dibuat dan privat (§1.4). |
| Error `rootDir must be explicitly set` di editor | Ini dari `node_modules/@supabase/ssr/tsconfig.json`, bukan kode project. Sudah dinetralkan lewat `.vscode/settings.json`. Restart VS Code / reload window jika masih muncul. `npm run typecheck` dan `npm run build` tetap lolos. |
