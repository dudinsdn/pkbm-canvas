# Tahap 3 — pengukuran dan unggahan browser

7 Oktober 2026. **Tahap 3 Lulus lokal; pengukuran dan unggahan browser selesai dibuktikan. Tahap berikutnya belum dimulai.** Bagian percobaan timeout di bawah merupakan riwayat sebelum pengujian melalui tampilan Files lama.

## Pengukuran

Tiga sampel idle diambil sebelum aktivitas browser. Dua belas sampel operasi mencakup login pengelola dan pembukaan Files course 2. Delapan sampel tambahan mencakup percobaan pemilih berkas. Semua lima layanan proyek berjalan. Sampel memakai `docker stats --no-stream`, `/proc/meminfo`, `df -B1 / /home`, dengan jeda dua detik antar sampel; waktu pembacaan Docker turut memperpanjang interval. Idle berarti tidak ada permintaan uji yang sengaja dikirim; pekerjaan worker dan aplikasi desktop lain tetap berjalan.

| Fase | Sampel | RAM host tersedia (MiB) |
|---|---:|---:|
| idle | 3 | 1578.9–1587.5 |
| operation | 12 | 1387.3–1573.2 |
| upload | 8 | 1484.5–1510.2 |

Rincian RAM/CPU per container serta disk per fase: [hasil pengukuran](./tahap3-pengukuran.json). Disk akhir sekitar root 10,0 GiB dan home 8,9 GiB tersedia. Swap nol. Selisih host/disk mencakup proses lain dan log; tidak seluruhnya dapat diatribusikan kepada Canvas. Sampel ini tidak mengukur puncak kontinu, waktu respons, konkurensi, atau kapasitas kelas nyata.

## Unggahan browser

Login pengelola berhasil; course 2 Files dan dialog Upload file terlihat. Percobaan lewat tombol “choose files” serta input file sebenarnya sama-sama timeout menunggu event filechooser selama 10 detik. Pemilihan file dan pengiriman belum terjadi; tidak ada klaim unggahan browser sukses. Kontrol komputer native tidak tersedia pada sesi ini, sehingga tidak ada jalur picker alternatif yang dapat dijalankan. Ini hambatan pembuktian melalui browser yang tersedia, bukan bukti bahwa uploader Canvas rusak.

Bukti dialog lokal: `var/validation/stage3/upload-dialog.png`. File uji: `var/validation/stage3/cek-browser-tahap3.txt`. Log/sampel mentah di direktori yang sama, dikecualikan Git. Bukti unggahan/download API, worker dan persistensi sebelumnya tetap berlaku.

## Checklist dan langkah tersisa

Butir pengukuran sekarang tercentang berdasarkan eksekusi. Tambahkan butir khusus unggahan browser yang masih terbuka agar kelulusan API tidak menutupi keterbatasan ini. Status Tahap 3 tetap parsial hingga pemilihan file dan unggahan selesai dibuktikan. Verifikasi tersisa dapat dilakukan melalui browser/picker yang mampu memilih berkas, lalu memastikan file tampil dan hasil unduh cocok. Belum masuk Tahap 4.

## Penyelesaian unggahan browser

Pengguna membuka tampilan Files lama dan menyatakan unggahan bisa dilakukan. Pada tab yang sama, pengujian agen berhasil menerima event filechooser, memilih fixture dan mengunggahnya. Toast `cek-browser-tahap3.txt uploaded successfully!` serta baris file terlihat. API baca kemudian menemukan dua record file uji (ID 2 dan 4); kedua unduhan berukuran 55 byte cocok dengan fixture dan SHA-256 sama. Tidak menghapus record. [Bukti terstruktur](./tahap3-unggahan-browser.json). Screenshot: `var/validation/stage3/upload-success.png`.

Butir unggahan browser sekarang tercentang. Seluruh checklist Tahap 3 lengkap untuk runtime lokal. Keberhasilan ini menggunakan Files lama, tidak menutup keterbatasan picker otomatis pada Files baru. Belum lulus produksi atau pengujian beban; Tahap 4 belum dikerjakan.

## Konfirmasi manual New Files Page

Pengguna mengonfirmasi unggahan New Files Page berhasil pada 7 Oktober 2026. Jalur tersebut dicatat lulus berdasarkan pengujian manual pengguna; timeout sebelumnya terbatas pada otomatisasi picker agen. Checklist unggahan browser tercentang dan status Tahap 3 tetap Lulus lokal. Bukti byte unduhan yang diperiksa agen berasal dari pengujian Files lama.
