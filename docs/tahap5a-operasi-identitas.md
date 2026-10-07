# Operasi identitas lokal Tahap 5A

## Perintah

- `scripts/identity-prepare`: sekali, buat realm/client dan secret lokal pada var/identity; menolak overwrite.
- `scripts/identity-compose up -d --no-deps identity pkbm`: jalankan overlay pada project yang sama. Jangan gunakan compose utama sendirian untuk recreate portal setelah cutover karena env OIDC ada pada overlay.
- `scripts/identity-bootstrap-demo`: provision enam profil DEMO-A/DEMO-B di IdP dengan identifier berdasarkan kode PKBM dan peran; password demo lama dipakai kembali sebagai credential pusat. Perintah tidak mengubah password lama pada portal/Canvas. Ia juga mengkonfigurasi URL backchannel logout kedua client.
- Import metadata: salin `var/identity/demo-mapping.json` ke `/tmp/pkbm-demo-mapping.json` pada container portal, lalu `PKBM_IDENTITY_MAPPING_FILE=/tmp/pkbm-demo-mapping.json bundle exec rails runner bin/identity-demo-import.rb`.
- `scripts/identity-canvas-prepare`: materialisasikan payload provider yang memuat secret pada direktori var yang diabaikan Git.
- `bin/identity-canvas-configure.rb`: menerima file token sementara `/tmp/pkbm-stage5a-token.json` dan payload `/tmp/pkbm-canvas-provider.json` pada container portal; pasang provider melalui API, lalu tautkan login federasi hanya ke user Canvas yang sudah terikat. Token dipakai pada model instance dalam memori dan tidak disimpan ke credentials_encrypted.

Pembuatan/pencabutan token tetap tindakan operator Canvas melalui mekanisme native yang diotorisasi. Jangan menyalin token ke Git, URL, log atau dokumentasi. Hapus file sementara setelah pencabutan.

## Pengguna demo

Username pusat berbentuk `demo-a-pengelola`, `demo-a-tutor`, `demo-a-warga-belajar`, dan bentuk DEMO-B yang sama. Password memakai credential demo sesuai peran yang sudah ada di .env, bukan password Canvas kedua. Enam profil fixture adalah enam identitas berbeda; email sama tidak membuatnya satu orang. Ini bootstrap fixture, belum alur undangan/aktivasi pengguna nyata.

## Login, konteks dan navigasi

Flag PKBM_SSO_ENABLED hanya diaktifkan setelah IdP, subject dan provider siap. Portal menggunakan callback issuer/subject untuk identity yang tertaut, kemudian memilih membership aktif. Token opaque diperiksa server pada setiap akses API.

Route /belajar/:id menelaah delivery pada scope membership, link identity dan binding user Canvas, lalu membuka provider dengan expected_user_id dan login_hint. Tidak memakai force_login yang memaksa password lagi. Sasaran route adalah Course terikat. Enrollment tetap kewenangan Canvas; status link ready hanya membuktikan tautan user/provider hasil read-back, belum semua hak delivery atau browser.

## Logout dan LTI

Portal mencabut token cookie/header lokal, lalu mengarahkan browser ke logout IdP untuk diselesaikan. Client IdP memakai endpoint backchannel Canvas native dan endpoint portal. Portal memverifikasi signature/issuer/audience/expiry/events/jti, menolak replay, dan mencabut sesi yang cocok dengan sid/subject. Sid juga dibawa ketika mengganti konteks. Keberhasilan logout semua sisi harus diuji; redirect saja bukan buktinya.

Ketika SSO aktif, pertukaran LTI memerlukan sesi portal yang sudah ada dan identity yang sama dengan membership launch. LTI tidak lagi membuat signed token legacy secara terpisah. Launch dengan identity berbeda ditolak, bukan mengubah pengguna otomatis.

## Batas deployment

Keycloak memakai start-dev dan database pengembangan lokal. Volume /var/identity/data harus disimpan/di-backup; ini belum deployment produksi atau rencana restore IdP yang dibuktikan. Tidak ada SMTP/reset/aktivasi publik yang siap. Akun lama tidak dihapus; rollback dapat menonaktifkan flag SSO dan mengembalikan login lokal dengan menelaah sesi/hasil yang dibuat selama cutover.

Compose overlay menginterpretasikan path volume relatif file Compose utama di infra; path yang benar ../var/identity. Percobaan awal ../../var/identity membuat volume salah sehingga H2 tidak dapat menulis, dan startup gagal sebelum provisioning. Path telah diperbaiki.

## Hasil tindakan implementasi lokal

- Image 26.8.0 terunduh, dikunci digest sha256:b0f60d489d51c5d113390bdf5461d4c06e6051be026c05549f2e1e10ec352bcc; layanan dan realm berhasil startup setelah path volume diperbaiki. Limit 768 MiB tidak menyebabkan OOM pada startup yang diamati.
- Migrasi 20261007000600 (state sekali pakai) dan 20261007000700 (sid logout) diterapkan. Dump structure.sql diperbarui Rails.
- Enam akun demo pusat dibuat dengan password peran lama, bukan password Canvas tambahan. Marker metadata awal dibuang oleh profil IdP; unmanagedAttributePolicy diatur ADMIN_EDIT. Marker fixture yang baru dibuat diperbaiki pada operasi bootstrap ini; mode perbaikan sementara dihapus dari script agar akun tanpa marker ditolak pada pengulangan berikutnya.
- Enam identity/membership/subject ditautkan di PKBM dengan audit; login/pseudonym lama tidak dihapus atau di-merge.
- Provider Canvas 3 dipasang melalui API. CanvasHttp awalnya menolak endpoint privat JWKS; initializer mount memberikan pengecualian development hanya pada HTTP identity:8080 dengan dua path kunci/discovery tepat, tanpa userinfo/query/fragment. Perlindungan host lain tetap memakai implementasi Canvas. Ini pengecualian lokal, bukan konfigurasi produksi.
- Login federasi ditambahkan pada user terikat: DEMO-A tutor 4 dan WB 5; DEMO-B tutor 6 dan WB 7. Tidak membuat user pengganti atau memindahkan pekerjaan/enrollment.
- Provider OIDC menjadi posisi 1; provider Canvas lokal tetap tersedia pada /login/1 untuk operasi pemulihan. Akun pengelola portal tidak diproyeksikan menjadi root Admin Canvas. Pengelola yang belum mempunyai user/link Canvas melihat akses sedang disiapkan, bukan link Course yang mengasumsikan hak sudah ada.
- Pengulangan konfigurasi sempat gagal HTTP 400 karena lookup /accounts/1/logins membutuhkan pengguna dan tidak mengembalikan semua login. Lookup diubah menjadi /users/:bound_user_id/logins dan difilter root/provider/identifier. Operasi ulang kemudian berhasil memakai empat login yang ada.
- Flag PKBM_SSO_ENABLED aktif melalui overlay; portal dimuat ulang pada port 3000 yang sama. Sinkronisasi dalam mode SSO mewajibkan identity/link ready, memakai kembali user global terikat dan menolak user hilang/konflik; tidak membuat password acak pengguna baru dalam mode tersebut.
- Dua token admin sementara digunakan dalam otorisasi pengguna: token pertama dicabut sebelum konflik pengulangan selesai; token pengganti dicabut setelah konfigurasi selesai. Keduanya tidak disimpan ke credential integrasi persisten. File token/payload/metadata sementara di container serta file token lokal di /tmp dihapus. Tidak ada token layanan persisten untuk worker yang dibuat; publikasi Tahap 6 tetap membutuhkan credential integrasi terotorisasi.

**Tingkat bukti:** hasil migrasi, provisioning IdP/API Canvas, read-back mapping sebagai bagian provisioning, startup log. Tidak menjalankan suite OIDC/API atau alur browser. Login sekali lintas aplikasi, perpindahan sesi lama, semua role, logout backchannel (termasuk root Host routing Canvas), pencabutan lintas tab, pemulihan password dan produksi belum dibuktikan. Gerbang 5A tetap terbuka. Ini cutover lokal yang harus diuji; bukan klaim lulus pengguna/produksi.

Akun untuk dicoba dari http://127.0.0.1:3000: demo-a-warga-belajar atau demo-a-tutor; password demo WB/tutor yang sudah ada di .env. Pengelola: demo-a-pengelola. Bentuk DEMO-B mengganti demo-a menjadi demo-b. Jika browser masih menyimpan tab/login lama, gunakan tombol Masuk pembelajaran pada portal; route belajar memakai expected_user_id. Perilaku sesi lama tetap perlu pengujian, jangan diasumsikan beres hanya karena parameter tersedia.

Konfigurasi aktif dan realm impor memuat secret, berada pada var/identity yang diabaikan Git; jangan melampirkannya ke hasil pengujian. Belum commit.

## Pengujian HTTP/API — 7 Oktober 2026

Atas permintaan pengguna, `scripts/validation/oidc-api.py` memeriksa enam akun dengan cookie terpisah. Hasil terakhir: **78 lolos, 0 gagal**, exit 0. [Laporan](tahap5a-hasil-uji-oidc-api.json). Tidak memakai token admin Canvas, membuat akun baru, atau mengubah enrollment/nilai. Rekaman login/sesi dan state dipertahankan seperti alur auth normal; sesi uji yang berhasil ditutup melalui logout, bukan transaksi rollback.

Cakupan: discovery issuer, flag SSO, credential tiap akun, callback, satu konteks tenant yang tertaut, pilihan konteks, API me/peran, links, login ulang tanpa password, user Canvas 4/5/6/7, akses Course, konfirmasi logout IdP, token portal terdahulu (tidak dicabut langsung oleh endpoint logout lokal) ditolak, dan cookie sesi Canvas ditolak setelah backchannel logout. Pengelola hanya diuji pada portal; tidak diberi root Admin atau Course enrollment tambahan.

Temuan dan perbaikan:

1. Client requests tidak mengirim cookie Secure pada localhost HTTP; harness meniru pengecualian loopback untuk cookie domain 127.0.0.1. Keamanan cookie aplikasi tidak diubah. Hasil gagal awal merupakan keterbatasan harness, bukan bukti password salah. Ini belum bukti perilaku cookie pada browser tertentu.
2. Canvas LoginController membuang target_link_uri saat meneruskan provider; adapter development pada initializer mount mempertahankan parameter itu. Target Course memakai path relatif sehingga validasi return path Canvas tidak bergantung pencocokan host dengan port. Alur tetap melalui login native yang menyimpan expected_user_id.
3. Host authorization Canvas menolak POST logout dari web:3000 (403). Overlay mengatur VIRTUAL_HOST=web, host spesifik yang didukung konfigurasi development Canvas. Pengujian ulang membuktikan logout pusat mencabut sesi Canvas.

Belum diuji: GUI/browser, stale sesi pengguna lain/masquerade, multi-tab/back, login langsung Canvas dan logout yang dimulai dari Canvas, callback adversarial/replay/expiry, satu identity di dua PKBM, konflik/concurrency provisioning, deactivation tenant/global, LTI setelah SSO, reset/undangan/SMTP, restore dan produksi. Gerbang 5A lengkap tetap belum lulus. Endpoint master/security-admin-console adalah konsol operator Keycloak; enam akun pembelajaran berada di realm pkbm dan masuk lewat portal 3000.

Belum commit.

## Penyederhanaan pintu masuk — 7 Oktober 2026

Portal kini langsung menuju login pusat bila tidak ada sesi; bila cookie sesi pusat masih aktif, portal mengambil konteks dan masuk otomatis untuk satu membership. Pilihan PKBM hanya muncul jika lebih dari satu membership aktif. localhost diarahkan ke origin kanonik dari konfigurasi portal sebelum memulai autentikasi, sambil mempertahankan path/query/hash. Tidak lagi menampilkan link Masuk sebelum login pertama; layar singkat memuat sesi tidak memerlukan klik.

Sesudah pengguna sengaja keluar, marker pada sessionStorage tab menahan login otomatis agar pengguna tidak langsung masuk lagi; tersedia Masuk kembali yang membersihkan marker. Kegagalan callback ditampilkan dengan opsi mencoba lagi, bukan redirect otomatis berulang. Perubahan JS/alur masuk ini belum diuji API atau browser; bukti 78 sebelumnya tetap hanya untuk protokol yang diuji saat itu. Belum commit.

## Pemeriksaan API setelah penyederhanaan pintu masuk

Login/Canvas/logout diulang atas permintaan pengguna: 78 lolos, 0 gagal. Pemeriksaan diperluas ke 17 koleksi operasional untuk enam akun, daftar penilaian, guard integrasi, pembacaan membership PKBM lain yang ditolak, akses Course Canvas PKBM lain yang ditolak, enam katalog UI, konfigurasi origin kanonik dari localhost, dan tiga asset yang benar-benar disajikan server.

Hasil gabungan akhir: **212 pemeriksaan lolos, 0 gagal**. Run diperluas awalnya 209 lolos/3 gagal akibat requests mendekode text/javascript sebagai ISO-8859-1. Perbandingan byte membuktikan seluruh asset identik dengan source; harness dikoreksi dan hanya tiga cek asset diulang, semuanya lolos. Laporan JSON memisahkan run awal dan retest terarah; bukan klaim satu suite penuh terakhir exit 0. node --check pada pkbm.js, integration.js dan assessments.js juga exit 0.

Tidak ada kegagalan endpoint baru pada cakupan ini. HTTP/API tidak mengeksekusi React; login otomatis, marker setelah keluar, redirect origin lewat JavaScript dan render/interaksi UI belum dibuktikan pada browser. Keberhasilan canonical_base_url pada API bukan bukti bahwa JavaScript browser telah menjalankan redirect. Pengujian mutasi penilaian/publikasi/hasil Tahap 6, LTI, callback negatif, deactivation, concurrency dan produksi tetap di luar cakupan. Tidak ada enrollment, nilai atau credential yang diubah; sesi uji ditutup melalui logout. Belum commit.


### 2026-10-07 — Logout kembali ke login bersama

- Portal kini mengirim tujuan logout `/auth/login`; IdP kedua client mengizinkan tujuan yang sama. Adapter Canvas hanya untuk provider PKBM lokal mempertahankan id_token_hint bawaan dan mengirim tujuan login portal.
- Callback portal menyimpan ID token yang telah diverifikasi dalam cookie terenkripsi HttpOnly untuk logout tanpa konfirmasi IdP tambahan; cookie dibuang ketika logout. Parameter hint disaring dari log Rails. Sesi lama tanpa hint masih meminta konfirmasi IdP sekali.
- Penanda logout pada tab tidak lagi menghentikan pengguna di halaman tombol Masuk kembali: membuka ulang portal mengarah ke login.
- HTTP/API: 230 pemeriksaan, 0 gagal; enam akun portal dan empat akun Canvas tutor/WB. Logout dari kedua aplikasi berakhir pada form login, bearer portal lama ditolak 401, cookie Canvas ditolak 401. Ini mencakup pemeriksaan baca API operasional/katalog/penilaian dan isolasi dua PKBM, bukan seluruh mutasi domain.
- Browser nyata, WB DEMO-A: login menuju rencana belajar otomatis, Keluar portal langsung ke form login; login ulang dan masuk Course 3, logout Canvas ke form login; buka ulang portal tetap login. Screenshot: docs/logout-login-browser.png. Canvas mempertahankan konfirmasi Log Out bawaan.
- Bootstrap demo sempat berhenti karena token admin kedaluwarsa setelah konfigurasi client diterapkan. Tidak ada perubahan password; logout aktual kedua client telah terbukti melalui HTTP dan browser. Restart portal/web selesai. Gerbang keseluruhan 5A tetap terbuka untuk skenario lainnya.


### 2026-10-07 — Akses pengelola Canvas (implementasi, otorisasi runtime tertunda)

- Ditambahkan route `/kelola/canvas`, tautan Kelola Canvas, pemetaan `canvas_management_links`, dan provisioning pengelola melalui API. Login memakai identity yang sama; tidak membuat password kedua.
- Provisioner memakai kembali binding/global identity/SIS key; memasang login federasi, memeriksa subaccount milik PKBM, menolak root admin, dan membaca ulang grant sebelum menandai siap. Skrip operasi dibatasi pada DEMO-A/DEMO-B.
- Migrasi 20261007000800 diterapkan lokal setelah backup `var/backups/pkbm-before-manager-access-20261007.dump`. Tidak menjalankan pengujian API/browser untuk perubahan ini.
- Review persetujuan otomatis menolak pemindahan token operasional dan pemberian AccountAdmin pada subaccount: permintaan akses Canvas belum dianggap otorisasi eksplisit untuk hak administrasi. Persetujuan pengguna diminta. Pemberian hak/user Canvas belum dijalankan; tautan tetap belum siap. Token sementara dicabut dalam langkah pembersihan.
- Bukti 230 pemeriksaan sebelumnya mendahului perubahan akses pengelola ini, sehingga bukan bukti kelulusannya.


### 2026-10-07 — Hak pengelola Canvas dipasang

Pengguna menyetujui pengelola sebagai admin Canvas pada subaccount masing-masing. Provisioning API selesai: Canvas user 9 → subaccount 4; user 10 → subaccount 5. Dua pemetaan berstatus ready setelah pembacaan ulang login federasi dan grant AccountAdmin; tidak diberi root admin. Link Kelola Canvas tersedia melalui `/kelola/canvas` memakai akun/login yang sama. Token operasional sementara dicabut dan salinan rahasia dihapus. Belum menjalankan suite API/browser untuk fitur pengelola; bukti 230 pemeriksaan sebelumnya tidak mencakup perubahan ini. Belum commit.


### 2026-10-07 — Halaman awal dan navigasi pengelola Canvas

- Adapter presentasi Canvas lokal mengarahkan Dashboard pengelola yang punya satu subaccount PKBM ke halaman Kelola pembelajaran. Jika lebih dari satu PKBM, menuju pemilih account native; operator root dan pengguna tanpa grant tetap memakai dashboard native.
- Halaman subaccount menampilkan nama PKBM, tautan pembelajaran, tutor/warga belajar dan pengaturan sesuai izin Canvas, serta daftar maksimal 12 course dengan tautan Lihat semua. Data dan otorisasi tetap milik Canvas. Ada tautan kembali ke ruang kerja PKBM; seluruh perpindahan link course/kelola menggunakan tab yang sama.
- Perubahan disimpan pada adapter/view/CSS milik proyek dan di-mount ke Canvas, tanpa mengubah versi/source vendor atau membangun ulang bundle Canvas. Aktivasi melalui recreate layanan web memakai image lokal.
- Tidak menjalankan suite pengujian atau verifikasi browser untuk perubahan dashboard ini; bukti 230 pemeriksaan lama tidak membuktikan tampilan baru. Belum commit.


### 2026-10-07 — Pengujian HTTP/API dashboard pengelola

Permintaan pengguna mengotorisasi pemeriksaan API. Uji awal menemukan adapter tidak menangani Accept wildcard (20 lulus/6 gagal). Setelah mengaktifkan HTML non-API, permintaan Dashboard menemukan HTTP 500 karena Canvas melarang `includes`; diganti `preload` (run kedua 24 lulus/6 gagal). Pengulangan akhir exit 0: **30 pemeriksaan lulus, 0 gagal**.

Kedua pengelola masuk dengan user Canvas 9/10, link Kelola Canvas dan Dashboard `/` menuju subaccount 4/5 yang benar, HTML halaman baru memuat tautan kembali portal, navigasi pembelajaran/pengguna/pengaturan dan CSS memberi HTTP 200. Endpoint account tetap JSON meski Accept wildcard. API daftar course account sendiri 200, account PKBM lain/root 403. Script: scripts/validation/manager-dashboard-api.py; bukti: docs/tahap5a-hasil-uji-dashboard-pengelola.json. Cookie Secure loopback diemulasikan untuk HTTP lokal. Ini bukti HTTP/API, bukan render/klik browser maupun seluruh skenario/gerbang 5A. Sesi uji ditutup; tidak memakai token admin. Belum commit.


### 2026-10-07 — Telusur browser alur login pengelola

Permintaan pengguna: cek lagi alur login. Pada satu tab browser diuji WB DEMO-A keluar → form login → login demo-a-pengelola → portal mengidentifikasi Pengelola DEMO-A → Kelola Canvas → /accounts/4. Tidak ada password kedua. Membuka Canvas `/` saat sesi aktif menuju /accounts/4. Setelah logout portal, membuka Canvas `/` tanpa sesi menampilkan form OIDC client pkbm-canvas; satu password pengelola membawa ke /accounts/4. Kembali ke portal menyelesaikan callback OIDC otomatis dan mengidentifikasi pengelola yang sama, lalu Kelola Canvas kembali ke /accounts/4 pada tab yang sama. Screenshot docs/pengelola-login-browser.png.

Tidak ditemukan kegagalan login pada jalur terbatas ini. Detail masalah yang dialami pengguna diminta (form kedua, akun salah, atau tujuan halaman). Tidak mengubah algoritma login tanpa reproduksi. Ini bukan bukti semua akun/perangkat/multitab atau gerbang 5A keseluruhan.

## Aktivasi dan pemulihan lokal

Persetujuan pengguna: client layanan pengelolaan akun PKBM dan nama keluarga opsional. Jalankan `scripts/identity-account-setup` hanya pada stack lokal ini untuk menyiapkan SMTP internal, aturan profil dan client confidential `pkbm-provisioning` (`manage-users`, `view-users`, `query-users`). Secret lokal tetap di `var/identity/runtime.env` dan tidak ditampilkan/commit. Setelah konfigurasi secret baru, gunakan `scripts/identity-compose up -d --no-deps --no-build --pull never pkbm` agar environment portal diperbarui.

Alur pengelola: Anggota dan peran → simpan orang dengan email → membership dan peran → Aktivasi akun → pilih anggota dan username → kirim. Pengguna membuka email, memverifikasi alamat, mengatur password terpusat dan kembali ke portal. Lupa password berada pada form Keycloak yang sama. Aktivasi ini tidak otomatis memberikan enrollment atau hak admin Canvas: provisioning mengikuti membership/peran yang disetujui.

Email hanya ditampung di `apps/pkbm/tmp/identity-mail` (direktori 0700, file 0600, diabaikan Git), melalui SMTP port internal 1025. File mengandung tautan aktivasi/reset: jangan ditampilkan dalam log, dokumen atau commit. Tidak ada port host/email UI dan tidak ada pengiriman internet. SMTP produksi memerlukan konfigurasi terpisah. Client layanan mempunyai izin persisten pada realm PKBM; hapus grant/client dan secret bila fungsi ini dinonaktifkan.

Uji: `scripts/validation/identity-activation-api.py` membuat profil bernama eksplisit, memakai password acak di memori dan menyimpan report tanpa password/token. Setelah selesai jalankan `scripts/identity-compose exec -T pkbm bundle exec rails runner - < scripts/validation/identity-activation-cleanup.rb` untuk menonaktifkan hanya profil uji dengan marker/name/email yang sesuai, tanpa menghapus audit. Delapan profil iterasi saat ini sudah dinonaktifkan. Report akhir 11 lolos/0 gagal; panel terlihat di browser pengelola DEMO-A.

Bukti tambahan: fondasi 24 lolos; callback/assertion 23 lolos; retry provisioning kedua pengelola memakai ID lama dan tepat satu grant, token sementara dicabut; restore database PKBM/Canvas 24 lolos. Restore Keycloak, worker paralel, seluruh cakupan browser dan histori penilaian yang terisi belum dibuktikan. Gerbang keseluruhan 5A belum lulus.


Pemeriksaan tambahan API undangan: **6 lolos, 0 gagal**, tanpa membuat/mengubah akun: unauthenticated 401, akun aktif dan username invalid 422, membership PKBM lain 404, tutor/WB 403. Report tahap5a-hasil-uji-otorisasi-undangan.json. Browser satu tab juga membuktikan logout pengelola DEMO-A → login, tombol Back tetap menuju form login tanpa menampilkan ruang kerja lama, lalu pengelola DEMO-B → portal → Canvas subaccount 5 → kembali portal dengan identitas DEMO-B tanpa password kedua. Ini menambah cakupan pengelola dua PKBM; belum membuktikan multi-tab atau seluruh skenario semua peran.
