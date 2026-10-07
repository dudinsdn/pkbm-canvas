# Tahap 5A — konfigurasi OIDC dan callback portal

## Koreksi inspeksi Canvas

Checkout terkunci mempunyai `AuthenticationProvider::OpenIDConnect` di `vendor/canvas-lms/app/models/authentication_provider/open_id_connect.rb`. File sebelumnya dicari dengan nama `openid_connect.rb` sehingga dukungannya terlewat. Source mengakui issuer, discovery/JWKS, login_attribute, endpoint logout serta autentikasi client. Desain sekarang memilih OIDC untuk portal dan Canvas; SAML tidak lagi menjadi jalur awal.

## Status terbaru

Keycloak sudah berjalan pada 8082, realm/client telah diimpor, enam profil demo tertaut ke subject pusat, dan empat login Canvas memakai user 4/5/6/7 melalui provider 3. Migrasi state dan sid diterapkan. Flag SSO lokal aktif. [Operasi dan batas](tahap5a-operasi-identitas.md). Uraian pending berikut merupakan catatan saat kode pertama ditulis; status terbaru ini menggantikannya. Browser dan logout belum diuji.

## Perubahan implementasi

- Overlay `infra/identity/compose.yml` menyiapkan Keycloak 26.8.0 untuk lokal pada 8082, limit memori 768 MiB, heap maksimum 384 MiB. Portal 3000 dan Canvas 8081 tetap. `start-dev`/penyimpanan lokal hanya untuk pengembangan, bukan produksi.
- `scripts/identity-prepare` menyiapkan realm dengan dua client confidential, callback tepat, PKCE portal, tanpa registrasi publik/JIT. Secret acak tersimpan 0600 pada var/identity, tidak masuk Git. Script menolak menimpa konfigurasi. SMTP/pemulihan password belum disiapkan; resetPasswordAllowed=false untuk mencegah klaim pemulihan siap.
- Image belum diunduh atau layanan dijalankan; izin download diajukan kepada pengguna. Resource aktual sebelum layanan: RAM tersedia sekitar 1.4 GiB, tanpa swap. Limit konfigurasi tidak membuktikan kapasitas runtime.
- Library `jwt` 3.1.2 dipasang dari cache lokal dan lockfile diperbarui; tidak mengunduh gem baru.
- Callback portal memakai Authorization Code/PKCE, cookie terenkripsi HttpOnly/SameSite=Lax, state tersimpan server yang dikonsumsi sekali, validasi RS256/JWKS/issuer/audience/expiry/iat/nonce/azp. Backchannel tidak mengikuti redirect dan endpoint berasal dari konfigurasi server, bukan klaim pengguna.
- Callback hanya menerima subject yang sudah ditautkan ke identity; tidak mengklaim akun berdasarkan email/nama dan tidak membuat identity otomatis.
- API contexts memilih membership aktif dan mengeluarkan opaque token yang diperiksa oleh API operasional; saat flag SSO aktif, login password lokal dan token signed legacy tidak lagi diterima oleh controller operasional.
- React memperoleh flag konfigurasi, menampilkan tombol login bersama dan pilihan konteks saat SSO aktif. Flag tetap false; UI aktif lama belum berubah.
- Template provider Canvas menggunakan sub dan JIT=false. Belum ada provider dipasang atau pseudonym akun lama ditautkan. Template memisahkan endpoint browser dan backchannel jaringan Docker.

## Batas yang harus diselesaikan sebelum cutover

Migrasi 20261007000600 untuk state login **belum diterapkan**. Kode callback/UI baru **belum diuji**. Bukti 23 uji fondasi sebelumnya tidak berlaku untuk OIDC.

Belum: image/runtime IdP, subject akun lama, konfigurasi provider melalui API Canvas, tautan pseudonym, enrollment/kesiapan akses, route Mulai belajar yang memeriksa sesi Canvas, aktivasi/undangan/reset, logout/pencabutan lintas aplikasi, audit provisioning subject/provider, migrasi LTI ke identity, dan pengujian browser/protokol. Jangan mengaktifkan PKBM_SSO_ENABLED sebelum ketergantungan ini siap. LTI legacy belum bisa dipakai sebagai jalur sesi baru setelah cutover. Tombol keluar lama belum membuktikan pencabutan sesi server atau logout bersama.

## Sumber

- Keycloak [panduan Docker resmi](https://www.keycloak.org/getting-started/getting-started-docker) untuk image 26.8.0 dan start-dev.
- [Konfigurasi hostname](https://www.keycloak.org/server/hostname) untuk URL frontend/backchannel.
- Canvas: source lokal terkunci, provider open_id_connect dan route /login/oauth2/callback.

Belum commit; SSO tetap tidak aktif.
