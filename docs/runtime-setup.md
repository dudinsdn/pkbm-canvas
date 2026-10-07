# Setup runtime lokal

Lihat catatan implementasi untuk tahap yang sudah dilakukan. Perintah di bawah adalah urutan operasi; bukan bukti semua operasi sudah berhasil.

Jalankan `./scripts/canvas-prepare` setelah checkout source untuk direktori hasil build, kompilasi berurutan, dan pemuatan task sesuai BUNDLE_WITHOUT.

1. `./scripts/compose build web` membangun image dasar web/jobs.
2. `./scripts/local canvas-gems` memasang gems dengan satu job, tanpa grup test.
3. `./scripts/local canvas-node` memasang paket JS menggunakan lockfile.
4. `./scripts/compose pull redis` mengunduh image pada digest terpilih; lalu `./scripts/compose up -d --no-build --pull never postgres redis`.
5. `./scripts/local canvas-init` menjalankan migrasi serta inisialisasi akun default/admin. Jangan mengulang init untuk mengganti akun/password.
6. `./scripts/local canvas-assets` mengompilasi aset development dengan satu proses dan heap Node maksimal 2 GiB. Tidak menjalankan watcher.
7. `./scripts/compose run -T --no-deps --rm web bundle exec rails runner - < scripts/canvas-demo.rb` menyiapkan tutor/WB dan course orientasi simulasi.
8. `./scripts/compose up -d --no-build --pull never web jobs` menyalakan web dan worker.

Canvas di http://127.0.0.1:8081. Port internal web 3000 dengan Rails/Puma, thread mengikuti konfigurasi Canvas. PostgreSQL/Redis tidak dipublikasikan ke host. RAM dan disk dipantau sebelum langkah besar; disk gate bukan jaminan cukup untuk seluruh build.

Login lokal memakai email admin@pkbm.local, tutor@pkbm.local, wb@pkbm.local. Password ada pada .env berizin 0600; jangan salin .env ke dokumentasi/commit. Akun tutor/WB baru ada setelah langkah 7 berhasil.

Email memakai delivery_method test, yaitu penampung pesan lokal Rails; tidak mengirim email eksternal. Ini konfigurasi runtime, bukan pelaksanaan suite test. Kursus orientasi tidak berisi nilai/capaian akademik atau pengakuan SKK.

Image/jobs memakai konfigurasi versi yang sama; data/dependensi terletak pada var/ dan vendor/. Stop mempertahankan penyimpanan. Jangan menghapus volume/direktori untuk mengatasi kegagalan setup.

API katalog pendamping memakai image web yang sama dengan gems dan konfigurasi terpisah. Setelah image tersedia, `./scripts/local pkbm-install` lalu `./scripts/local catalog-start` menyalakan API pada 127.0.0.1:3000. Canvas dan PKBM memakai database dan user berbeda.

Pada database development, init PostgreSQL juga menyediakan role canvas_readonly_user NOLOGIN agar migrasi upstream dapat memberi hak baca tanpa memberikan CREATEROLE kepada user Canvas. Untuk data yang sudah dibuat sebelum perubahan ini, role tersebut telah disiapkan administrator lokal pada 7 Oktober 2026.
