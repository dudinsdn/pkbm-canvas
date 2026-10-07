# Catatan implementasi PKBM–Canvas

**Status terbaru:** Tahap 4 diimplementasikan dan API lulus lokal; pengguna mengonfirmasi UI dasar secara manual. Tahap 4 Lulus lokal berdasarkan uji API agen dan konfirmasi alur dasar browser oleh pengguna. Tahap 1–2 lulus lokal untuk fondasi dan katalog contoh; Tahap 3 lulus lokal dengan checklist lengkap, termasuk pengukuran terpisah dan unggahan browser melalui Files lama. [Bukti terbaru](../tahap12-verifikasi.md). Bagian sebelumnya merupakan riwayat bertanggal, bukan status terkini.

## Tahap 0 — 7 Oktober 2026

Status: pemeriksaan lingkungan dan pemilihan konfigurasi selesai; gerbang build bersyarat. Canvas belum dipasang. Tahap 1 belum dikerjakan.

### Bukti lingkungan terbaru

| Item | Hasil pemeriksaan |
|---|---|
| Root | 49 GiB, terpakai 35 GiB, tersedia 12 GiB, 75% |
| Home | 113 GiB, terpakai 91 GiB, tersedia 17 GiB, 85% |
| RAM | Total 6,7 GiB; tersedia 3,5 GiB |
| Swap | 1 GiB; belum terpakai |
| Docker root | `/var/lib/docker`, pada root |
| Image | 5 image, total 2,019 GB; Canvas dan Redis belum tersedia |
| Build cache | 6,912 GB; belum dibersihkan |
| Container | Empat container proyek lama, semuanya berhenti |
| Volume | Tiga volume, seluruhnya masih direferensikan |
| Endpoint yang dipilih | Canvas `127.0.0.1:8081`; PKBM `127.0.0.1:3000` |

Port 8081 dan 3000 tidak terlihat digunakan pada snapshot `ss -ltn`. Periksa ulang sebelum start. Pemeriksaan Docker/port membutuhkan akses host karena sandbox membatasi socket. Ini pemeriksaan lingkungan, bukan validasi aplikasi.

### Versi yang dipilih

Canvas memakai tag `release/2026-05-20.143`, commit `2e2b4a46d08e32667d4845f7b78e1214250345d3`. Pemilihan tag eksplisit untuk baseline lokal; bukan klaim release terbaru atau rekomendasi produksi. GitHub Tags API mengonfirmasi pasangan tag/commit.

Sumber pada commit tersebut:

- [Dockerfile Canvas](https://github.com/instructure/canvas-lms/blob/2e2b4a46d08e32667d4845f7b78e1214250345d3/Dockerfile): Ruby 3.4, image dasar `instructure/ruby-passenger:3.4-jammy`, Rails 8.0, Node major 20, Bundler 2.5.10, Yarn 1.19.1.
- [PostgreSQL Dockerfile](https://github.com/instructure/canvas-lms/blob/2e2b4a46d08e32667d4845f7b78e1214250345d3/docker-compose/postgres/Dockerfile): PostgreSQL major 14 dengan pgvector dan konfigurasi Canvas. Image lokal PostgreSQL 18.6 tidak langsung dipakai sebagai pengganti.
- [Compose](https://github.com/instructure/canvas-lms/blob/2e2b4a46d08e32667d4845f7b78e1214250345d3/docker-compose.yml): layanan web, jobs, PostgreSQL dan Redis; upstream Redis menggunakan tag bergerak `redis:alpine`.
- [package.json](https://github.com/instructure/canvas-lms/blob/2e2b4a46d08e32667d4845f7b78e1214250345d3/package.json): Node >=20, Yarn ^1.19.1, kompilasi GraphQL/CSS/packages/JS. Gunakan Node 20 dalam container agar sesuai Dockerfile.
- [Petunjuk Docker](https://github.com/instructure/canvas-lms/blob/2e2b4a46d08e32667d4845f7b78e1214250345d3/doc/docker/README.md): setup pengembangan lokal; skrip perlu ditelaah sebelum dieksekusi karena dapat mengubah lingkungan.

Redis dipilih sementara `redis:7.2-alpine` sebagai keputusan lokal, bukan versi yang dipatok upstream. Digest image dan kompatibilitas nyata belum diverifikasi; kunci digest setelah pengambilan metadata pada Tahap 1/3. Patch Ruby/Node/PostgreSQL juga perlu dicatat dari image terpilih, bukan diasumsikan dari major.

### Penempatan dan mode lokal

- Direktori implementasi: `pkbm-canvas/` di workspace ini. Canvas di `vendor/canvas-lms/`; pendamping di `apps/pkbm/`; konfigurasi di `infra/`; dokumen di `docs/`.
- Kode, dependensi yang di-bind mount, aset dan unggahan lokal berada di home. Layer image/build cache tetap di root Docker. Pisahkan kedua pengukuran.
- Mode Canvas development lokal, aset dikompilasi satu kali per perubahan; tidak menjalankan watcher terus-menerus pada mesin ini.
- Web dan jobs berbagi image Canvas; PostgreSQL 14 + pgvector dan Redis pada jaringan internal. Database pendamping dipisahkan secara logis beserta user; boleh memakai layanan PostgreSQL yang sama setelah kebutuhan Rails pendamping ditetapkan.
- PostgreSQL/Redis tidak membuka port host. Nama proyek/volume baru berawalan `pkbm-canvas`; data Moodle dan website-platform dipertahankan.
- Build dan kompilasi dilakukan berurutan. Jalankan layanan yang diperlukan saja; kapasitas banyak pengguna belum diketahui.

### Unduhan dan kapasitas

Unduhan baru dibutuhkan: source Canvas pada commit terpilih, base image Ruby/Passenger, PostgreSQL 14, Redis, paket sistem, gems dan paket Yarn. Besarnya belum diukur. Instruksi larangan unduhan pada proyek Moodle sebelumnya tidak diperlakukan sebagai larangan global untuk proyek Canvas baru.

Gunakan ruang yang tersedia saat ini untuk setup bertahap; tidak memindahkan Docker root atau membersihkan cache. Sebelum setiap operasi besar, ukur root/home kembali. Ambang operasional lokal: hentikan langkah berikutnya bila root tinggal <5 GiB atau home <5 GiB. Angka ini cadangan kerja yang dipilih, bukan kebutuhan minimum resmi Canvas dan bukan jaminan build cukup. Jika pemakaian tahap awal menunjukkan sisa tidak cukup untuk operasi berikutnya, runtime menunggu keputusan kapasitas dengan sasaran konkret; pekerjaan skema mandiri dapat lanjut.

### Gerbang dan langkah berikut

- Inventaris, baseline commit, major dependencies, lokasi data dan endpoint sudah ditetapkan.
- Gerbang Tahap 1 untuk source/config terbuka.
- Gerbang build Tahap 3 bersyarat: patch/digest image, dependensi dan penggunaan disk harus dicatat bertahap. Belum ada bukti build, database, API atau browser.
- Langkah berikut: fondasi direktori, aturan proyek, salinan acuan, checkout Canvas terpilih, konfigurasi Compose dan perintah lokal pada Tahap 1.

Tidak ada image/container/volume yang dihapus atau dijalankan selama Tahap 0. Tidak ada test aplikasi yang dijalankan.

## Koreksi versi dan Tahap 1 — 7 Oktober 2026

Status: fondasi repo/source/config tersedia; gerbang konfigurasi terpenuhi. Perintah migrasi/seed/sync pendamping belum tersedia. Runtime dan gerbang Tahap 3 belum terpenuhi.

### Koreksi pilihan versi

Pilihan tag Mei pada Tahap 0 digantikan oleh snapshot terbaru branch `prod` yang teramati saat pengecekan: `44bfdc264d5fe6a942ebdb5f10a0eb63ee04df3a`, commit upstream bertanggal 30 April 2026, dengan pesan `treesame commit of origin/stable/2026-04-22`. Tanggal ini berasal dari API; tanggal lokal 7 Oktober tidak digunakan untuk mengarang release Oktober.

GitHub Releases API mengembalikan daftar kosong; branch bernama `stable` mengembalikan 404. [Panduan resmi Production Start](https://github.com/instructure/canvas-lms/wiki/Production-Start) mengarahkan checkout ke `prod`. Karena itu istilah yang akurat adalah **snapshot prod terbaru yang tersedia saat pengecekan**, bukan GitHub release stabil terbaru. Tidak memilih head master atau tag pra-rilis yang tanggal namanya lebih baru sebagai pengganti prod.

Dependensi mengikuti [Dockerfile pada commit prod](https://github.com/instructure/canvas-lms/blob/44bfdc264d5fe6a942ebdb5f10a0eb63ee04df3a/Dockerfile): Ruby 3.4, Rails 8.0, Node 20, Bundler 2.5.10 dan Yarn 1.19.1. PostgreSQL major 14 mengikuti Dockerfile upstream dengan pgvector; base tag 14 di-resolve saat ini. Redis memakai tag upstream `alpine` yang di-resolve saat ini; kandidat Redis 7.2 dari catatan lama dibatalkan.

Metadata registry mengunci digest:

- Ruby/Passenger: `sha256:9bea82cbb2bfef450231582e25311db300ccf69de6bceeb0ab529d60002a4d9e`.
- PostgreSQL 14: `sha256:ceef4a62198b562d6fe3e51be67362f72a0abf0aaa255f54f0c0e55be9768ed2`.
- Redis alpine: `sha256:3811787313eba226a2ef38658c6ccb91cd5e110edc89c37767de373120a0e5a0`.

Ini bukti metadata, belum bukti kompatibilitas runtime. Patch Ruby/Node/PostgreSQL/Redis aktual dicatat setelah image tersedia. Paket apt dan repositori Node di Dockerfile masih sumber bergerak; digest base tidak membuat seluruh build sepenuhnya identik. Lockfile Canvas dipertahankan; pembaruan dependensi dilakukan sebagai keputusan berikutnya, bukan `upgrade` seluruh paket.

### Perubahan Tahap 1

- Direktori implementasi `pkbm-canvas/` dan repo Git lokal dibuat, belum ada commit/push.
- Checkout Canvas dengan fetch depth 1 dan detached HEAD pada commit prod di `vendor/canvas-lms/`; source sekitar 736 MB termasuk Git.
- `AGENTS.md`, README, acuan dalam `docs/acuan/`, dan manifest pilihan runtime disimpan.
- Compose mempunyai web/jobs berbagi image, PostgreSQL dan Redis. Endpoint Canvas loopback 8081; port 3000 dicadangkan untuk pendamping. PostgreSQL/Redis tanpa port host.
- Database `canvas_development`/`pkbm_development` dengan role terpisah, hak CONNECT dibatasi; pgvector disiapkan pada database Canvas oleh init admin.
- Data memakai bind mount di `var/` pada home; layer/cache Docker tetap di root. Init SQL hanya berlaku untuk data PostgreSQL baru.
- Environment dengan secret acak dibuat dalam `.env` berizin 0600, tidak ditampilkan. `.env`, konfigurasi lokal, vendor dan var diabaikan Git; template tanpa secret tetap tersedia.
- Perintah env/capacity/build/start/stop/logs/Canvas migrate/init/shell disediakan. Build web dan PostgreSQL berurutan, dengan cek cadangan disk sebelum tiap build. Start menggunakan image lokal tanpa pull/build otomatis.
- Perintah PKBM migrate/seed/sync masih mengembalikan error eksplisit belum tersedia. Aplikasi pendamping dibangun pada Tahap 2 dan sesudahnya.

### Bukti dan batas

`docker compose --env-file ... -f ... config --quiet` selesai dengan exit 0. Ini pemeriksaan konfigurasi; tidak menjalankan daemon/container atau test aplikasi. Source di-checkout pada commit terpilih. Setelah checkout, home kosong sekitar 16 GiB dan root tetap 12 GiB.

Belum ada pull/build image, gems/Yarn, kompilasi aset, migrasi, Canvas init, login, API, browser atau pengujian aplikasi. Template konfigurasi tambahan dan kebutuhan editor RCE/LTI akan ditelaah pada Tahap 3/5. Source/config siap digunakan; runtime belum siap start.

Langkah berikut: Tahap 2 untuk skema/seed pendamping dan Tahap 3 untuk build/setup Canvas sesuai gerbang kapasitas. Tidak melakukan pembersihan Docker atau mengubah data proyek lama.

## Tahap 2 — katalog akademik, 7 Oktober 2026

Status: database katalog terpasang dan seed dimasukkan; kerangka API baca tersedia sebagai source, belum runtime. Tahap 2 belum lulus penuh karena API belum dijalankan dan pengulangan/negatif belum diuji.

### Perubahan

- Aplikasi pendamping Rails API minimal dibuat di apps/pkbm/. Rails 8.0.5 mengikuti versi yang ditemukan dalam lockfile Canvas prod; Ruby 3.4. Gemfile.lock pendamping belum dihasilkan karena gems belum diinstal.
- Migrasi 20261007000100 menyediakan 20 tabel acuan, sumber, tingkatan, kelompok, peminatan, komponen, acuan, target, materi/kegiatan, temuan, resources/pemetaan dan pernyataan aturan sumber.
- UUID/FK, FK parent target dalam komponen yang sama, batas halaman sumber, konteks peminatan, hubungan kegiatan/target dan larangan siklus target diterapkan pada database.
- Runner SQL memungkinkan migrasi/seed sebelum image Ruby tersedia; migrasi Rails memakai SQL dan ID versi yang sama. Dua seeder menggunakan transaksi/advisory lock dan UUID deterministik; perubahan isi seed yang sudah ada ditolak. Idempotensi secara implementasi belum diuji dengan pengulangan.
- Semua komponen struktur Paket C disimpan untuk V/VI, termasuk umum, peminatan, pemberdayaan, keterampilan wajib/pilihan, sumber mapel keterampilan wajib dan cabang pilihan sertifikasi/nonsertifikasi. Hubungan tidak menggandakan bobot SKK.
- KI/KD Matematika V yang diperlukan tiga modul dan Bahasa Indonesia V bagian LHO disimpan; indikator, materi/kegiatan, area/performa pemberdayaan diberi rujukan. Sebagian KI dan indikator/kegiatan berupa ringkasan editorial dengan penanda, bukan kutipan verbatim lengkap.
- Sepuluh bagian pemetaan tiga modul menghasilkan 18 hubungan KD; MAP-04 tetap bertanda perbedaan konsep. Kode indikator berulang dan 4..1.2 dipertahankan sebagai kode sumber.
- Semua subject_skk masih null. Dua puluh dua pernyataan sumber tidak berupa aturan yang dieksekusi dan tidak mengesahkan capaian/SKK.
- API GET /api/v1/catalog dan koleksi berpaginasi ditulis. API hanya katalog bersama; data pribadi, login/peran, rancangan/pelaksanaan serta UI React belum dibuat.

### Runtime database dan bukti

Image pkbm-canvas-postgres:local berhasil dibuild, memakai digest base yang dipilih. Container pkbm-canvas-postgres-1 berjalan healthy tanpa port host. PostgreSQL aktual 14.24; pgvector 0.8.7 terpasang dari paket build. Data pada var/postgres di home. Database Canvas juga disiapkan oleh init, tetapi migrasi/inisialisasi Canvas belum dijalankan.

Perintah catalog-migrate selesai exit 0 dan mencatat schema_migrations 20261007000100. Perintah catalog-seed selesai exit 0. Pembacaan database menunjukkan:

| Koleksi | Jumlah |
|---|---:|
| Sumber | 8 |
| Komponen | 52 |
| Target | 75 |
| Pemetaan bahan ke KD | 18 |
| Pernyataan aturan sumber | 22 |

Anggaran kelompok database: V umum/peminatan/khusus = 26/30/24; VI = 14/15/13. Ini pembacaan hasil pemasukan, bukan uji kebijakan akademik.

Disk setelah database: root sekitar 11,4 GiB tersedia sebelum start (df membulatkan 12 GB); home sekitar 16 GiB. Snapshot df setelah seed masih root 12 GB, home 16 GB. Tidak ada pembersihan atau perubahan container/volume proyek lain.

### Yang belum terbukti

- Gemfile.lock/dependensi pendamping, proses Rails, API dan browser belum dijalankan.
- Seed ulang, migrasi ulang, uji negatif constraint dan akses lintas role belum dijalankan; tidak ada suite test aplikasi yang dijalankan.
- Seluruh KI/KD/silabus Paket C belum menjadi seed; coverage_status menyatakan cakupan. Nama kategori agama/bahasa asing dalam struktur bukan daftar seluruh agama/bahasa atau silabus spesifiknya.
- Capaian, penilaian, hasil warga belajar, SKK dan integrasi Canvas belum tersedia.

Langkah berikut: setup image web Canvas pada Tahap 3, kemudian instal gems pendamping dan aktifkan API katalog untuk menyelesaikan gerbang baca Tahap 2. PostgreSQL proyek ini dibiarkan berjalan; jangan membuat instance database duplikat.


## Tahap 3 — build dan setup runtime, 7 Oktober 2026

Status: sedang dikerjakan. Image Canvas selesai dibangun (1.223.272.266 byte); Ruby 3.4.8, Node 20.20.2, Rails 8.0.5 dan Bundler 2.6.7 dari lockfile. Bundler 2.5.10 adalah langkah image upstream, bukan versi aktual setelah pemasangan lockfile. 340 gems dan dependensi Yarn terpasang; Yarn selesai dengan exit 0 dalam 1503 detik. PostgreSQL 14.24 dan Redis 8.10.2 berjalan tanpa port host.

Compose 2.26.1 tidak menerima `run --pull never`; perintah run memakai `pull_policy: never`, sedangkan up memakai flag tersebut. Patch lokal yang dapat disiapkan ulang melalui `scripts/canvas-prepare` membatasi build packages secara serial dan melewati task RSpec ketika BUNDLE_WITHOUT mengecualikan test. Percobaan awal init/aset gagal ketika task upstream merujuk MissingSourceFile tanpa dependensi RSpec; percobaan setup dilanjutkan setelah patch. Lockfile Yarn tetap sama dengan checkout.

Log proses di `var/setup-logs/`, status ringkas di `docs/tahap3-status.json`. Sisa disk setelah instalasi JavaScript sekitar root 10 GiB dan home 9,7 GiB. Data proyek lain dan cache Docker lama dipertahankan. Tidak mengubah swap/partisi.

Belum ada bukti login, tampilan, unggahan, eksekusi job atau integrasi API/LTI. Tidak menjalankan tests atau validasi aplikasi. Tahap 3 belum dinyatakan lulus.

Pendamping Rails: pemasangan 67 gems selesai (exit 0), Puma 7.2.1 mencatat Listening pada port internal 3000; mapping host 127.0.0.1:3000. Belum dilakukan permintaan endpoint. Migrasi Canvas berikutnya membutuhkan canvas_readonly_user; role NOLOGIN disiapkan admin dan ditambahkan pada init PostgreSQL untuk instalasi baru. Role aplikasi tetap NOCREATEROLE. Migrasi awal yang gagal dibatalkan oleh transaksi, kemudian setup diulang.

Inisialisasi Canvas selesai dengan exit 0 dan pesan Initial data loaded. Ini bukti migrasi/setup database, bukan bukti login atau operasional pembelajaran.

Seed akun lokal dan course orientasi selesai dengan exit 0 (course 1). Password tetap di .env. Belum menguji login ketiga akun atau fungsi enrollment melalui UI.

CSS selesai dikompilasi (132,38 detik); peringatan font OpenDyslexic tidak ditemukan dicatat, belum ditelaah visual. Terjemahan selesai (221,09 detik), gulp rev selesai (41,46 detik). Web Canvas/Puma 7.2.0 mencatat Listening pada port internal 3000, mapping 127.0.0.1:8081; worker dimulai. Kompilasi JavaScript masih berjalan, sehingga UI belum dinyatakan siap.

Paket k5uploader, canvas-media dan canvas-rce berhasil dibuild secara serial (87,69 detik). Saat Rspack membentuk bundle utama, web/jobs dihentikan sementara agar RAM tersedia; API katalog, PostgreSQL dan Redis tetap berjalan. Kompilasi belum merupakan pengujian aplikasi.

Rspack awal gagal (exit 1) karena import @instructure/platform-alerts tidak tersedia pada dependency source. Patch mengarahkan ConfigureModal ke @canvas/alerts/react/FlashAlert, fungsi showFlashAlert yang telah tersedia di source dengan signature pemanggilan yang sama. Patch dicatat di infra/canvas-low-memory.patch dan scripts/canvas-prepare; build JavaScript diulang secara terpisah, tanpa mengulang CSS/database.

Build JavaScript ulang selesai dengan exit 0: GraphQL codegen, paket serial (67,07 detik), dan Rspack compiled successfully (21,14 detik; hasil cache build pertama membantu). Seluruh langkah aset yang diperlukan compile_assets_dev selesai melalui build awal dan ulang JS. Web/jobs kemudian dinyalakan kembali. Tidak menjalankan tests, curl endpoint atau browser; gerbang Tahap 3 yang meminta login/course/unggahan/persistensi tetap belum terpenuhi.

Snapshot akhir: lima container proyek (web, jobs, API PKBM, PostgreSQL dan Redis) berstatus Up; PostgreSQL healthy. Endpoint loopback Canvas 8081 dan PKBM 3000. Sisa disk root sekitar 10 GiB dan home 9 GiB. Gerbang penggunaan browser dan fungsi pembelajaran masih menunggu validasi yang diminta secara eksplisit.


### Penyelesaian gerbang Tahap 3 — Lulus lokal

Pengguna meminta menyelesaikan runtime; pemeriksaan operasional dilakukan pada 7 Oktober 2026. Ini pembaruan status; catatan belum diuji di atas adalah snapshot historis.

- Masalah restart ditemukan: PID 1 tertinggal pada tmp/pids/server.pid menyebabkan Rails exit 1. Perintah startup web/PKBM kini membersihkan PID saat container baru dimulai; restart web berikutnya berhasil. Tidak menghapus database atau unggahan.
- Browser: pengelola, tutor dan warga belajar login dengan akun masing-masing. Pengelola membuat course 2 Pemeriksaan Operasional Canvas — Lokal melalui UI. Tutor melihat course 1, membuat dan menerbitkan modul Mulai belajar di PKBM. Warga belajar melihat modul itu tanpa kontrol pengelolaan. Reload sesudah restart mempertahankan sesi dan kursus.
- API: /users/self/profile dan /courses/1 berhasil untuk ketiga akun. Tutor/admin memiliki manage_files_add dan manage_grades; WB tidak. manage_content ternyata bukan izin pengelolaan yang sesuai snapshot ini; pemeriksaan akhir memakai manage_assignments_add, manage_files_add dan manage_grades. Tidak mencakup seluruh matriks RBAC atau isolasi banyak PKBM.
- Unggahan: browser filechooser otomatis timeout; unggahan melalui API Canvas berhasil pada course 2, file 1, lalu download cocok byte demi byte. Setelah restart file yang sama masih dapat diunduh dengan byte yang sama. Interaksi picker browser belum terverifikasi.
- Worker: job 240 Account.default.touch dijadwalkan melalui inst-jobs. updated_at bertambah dan job dihapus dari antrean setelah dieksekusi; bukti var/validation/worker-result.txt. Penerbitan modul melalui UI juga selesai. Percobaan pencatatan awal menganggap delay mengembalikan ID; inst-jobs mengembalikan nil secara default, diperbaiki dengan ignore_transaction: true pada pemeriksaan eksplisit.
- Restart: web di-recreate untuk perintah startup baru; worker restart normal. Login tiga peran, course 1 dan file 1 diperiksa sesudah restart. Tidak menjalankan seluruh suite upstream Canvas.
- API pendamping /api/v1/catalog HTTP 200 dengan counts/coverage; keputusan akademik masih nonaktif.
- Snapshot layanan setelah operasi: web 347 MiB, jobs 361 MiB, PKBM 76 MiB, Redis 12 MiB, PostgreSQL 108 MiB. Ini snapshot lokal setelah pemeriksaan, bukan ukuran kapasitas pengguna nyata. Root tersedia sekitar 10 GiB; home 9 GiB.

Bukti lokal: var/validation/runtime-api.json, runtime-persistence.json, worker-result.txt dan warga-belajar.jpg. Skrip pemeriksaan terarah scripts/validate-runtime.py tersedia; jangan jalankan ulang tanpa permintaan. Konfigurasi rahasia dan bukti runtime tetap diabaikan Git.

Batas: font OpenDyslexic memberi peringatan berkas tidak ditemukan saat build; font default tampil normal. RCE layanan media eksternal, email keluar, seluruh peran/fitur, beban banyak pengguna dan produksi belum diperiksa. Tahap 3 Lulus lokal; Tahap 4–11 dan keputusan akademik belum selesai.


### Rekonsiliasi checklist Tahap 1–2

Checklist diperbarui dari bukti yang sudah ada, tanpa menjalankan pemeriksaan ulang. Tahap 1 selesai untuk fondasi lokal: perintah start/stop/log/migrasi/seed dan dokumentasi penyimpanan tersedia. Perintah sync masih guard yang menolak operasi; implementasi sinkronisasi tetap Tahap 5. Kalimat runtime belum dibuild pada catatan Tahap 1 adalah snapshot historis, sudah dilanjutkan Tahap 3.

Checklist implementasi Tahap 2 seluruhnya tercentang: API katalog HTTP 200 dan cakupan diperiksa pada penyelesaian Tahap 3. Gerbang pengulangan seed tanpa duplikasi belum dibuktikan; status Tahap 2 masih belum lulus penuh pada gerbang tersebut. Tidak menjalankan seed ulang, migrasi ulang, tests atau browser baru untuk pembaruan dokumentasi ini.


### Koreksi status berdasarkan kecukupan bukti

Koreksi ini menggantikan klaim rekonsiliasi sebelumnya bahwa seluruh checklist implementasi Tahap 2 selesai. Checklist roadmap kini mengikuti tuntutan setiap butir, bukan hanya keberadaan kode. Tidak menjalankan pemeriksaan/seed/test baru.

- Tahap 1: source/config, pemisahan database dan perintah tersedia dengan bukti file/runtime terdahulu; audit konsistensi seluruh rujukan belum lengkap, sehingga butir gabungannya tetap terbuka. Ketersediaan skrip tidak berarti seluruh cabang perintah sudah dijalankan.
- Tahap 2: migrasi dan seed awal berhasil; jumlah koleksi/anggaran kelompok serta API katalog terbaca. UUID/FK ada pada skema, tetapi perilaku penolakan data invalid belum diuji. Jumlah baris tidak membuktikan semua komponen/indikator/pemetaan sesuai sumber. Butir ketepatan akademik, constraint dan idempotensi tetap terbuka.
- Tahap 3: bukti login tiga peran, pembuatan course/modul, unggahan/download via API, worker dan persistensi tetap berlaku sebagai kelulusan gerbang fungsi dasar lokal. Checklist keseluruhan masih parsial karena snapshot sumber daya yang ada belum memisahkan idle dan operasi contoh. Pemilih berkas browser otomatis belum terbukti.

Status akhir yang berlaku: Tahap 1–2 terbukti sebagian; Tahap 3 gerbang fungsi dasar lulus lokal dengan checklist pengukuran belum lengkap. Tidak ada klaim lulus produksi atau seluruh roadmap selesai.

## Pembuktian aktual Tahap 1–2 — 7 Oktober 2026

Bagian ini menggantikan status parsial Tahap 1–2 pada koreksi sebelumnya. Pembuktian dijalankan setelah permintaan pengguna, sehingga kelulusan sekarang didukung hasil eksekusi dan telaah sumber.

- 62 pemeriksaan database/API lulus: migrasi database baru, seed ulang tanpa perubahan hash/jumlah 20 koleksi, seed berbeda ditolak, kasus constraint invalid ditolak, seluruh koleksi API dan pembatasan endpoint. Database audit dibuang setelah selesai; data katalog aktif tidak berubah.
- Migrasi dan seed melalui Rails juga selesai exit 0. Schema dump disimpan di `apps/pkbm/db/structure.sql`.
- Delapan PDF diperiksa identitas/jumlah halaman, batas rujukan dan struktur register; isi struktur kurikulum, KI/KD contoh, indikator, muatan khusus, pemetaan dan aturan ditelaah pada halaman sumber. Rincian serta jumlah pemeriksaan integritas tersimpan pada laporan.
- Konfigurasi, source pin, manifest, patch dan pengecualian rahasia diperiksa. Dokumen acuan dibedakan dari status implementasi terkini.

**Keputusan:** Tahap 1 Lulus lokal fondasi; Tahap 2 Lulus lokal katalog contoh. Pengesahan tutor/PKBM tetap belum dilakukan, temuan persamaan/pertidaksamaan tidak ditutup, seluruh KD nasional tidak diklaim lengkap, alokasi SKK per mapel tidak diisi. Tahap 3 mempertahankan bukti fungsi dasar yang sudah ada; pengukuran idle/operasi terpisah dan picker browser belum dibuktikan pada pemeriksaan ini.

Laporan: [tahap12-verifikasi.md](../tahap12-verifikasi.md), hasil terstruktur: [tahap12-verifikasi.json](../tahap12-verifikasi.json). Log rinci berada di `var/validation/stage12/` dan dikecualikan Git.

## Pengukuran Tahap 3 dan hambatan picker — 7 Oktober 2026

Pengukuran terpisah dijalankan: 3 sampel idle, 12 sampel login/navigasi dan 8 sampel percobaan picker. Butir pengukuran roadmap tercentang berdasarkan hasil nyata. Dialog Upload file terbuka; dua metode filechooser timeout. Unggahan browser tetap belum terverifikasi, sehingga Tahap 3 keseluruhan masih parsial dan Tahap 4 belum dimulai. [Laporan dan batas ukur](../tahap3-pengukuran.md), [metrik](../tahap3-pengukuran.json). Ini memperbarui keterbatasan pengukuran pada catatan historis di atas.

## Penyelesaian validasi Tahap 3 — 7 Oktober 2026

Pada tampilan Files lama yang dibuka pengguna, event filechooser berhasil, fixture dipilih lewat browser dan toast unggahan sukses terlihat. Kedua record bernama tampilan `cek-browser-tahap3.txt` (ID 2 dan 4) diperiksa lewat unduhan API baca; masing-masing 55 byte identik dengan fixture asli. [Bukti unggahan](../tahap3-unggahan-browser.json). Bukti screenshot di `var/validation/stage3/upload-success.png`.

**Status terbaru: Tahap 3 Lulus lokal; seluruh checklist lengkap.** Pengukuran idle/operasi sebelumnya tetap berlaku. Picker Files baru tetap tidak terverifikasi; jalur Files lama terbukti. Tidak ada klaim produksi/kapasitas kelas nyata. Tahap 4 belum dimulai. Bagian hambatan sebelumnya adalah riwayat yang telah diselesaikan melalui jalur Files lama.

## Konfirmasi manual New Files Page

Pengguna mengonfirmasi unggahan New Files Page berhasil pada 7 Oktober 2026. Jalur tersebut dicatat lulus berdasarkan pengujian manual pengguna; timeout sebelumnya terbatas pada otomatisasi picker agen. Checklist unggahan browser tercentang dan status Tahap 3 tetap Lulus lokal. Bukti byte unduhan yang diperiksa agen berasal dari pengujian Files lama.

## Implementasi Tahap 4 — 7 Oktober 2026

Migrasi `20261007000200` berhasil (exit 0) dan fixture opt-in dua PKBM berhasil diterapkan (exit 0). Schema SQL hasil Rails diperbarui. PKBM, orang/membership/peran, program/kelompok, rancangan versi/komponen/kegiatan/target, pelaksanaan/staff/enrollment, rencana/item serta sesi diimplementasikan. FK lokal komposit membatasi relasi PKBM; API menambahkan pemeriksaan peran, penugasan dan konteks akademik.

UI React lokal menyediakan layar pengelola/tutor/warga belajar pada port 3000 yang sama. React/ReactDOM dan lisensinya disalin dari dependensi Canvas lokal; tidak memasang dependensi baru. Kredensial pendamping berbeda dari Canvas, ditambahkan ke `.env` yang dikecualikan Git; tidak ditampilkan. Rancangan terbit dipertahankan dan perubahan memakai versi baru. Tidak menulis tabel Canvas, menetapkan nilai akhir atau mengesahkan SKK.

**Status: implementasi tersedia; gerbang Tahap 4 belum lulus.** Pengguna memilih “Implementasi saja dahulu” ketika ditawarkan pemeriksaan API dua PKBM/peran dan alur browser. Tidak menjalankan pengujian tersebut. Checklist penyediaan implementasi tercentang, tidak menjadi klaim keamanan/alur runtime sudah terbukti. Tahap 5 belum dikerjakan. [Lingkup/batas](../tahap4-implementasi.md), [status](../tahap4-status.json). Log pemasangan: `var/validation/stage4-migrate.log`, `var/validation/stage4-seed.log`.

## Validasi API Tahap 4 — 7 Oktober 2026

Atas permintaan pengguna, API diuji pada dua PKBM dan tiga peran, dilengkapi warga belajar sementara pada PKBM yang sama. Hasil akhir 483 assertion lulus, 0 gagal. Seluruh koleksi, otorisasi lintas PKBM, mutasi peran, rancangan/target, penugasan, rencana pribadi serta alur tulis diuji. Celah pembacaan item rencana pelaksanaan lain oleh tutor ditemukan, dibatasi pada delivery yang dapat diakses, kemudian kasus diuji ulang dan lulus.

Record sementara dibersihkan tepat UUID; seluruh record asli kedua PKBM sama sebelum/sesudah. Tidak mengubah tabel Canvas. Pengguna mengonfirmasi tampilan/alur dasar browser berjalan; belum ada bukti agen atas keseluruhan alur browser pembuatan/penugasan/rencana WB. Tahap 4 Lulus lokal: batas PKBM/peran terbukti lewat API dan alur dasar browser dikonfirmasi manual pengguna sesuai gerbang roadmap. Pengujian otomatis seluruh formulir tidak diklaim. Penundaan validasi API sebelumnya adalah riwayat yang digantikan permintaan terbaru. [Bukti](../tahap4-api-verifikasi.md), [hasil](../tahap4-api-verifikasi.json). Belum commit atau mulai Tahap 5.
