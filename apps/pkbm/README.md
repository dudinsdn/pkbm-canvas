# Katalog akademik pendamping PKBM

Tahap 2 menyediakan migrasi PostgreSQL, seed sumber dan API baca Rails yang sudah berjalan lokal dan diperiksa pada penyelesaian Tahap 3. Antarmuka React dan data pelaksanaan PKBM berada pada tahap berikutnya.

## Cakupan

- Delapan sumber, K13 Paket C, Tingkatan V/VI, kelompok SKK, tiga peminatan, semua komponen struktur acuan.
- KD Matematika V 3.1–3.4/4.1–4.4 dan Bahasa Indonesia V 3.1–3.2/4.1–4.2; KI tersedia, sebagian berupa ringkasan editorial.
- Indikator silabus terkait, materi/kegiatan ringkas, area dan performa pemberdayaan Paket C.
- Tiga modul dan pemetaan, temuan konsep/kode sumber; 22 pernyataan sumber non-eksekutabel.

Kode sumber asli dan kode tampilan berbeda kolom. `transcription_type` membedakan normalisasi tipografi dan ringkasan editorial. `coverage_status` menyatakan cakupan komponen; seed bukan transkripsi lengkap seluruh kurikulum.

Seni Budaya, Pendidikan Olahraga/Rekreasi dan Prakarya menjadi acuan keterampilan wajib. Keterampilan pilihan memiliki cabang tersertifikasi/nonsertifikasi. Relasi tidak menambah anggaran SKK; `subject_skk` belum diisi.

## Migrasi dan seed

Jalankan dari root proyek setelah image PostgreSQL dibuild:

```sh
./scripts/local catalog-db-start
./scripts/local catalog-migrate
./scripts/local catalog-seed
```

Runner SQL dan migrasi Rails menggunakan satu SQL serta ID migrasi yang sama. Runner SQL dapat digunakan sebelum Ruby/Canvas terpasang. Kedua seeder memakai UUID deterministik, transaksi dan advisory lock. Isi yang sama dapat dipanggil ulang secara desain; perubahan isi existing ditolak agar tidak diam-diam menimpa versi. Perubahan sumber harus menghasilkan versi/key baru. Uji pengulangan SQL/Rails, database baru, penolakan perubahan seed dan kasus constraint invalid sudah lulus lokal. Bukti dan batas cakupan: [verifikasi Tahap 1–2](../../docs/tahap12-verifikasi.md).

`db/seeds/build_catalog.py` menghasilkan `catalog.json` dari register pemetaan dan data acuan yang ditelaah. Script ini tidak terhubung ke database. Gunakan setelah perubahan seed yang memang disengaja.

## API baca

Setelah image web, gems pendamping dan PostgreSQL tersedia:

```sh
./scripts/local pkbm-install
./scripts/local catalog-start
```

- `GET /api/v1/catalog`: jumlah koleksi dan cakupan komponen.
- `GET /api/v1/catalog/learning_targets?limit=50&offset=0`: data target, maksimal 100 per halaman.
- Koleksi lain menggunakan nama tabel katalog yang diizinkan controller.

Endpoint katalog lokal pada port 3000 tetap hanya katalog bersama. API operasional Tahap 4 memiliki login/peran dan mutasi terpisah melalui `/api/v1/operations`. Jangan membuka endpoint ini ke internet. Secret Rails ada pada `.env` proyek. Gems pendamping terpisah dari gems Canvas.

## Batas

Skema PKBM, orang, kelompok dan rencana tersedia pada Tahap 4. Bukti hasil serta keputusan akademik mengikuti Tahap 6 dan seterusnya. Penarikan hasil Canvas dan pengesahan SKK belum tersedia. Struktur katalog bukan klaim ketuntasan warga belajar.

## Pengelolaan dan rencana belajar (Tahap 4)

Implementasi data pelaksanaan, autentikasi pendamping, pembatasan PKBM/peran dan UI React tersedia. Jalankan `./scripts/local pkbm-migrate`, `pkbm-operations-seed` (fixture opt-in dua PKBM), lalu `catalog-start`. UI pada port 3000 yang sama. [Lingkup, alur dan batas](../../docs/tahap4-implementasi.md). Gerbang kelulusan mengikuti bukti API/browser yang tercatat, bukan keberadaan file.
