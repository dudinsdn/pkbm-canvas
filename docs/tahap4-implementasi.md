# Tahap 4 — pengelolaan PKBM dan rencana belajar

## Lingkup

Pendamping menyediakan PKBM, orang, membership/peran, program warga belajar, kelompok, rancangan versi, kegiatan/target, pelaksanaan, penugasan, enrollment, rencana/item dan sesi. Rencana bukti serta cara penilaian berupa rancangan lokal, belum hasil/nilai akademik. Canvas tetap terpisah; sinkronisasi mengikuti Tahap 5.

## Akses dan data

- Semua relasi lokal memakai FK komposit `pkbm_id + id`. Katalog acuan bersama hanya dibaca; pilihan komponen/target diperiksa terhadap versi kurikulum/rancangan.
- Login pendamping menggunakan kode PKBM, email dan password lokal. Password PBKDF2 SHA-256 dengan salt acak/210.000 iterasi; token ditandatangani, berlaku delapan jam, disimpan di sessionStorage tab. Peran selalu dibaca database, bukan header atau payload. Membership inactive tidak dapat memakai token.
- Pengelola dapat menyiapkan data PKBM sendiri. Tutor/instruktur menulis rancangan miliknya dan sesi pelaksanaan yang ditugaskan. Warga belajar membaca rencana aktif miliknya, kegiatan/sesi dan pendamping dari enrollment-nya. Email anggota lain tidak ditampilkan kepada nonpengelola.
- Rancangan terbit tidak diubah; revisi menjadi versi baru. Publikasi memerlukan komponen, kegiatan dan target. Aktivasi pelaksanaan memerlukan rancangan terbit. Satu rencana aktif per program warga belajar; versi lama dapat ditandai superseded sebelum versi baru aktif.
- Mutasi relasi/identitas versi tidak menggunakan PATCH. Endpoint penghapusan tidak disediakan. Kegiatan/bukti penilaian tersimpan sebagai rencana, tanpa klaim mastery atau pengesahan SKK.

## UI lokal

`http://127.0.0.1:3000/` memakai React lokal, tanpa CDN, server atau port tambahan. Asset React/ReactDOM beserta lisensi disalin dari dependensi Canvas terpasang. UI pengelola: anggota/peran, program/kelompok, pelaksanaan/penugasan/enrollment dan rencana. UI tutor: rancangan, komponen, kegiatan/target dan sesi. UI warga belajar: rencana berlaku, target, kegiatan, bukti yang perlu disiapkan dan pendamping.

Urutan pengelola: buat orang → membership → peran → program → program warga belajar → kelompok/peserta → rancangan dan komponen/kegiatan/target → terbitkan rancangan → pelaksanaan/penugasan/enrollment → rencana aktif/item/sesi. Saat pilihan acuan tidak sesuai, API menolak dan memberi alasan. Rancangan sumber tidak dimutasi.

## Operasional

```sh
./scripts/local pkbm-migrate
./scripts/local pkbm-operations-seed
./scripts/local catalog-start
```

Fixture opt-in menyediakan `DEMO-A` dan `DEMO-B`, masing-masing pengelola, tutor dan warga belajar. Email: `pengelola@pkbm.local`, `tutor@pkbm.local`, `warga_belajar@pkbm.local`; password dari `PKBM_LOCAL_ADMIN_PASSWORD`, `PKBM_LOCAL_TUTOR_PASSWORD`, `PKBM_LOCAL_WB_PASSWORD` di `.env`. Password tidak ditampilkan/ditanamkan pada dokumen atau UI. Fixture menggunakan dua rancangan (Matematika dan Bahasa Indonesia), kegiatan, target, pelaksanaan, penugasan, rencana serta sesi. Seluruh nama/orang adalah simulasi.

API: `POST /api/v1/session`, `GET /api/v1/me`, GET/POST koleksi dan GET/PATCH record pada `/api/v1/operations/:collection`. Koleksi dibatasi allowlist, atribut ID/PKBM ditetapkan server. Daftar maksimum 500 catatan; perlu pagination sebelum pemakaian skala besar. Katalog lama tetap `/api/v1/catalog`.

## Gerbang

Implementasi tidak otomatis berarti gerbang lulus. Bukti yang diperlukan: API dua PKBM/semua peran, penolakan akses tenant lain, WB hanya rencana sendiri, tutor di luar penugasan ditolak, dan alur pembuatan/pembacaan di browser. Pengujian mengikuti izin eksplisit pengguna sesuai AGENTS.md. Produksi, reset password, pembatasan percobaan login terdistribusi, audit perubahan lengkap dan integrasi Canvas belum menjadi klaim tahap ini.

## Status bukti terbaru

[Validasi API](./tahap4-api-verifikasi.md): 483 assertion lulus. Item rencana tutor dibatasi juga menurut pelaksanaan yang dapat diakses. UI dasar dikonfirmasi manual oleh pengguna; pengujian alur browser keseluruhan belum direkam. Gerbang Tahap 4 lulus lokal berdasarkan uji API dan konfirmasi alur dasar browser manual pengguna. Pengujian otomatis seluruh formulir tidak diklaim.
