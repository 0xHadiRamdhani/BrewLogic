# BrewLogic

**Seduh presisi, nikmati pelan.**

BrewLogic adalah aplikasi iOS dan Android untuk homebrewer kopi: menghitung takaran
dan suhu, memandu seduhan step-by-step dengan timer, lalu menyimpan resep, biji,
rating, dan catatan rasa dalam satu jurnal. Semua data tersimpan di perangkat
(offline, tanpa akun).

Versi saat ini: **1.1.0 (build 2)**.

## Fitur

- **Kalkulator seduh**: hitung air dan fase tuang dari gramasi kopi untuk V60,
  Aeropress, French Press, dan Chemex, dengan tiga tingkat roasting (Light, Medium,
  Dark). Rasio, suhu, dan durasi bisa disesuaikan. Semua air dalam ml.
- **Kalkulator terbalik**: masukkan jumlah air, aplikasi menghitung kopi yang
  dibutuhkan.
- **Timer step-by-step**: bloom dan tuang bertahap dalam cincin timer dengan
  animasi Lottie menuang kopi, suara dan haptic penanda fase, notifikasi saat
  aplikasi di latar belakang, dan layar tetap menyala selama menyeduh.
- **Brew journal**: catat setiap seduhan dengan rating biji kopi, tag rasa, foto,
  dan catatan. Dikelompokkan per hari (Hari ini, Kemarin), cari dan saring, geser
  untuk menghapus.
- **Mocktail**: mode "Mocktail" di tab Kalkulator untuk membuat minuman bersirup.
  Pilih bahan dasar (soda, tonic, ginger ale, air putih, air kelapa, teh dingin),
  sampai 3 sirup (preset atau buatan sendiri) dengan pembagian bagian, tingkat
  manis, teknik (langsung atau kocok), es, jeruk nipis, dan hiasan. Takaran per
  porsi dan total dihitung otomatis lengkap dengan langkah pembuatan. Tombol
  **Mulai Buat Mocktail** membuka timer seperti timer kopi: cincin ganda dengan
  gelas beranimasi (Lottie) di dalamnya yang terisi sendiri mengikuti langkah
  (es, sirup, jeruk nipis, aduk atau kocok, bahan dasar, hiasan), langkah pindah
  otomatis menurut durasi dengan bunyi dan getaran, tombol Mulai/Jeda/Reset,
  daftar langkah yang bisa dilompati, daftar bahan yang bisa dicentang, dan
  pengulangan per gelas bila lebih dari satu porsi. Warna sirup dan bahan dasar
  serta hiasan mengikuti resep.
- **Resep Saya**: simpan resep kopi maupun mocktail dalam satu daftar (ketuk untuk
  memuat, tahan untuk menghapus).
- **Perpustakaan biji** (termasuk kesegaran biji).
- **Dial-in**: saran penyesuaian seduhan, termasuk rasio air:kopi, berdasarkan kesan rasa.
- **Statistik seduhan** dan grafik rating.
- **Ekspor dan bagikan**: kartu bagikan (PNG), ekspor CSV, serta ekspor dan impor
  cadangan JSON (jurnal, resep kopi dan mocktail, serta biji).
- **Pengaturan**: ukuran teks (Kecil, Normal, Besar), suhu °C/°F, getaran haptic,
  suara pengingat, layar tetap menyala, dan notifikasi selesai.

## Desain

Tema "Soft Café": latar espresso, aksen karamel dan sage, kartu kaca, serta ikon
kustom untuk metode seduh dan tingkat roasting. Font **DM Sans** untuk teks isi dan
**Pixelify Sans** untuk judul dan angka besar (keduanya berlisensi OFL, dibundel di
`assets/fonts`). Animasi menuang kopi (`assets/animations/pour.json`) dibuat khusus
untuk aplikasi ini dan menghormati pengaturan "kurangi gerakan" sistem.

## Teknologi

| Bagian | Pilihan |
| --- | --- |
| Framework | Flutter 3.47, Dart 3.13 |
| Arsitektur | MVVM (`models`, `viewmodels`, `views`, `services`) |
| State | `provider` (ChangeNotifier sebagai ViewModel) |
| UI adaptif | `adaptive_platform_ui` (Cupertino di iOS, Material di Android) |
| Penyimpanan | `hive`, `hive_flutter`, `path_provider` |
| Animasi | `lottie` |
| Timer | `wakelock_plus`, `audioplayers`, `flutter_local_notifications`, `timezone` |
| Berbagi dan berkas | `share_plus`, `file_picker`, `image_picker`, `url_launcher` |

## Struktur proyek

```
lib/
  core/        tema, info aplikasi, navigasi, utilitas (formatters, haptics)
  models/      model seduhan dan adapter Hive
  services/    kalkulator seduh, timer, jurnal (Hive), statistik, ekspor, cadangan
  viewmodels/  ViewModel untuk kalkulator, jurnal, resep, biji, pengaturan
  views/       layar dan widget (glass card, kontrol, ikon, animasi menuang)
assets/
  animations/  pour.json (Lottie)
  fonts/       DM Sans dan Pixelify Sans
  images/      ikon aplikasi dan foto pengembang
  sounds/      penanda fase dan selesai
test/          tes unit dan widget
```

## Menjalankan

Prasyarat: Flutter SDK dengan Dart `^3.13.5`, Xcode (iOS), Android Studio atau
Android SDK (Android).

```bash
flutter pub get
flutter run
```

Pilih perangkat atau simulator saat diminta. Build debug:

```bash
flutter build apk --debug
flutter build ios --simulator --debug --no-codesign
```

## Kualitas kode

Proyek memakai analisis statis ketat (`analysis_options.yaml`).

```bash
flutter analyze
flutter test
```

## Pengembang

**Hadi Ramdhani**, Lead Developer & Mobile Expert Developer, Kota Bandung.

- GitHub: [0xHadiRamdhani](https://github.com/0xHadiRamdhani)
- Instagram: [@hadiramdhani.tsx](https://www.instagram.com/hadiramdhani.tsx)

## Lisensi

Font DM Sans dan Pixelify Sans berlisensi SIL Open Font License (lihat berkas OFL
di `assets/fonts`). Belum ada lisensi yang ditetapkan untuk kode aplikasi.
