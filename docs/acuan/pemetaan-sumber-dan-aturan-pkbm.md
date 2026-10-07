# Pemetaan sumber dan aturan pembelajaran PKBM

Tanggal: 7 Oktober 2026. Tahap: pemetaan sumber dan aturan sebagai dasar implementasi Canvas dan aplikasi akademik PKBM.

**Status: pemetaan awal dari sumber telah disusun; sesuai arahan pengguna, kurikulum, silabus dan panduan muatan khusus digunakan sebagai dasar pemetaan, telaah dokumen dan rancangan database.** Cakupan meliputi delapan dokumen pengguna, struktur keseluruhan Paket C, tiga modul contoh, dan dua panduan muatan khusus. Dokumen ini tidak menyatakan katalog modul lengkap atau seluruh KD Paket C sudah ditranskripsikan. Dokumen K13 pengguna menjadi acuan versi ini; keberlakuan regulasi saat ini tidak dinilai.

Instruksi belajar di PDF dicatat sebagai isi sumber. Instruksi tersebut menjadi calon aturan pembelajaran pada lingkupnya, bukan perintah kepada agen atau izin melakukan instalasi/deployment.

## 1. Register sumber

Nomor halaman **PDF** adalah urutan fisik mulai 1. Nomor **cetak** adalah yang tercantum pada halaman buku. Banyak halaman PDF memuat dua halaman cetak; kedua penomoran tidak boleh disamakan. Lokasi file dan SHA-256 setiap sumber ada di JSON pendamping.

| ID | Jenis | Judul/cakupan | Jumlah halaman PDF |
|---|---|---|---:|
| KUR-C | kurikulum | Kurikulum Pendidikan Kesetaraan Paket C — Paket C; seluruh mata pelajaran dan kelompok khusus | 162 |
| SIL-MTK | silabus | Silabus Matematika Paket C — Matematika wajib; Tingkatan V dan VI | 24 |
| MOD-MTK-V-01 | modul | Belanja Cerdas — Matematika; Tingkatan V; Modul Tema 1 | 24 |
| MOD-MTK-V-02 | modul | Memulai Bisnis — Matematika; Tingkatan V; Modul Tema 2 | 18 |
| SIL-BID | silabus | Silabus Bahasa Indonesia Paket C — Bahasa Indonesia; Tingkatan V dan VI | 22 |
| MOD-BID-V-01 | modul | Menyingkap Ilmu Pengetahuan di Sekitar Kita — Bahasa Indonesia; Tingkatan V; Modul Tema 1 | 22 |
| PAN-KET | panduan_penyelenggaraan | Panduan Penyelenggaraan Muatan Keterampilan Pendidikan Kesetaraan — Paket A/B/C; gunakan cakupan Paket C pada rancangan ini | 18 |
| PAN-PEM | panduan_penyelenggaraan | Panduan Penyelenggaraan Muatan Pemberdayaan Pendidikan Kesetaraan — Paket A/B/C; gunakan cakupan Paket C pada rancangan ini | 20 |

Judul internal Modul Bahasa Indonesia adalah **Menyingkap Ilmu Pengetahuan di Sekitar Kita**; nama file memakai **Menyingkapi**. Simpan nama file asli dan judul internal sebagai kolom terpisah. Tanggal metadata pembuatan PDF bukan identitas revisi resmi dokumen.

## 2. Struktur program dari kurikulum

KUR-C PDF 5–7, cetak 1–4: Paket C memiliki Tingkatan V (setara X–XI) dan VI (setara XII). Struktur memuat umum, peminatan dan kelompok khusus. Catatan tabel menyebut peminatan termasuk kelompok umum dalam pengertian luas; model boleh memisahkannya untuk pengelolaan, sambil mempertahankan kelompok asal sumber.

| Kelompok | Komponen |
|---|---|
| Umum | Pendidikan Agama, Pendidikan Kewarganegaraan, Bahasa Indonesia, Matematika, Sejarah Indonesia, Bahasa Inggris |
| Peminatan Matematika dan Ilmu Alam | Matematika peminatan, Biologi, Fisika, Kimia |
| Peminatan Ilmu-ilmu Sosial | Geografi, Sejarah peminatan, Sosiologi, Ekonomi |
| Peminatan Ilmu Bahasa dan Budaya | Bahasa dan Sastra Indonesia, Bahasa dan Sastra Inggris, pilihan bahasa asing, Antropologi |
| Khusus | Pemberdayaan dan keterampilan |

Bagian isi kurikulum juga memuat Seni Budaya, Pendidikan Olahraga dan Rekreasi, serta Prakarya dan Kewirausahaan. PAN-KET mengaitkan keterampilan wajib dengan KD Seni Budaya, Pendidikan Olahraga dan Rekreasi serta Prakarya. Simpan hubungan ke materi/KD asal tersebut; jangan membuat muatan tambahan yang menggandakan beban karena nama program pelaksanaannya berbeda.

| Bobot SKK pada tabel | Tingkatan V | Tingkatan VI | Jumlah |
|---|---:|---:|---:|
| Umum | 26 | 14 | 40 |
| Peminatan | 30 | 15 | 45 |
| Khusus | 24 | 13 | 37 |
| Total | 80 | 42 | 122 |

Angka merupakan bobot kelompok, bukan bobot setiap mata pelajaran. Sumber yang dibaca belum menetapkan pembagian angka tersebut ke masing-masing modul atau keputusan pengakuan warga belajar. Satu SKK terkait 1 JP tatap muka atau 2 JP tutorial atau 3 JP mandiri, atau kombinasi proporsional; JP Paket C 45 menit (KUR-C PDF 5–6). Waktu belajar dan pengakuan capaian tetap dicatat terpisah.

Pendidikan Agama mengikuti kurikulum pendidikan formal yang dirujuk dokumen, tanpa kontekstualisasi dalam buku ini (KUR-C PDF 5 dan 7). Sumber silabus/modul Agama belum diberikan.

## 3. Posisi dokumen dan pelaku

```text
Kurikulum Paket C
├── Umum/peminatan
│   └── Mata pelajaran → silabus → koleksi modul
│       └── Unit → kegiatan → bukti → penilaian
└── Khusus
    ├── Pemberdayaan → panduan → rancangan program/kegiatan
    └── Keterampilan → panduan
        ├── Wajib → KD sumber → rancangan pelaksanaan
        └── Pilihan → standar program → bersertifikasi/nonsertifikasi
```

Silabus menguraikan KD, indikator, materi dan kegiatan; modul adalah salah satu bahan/rangkaian belajar untuk sebagian cakupan silabus. Satu modul dapat memetakan beberapa KD; beberapa modul dapat menguatkan KD yang sama. Pemetaan adalah hasil telaah isi, bukan hubungan otomatis dari nomor modul atau kata pada judul.

| Pelaku | Tanggung jawab rancangan |
|---|---|
| PKBM | Menentukan program/kurikulum yang dipakai, peminatan, kapasitas, kelompok, tutor, mitra, aturan akademik dan alokasi SKK yang belum dirinci sumber |
| Tutor/instruktur | Memetakan kegiatan dan bukti ke indikator, merancang instrumen/rubrik, memfasilitasi belajar, menilai, memberi umpan balik dan tindak lanjut |
| Warga belajar | Terlibat dalam rencana pelaksanaan, belajar mandiri/bersama, mengerjakan kegiatan, menunjukkan bukti, menerima umpan balik dan memperbaiki |
| Mitra/asesor | Memberikan bukti/penilaian praktik atau hasil uji sesuai penugasan dan kewenangan; sertifikasi eksternal tercatat sebagai hasil penerbitnya |

## 4. Pemetaan tiga modul contoh

Semua hubungan berikut adalah pemetaan kerja dari isi yang diberikan, **belum disahkan tutor sebagai cakupan penilaian**. “Selaras materi” menunjukkan kesesuaian pokok bahasan, bukan bukti seluruh indikator telah dinilai atau warga belajar telah menguasainya. JSON menyimpan kode indikator, halaman dan catatan tiap hubungan.

| ID | Modul dan bagian | KD Tingkatan V | Status hubungan | Sumber silabus |
|---|---|---|---|---|
| MAP-01 | MOD-MTK-V-01 — Unit 1: Persamaan linear satu variabel dan dua variabel serta penerapan sehari-hari | 3.1, 4.1 | landasan_sebagian | SIL-MTK PDF 11; cetak 14-15 |
| MAP-02 | MOD-MTK-V-01 — Unit 2: Sistem pertidaksamaan linear satu variabel dan nilai mutlak | 3.1, 4.1 | selaras_materi | SIL-MTK PDF 11; cetak 14-15 |
| MAP-03 | MOD-MTK-V-01 — Unit 3: Pertidaksamaan rasional dan irasional satu variabel | 3.2, 4.2 | selaras_materi | SIL-MTK PDF 11,12; cetak 15-16 |
| MAP-04 | MOD-MTK-V-01 — Bagian A/B di Unit 3: sistem persamaan linear-kuadrat dan kuadrat-kuadrat | 3.4, 4.4 | perlu_telaah_perbedaan_konsep | SIL-MTK PDF 12; cetak 17 |
| MAP-05 | MOD-MTK-V-02 — Unit 1: Konteks penggunaan sistem persamaan linear dalam dunia usaha dan masalah sehari-hari | 3.3, 4.3 | selaras_materi | SIL-MTK PDF 12; cetak 16 |
| MAP-06 | MOD-MTK-V-02 — Unit 2: Strategi sistem persamaan linear tiga variabel | 3.3, 4.3 | selaras_materi | SIL-MTK PDF 12; cetak 16 |
| MAP-07 | MOD-MTK-V-02 — Unit 3: Penyelesaian masalah yang terkait dengan sistem persamaan linear tiga variabel | 3.3, 4.3 | selaras_materi | SIL-MTK PDF 12; cetak 16 |
| MAP-08 | MOD-BID-V-01 — Unit 1: Alam sekitar kita yang luar biasa | 3.1, 4.1 | selaras_materi | SIL-BID PDF 10; cetak 13 |
| MAP-09 | MOD-BID-V-01 — Unit 2, Kegiatan Belajar 1: analisis struktur dan kebahasaan LHO | 3.2 | selaras_materi | SIL-BID PDF 10; cetak 13 |
| MAP-10 | MOD-BID-V-01 — Unit 2, Kegiatan Belajar 2: menyusun dan menyunting LHO | 4.2 | selaras_materi | SIL-BID PDF 10; cetak 13 |

### 4.1. Matematika 1 — Belanja Cerdas

Unit 1 memberikan landasan persamaan linear satu/dua variabel. Unit 2 membahas pertidaksamaan linear satu variabel dan nilai mutlak. Unit 3 membahas rasional/irasional dan kemudian bagian sistem dua variabel. Pengantar menyebut sistem **pertidaksamaan**, tetapi bagian A/B dan contoh halaman cetak 32–36 membahas sistem **persamaan** linear-kuadrat/kuadrat-kuadrat. KD 3.4/4.4 pada kurikulum dan silabus adalah sistem **pertidaksamaan** dua variabel.

Karena ada perbedaan konsep, MAP-04 berstatus perlu telaah. Bagian ini tidak boleh otomatis dianggap memenuhi KD 3.4/4.4. Tutor perlu menentukan penggunaan sebagai landasan serta kegiatan/penilaian tambahan yang diperlukan. Daftar isi juga menuliskan “Penugasan” Unit 3 halaman 26 meskipun unit tercantum mulai halaman 29 (PDF 4); navigasi digital memakai lokasi isi nyata.

### 4.2. Matematika 2 — Memulai Bisnis

Tiga unit mengembangkan konteks, strategi, dan penyelesaian SPLTV. Hubungan materi dengan KD 3.3/4.3 terlihat pada kurikulum PDF 24, cetak 38, dan SIL-MTK PDF 12, cetak 16. Tema bisnis tidak otomatis memasukkan modul ke Ekonomi atau mengakui capaian Ekonomi.

Calon bukti penilaian (keputusan desain tutor): identifikasi besaran/variabel; model SPLTV; langkah penyelesaian; penafsiran dan pemeriksaan jawaban dalam konteks. Rubrik/bobot per bukti belum ditetapkan oleh pemetaan ini.

### 4.3. Bahasa Indonesia 1 — Menyingkap Ilmu Pengetahuan di Sekitar Kita

Unit 1 selaras dengan KD 3.1/4.1 dan Unit 2 dengan 3.2/4.2 (KUR-C PDF 17, cetak 25; SIL-BID PDF 10, cetak 13). KD 3.2 meminta analisis minimal dua teks. Modul membahas observasi, penyusunan kerangka, penulisan dan penyuntingan di Unit 2 (PDF 12–16).

Calon bukti (keputusan desain tutor): analisis dua teks, kerangka, teks warga belajar, dan hasil revisi. Nilai TAM pilihan ganda tidak sendirinya membuktikan kemampuan menulis/menyunting. Rubrik produk yang dipakai pada LMS harus dirancang dan ditelaah.

## 5. Aturan belajar dan penilaian

Label **eksplisit sumber** berarti ketentuan ditemukan pada lokasi yang dicantumkan. Label **keputusan desain** berarti rancangan sistem yang diusulkan agar ketentuan dapat dikelola. Ketentuan per modul tidak digeneralisasi ke seluruh mata pelajaran.

### R-01 — program

**Dasar: eksplisit_sumber.** Paket C memiliki Tingkatan V setara X-XI dan VI setara XII.

Sumber: KUR-C PDF 6, cetak 2-3 (Struktur)

Implikasi: Pisahkan tingkatan dari tahun/periode pelaksanaan.

### R-02 — program

**Dasar: eksplisit_sumber.** Beban kelompok: umum 26/14; peminatan 30/15; khusus 24/13 SKK pada V/VI. Total 80/42, keseluruhan 122.

Sumber: KUR-C PDF 6,7, cetak 3-4 (Tabel struktur)

Implikasi: Simpan anggaran SKK per kelompok dan tingkatan; tidak membagi rata ke mata pelajaran atau modul.

Belum ditetapkan: Alokasi per mata pelajaran, pemberdayaan, keterampilan, modul dan pelaksanaan belum tersedia.

### R-03 — program

**Dasar: eksplisit_sumber.** Satu SKK terkait 1 JP tatap muka atau 2 JP tutorial atau 3 JP mandiri atau kombinasi proporsional; satu JP Paket C 45 menit.

Sumber: KUR-C PDF 5,6, cetak 1-3 (SKK)

Implikasi: Simpan mode, JP dan bukti capaian secara terpisah; konversi waktu bukan pengesahan SKK.

Belum ditetapkan: Siapa yang menetapkan, bukti yang dipakai dan prosedur pengakuan SKK PKBM perlu kebijakan.

### R-04 — program

**Dasar: eksplisit_sumber.** Pembelajaran dapat berbasis mata pelajaran atau tematik terpadu.

Sumber: KUR-C PDF 6, cetak 3 (Strategi pembelajaran)

Implikasi: Default katalog mengikuti modul asli; pemetaan lintas mata pelajaran hanya bila dirancang dan ditelaah.

### R-05 — silabus

**Dasar: eksplisit_sumber.** Silabus Matematika tidak menetapkan alokasi waktu, penilaian dan sumber belajar; tutor bersama peserta didik menentukannya.

Sumber: SIL-MTK PDF 3, cetak iii (Kata pengantar)

Implikasi: Sediakan rencana pelaksanaan dengan jadwal, instrumen, rubrik dan sumber yang dapat disesuaikan.

### R-06 — MOD-MTK-V-01

**Dasar: eksplisit_sumber.** Pindah modul melalui salah satu alternatif: tugas/latihan lengkap benar akurat sesuai prosedur; atau tugas/latihan minimal 75%; atau tes penempatan minimal 75%.

Sumber: MOD-MTK-V-01 PDF 23, cetak 39 (Kriteria pindah modul)

Implikasi: Modelkan alternatif OR, jenis jalur dan bukti keputusan; pemeriksaan prosedur memerlukan tutor.

Belum ditetapkan: Cara menghitung persentase tugas/latihan dan instrumen tes penempatan belum ditetapkan rinci. Sumber juga menyebut nilai di bawah 75% belum boleh pindah; konflik antarbukti perlu keputusan tutor, bukan OR otomatis tanpa konteks.

### R-07 — MOD-MTK-V-02

**Dasar: eksplisit_sumber.** Pindah modul melalui salah satu alternatif: tugas/latihan lengkap benar akurat sesuai prosedur; atau tugas/latihan minimal 75%; atau tes penempatan minimal 75%.

Sumber: MOD-MTK-V-02 PDF 16, cetak 25 (Kriteria pindah modul)

Implikasi: Modelkan alternatif OR, jenis jalur dan bukti keputusan; pemeriksaan prosedur memerlukan tutor.

Belum ditetapkan: Cara menghitung persentase tugas/latihan dan instrumen tes penempatan belum ditetapkan rinci. Sumber juga menyebut nilai di bawah 75% belum boleh pindah; konflik antarbukti perlu keputusan tutor, bukan OR otomatis tanpa konteks.

### R-08 — MOD-BID-V-01/Unit1

**Dasar: eksplisit_sumber.** Skor maksimum 10; nilai jumlah skor x 10; minimal 70 untuk lanjut Unit 2, jika belum ulang pembelajaran.

Sumber: MOD-BID-V-01 PDF 20, cetak 28 (Pedoman Penilaian Unit 1)

Implikasi: Simpan aturan pada penilaian Unit 1, bukan batas universal semua program.

### R-09 — MOD-BID-V-01/Unit2

**Dasar: eksplisit_sumber.** Skor maksimal lima soal: 2,2,4,1,1; nilai jumlah skor/10 x 100.

Sumber: MOD-BID-V-01 PDF 21, cetak 30 (Pedoman Penilaian Unit 2)

Implikasi: Penilaian uraian memakai bobot per soal; petunjuk unit menyebut sekitar 70% untuk lanjut.

Belum ditetapkan: Makna operasional sekitar 70% dan aturan setelah pengulangan ditetapkan tutor.

### R-10 — MOD-BID-V-01/TAM

**Dasar: eksplisit_sumber.** Nilai TAM = jawaban benar/jumlah soal x 100; jika skor kurang dari 70 diberikan sekali lagi kesempatan mengulang TAM.

Sumber: MOD-BID-V-01 PDF 21, cetak 31 (Pedoman Penilaian Test Uji Kompetensi)

Implikasi: Simpan hasil awal dan pengulangan; aturan hanya berlaku untuk TAM modul ini.

Belum ditetapkan: Hasil yang dipakai untuk rekap (terakhir/tertinggi) serta tindak lanjut setelah gagal ulang belum ditentukan.

### R-11 — MOD-BID-V-01

**Dasar: eksplisit_sumber.** Warga belajar mempelajari unit secara bertahap, latihan dan pemeriksaan mandiri, serta meminta waktu uji kompetensi kepada tutor; tutor sebagai fasilitator pendalaman.

Sumber: MOD-BID-V-01 PDF 4,5, cetak v-vi (Petunjuk penggunaan)

Implikasi: Pisahkan latihan mandiri, permintaan uji, uji formal, dan pendampingan.

Belum ditetapkan: Petunjuk memakai istilah uji kompetensi berulang sebelum/ sesudah meminta uji; jenis asesmen dan kewenangan pelepasan kunci perlu dirumuskan tutor.

### R-12 — Bahasa Indonesia V/3.2

**Dasar: eksplisit_sumber.** Analisis isi dan kebahasaan minimal dua teks laporan hasil observasi.

Sumber: KUR-C PDF 17, cetak 25 (KD 3.2); SIL-BID PDF 10, cetak 13 (KD 3.2)

Implikasi: Catat dua teks yang dianalisis dan bukti hasil analisis; jangan gunakan skor tes tunggal sebagai pengganti.

### R-13 — keterampilan

**Dasar: eksplisit_sumber.** Keterampilan terdiri dari wajib dan pilihan. Wajib dikembangkan dari Seni Budaya, Pendidikan Olahraga dan Rekreasi, serta Prakarya.

Sumber: PAN-KET PDF 7,8, cetak 6-9 (Muatan keterampilan)

Implikasi: Modelkan cabang wajib/pilihan dan referensi KD; mata pelajaran sumber sudah tercantum di kurikulum, jangan menggandakan SKK.

### R-14 — keterampilan Paket C

**Dasar: eksplisit_sumber.** Keterampilan untuk kebutuhan sehari-hari, tuntutan dunia kerja dan berwirausaha; pilihan sesuai minat, kebutuhan, potensi lokal dan kapasitas lembaga.

Sumber: PAN-KET PDF 8, cetak 8-9 (Tabel 1 dan penyelenggaraan)

Implikasi: Simpan analisis kebutuhan, program terpilih dan kapasitas praktik.

### R-15 — keterampilan

**Dasar: eksplisit_sumber.** Penyelenggaraan dapat mandiri atau bermitra, termasuk praktik/magang; pilihan dapat tersertifikasi atau nonsertifikasi.

Sumber: PAN-KET PDF 8,15,16, cetak 9;22-25 (Penyelenggaraan dan keterampilan pilihan)

Implikasi: Simpan mitra, lokasi, pendidik/instruktur, dan bukti praktik serta penilaian mitra bila dipakai.

### R-16 — keterampilan

**Dasar: eksplisit_sumber.** Instrumen/rubrik sesuai kompetensi, silabus/RPP dan prinsip penilaian; peserta didik terlibat aktif.

Sumber: PAN-KET PDF 12,13, cetak 17-19 (Strategi dan prosedur penilaian)

Implikasi: Tidak memakai satu tes atau ambang 70/75 untuk semua keterampilan.

Belum ditetapkan: Rubrik, bobot, ambang dan standar program spesifik perlu ditetapkan.

### R-17 — keterampilan tersertifikasi

**Dasar: eksplisit_sumber.** Penilaian dan sertifikasi mengacu standar/prosedur lembaga sertifikasi; uji teori dan praktik serta sertifikat dari lembaga berwenang.

Sumber: PAN-KET PDF 16,17,18, cetak 24-28 (Pelaksanaan, uji kompetensi, sertifikasi)

Implikasi: Pisahkan nilai PKBM dari hasil uji eksternal, nomor sertifikat, penerbit, tanggal dan bukti.

Belum ditetapkan: Nama lembaga, standar/skema, TUK, asesornya dan masa berlaku jika relevan belum tersedia.

### R-18 — pemberdayaan

**Dasar: eksplisit_sumber.** Penilaian memperhatikan kondisi awal, proses dan akhir pada pengetahuan, keterampilan serta sikap; bersifat partisipatif.

Sumber: PAN-PEM PDF 14, cetak 21 (Penilaian pemberdayaan)

Implikasi: Simpan baseline dan pengamatan berkala; rubrik perkembangan tidak diganti dengan kuis tunggal.

### R-19 — pemberdayaan

**Dasar: eksplisit_sumber.** Metode langsung: kuesioner, wawancara, diskusi kelompok terfokus; tidak langsung: observasi dan unjuk karya/performa; dapat melibatkan pihak luar.

Sumber: PAN-PEM PDF 15, cetak 22-23 (Standar, Tabel 5 dan metode)

Implikasi: Simpan instrumen, waktu, peserta/kelompok, pemberi masukan dan bukti.

Belum ditetapkan: Peran pengesah hasil dan skala capaian lokal belum ditetapkan.

### R-20 — sistem

**Dasar: keputusan_desain.** Progres, skor, capaian kompetensi, penyelesaian program, SKK dan sertifikasi merupakan catatan berbeda.

Sumber: Keputusan desain; bukan ketentuan tercetak.

Implikasi: Setiap keputusan punya bukti, aturan/versi, pelaku dan tanggal; waktu akses atau klik selesai tidak otomatis mengesahkan kompetensi.

### R-21 — sistem

**Dasar: keputusan_desain.** Sumber dan pelaksanaan memiliki versi; pemetaan diperiksa tutor sebelum digunakan sebagai dasar penilaian.

Sumber: Keputusan desain; bukan ketentuan tercetak.

Implikasi: Simpan teks/kode sumber asli, kode normalisasi, lokasi dan status telaah. Kode indikator tidak menjadi primary key tunggal.

### R-22 — sistem

**Dasar: keputusan_desain.** Tiap percobaan dan revisi bukti dipertahankan.

Sumber: Keputusan desain; bukan ketentuan tercetak.

Implikasi: Pisahkan bukti mandiri/kelompok dan penilaian individu; rumus agregasi tidak diisi tanpa aturan.

## 6. Pemberdayaan dan keterampilan: rancangan yang diturunkan

### Pemberdayaan

PAN-PEM PDF 9–13 menguraikan area pengembangan diri/kolektif untuk mengatasi masalah, apresiasi, serta mengisi ruang publik. PDF 15, cetak 23, Tabel 5 memberikan performa Paket C menurut pengetahuan, keterampilan dan sikap. Simpan capaian panduan sebagai acuan tanpa mengarang kode KD nasional.

Alur rancangan: kebutuhan/potensi awal → tujuan dan kegiatan → bukti berkala → penilaian perubahan → tindak lanjut. Rekam kegiatan kelompok beserta bukti/peran tiap anggota. Evaluasi efektivitas program bagi PKBM dan perkembangan warga belajar bagi tutor merupakan dua keluaran berbeda.

### Keterampilan

PAN-KET PDF 8, cetak 8–9: keterampilan Paket C diarahkan pada kehidupan sehari-hari, tuntutan kerja dan berwirausaha. Program wajib dan pilihan harus sama-sama terwakili. Simpan penyelenggara, minat/kebutuhan, sumber daya, mitra, program, standar dan mode sertifikasi. Keterampilan wajib dapat memakai jadwal/blok waktu atau sebagian belajar mandiri.

PAN-KET PDF 16, cetak 24 menyebut proporsi 30% teori/70% praktik pada bahasan keterampilan pilihan tersertifikasi. Catat sebagai ketentuan lingkup bagian tersebut; angka ini bukan bobot nilai dan bukan proporsi universal seluruh program. Skema program aktual perlu dipastikan tutor/mitra sebelum konfigurasi.

Hasil pembelajaran lokal dan sertifikasi eksternal memiliki rekam terpisah. Sumber memakai sebutan LSP/LSI/LSK pada bagian berbeda; simpan jenis/nama lembaga sesuai skema aktual, jangan menetapkan semuanya identik.

## 7. Register temuan dan keputusan yang masih diperlukan

| ID | Temuan | Keputusan sebelum digunakan |
|---|---|---|
| T-01 | MTK1 pengantar menyebut pertidaksamaan dua variabel, bagian A/B membahas persamaan | Tutor memeriksa cakupan KD 3.4/4.4 dan menambahkan kegiatan yang sesuai bila diperlukan |
| T-02 | SIL-MTK cetak 17 mengulang kode 3.2.2/3.2.3 dan 4.2.1/4.2.2 pada KD 3.4/4.4; terlihat pada render PDF 12 | ID unik memakai dokumen, KD induk, lokasi dan nomor baris; kode sumber disimpan, usulan normalisasi ditelaah |
| T-03 | SIL-BID mencetak 4..1.2 pada cetak 13 | Simpan kode asli, usulkan tampilan 4.1.2 dengan riwayat normalisasi |
| T-04 | Daftar isi MTK1 menempatkan penugasan Unit 3 di cetak 26 | Tautan kegiatan memakai lokasi fisik isi, bukan daftar isi secara otomatis |
| T-05 | Kriteria MTK memakai alternatif, tetapi juga menyebut nilai di bawah 75% belum boleh pindah | Tentukan jalur keputusan, penyelesaian konflik hasil, dan evaluasi prosedur oleh tutor |
| T-06 | MTK belum memiliki bobot penilaian rinci atau instrumen tes penempatan siap pakai pada bagian kriteria | Tutor menyiapkan instrumen, denominator, rubrik dan aturan penggabungan hasil |
| T-07 | Petunjuk BId memakai istilah uji kompetensi sebelum dan setelah meminta uji kepada tutor | Pisahkan latihan mandiri dari uji formal; tentukan pengaturan kunci dan persetujuan pelaksanaan |
| T-08 | BId TAM menyediakan sekali lagi kesempatan mengulang; sumber tidak menetapkan nilai rekap atau tindak lanjut setelah gagal ulang | Jangan memilih nilai tertinggi/terakhir atau remedial tak terbatas secara otomatis |
| T-09 | Alokasi SKK per mapel/modul/program belum tersedia | PKBM menetapkan pembagian dan prosedur pengakuan, termasuk pencegahan penghitungan ganda |
| T-10 | Panduan khusus memuat Paket A/B/C | Filter Paket C; jangan memindahkan capaian jenjang lain ke rencana Paket C |
| T-11 | Belum ada silabus/modul lengkap mapel lain dan standar keterampilan pilihan lokal | Katalog tetap dapat diperluas; cakupan yang belum diberikan ditandai belum dipetakan |

## 8. Kontrak data untuk tahap berikutnya

Setiap sumber: ID, jenis, judul internal, nama/path asli, hash, versi/revisi jika diketahui, halaman dan cakupan.

Setiap kompetensi: ID internal, sumber, versi, tingkatan, mapel/muatan, kode asli, teks asli/ringkasan terpisah. Indikator terikat KD induk dan lokasi; normalisasi tidak menimpa sumber.

Setiap pemetaan: rancangan modul/program, unit/kegiatan, KD/indikator, sifat hubungan (landasan/selaras/perlu telaah), sumber halaman, keputusan tutor dan status telaah.

Setiap aturan: lingkup program/modul/unit/penilaian, jenis sumber/desain/kebijakan PKBM, threshold dan satuan, formula, jalur alternatif, prasyarat, percobaan, evaluator dan tanggal berlakunya. Nilai belum ditetapkan tetap null.

Setiap hasil: warga belajar, pelaksanaan, kegiatan, bukti/revisi, percobaan, penilai, aturan/rubrik versinya, skor/performa, umpan balik dan keputusan. Progres, skor, capaian, penyelesaian, SKK dan sertifikasi merupakan rekam berbeda.

Identitas contoh: `K13-PKC/MTK/V/KD-3.3` dan `K13-PKC/BID/V/KD-3.1`. Label K13-PKC merupakan alias katalog kerja, bukan nomor revisi resmi. Relasi banyak-ke-banyak memungkinkan satu KD dikuatkan beberapa modul dan modul terpadu dirancang kemudian.

## 9. Status tahap 1

- [x] Delapan sumber terdaftar beserta jenis, jumlah halaman fisik dan fingerprint.
- [x] Struktur program, kelompok muatan dan SKK pada kurikulum dicatat.
- [x] Tiga modul contoh dipetakan pada unit/KD/indikator yang relevan.
- [x] Aturan belajar/penilaian contoh dan muatan khusus memiliki rujukan halaman.
- [x] Perbedaan konsep, kode berulang dan aturan yang belum lengkap ditandai.
- [x] Bagian tabel/aturan yang menentukan pemetaan diperiksa melalui render: KUR-C PDF 6; SIL-MTK PDF 12; SIL-BID PDF 10; MTK1 PDF 4; BID1 PDF 21; PAN-KET PDF 8; PAN-PEM PDF 15.
- [x] Dasar pemetaan dan struktur database ditetapkan dari kurikulum, silabus serta panduan muatan khusus sesuai arahan pengguna.
- [ ] Pemeriksaan kecocokan kegiatan, instrumen dan bukti dilakukan pada pelaksanaan yang akan digunakan.
- [ ] Kebijakan lokal SKK, penggabungan nilai dan remedial ditetapkan.
- [ ] Katalog seluruh modul dan silabus semua mata pelajaran dipetakan.

**Tahap berikutnya:** gunakan `struktur-database-akademik-pkbm.md` untuk implementasi struktur akademik dari acuan. Katalog seluruh modul tidak menjadi prasyarat desain database. Selanjutnya siapkan satu pelaksanaan Matematika dan satu Bahasa Indonesia di Canvas berdasarkan pemetaan ini. Hubungan/aturan berstatus perlu telaah tetap membutuhkan keputusan sebelum diaktifkan sebagai dasar capaian otomatis. Muatan khusus memiliki kerangka sumber; program lokalnya belum dipilih.

## 10. Berkas pendamping

`pemetaan-sumber-dan-aturan-pkbm.json` menyimpan register delapan sumber, sepuluh hubungan modul dan 22 aturan dalam bentuk terstruktur. ID dokumen ini konsisten dengan JSON. JSON merupakan data rancangan, belum konfigurasi Canvas siap impor.
