# Tahap 5 — integrasi Canvas lokal

7 Oktober 2026. **Implementasi dan pengujian lokal selesai; gerbang lulus lokal.** Bagian berikut mencatat desain dan batas implementasi awal. Status pengujian terbaru: [verifikasi](./tahap5-verifikasi.md). Token sementara telah dipakai lalu dicabut.

## Data dan otorisasi

Migrasi menyediakan `canvas_instances`, `canvas_bindings`, `delivery_resources`, `sync_jobs`, `sync_events`, `lti_nonces` dan `lti_launch_codes`. Relasi PKBM/instance/job/pelaksanaan menggunakan FK komposit. PKBM hanya memiliki satu instance aktif dalam lingkup lokal ini. Token API dan shared secret LTI disimpan bersama dalam ciphertext AES-256-GCM dengan kunci turunan `PKBM_SECRET_KEY_BASE`. Kunci ini harus dipertahankan bersama backup database; menggantinya membuat kredensial lama tidak terbaca. Nilai rahasia difilter dari parameter log dan tidak dikirim dalam GET status.

API integrasi dikelola pengelola PKBM. URL internal/public dan root account ditetapkan konfigurasi deployment, tidak menerima URL bebas dari form. Default internal `http://web:3000`, browser `http://127.0.0.1:8081`, pendamping `http://127.0.0.1:3000`. Client menolak redirect keluar origin; redirect Canvas ke origin publik yang dikonfigurasi diterjemahkan kembali ke endpoint internal yang sama. HTTP loopback/container adalah lingkup lokal; bukan pola deployment produksi.

Token Canvas perlu disediakan pengguna/pengelola lewat **Integrasi Canvas** di UI pendamping. Token harus memiliki izin API untuk account/SIS, course/section, users/enrollments, Outcomes, Pages/modules dan external tools. Token sementara telah digunakan dalam pengujian dan dicabut; token saat ini tidak tersedia. Pembuatan credential akses Canvas perlu otorisasi pengguna pada saat tindakan dilakukan. Akun/credential yang diprovisikan oleh sinkronisasi merupakan akun Canvas terpisah; password login pendamping tidak disalin atau dipakai ulang.

## Kepemilikan dan sinkronisasi

PKBM adalah sumber utama identitas lokal, peserta/penugasan, rancangan dan pilihan bahan. Satu sub-account per PKBM, Course dan Section per pelaksanaan. Pengguna menggunakan SIS ID dari UUID orang yang mencakup PKBM; enrollment berasal dari tutor aktif dan peserta/program aktif. Nama diperbarui; password random awal Canvas tidak ditampilkan/disimpan ulang oleh pendamping. Pengaktifan akun/password reset Canvas mengikuti mekanisme Canvas, belum disediakan melalui UI pendamping.

Binding mencakup instance, jenis objek, local key, remote ID/context, checksum payload dan snapshot field remote yang dikelola. Course/account/section dipastikan berada pada hierarki PKBM yang dikonfigurasi sebelum memprovisikan isi/peserta. Pemulihan mencari SIS ID, vendor GUID, halaman bertaut identitas kegiatan, atau objek module/item/tool yang cocok; tidak mengulang POST secara buta. Nama module dikelola pada Course milik integrasi. Jika ada beberapa kandidat atau binding menunjuk objek hilang, job berstatus konflik dan tidak membuat pengganti otomatis.

Setiap operasi menyimpan binding/event agar tahap berikutnya dapat dilanjutkan pada retry. Snapshot remote yang berbeda dari snapshot terakhir menjadi konflik. Retry biasa mempertahankan pemeriksaan; tindakan pengelola **Terapkan rancangan PKBM pada konflik** mengizinkan penerapan ulang field yang dikelola. UI memberi konfirmasi perubahan manual dapat tertimpa. Pengelola dapat mempertahankan perubahan manual dengan menunda retry dan menyesuaikan rancangan lokal/keadaan Canvas terlebih dahulu. Tidak ada klaim merger otomatis.

Enrollment terikat yang tidak lagi termasuk roster dinonaktifkan melalui API, tidak dihapus permanen; enrollment Canvas yang tidak mempunyai binding tidak disentuh. Penerbitan course mengikuti pelaksanaan aktif. Job menyimpan status/attempt/error, riwayat objek serta konflik. Lock advisory PKBM/instance mencegah dua worker membuat objek yang sama bersamaan. Job running lebih dari sepuluh menit dapat diambil kembali hanya setelah lock dilepas; operasi remote sebelumnya dipulihkan lewat lookup/binding.

## Target, kegiatan dan bahan

Target kegiatan dari rancangan terbit dipublikasikan sebagai Outcomes dengan `vendor_guid`, deskripsi dan rujukan. Client tidak mengirim ratings, bobot atau threshold mastery. Properti/default Canvas bukan keputusan akademik PKBM; pengesahan SKK tidak diaktifkan.

Kegiatan menjadi Page berisi tujuan, target, bukti yang perlu disiapkan dan cara pendampingan, ditautkan dalam module. Komponen/kegiatan sumber tidak ditulis ulang. Pilihan bahan menggunakan relasi bahan-komponen katalog; bahan ditautkan sebagai referensi dengan temuan pemetaan yang tercatat, tanpa klaim cakupan KD penuh. PDF dilayani pendamping hanya bila warga belajar/tutor memiliki akses delivery dan bahan dipilih pada delivery tersebut. Mount sumber read-only dari folder PDF pengguna; file/data tidak disalin ke repo.

## LTI

Implementasi menggunakan endpoint LTI 1.1 yang terdapat pada checkout Canvas terkunci: external tool course navigation, HMAC-SHA1, consumer key per instance, shared secret terenkripsi. Ini keputusan terbatas untuk integrasi lokal; LTI 1.3/developer key, OIDC/JWKS dan deployment produksi belum dibuat atau diklaim.

Launch memeriksa jenis/version/method OAuth, timestamp lima menit, signature terhadap URL launch kanonis, nonce unik dan binding Canvas user/course. Identitas berasal dari custom `$Canvas.user.id`/`$Canvas.course.id` yang ditandatangani; peran dari database PKBM, bukan klaim peran kiriman tool. Membership harus aktif dan memiliki akses delivery. Launch menghasilkan kode acak satu kali selama 60 detik dalam fragment URL; frontend menukar kode, membersihkan fragment dan menyimpan token sesi seperti login lokal. Replay nonce/kode ditolak. Launch bertanda tangan Canvas dan exchange identitas telah diuji melalui HTTP; navigasi penuh browser belum diuji. Nonce/kode disimpan untuk audit/replay; retensi/pembersihan terjadwal belum diimplementasikan.

## Operasional

```sh
./scripts/local pkbm-migrate
./scripts/local catalog-start
# Setelah token disimpan dan job diantrekan secara sengaja:
./scripts/local sync       # satu job, tanpa worker terus-menerus
./scripts/local sync-start # worker opsional pada profile integration, tanpa port baru
./scripts/local sync-stop
```

Worker tidak dimulai otomatis pada pekerjaan implementasi. Antrekan lewat UI **Integrasi Canvas**; penyimpanan token/antrean belum membuktikan koneksi. Ulangi sinkronisasi completed dengan mengantrekan job baru. Retry failed/conflict menggunakan job yang sama dan menambah attempt saat worker mengambilnya. Binding/status course dapat dilihat pada UI; warga belajar/tutor hanya mendapat tautan Course untuk delivery yang dapat diakses.

API: GET/PUT `/api/v1/integration`; POST `/api/v1/integration/jobs`; POST `/api/v1/integration/jobs/:id/retry`; POST `/api/v1/integration/resources`; GET `/api/v1/integration/links`; GET `/api/v1/integration/resources/:id?delivery_id=...`; POST `/lti/launch`; POST `/api/v1/lti/exchange`.

## Bukti dan gerbang

Bukti instalasi migrasi dan pengujian perilaku dicatat terpisah. Gerbang lokal lulus: 130 pemeriksaan akhir, 0 gagal. Pengguna menggantikan pilihan “Implementasi dahulu” dengan permintaan pengujian serta otorisasi token sementara. [Verifikasi dan batas](./tahap5-verifikasi.md).

Implementasi API disesuaikan dari controller/routes pada checkout Canvas lokal terkunci, antara lain `sub_accounts_controller`, `users_controller`, `enrollments_api_controller`, `outcome_groups_api_controller`, `wiki_pages_api_controller`, `context_modules_api_controller`, `context_module_items_api_controller` dan `external_tools_controller`. Inspeksi ini membuktikan acuan endpoint source, bukan keberhasilan koneksi atau kompatibilitas seluruh payload runtime.
