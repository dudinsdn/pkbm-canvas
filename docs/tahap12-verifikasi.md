# Pembuktian Tahap 1–2 — 7 Oktober 2026

**Status: Lulus lokal untuk fondasi dan katalog contoh yang ditetapkan roadmap.** Ini hasil pemeriksaan yang dijalankan, bukan kesimpulan dari keberadaan kode. Ringkasan terstruktur: [tahap12-verifikasi.json](./tahap12-verifikasi.json).

## 1. Bukti fondasi

- Compose `config --quiet` selesai exit 0. Source Canvas tetap dipatok pada commit prod yang tercatat di `infra/runtime-selection.json`; manifest acuan dan manifest runtime sama.
- Repo dan aplikasi pendamping terpisah dari checkout upstream. Patch checkout direkam melalui `infra/canvas-low-memory.patch` dan `scripts/canvas-prepare`.
- Tautan file lokal pada dokumen yang diperiksa ditemukan; dokumen desain diberi penanda snapshot historis. Klaim status terkini mengikuti laporan ini dan catatan implementasi.
- Database `canvas_development` dan `pkbm_development` memakai pengguna berbeda. PostgreSQL mengonfirmasi pengguna PKBM tidak memiliki CONNECT ke database Canvas dan sebaliknya.
- Wrapper start/stop/log/migrasi/seed tersedia. Bukti operasi yang sudah dijalankan ada pada catatan implementasi; penyediaan perintah tidak diklaim sebagai pengujian setiap kombinasi argumen. `sync` tetap guard yang menolak operasi; sinkronisasi sebenarnya milik Tahap 5.
- Rahasia/data runtime dikecualikan Git dan nilai rahasia diperiksa terhadap isi yang akan dilacak. Tidak mengubah data proyek lain.

## 2. Migrasi, seed, constraint dan API

**62 pemeriksaan terarah lulus, 0 gagal.** Skrip: `scripts/verify-catalog.py`.

| Yang dibuktikan | Hasil |
|---|---|
| Migrasi dan seed database baru | Berhasil pada database audit sementara yang dibuat oleh pemeriksaan; database audit dihapus sesudahnya |
| Migrasi/seed diulang | Berhasil; jumlah dan hash seluruh baris pada 20 koleksi tidak berubah |
| Seed baru dibanding database aktif | Jumlah dan hash setiap koleksi sama |
| Perubahan isi seed yang sudah ada | Ditolak; transaksi gagal tidak mengubah isi database audit |
| Jalur Rails sesudah runner SQL | `pkbm-migrate` exit 0; `pkbm-seed` exit 0 dan pesan Catalog seed applied |
| UUID/FK/keunikan dan konteks | Kasus negatif di bawah ditolak; transaksi dibatalkan |
| Kode indikator berulang | Dua indikator berkode sumber 3.2.2 di konteks parent berbeda tetap tersimpan |
| SKK | V: 26/30/24; VI: 14/15/13. subject_skk seluruh komponen tetap null |
| API indeks/cakupan | HTTP 200; jumlah 20 koleksi cocok seed, 52 komponen dengan status cakupan |
| API koleksi | Semua ID pada 20 koleksi terbaca melalui pagination dan cocok seed |
| Batas API | Limit dibatasi 100; koleksi tidak dikenal dan POST tidak tersedia: HTTP 404 |
| Data setelah pemeriksaan | Hash seluruh koleksi tetap sama |

Kasus negatif: catalog_key duplikat, SHA invalid, rujukan melampaui halaman PDF, rentang halaman terbalik, FK sumber hilang, jenis kelompok invalid, SKK nol/negatif, parent target beda komponen/jenis, parent diri sendiri/siklus, framework-target beda komponen, activity-target beda komponen, unit-resource tidak cocok, klaim mastery otomatis, aturan sumber executable, dan peminatan dari versi kurikulum berbeda. Ini pemeriksaan terhadap constraint yang diterapkan, bukan jaminan seluruh kemungkinan data invalid sudah tercakup.

## 3. Identitas dan telaah sumber

**317 pemeriksaan integritas lulus, 0 gagal.** Skrip: `scripts/verify-source-register.py`. Pemeriksaan otomatis meliputi SHA-256/jumlah halaman delapan PDF, 45 rentang rujukan, provenance pemetaan/aturan, konteks parent target, tipe transkripsi, 52 komponen, tiga bahan modul, 18 hubungan KD, pemisahan panduan dari modul, dan pencegahan otomatisasi mastery/SKK. Pemeriksaan otomatis ini tidak menggantikan pembacaan isi.

Pembacaan ulang dilakukan pada halaman sumber yang mendasari katalog contoh, dengan ekstraksi teks dan pemeriksaan visual tabel struktur kurikulum serta tabel indikator Matematika. Hasil telaah:

| Isi katalog yang ditelaah | Dasar dan hasil |
|---|---|
| 52 komponen V/VI, tiga peminatan, anggaran kelompok | Kurikulum PDF 6–7; enam mapel umum, empat mapel tiap peminatan, pemberdayaan dan cabang keterampilan. Nama mapel wajib/peminatan serta cabang keterampilan memakai label sistem agar konteksnya berbeda; bukan penggandaan SKK |
| Keterampilan wajib/pilihan dan 10 relasi komponen | Panduan keterampilan PDF 7–8; wajib merujuk Seni Budaya, Olahraga/Rekreasi dan Prakarya; pilihan sertifikasi/nonsertifikasi tidak menambah bobot kelompok |
| 8 KI dan 12 KD contoh | Kurikulum PDF 17, 23–24; KI 1/2 normalisasi tipografi, KI 3/4 ringkasan editorial. Matematika hanya KD 3.1–3.4/4.1–4.4; Bahasa Indonesia hanya 3.1–3.2/4.1–4.2 |
| 31 indikator | Silabus Matematika PDF 11–12 dan Bahasa Indonesia PDF 10; ringkasan editorial tetap memiliki parent dan kode sumber. Kode 3.2.2/3.2.3/4.2.1/4.2.2 di bagian KD 3.4/4.4 tidak diganti; 4..1.2 dipertahankan dengan kode tampilan 4.1.2 |
| 24 target pemberdayaan pada V/VI | Panduan pemberdayaan PDF 15 tabel Paket C dan PDF 16 tiga area. Deskripsi merupakan ringkasan panduan, kode area/capaian adalah kode lokal; tidak dinyatakan sebagai KD nasional |
| 6 materi dan kegiatan contoh | Silabus pada halaman yang sama; ringkasan editorial kegiatan dibedakan dari rumusan sumber dan terhubung dengan KD contoh |
| 10 bagian dari tiga modul, 18 hubungan KD | Halaman modul tercatat pada setiap provenance. MAP-01 hanya landasan sebagian untuk nilai mutlak. MAP-04 berisi persamaan linear-kuadrat/kuadrat-kuadrat sedangkan KD menuntut pertidaksamaan; tetap berstatus perlu telaah, bukan selaras penuh |
| 19 pernyataan sumber dan 3 keputusan desain | Aturan modul 75%/70% memiliki lingkup masing-masing. Panduan penilaian pemberdayaan/keterampilan tetap dibedakan dari modul; R-20–R-22 bertanda keputusan desain, tidak diberi provenance nasional yang dibuat-buat |

Rujukan framework yang belum disemai kompetensinya, misalnya Matematika/Bahasa Indonesia VI, merupakan rujukan ketersediaan dokumen; halaman sampul bukan bukti bahwa KD VI telah masuk katalog. Status cakupan tetap terbatas.

## 4. Batas kelulusan

- Lulus lokal berlaku pada **fondasi dan katalog contoh**; bukan seluruh transkripsi kurikulum/silabus, implementasi hasil belajar, integrasi Canvas, pengesahan SKK atau produksi.
- Pemetaan diperiksa terhadap sumber pengguna oleh agen pada tahap teknis ini. `review_status=belum_ditelaah_tutor_pkbm` tetap benar: belum ada penelaahan/pengesahan oleh tutor PKBM. Perbedaan MAP-04 adalah temuan yang berhasil dicatat, bukan masalah akademik yang dianggap sudah diselesaikan.
- Uji negatif mencakup kasus yang disebutkan di atas; tidak mengklaim seluruh kombinasi relasi atau kebutuhan tahap mendatang sudah diuji.
- Bukti fungsi dasar Tahap 3 tetap berlaku. Pengukuran idle/operasi terpisah dan pemilih berkas browser otomatis tidak ditambahkan oleh pemeriksaan Tahap 1–2 ini.
- Log lengkap, hash snapshot dan ekstraksi sumber berada di `var/validation/stage12/` (diabaikan Git). Ringkasan bukti tersimpan pada dokumen ini dan JSON pendamping agar hasilnya dapat ditinjau tanpa mencantumkan rahasia.

## Sumber yang diperiksa

- Kurikulum Paket C: :codex-file-citation{path="/home/din/Downloads/modul-kesetaraan/Kurikulum_2013_Pendidikan_Kesetaraan-Paket-C.pdf" purpose="source"}
- Silabus Matematika: :codex-file-citation{path="/home/din/Downloads/modul-kesetaraan/Matematika/C-Silabus-Matematika.pdf" purpose="source"}
- Belanja Cerdas: :codex-file-citation{path="/home/din/Downloads/modul-kesetaraan/Matematika/C-Mtk-1-BELANJA_CERDAS.pdf" purpose="source"}
- Memulai Bisnis: :codex-file-citation{path="/home/din/Downloads/modul-kesetaraan/Matematika/C-Mtk-2-MEMULAI_BISNIS.pdf" purpose="source"}
- Silabus Bahasa Indonesia: :codex-file-citation{path="/home/din/Downloads/modul-kesetaraan/Bahasa_Indonesia/C-Silabus-BId.pdf" purpose="source"}
- Menyingkap Ilmu Pengetahuan di Sekitar Kita: :codex-file-citation{path="/home/din/Downloads/modul-kesetaraan/Bahasa_Indonesia/C-BId-1-Menyingkapi_Ilmu_Pengetahuan_di_Sekitar_Kita.pdf" purpose="source"}
- Panduan keterampilan: :codex-file-citation{path="/home/din/Downloads/modul-kesetaraan/muatan_khusus/Muatan-Keterampilan.pdf" purpose="source"}
- Panduan pemberdayaan: :codex-file-citation{path="/home/din/Downloads/modul-kesetaraan/muatan_khusus/Muatan-Pemberdayaan.pdf" purpose="source"}
