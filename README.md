# PKBM dan Canvas LMS lokal

Fondasi implementasi untuk Paket C. Canvas mengelola pembelajaran; pendamping PKBM mengelola kurikulum, rencana, capaian dan keputusan akademik.

## Status

Tahap 3 **lulus lokal; checklist lengkap**: Canvas beserta web/worker, database, aset, tiga akun demo dan kursus tersedia. Login/UI, izin dasar, unggahan/download, job dan persistensi setelah restart telah diperiksa. API katalog PKBM berjalan. Tahap 1–2 **lulus lokal untuk fondasi dan katalog contoh** setelah migrasi database baru, seed ulang, uji negatif, API dan telaah sumber. Bukti: [verifikasi Tahap 1–2](docs/tahap12-verifikasi.md). Implementasi rencana belajar, penilaian akademik dan integrasi PKBM–Canvas mengikuti Tahap 4 dan seterusnya. Bukti di [catatan implementasi](docs/catatan-implementasi.md).

- Acuan dan roadmap: docs/acuan/
- Versi terpilih: infra/runtime-selection.json
- Bukti pelaksanaan: docs/catatan-implementasi.md
- Aturan kerja: AGENTS.md
- Urutan setup runtime: docs/runtime-setup.md

## Perintah dari direktori ini

```sh
./scripts/local env
./scripts/local capacity
./scripts/compose config --quiet
./scripts/local build
./scripts/local canvas-shell
```

Build hanya membuat image dasar. Tahap 3 menginstal gems/Yarn, mengompilasi aset, menyiapkan konfigurasi tambahan yang diperlukan Canvas, dan menginisialisasi database sebelum start. Jangan menganggap `start` cukup untuk Canvas yang belum disiapkan.

Endpoint yang dipilih: http://127.0.0.1:8081 (Canvas), http://127.0.0.1:3000 (API katalog PKBM). Jika port Canvas diubah, domain.yml dan security.yml harus diubah bersamaan.

`stop` mempertahankan data. Penyimpanan di var/ mencakup postgres, Redis, gems, cache dan unggahan. Source Canvas dan node_modules di vendor/canvas-lms/. Jangan menghapus keduanya ketika perlu mempertahankan runtime/data. PostgreSQL dan Redis tidak dipublikasikan ke host.

Database Canvas/PKBM terpisah dengan pengguna dan hak CONNECT berbeda. Init SQL hanya berjalan pada direktori PostgreSQL baru; perubahan .env tidak otomatis mengganti password database lama. Jangan menghapus data untuk mengatasi beda password.

Perintah catalog-db-start/catalog-migrate/catalog-seed menjalankan database dan katalog melalui SQL. pkbm-install/pkbm-migrate/pkbm-seed/catalog-start memakai Rails setelah image web tersedia. Runner sinkronisasi Tahap 5 tersedia; token/worker harus diaktifkan secara sengaja; gerbang integrasi lulus lokal. Lihat apps/pkbm/README.md.

Pengukuran idle/operasi Tahap 3 sudah dilakukan; picker dan unggahan browser pada tampilan Files lama sudah terbukti; hasil unduhan cocok byte. [Laporan terbaru](docs/tahap3-pengukuran.md).

Tahap 4 sudah diimplementasikan dan migrasi/fixture dua PKBM dipasang lokal. UI pendamping: `http://127.0.0.1:3000/`. Tahap 4 lulus lokal: API lulus 483 pemeriksaan dan alur dasar UI dikonfirmasi manual pengguna; seluruh formulir tidak diklaim diuji otomatis. [Alur dan batas Tahap 4](docs/tahap4-implementasi.md).

Bukti Tahap 4 terbaru: [validasi API](docs/tahap4-api-verifikasi.md).

Tahap 5: konfigurasi integrasi, binding, job/retry/konflik, publikasi target/kegiatan/bahan dan akses LTI lokal sudah diimplementasikan. Migrasi dan pengujian nyata lulus lokal (130 pemeriksaan akhir). Token sementara telah dicabut; sinkronisasi berikutnya memerlukan otorisasi baru. Worker daemon belum dimulai. [Bukti Tahap 5](docs/tahap5-verifikasi.md).

Tahap 6 dimulai: draf tiga modul, versi/rubrik, publisher assessment Canvas serta alur bukti/feedback ditulis. Migrasi dan seed terpasang; publikasi dan pengujian belum dilakukan. [Status dan batas Tahap 6](docs/tahap6-implementasi.md).
