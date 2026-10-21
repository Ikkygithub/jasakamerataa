# Audit & Rencana Deployment Jasakamerata ke Hostinger Web Hosting (tanpa VPS)

Tanggal: 21 Oktober 2026 · Status: **RENCANA — belum ada perubahan kode** · Tidak ada rahasia yang ditampilkan.

## 1. Hasil audit proyek

| Bagian | Temuan (diperiksa dari source code) |
|---|---|
| Frontend | React 19 + react-router 7, CRA (react-scripts 5) + CRACO, Tailwind 3, shadcn/ui, sonner, lucide-react. Build → file statis (`yarn build` → `frontend/build`) |
| Backend | **Python 3.11 + FastAPI 0.110 + Uvicorn** (proses server yang harus berjalan terus). ±2.500 baris di `server.py`, `auth.py`, `core.py`, `ledger.py`, `storage.py`, `emailer.py`, `seed.py`, `routers/` (catalog, availability, bookings, chat, customer, photographer, admin, payments) |
| Database | **MongoDB** (driver Motor/PyMongo), 21 koleksi |
| Dependensi penting | `cryptography` (enkripsi rekening), `httpx`/`requests`, `python-multipart` (upload), `emergentintegrations` |
| Login Google | **Emergent-managed Google Auth** (`auth.emergentagent.com` + endpoint sesi Emergent). Bukan OAuth Client milik Anda sendiri |
| Penyimpanan file | **Emergent Object Storage** (portofolio, file hasil, KTP), memakai kunci Emergent |
| Email | **Resend via proxy Emergent**. `EMERGENT_EMAIL_KEY` masih kosong, jadi email belum terkirim |
| Midtrans | Snap + webhook `/api/payments/midtrans/notification`. Kunci masih kosong, jadi masih mode DEMO |
| Admin | Peran dari `ADMIN_EMAILS` (server-side) |

### Temuan risiko penting
1. **Kunci enkripsi rekening diturunkan dari `MONGO_URL`.** Jika database dipindah atau URL berubah, nomor rekening terenkripsi **tidak bisa dibuka lagi**. Wajib diganti dulu ke `ENCRYPTION_KEY` khusus (dengan re-enkripsi) sebelum migrasi apa pun.
2. Login Google, penyimpanan file, dan email bergantung pada layanan Emergent. Di Hostinger, ketiganya sebaiknya diganti dengan versi milik sendiri: Google OAuth Client sendiri, penyimpanan file di hosting, dan SMTP email Hostinger.
3. Data di database preview saat ini adalah **data uji dan DEMO** (13 users, 29 bookings, 88 ledger, dst.). Sesuai instruksi Anda, data ini **tidak dipindahkan ke produksi**. Yang dimigrasi hanya skema, plus data asli jika nanti sudah ada.

## 2. Bisakah backend Python berjalan di Hostinger Web Hosting?
**Tidak.** Dokumentasi resmi Hostinger menyatakan Python hanya didukung di VPS, karena Web/Cloud Hosting tidak memberi akses root untuk memasang Python dan dependensinya.
Fitur "Node.js Web Apps" di hPanel **bukan** berarti Python didukung. Fitur Node.js itu sendiri hanya ada di paket **Business Web Hosting** dan **Cloud** (Startup/Professional/Enterprise). Paket Single/Premium tidak punya fitur ini.
> Nama "Unlimited" bukan nama paket Hostinger saat ini. Mohon cek di **hPanel → Hosting → (paket) → Plan details** apakah paket Anda Premium atau Business, karena ini menentukan pilihan di bawah.

Yang **bisa** berjalan di semua paket Web Hosting: PHP 8.x, MySQL/MariaDB, file statis (hasil build React), cron job, dan akun email domain (SMTP).

## 3. Migrasi MongoDB → MySQL: **memungkinkan**
- Koleksi dipetakan menjadi tabel relasional: `users`, `user_sessions`, `photographers`, `services` (sekarang array di dalam photographers), `portfolio_items`, `availability_blocks`, `bookings`, `booking_history` (sekarang array), `deliveries`, `delivery_files`, `reviews`, `conversations`, `messages`, `favorites`, `payments`, `payment_events`, `ledger`, `wallets`, `payouts`, `payout_history`, `verifications`, `verification_documents`, `audit_logs`, `email_logs`.
- Keuntungan: constraint `UNIQUE` (idempotensi ledger dan webhook), transaksi atomik (`SELECT … FOR UPDATE`) untuk penarikan dan anti double booking.
- Data lama di MongoDB **tidak dihapus**. Migrasi dilakukan lewat skrip ekspor terpisah dan diverifikasi dengan menghitung jumlah baris.

## 4. Pilihan arsitektur

| | A. Frontend di Hostinger, backend tetap di Emergent | B. Konversi backend ke **PHP + MySQL** | C. Konversi backend ke **Node.js + MySQL** |
|---|---|---|---|
| Paket yang dibutuhkan | Semua paket | **Semua paket** (termasuk Premium) | Hanya **Business/Cloud** |
| Pakai MySQL Hostinger | Tidak (tetap MongoDB di Emergent) | Ya | Ya |
| Perubahan kode | Kecil | **Besar**: tulis ulang seluruh backend (~2.500 baris Python → PHP) | **Besar**: tulis ulang ke Express |
| Biaya tambahan | Biaya deploy Emergent bulanan | Tidak ada | Tidak ada (jika paket Business) |
| Risiko | Rendah | Sedang; perlu uji ulang semua alur | Sedang |
| Proses background | — | Cron hPanel (kedaluwarsa bayar) | Cron / proses Node |

**Rekomendasi:**
- Jika ingin semuanya di Hostinger tanpa biaya tambahan: **B (PHP 8 + MySQL)**, karena berjalan di paket apa pun.
- Jika paket Anda Business dan ingin bahasa yang lebih mirip kode sekarang: **C**.
- Jika ingin cepat online dengan risiko paling kecil: **A** sebagai langkah sementara.

### Perubahan yang diperlukan untuk B (sebelum dikerjakan, perlu persetujuan Anda)
| Fitur | Sekarang | Di Hostinger (PHP) |
|---|---|---|
| Login Google | Emergent Auth | **Google OAuth Client milik Anda** (Google Cloud Console). Backend memverifikasi ID token Google (`google/apiclient`). Admin tetap lewat `ADMIN_EMAILS` |
| Sesi | Cookie `session_token` | Sama: cookie httpOnly + Secure, disimpan di tabel `user_sessions` |
| Booking & kalender, cek bentrok | Python | PHP + transaksi MySQL dengan row lock |
| Chat, favorit, ulasan, admin, ledger, penarikan | Python | Endpoint PHP dengan path `/api/...` yang **sama persis**, sehingga frontend hampir tidak berubah |
| Upload file | Emergent Object Storage | Folder privat di luar `public_html` (mis. `~/storage/`), disajikan lewat PHP dengan cek izin. File portofolio lama disalin sekali |
| Email | Proxy Emergent | **SMTP email Hostinger** (mis. `notifikasi@jasakamerata.com`) via PHPMailer |
| Midtrans | Python Snap + webhook | `midtrans/midtrans-php` (library resmi). Verifikasi SHA512 dan cek nominal yang sama |
| Kedaluwarsa bayar 24 jam | Dicek saat request | Tetap begitu, ditambah **Cron Job hPanel** tiap 15 menit |
| Enkripsi rekening | Fernet (kunci dari MONGO_URL) | `sodium_crypto_secretbox` dengan `ENCRYPTION_KEY` khusus. Data lama didekripsi dan dienkripsi ulang lewat skrip migrasi |

## 5. Konfigurasi deployment (untuk B)
- **Build frontend** (di komputer/CI, bukan di hosting): `cd frontend && yarn install && REACT_APP_BACKEND_URL=https://jasakamerata.com yarn build`. Unggah isi `frontend/build/` ke `public_html/`.
- **Backend PHP:** `public_html/api/index.php` (front controller) + `public_html/api/.htaccess` (semua `/api/*` diarahkan ke index.php). Kode inti dan `vendor/` (Composer) diletakkan di luar `public_html`.
- **Routing SPA:** `public_html/.htaccess` mengarahkan semua path non-file ke `index.html`, kecuali `/api/`.
- **Start command:** tidak ada; PHP dijalankan oleh LiteSpeed. Untuk opsi C: `npm ci && npm run build`, start `node server.js` lewat Node.js Web App di hPanel.
- **Environment variables** (file `.env` di luar `public_html`, diisi sendiri lewat File Manager): `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASS`, `ENCRYPTION_KEY`, `ADMIN_EMAILS`, `GOOGLE_CLIENT_ID`, `SMTP_HOST`, `SMTP_USER`, `SMTP_PASS`, `EMAIL_REPLY_TO`, `MIDTRANS_SERVER_KEY`, `MIDTRANS_CLIENT_KEY`, `MIDTRANS_IS_PRODUCTION`, `PUBLIC_SITE_URL=https://jasakamerata.com`.
- **Domain & SSL:** jasakamerata.com diarahkan ke hosting (hPanel → Domains), SSL gratis diaktifkan di hPanel → Security → SSL, dan Force HTTPS dinyalakan.
- **Google Cloud Console:** Authorized JavaScript origin `https://jasakamerata.com`.
- **Midtrans:** Notification URL `https://jasakamerata.com/api/payments/midtrans/notification`. Ingat: akun merchant Anda juga dipakai website lain dan hanya punya satu Notification URL, jadi konfirmasi dulu ke Midtrans.
- **Cron hPanel:** `php ~/app/bin/expire.php` tiap 15 menit.
- **Backup:** hPanel → Backups (harian) + ekspor MySQL via phpMyAdmin sebelum setiap update.

## 6. Langkah bertahap (setiap tahap diuji sebelum lanjut)
1. **Persiapan (di proyek sekarang):** ganti kunci enkripsi ke `ENCRYPTION_KEY`, buat skrip ekspor MongoDB → JSON. Tidak ada data yang dihapus.
2. **Skema MySQL:** file `schema.sql` + skrip migrasi, diuji di MySQL lokal. Anda mengimpornya lewat phpMyAdmin ke database yang sudah dibuat.
3. **Backend PHP tahap 1:** auth Google (OAuth sendiri), katalog, profil, favorit, chat.
4. **Tahap 2:** booking, kalender, anti bentrok, Studio fotografer (layanan, portofolio upload, rekening, verifikasi).
5. **Tahap 3:** ledger, penarikan, panel admin, audit log.
6. **Tahap 4:** Midtrans Snap + webhook (uji sandbox dulu), email SMTP, cron kedaluwarsa.
7. **Frontend:** sesuaikan login ke Google Identity Services. Semua endpoint lain tetap sama.
8. **Uji penuh** di lingkungan setara (PHP 8.2 + MySQL 8), lalu paket ZIP siap unggah + panduan hPanel langkah demi langkah.
9. **Go-live** oleh Anda (unggah, `.env`, DNS, SSL), lalu uji setelah deploy bersama.

Catatan jujur: saya bisa membangun dan menguji PHP + MySQL di lingkungan ini, tetapi **tidak punya akses ke akun Hostinger Anda**. Status akhirnya adalah "diuji pada lingkungan setara" sampai Anda mengunggah dan kita uji bersama di jasakamerata.com.
