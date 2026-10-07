# Verifikasi Tahap 5 — 7 Oktober 2026

**Lulus lokal: 130 pemeriksaan lulus, 0 gagal pada rangkaian akhir.** Pengguna mengizinkan pengujian dan token sementara. [Hasil terstruktur](./tahap5-verifikasi.json).

| Rangkaian | Lulus | Gagal |
|---|---:|---:|
| preflight | 44 | 0 |
| integration | 18 | 0 |
| behavior | 36 | 0 |
| update | 10 | 0 |
| binding | 12 | 0 |
| canvas-lti | 4 | 0 |
| cleanup | 6 | 0 |

## Bukti nyata

Dua fixture PKBM menghasilkan subaccount berbeda, Course 3/4, section, dua pengguna/enrollment per course, Outcomes, Page, module/item dan tool LTI. Relasi account/course/section/user/enrollment serta Outcome/module/Page diperiksa terhadap API Canvas. Pengulangan mempertahankan ID binding dan jumlah objek remote. Course diterbitkan dan bahan PDF terpilih dapat dibaca tiga peran yang sesuai. Course/PDF serta mutasi job/bahan lintas PKBM ditolak.

Nama pelaksanaan diperbarui lewat API PKBM dan terbukti berubah di Canvas, kemudian dipulihkan. Program warga belajar dinonaktifkan/diaktifkan melalui API PKBM dan roster Canvas mengikuti, kemudian status dipulihkan. API mempertahankan enrollment lokal sebagai record yang tidak dapat diubah langsung; uji memakai status learner_program yang didukung.

Perubahan nama manual Canvas menghasilkan konflik; retry biasa tetap konflik, retry dengan force_local menerapkan ulang rancangan lokal. Untuk kegagalan parsial, binding module uji dilepas dan fault disisipkan pada proses runner setelah PUT Canvas nyata berhasil sebelum binding tersimpan. Job gagal tercatat; retry memulihkan ID yang sama tanpa objek ganda. Ini injeksi kegagalan terkontrol pada batas persistensi, bukan bukti kehilangan jaringan/power atau semua kondisi concurrent worker.

LTI HMAC buatan uji memverifikasi launch, pertukaran kode, identitas, peran palsu, nonce/kode replay, timestamp kedaluwarsa, course lintas PKBM, user tak dikenal dan signature palsu. HTML launch bertanda tangan benar-benar diperoleh dari Canvas dengan sesi Act as warga belajar pada sesi HTTP uji terpisah, dipost ke pendamping, ditukar dan identitas membership diperiksa. Perilaku ini diuji melalui HTTP, bukan klik navigasi LTI lengkap di browser. UI browser integrasi diperiksa dan bukti tersimpan di `var/validation/stage5/integration-ui.png`.

## Perbaikan dari pengujian

Client internal semula menerima HTTP 403: domain root Canvas adalah 127.0.0.1:8081, sementara host container web:3000 berbeda. Koneksi tetap ke jaringan container, header Host sekarang mengikuti origin publik terkonfigurasi. Pengujian nyata setelah perubahan lulus.

Status API/UI kini membedakan instance tersimpan dan token tersedia. Antrean baru ditolak 422 tanpa token. Token sementara berlaku maksimum empat jam, sudah dicabut lewat API Canvas; pemakaian ulang terbukti HTTP 401. File secret sementara dihapus dan token dihapus dari ciphertext pendamping. Shared secret LTI tetap terenkripsi untuk tool yang telah terpasang. Tidak mengirim secret dalam respons status atau commit.

## Keadaan akhir dan batas

Dua Course, subaccount, pengguna, isi, binding dan riwayat uji dipertahankan untuk ditinjau. Job kegagalan awal HTTP 403 dipertahankan sebagai riwayat, bukan job aktif; tidak ada queued/running tertinggal. Nama/status program dipulihkan. Worker daemon tidak dijalankan; pengujian memakai runner satu job. Sinkronisasi selanjutnya perlu token baru karena token uji sudah dicabut.

Gerbang roadmap Tahap 5 lulus lokal berdasarkan koneksi nyata, pengulangan, update, pemulihan parsial dan binding benar. LTI masih 1.1 lokal; produksi/LTI 1.3, pengujian load/concurrent worker dan semua formulir browser tidak diklaim. Nilai akhir/SKK dan Tahap 6 belum dikerjakan. Tidak ada direct write dari pendamping ke database Canvas.
