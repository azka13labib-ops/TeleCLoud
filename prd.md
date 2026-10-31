Product Requirements Document (PRD) - Personal Cloud Vault

1. Ringkasan Eksekutif
Proyek ini adalah pengembangan aplikasi penyimpanan awan (cloud storage) pribadi berbasis mobile yang mengadaptasi fungsionalitas TeraBox. Sistem ini dirancang untuk memangkas biaya langganan peladen (server) dengan memanfaatkan infrastruktur Telegram sebagai media penyimpanan file tak terbatas, dikombinasikan dengan Firebase untuk manajemen metadata dan autentikasi secara real-time.

1. Tujuan & Sasaran Utama

Bypass Batasan Sistem: Menggunakan protokol MTProto/TDLib sebagai klien (client) untuk melewati batas unggah 50MB pada Bot API standar, memungkinkan unggahan file hingga 2GB per file.

Pengalaman Pengguna Tanpa Batas: Memberikan pengalaman navigasi hierarki folder yang instan dan mulus menggunakan arsitektur offline-first.

Keamanan & Privasi Pribadi: Memastikan seluruh file hanya tersimpan di dalam Private Channel Telegram milik pengguna dan metadata hanya dapat diakses oleh user terautentikasi melalui security rules Firestore.

3. Tumpukan Teknologi (Tech Stack)

Frontend: Flutter (Dart) untuk lintas platform (mobile).

Storage Engine: Telegram MTProto API via TDLib.

Metadata & Database: Firebase (Firestore) dengan struktur NoSQL flat-collection.

Autentikasi: Firebase Auth (Email/Password atau Google) ditambah Telegram OTP Auth untuk sesi TDLib.

Local Caching: SQLite atau Isar.

Background Processing: Flutter Workmanager / Background Downloader untuk unggah/unduh file berukuran besar.

4. Spesifikasi Fitur Utama

F-01: Autentikasi Ganda

Pengguna harus login ke Firebase untuk mengakses sinkronisasi metadata.

Pengguna harus memasukkan nomor HP dan OTP Telegram untuk menginisialisasi sesi klien TDLib (hanya dilakukan satu kali saat setup awal).

F-02: Sistem Direktori Berjenjang

Pembuatan folder dan sub-folder root/parent.

Visualisasi hierarki direktori secara dinamis berdasarkan folder_id dan parent_id dari Firestore.

F-03: Manajemen File (Upload/Download)

Pengunggahan file ke Telegram Private Channel secara asinkron (background).

Penyimpanan metadata (telegram_file_id, ukuran, tipe mime, relasi folder) ke Firestore segera setelah unggahan Telegram berhasil.

Pengunduhan file menggunakan telegram_file_id dengan indikator progres (progress bar).

F-04: Offline-First Read

Struktur direktori dan daftar file disinkronisasi ke basis data lokal perangkat, sehingga pengguna dapat melihat isi cloud tanpa koneksi internet.

5. Panduan UI/UX (Desain Visual)

Tema Utama: Mode gelap (Dark Mode) dengan aksen Cyan.

Gaya Desain: Glassmorphism modern. Penggunaan backdrop blur, lapisan semi-transparan, dan garis tepi (border) putih yang sangat tipis dan halus.

Ikonografi: Estetika minimal line-art doodle.

Batasan Ketat (Strict Anti-Pattern): Dilarang keras menggunakan elemen desain Neobrutalism (tidak ada bayangan solid yang keras, bentuk balok kasar, atau garis tepi hitam tebal).

6. Arsitektur Data (Firestore Skema)

Collection: folders

Atribut: id, name, parent_id (null untuk root), user_id, created_at.

Collection: files

Atribut: id, filename, telegram_file_id, size, mime_type, folder_id, user_id, uploaded_at.