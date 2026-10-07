# Tahap 6 — implementasi pembelajaran dan penilaian

7 Oktober 2026. **Implementasi tersedia; gerbang belum diuji.** Migrasi `20261007000400` dan seed draf berhasil dijalankan (exit 0). Tidak menjalankan tests, lint, build, pemeriksaan API/browser atau sinkronisasi nyata Tahap 6. Otorisasi pengujian sebelumnya berlaku untuk Tahap 5; permintaan terbaru memulai tahap berikutnya.

## Sumber dan tiga modul

Katalog bersama `resource_units`, `resource_target_mappings` dan `source_policy_statements` tetap acuan. Blueprint pelaksanaan tidak mengubah katalog. Seed opt-in menyediakan Belanja Cerdas, Memulai Bisnis dan LHO untuk masing-masing DEMO-A/DEMO-B, terkait delivery Matematika/Bahasa Indonesia yang sudah tersedia. Matematika menggunakan satu Course untuk dua modul; Bahasa Indonesia menggunakan Course sendiri ketika sinkronisasi dijalankan. Course Bahasa Indonesia belum diprovisikan oleh pekerjaan ini.

Teks bagian unit/penugasan/pedoman penilaian ketiga PDF dibaca ulang memakai Poppler; sumber asli dipertahankan. Unit dan halaman dipakai sebagai rujukan, bukan salinan lengkap. MAP-04 menjadi halaman referensi dengan peringatan; tidak dibuat instrumen yang mengklaim menilai KD 3.4/4.4. Ini tidak menutup temuan akademik tersebut.

Draf Unit 1 BId mengikuti sepuluh soal pada PDF dan maksimum 10 poin; persentase poin/10 × 100 setara poin × 10. Unit 2 memakai maksimum 2,2,4,1,1 untuk lima jawaban. Analisis minimal dua teks dicatat sebagai bukti tambahan yang ditelaah tutor. Produk LHO dan revisinya memiliki rubrik lokal terpisah. TAM berisi 15 butir **adaptasi lokal baru**, bukan transkripsi TAM pada PDF, dan belum ditelaah/diterbitkan. Kunci soal hanya dikirim kepada pengelola/tutor sesuai akses.

## Versi, rubrik dan kebijakan lokal

`assessment_plans`: bahan/delivery/versi, blueprint, status draft/published, penelaah/waktu. Relasi tenant komposit mengikuti tabel sebelumnya. Trigger DB mempertahankan versi yang sudah terbit. Draf dapat diperbaiki; versi baru disalin secara eksplisit. Publish memerlukan konfirmasi telaah dan memeriksa komponen, target, unit, instrumen, rubrik serta MAP-04.

Rubrik Matematika usulan lokal: model, prosedur, perhitungan dan penafsiran masing-masing 25 poin. Denominator tugas = jumlah maksimum seluruh rubrik tugas/latihan yang diterbitkan; tes penempatan terpisah. Instrumen penempatan berupa masalah lokal yang perlu ditelaah. Ini keputusan rancangan, bukan bobot resmi kurikulum/silabus/modul.

BId Unit 2 menggunakan usulan ambang operasional 70% atas ungkapan sumber “sekitar 70%”. Rubrik produk/revisi memakai empat kriteria masing-masing 25 poin sebagai usulan lokal. Tutor mengesahkan usulan melalui publish, tidak melalui seed. Rekap pendamping mempertahankan setiap percobaan tanpa memilih nilai tertinggi/terakhir secara otomatis. Canvas membutuhkan `keep_latest` untuk tampilan gradebook quiz; itu properti pelaksanaan native yang tidak menjadi nilai rekap modul. Assignment termasuk TAM dikecualikan dari nilai akhir Course melalui `omit_from_final_grade`.

## Publikasi ke Canvas

Publisher Tahap 5 memanggil `CanvasAssessmentPublisher` untuk versi terbit terbaru per bahan. Module per bahan, Page per unit, Assignment/rubrik per bukti, Quiz TAM/soal dan module items menggunakan binding, checksum, snapshot dan lookup marker. Seluruhnya melalui API; tidak menulis tabel Canvas. TAM awal belum published, satu percobaan, hanya terlihat melalui assignment overrides. Tutor melepas uji bagi warga belajar yang dipilih setelah Unit 1 minimal 70. Ulangan membutuhkan TAM pertama selesai dengan nilai di bawah 70; extension satu kali dicatat dan dibatasi lintas versi modul. Versi baru tidak otomatis mereset kesempatan bila riwayat sudah ada.

Pendaftaran Quiz, rubric association, submission/grade, assignment override dan quiz extension ditulis berdasarkan source API checkout Canvas yang dikunci. Kompatibilitas payload/runtime **belum diuji**. Worker/job nyata memerlukan token baru. Pemulihan/idempotensi Tahap 5 yang sudah lulus tidak otomatis membuktikan jenis objek Tahap 6 yang baru.

## Pekerjaan, nilai dan tindak lanjut

UI “Belajar dan umpan balik” menampilkan versi terbit untuk warga belajar; pengelola/tutor dapat menelaah draf, petunjuk, kriteria/poin dan soal/kunci serta membuat versi baru. Warga belajar mengumpulkan teks/revisi melalui pendamping ke Submission Canvas dengan `as_user_id` dari binding sendiri. Rujukan dua teks dipersyaratkan untuk analisis; validasi struktur ini bukan pembuktian kualitas isi. Tutor tetap menelaah apakah benar dua teks dan analisisnya sesuai. Unggahan file dan pengerjaan TAM dilakukan di Canvas melalui tautan native; login Canvas terpisah masih diperlukan. LTI Canvas → pendamping tetap tersedia; SSO pendamping → Canvas belum tersedia.

Penilaian memakai tutor yang ditugaskan dan ID Canvas tutor sebagai pelaku, bukan identitas admin token. Poin kriteria dibatasi maksimum, jumlahnya dihitung dan dikirim bersama rubric assessment serta feedback/tindak lanjut ke Canvas. `assessment_attempts` menyimpan snapshot source submission, attempt, versi, learner, penangkap/waktu. GET pekerjaan menangkap snapshot baru hanya bila berubah. Canvas submission history/comments menjadi sumber pekerjaan/revisi. `assessment_actions` mencatat ulangan serta telaah lanjut/pendampingan, alasan, prosedur, konflik dan ID bukti.

Telaah Matematika memilih jalur lengkap/prosedur, tugas ≥75%, atau penempatan ≥75%; hasil yang berlawanan memerlukan catatan konflik. Telaah BId mempertimbangkan unit, produk/revisi serta TAM. “Siap lanjut” merupakan telaah modul, bukan keputusan capaian kompetensi/SKK. Penarikan seluruh hasil native secara berkala, rekap lintas modul dan keputusan capaian mengikuti Tahap 7. Memulai Bisnis memerlukan telaah lanjut Belanja Cerdas sebelum penugasan dilepas per warga belajar. Unit 2 BId memerlukan Unit 1 minimal 70; produk memerlukan bukti Unit 2 minimal 70; TAM memerlukan semua bukti unit/produk termasuk revisi. Assignment overrides membatasi penugasan bagi warga belajar yang dilepas tutor. Halaman materi dapat dibaca sebagai persiapan; gerbang berlaku pada penugasan/uji. Seluruh orkestrasi ini belum diuji pada Canvas nyata.

## Menjalankan dan pekerjaan tersisa

```sh
./scripts/local pkbm-migrate
./scripts/local pkbm-assessment-seed
# Telaah draf melalui Belajar dan umpan balik, kemudian terbitkan.
# Setelah otorisasi Canvas baru tersedia, antrekan delivery melalui Integrasi Canvas.
./scripts/local sync
```

Pemasangan tercatat di `var/validation/stage6-migrate.log` dan `stage6-seed.log`. Blueprint tersimpan di `apps/pkbm/db/seeds/assessment-blueprints.json`. Rangkaian pengujian Tahap 6 belum ditulis/dijalankan sesuai AGENTS.md. Gerbang masih membutuhkan: telaah/publikasi nyata, pembuktian prasyarat seluruh alur unit/modul, Course BId dan dua module MTK nyata, browser WB/tutor, contoh perhitungan, revisi LHO, batas percobaan/replay/lintas versi, kesesuaian rubric ID, atribusi grader, isolasi tenant/peran dan retry objek assessment. Tahap 7 belum dimulai.
