# Aturan proyek PKBM–Canvas

- Kerjakan satu tahap roadmap dengan bukti dan status pada docs/catatan-implementasi.md.
- Acuan akademik: kurikulum, silabus, panduan pemberdayaan/keterampilan. Modul adalah bahan pelaksanaan.
- Canvas dan PKBM memakai database/user terpisah. Integrasi API/LTI; jangan menulis langsung tabel Canvas dari pendamping.
- Istilah antarmuka: pengelola PKBM, tutor, warga belajar.
- Pertahankan data proyek lain. Jangan prune, down -v, memindahkan Docker root, atau deploy tanpa permintaan yang sesuai.
- Jangan commit .env, konfigurasi rahasia, data unggahan, token atau kredensial.
- Versi Canvas dikunci di infra/runtime-selection.json; jangan mengganti dengan master tanpa alasan tercatat.
- Jangan menjalankan tests/validasi aplikasi tanpa permintaan pengguna. Laporkan tingkat bukti aktual; konfigurasi bukan runtime.
- Jangan membuat subagen kecuali diminta pengguna.
