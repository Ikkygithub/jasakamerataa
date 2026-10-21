# Panduan Deployment Jasakamerata ke Hostinger

Status per Juni 2026: aplikasi aktif tetap berjalan di Emergent (FastAPI + MongoDB). File di folder `deploy/` adalah **persiapan** migrasi bertahap. Belum ada data yang dipindahkan ke Hostinger.

---

## 1. Database MySQL (phpMyAdmin)

File:
- `deploy/mysql/schema.sql` — 26 tabel (hanya `CREATE TABLE IF NOT EXISTS`, aman diulang).
- `deploy/mysql/export_mongo_to_mysql.py` — membuat `deploy/mysql/data_export.sql` dari MongoDB (MongoDB tidak diubah).

Hasil uji lokal (MariaDB 10.11):
- Skema + data DEMO berhasil diimpor tanpa error, 0 baris yatim (booking/pesan/ulasan).
- Mode data asli (tanpa DEMO/uji): 4 pengguna, 2 fotografer.
- Data uji dengan email ganda dan data milik booking yang sudah dihapus otomatis dilewati dan dilaporkan sebagai `DILEWATI`.

Langkah:
1. hPanel → **Databases → MySQL Databases** → buat database + user (catat nama, user, password di tempat aman, jangan dikirim lewat chat).
2. hPanel → **phpMyAdmin** → pilih database → tab **Import** → pilih `schema.sql` → **Go**.
3. Saat siap pindah data (saat tidak ada transaksi): jalankan di server Emergent/lokal
   `cd backend && python ../deploy/mysql/export_mongo_to_mysql.py`
   lalu impor `deploy/mysql/data_export.sql` dengan cara yang sama. Jangan unggah file ini ke tempat publik: berisi email dan rekening terenkripsi.
4. Simpan `ENCRYPTION_KEY` yang sama di backend baru. Tanpa kunci itu, nomor rekening tidak bisa dibuka.

---

## 2. Frontend React ke `public_html`

Perintah (dari folder `/app`):
```
bash deploy/build_hostinger.sh https://URL-BACKEND-AKTIF
```
- `URL-BACKEND-AKTIF` = alamat aplikasi Emergent yang sudah di-*deploy* (bukan URL preview). Paket yang ada saat ini dibangun dengan URL preview, hanya untuk uji.
- Hasil: `deploy/hostinger/jasakamerata_public_html.zip` (sudah berisi `.htaccess` untuk HTTPS, redirect www → non-www, dan routing halaman React). Skrip platform Emergent dihapus dari `index.html`.

Unggah: hPanel → **File Manager** → `public_html` → hapus `default.php` bawaan → **Upload** zip → klik kanan **Extract** → pastikan `index.html` dan `.htaccess` ada langsung di `public_html`.

Catatan penting:
- Login dari domain berbeda memakai token di `localStorage` (cookie pihak ketiga sering diblokir Safari). Sudah diuji di preview: masuk dan keluar berfungsi tanpa cookie.
- Login Google saat ini masih lewat layanan terkelola Emergent. Arah balik ke `https://jasakamerata.com` **belum diuji** dengan akun Google nyata.
- Data, foto portofolio, dan pembayaran tetap di backend Emergent sampai tahap Node.js selesai.

---

## 3. Backend Node.js + Express + MySQL (bertahap)

Folder: `deploy/node-api/`

| Tahap | Cakupan | Status |
|---|---|---|
| 1 | Katalog publik: kategori, daftar/cari/urut fotografer, unggulan, profil + portofolio, ulasan, layanan | **Selesai** — 11/11 uji paritas lulus (respons Express = FastAPI pada data yang sama) |
| 2 | Login Google sendiri + sesi di MySQL + peran | Belum — butuh Client ID Google (bagian 4) |
| 3 | Favorit, chat | Belum |
| 4 | Ketersediaan, booking, konflik jadwal | Belum |
| 5 | Ledger, dompet, penarikan, admin | Belum |
| 6 | Penyimpanan foto + pembayaran Midtrans + webhook | Belum |

Pasang di Hostinger (setelah tahap 2 selesai; tahap 1 boleh diuji lebih dulu di subdomain `api.jasakamerata.com`):
1. hPanel → **Websites → Add Website → Node.js Apps** (atau menu Node.js) → unggah isi `deploy/node-api` (tanpa `node_modules`).
2. Entry file: `server.js`, Node 20.
3. Isi environment variables sesuai `.env.example`: `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `CORS_ORIGINS=https://jasakamerata.com`.
4. Cek `https://api.jasakamerata.com/api/health` → harus `{"ok":true,"db":"mysql"}`.

Uji paritas lokal:
```
FASTAPI_URL=http://localhost:8001 EXPRESS_URL=http://localhost:8099 yarn test
```

---

## 4. Login Google sendiri (Google Cloud Console)

Dikerjakan oleh pemilik (butuh akun Google Anda):
1. Buka https://console.cloud.google.com → buat project **Jasakamerata**.
2. **APIs & Services → OAuth consent screen** → tipe **External** → isi nama aplikasi `Jasakamerata`, email dukungan `rifkyapriawan04@gmail.com`, logo, domain `jasakamerata.com`, tautan kebijakan privasi `https://jasakamerata.com/kebijakan/privasi`, syarat `https://jasakamerata.com/kebijakan/syarat-ketentuan`. Scope: `openid`, `email`, `profile`.
3. **Audience / Publishing status** → tekan **Publish app** (agar semua akun Google bisa masuk, bukan hanya akun uji).
4. **Credentials → Create credentials → OAuth client ID** → tipe **Web application**:
   - Authorized JavaScript origins: `https://jasakamerata.com`
   - Authorized redirect URIs: `https://jasakamerata.com/auth/google`
5. Simpan **Client ID** dan **Client Secret**. Masukkan nanti sebagai environment variable `GOOGLE_CLIENT_ID` dan `GOOGLE_CLIENT_SECRET` di panel Node.js Hostinger. **Jangan kirim Client Secret lewat chat.**
6. Beri tahu kami Client ID sudah dibuat; tahap 2 (kode login Express) akan dikerjakan dan diuji dengan akun Google nyata.

Catatan: alamat redirect `/auth/google` adalah alamat yang akan dipakai backend Express tahap 2. Bila nanti alamatnya berubah, daftar di Google Console juga harus diubah.
