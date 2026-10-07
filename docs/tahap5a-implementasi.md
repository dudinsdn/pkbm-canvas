# Tahap 5A — fondasi implementasi

Tanggal: 7 Oktober 2026.

## Bagian yang ditulis

- Migrasi `20261007000500` membaca `apps/pkbm/db/identity.sql`: identitas global, subject federasi, tautan membership, tautan Canvas, audit dan sesi server.
- Identitas tidak berisi password. Subject unik menurut issuer/protokol/identifier. Membership hanya dapat ditautkan ke satu identitas dan satu identitas memiliki satu profil pada setiap PKBM; beberapa peran tetap memakai role_assignments.
- Tautan Canvas unik berdasarkan deployment/root, identity, user remote dan identifier provider. Deployment bukan canvas_instances tenant: dua PKBM dapat memakai installation/root yang sama.
- Audit keputusan tidak dapat diperbarui/dihapus melalui SQL biasa. Tidak menaruh snapshot bebas yang dapat menyalin credential.
- `IdentityRegistry` merupakan layanan internal untuk pembuatan dan tautan identity yang ditelaah pengelola. Ia memeriksa membership aktif/peran pengelola pada tenant target, mengunci record, memakai transaksi, menolak konflik dan menulis audit. Tidak ada pencocokan otomatis berdasarkan email/nama atau endpoint klaim identitas publik.
- `IdentitySessionStore` menyediakan token opaque dengan digest SHA-256, batas 8 jam, pemeriksaan identity/status/version/membership pada resolusi, serta pencabutan lokal. Ini primitive untuk login federasi berikutnya, belum dipakai controller dan bukan logout bersama.

## Batas aktual

Migrasi `20261007000500` sudah diterapkan pada database PKBM lokal; `db/structure.sql` diperbarui oleh Rails. Pengujian fondasi selesai dengan 23 pemeriksaan lolos dan 0 gagal. Akun demo, bindings, credential, sesi login lama dan database Canvas belum diubah. Tidak ada paket/image yang dipasang.

Keputusan IdP dan protokol portal (5A.1) masih terbuka. Fondasi 5A.2 yang tidak bergantung produk didahulukan; model audit/sesi belum berarti 5A.2 seluruhnya selesai. Inventarisasi dan telaah kandidat akun lama belum dijalankan. Unique constraints merupakan rancangan kontrol konkurensi, belum bukti bahwa semua kasus retry berjalan.

Belum ada callback federasi, aktivasi/pemulihan password, login bersama, pemetaan provider Canvas, navigasi lintas aplikasi atau cutover. Login lokal lama masih menjadi jalur aktif. User interface belum berubah.

## Kelanjutan

1. Pilih layanan identitas setelah inspeksi resource/cache/dependensi lokal; tetapkan issuer/callback serta kontrak logout.
2. Lengkapi pemetaan subject/provider dan inventarisasi akun lama melalui API Canvas yang diotorisasi, dengan keputusan operator eksplisit.
3. Terapkan migrasi saat dependensi konfigurasi siap, lalu hubungkan callback yang memvalidasi assertion ke sesi server dan pemilihan konteks.
4. Integrasikan federasi Canvas, kesiapan enrollment serta navigasi/login/logout.
5. Uji setelah pengguna meminta pengujian, lalu perbarui checklist berdasarkan bukti aktual.

**Bukti terbaru: migrasi dan pengujian database/service lokal. Belum menguji browser, API federasi, SSO, logout bersama atau gerbang Tahap 5A. Belum commit.**

## Bukti migrasi dan pengujian lokal

Backup custom-format dibuat sebelum migrasi di `var/backups/pkbm-before-identity-20261007.dump` (221 KiB, akses 0600, tidak dilacak Git). Daftar isi dibaca dengan pg_restore --list; restore penuh belum diuji. Backup memuat data sensitif lokal dan tetap berada di direktori var yang diabaikan Git.

Script reproduksi: `scripts/validation/identity-foundation.rb`, dijalankan melalui stdin ke `docker exec -i pkbm-canvas-pkbm-1 bundle exec rails runner -`. Hasil: [23 pemeriksaan](tahap5a-hasil-uji-identitas.json). Pengujian pertama gagal pada fixture FK karena constraint unik terpicu terlebih dahulu. Fixture diperbaiki memakai identity yang belum tertaut; pengujian ulang exit 0, 23 lolos, 0 gagal.

Cakupan: retry identity, batas pengelola lintas tenant, larangan provisioning oleh WB, konflik membership, pemisahan profil tenant, pending/disabled identity, digest token, membership nonaktif, masa berlaku dan pencabutan sesi, keunikan subject/user Canvas, FK tenant, kesiapan link dan audit immutable. Fixture berada dalam transaksi rollback; pemeriksaan sesudahnya menemukan nol identity, membership link, session dan migration event. Tidak ada panggilan Canvas, migrasi akun lama atau perubahan credential. Konkurensi worker, pemetaan subject nyata, satu identity lintas dua PKBM dan logout federasi belum diuji.
