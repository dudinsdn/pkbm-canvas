# Validasi API Tahap 4 — 7 Oktober 2026

**Lulus lokal API: 483 pemeriksaan terarah, 0 gagal pada pengujian terakhir.** Angka ini menghitung assertion termasuk pengulangan matriks tenant/peran/koleksi; bukan 483 skenario keamanan berbeda. [Hasil terstruktur](./tahap4-api-verifikasi.json). Skrip: `scripts/verify-stage4-api.py`.

## Bukti yang dijalankan

| Lingkup | Hasil |
|---|---|
| Login dua PKBM × tiga peran dan identitas | Enam akun berhasil; password salah, akses anonim dan token dimodifikasi ditolak |
| Seluruh 17 koleksi untuk enam akun | GET berhasil dalam batas tenant; password digest tidak dikirim |
| Detail record PKBM lain | 404 untuk seluruh koleksi pada pengelola, tutor dan warga belajar DEMO-A terhadap DEMO-B |
| Mutasi warga belajar | Ditolak 403 pada seluruh koleksi; pemalsuan header peran/PKBM juga ditolak |
| Tutor dan pengelolaan peran | Tutor tidak dapat memberi peran; pemilik rancangan ditetapkan server |
| Alur tulis lokal | Orang, membership/peran, program, peserta, kelompok, rancangan, komponen, kegiatan/target, publikasi, pelaksanaan/staff/enrollment, sesi, rencana/item berhasil melalui API |
| Rancangan/acuan | Publikasi rancangan kosong dan target di luar komponen ditolak; kegiatan rancangan terbit tidak dapat diubah |
| Penugasan tutor | Pelaksanaan belum ditugaskan tersembunyi dan sesi ditolak; setelah ditugaskan dapat dibaca/dijadwalkan |
| Rencana warga belajar | Rencana dan item warga belajar lain pada PKBM yang sama ditolak; pemilik dapat membaca sendiri |
| Item rencana tutor | Item pada pelaksanaan yang tidak ditugaskan ditolak, walaupun warga belajar juga didampingi pada pelaksanaan lain |
| Relasi/versi | Referensi anggota PKBM lain, PATCH record asing dan rencana aktif kedua ditolak |
| Privasi | Email orang lain disembunyikan bagi warga belajar; password digest tidak diserialisasi |
| Data setelah pengujian | Semua record audit sementara dihapus tepat ID; data asli 17 koleksi kedua PKBM sama sebelum/sesudah |

## Temuan dan perbaikan

Pengujian tambahan menemukan tutor dapat membaca semua item rencana seorang warga belajar yang didampingi, termasuk item pada pelaksanaan lain yang tidak ditugaskan. `OperationScope` diperbaiki: item rencana harus berada pada rencana yang boleh dibaca **dan** pelaksanaan yang boleh diakses. Scope pelaksanaan staff juga memerlukan peran tutor/instruktur saat ini. Kasus reproduksi masuk skrip dan lulus setelah perbaikan.

Pengujian awal memakai payload kosong yang ditolak Rails sebelum pemeriksaan mutasi peran, serta nama/kode katalog yang tidak sesuai seed. Skrip diperbaiki memakai payload nonkosong dan identitas katalog aktual. Hasil akhir di atas berasal dari pengujian lengkap sesudah koreksi tersebut dan perbaikan aplikasi.

## Batas bukti

- Pengguna menyatakan sudah mencoba UI langsung di browser dan berjalan dengan tampilan sederhana. Itu dicatat sebagai bukti manual pengguna untuk tampilan/alur dasar; tidak diklaim sebagai rekaman agen atas semua formulir atau alur end-to-end.
- Gerbang API dua PKBM/peran terbukti. Pengujian ini tidak mencakup semua kombinasi relasi, status/nonaktif, kedaluwarsa token, konkurensi, seluruh skenario administrasi, pagination skala besar atau hardening produksi.
- Dua tenant fixture memiliki tiga peran. Kasus isolasi warga belajar diperluas dengan akun/peserta sementara dalam tenant yang sama. Tidak memakai data pribadi nyata atau mengubah database Canvas.
- Cleanup hanya menyasar UUID record yang dibuat oleh skrip. Tidak menghapus fixture awal atau perubahan manual pengguna. Log rinci lokal: `var/validation/stage4-api.log`; hasil mentah: `var/validation/stage4/api-results.json`.
- Rancangan kegiatan/bukti belum merupakan nilai akademik, keputusan mastery atau pengesahan SKK. Integrasi Canvas tetap Tahap 5, belum dikerjakan.

## Status roadmap

Tahap 4 **Lulus lokal**, berdasarkan API yang dijalankan agen dan konfirmasi manual pengguna bahwa alur dasar UI berjalan. Ini memenuhi gerbang alur dasar browser pada roadmap; tidak diklaim sebagai pengujian otomatis lengkap seluruh formulir. Tahap 5 belum dimulai.
