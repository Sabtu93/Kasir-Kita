# Kasir Kita

## Menjalankan aplikasi

Hubungkan HP Android dengan USB debugging aktif, lalu jalankan dari folder proyek:

```bash
flutter pub get
flutter run
```

## Akun dan produk

- Pada penggunaan pertama, pilih **Daftar akun** untuk mengisi ID akun, kata sandi, nama toko, dan logo toko (opsional). ID akun harus 3–24 karakter; kata sandi minimal 8 karakter.
- Setelah masuk, pilih **Tambah** di bagian **Daftar Produk** untuk mengisi nama, kategori (bisa diketik sendiri), foto produk (opsional), HPP/harga modal, harga jual, dan stok.
- Gunakan menu **Laporan** untuk mengunduh file Excel `.xlsx` harian atau bulanan. Pilih tanggal pada bulan yang diinginkan untuk laporan bulanan. Laporan berisi omzet, HPP, laba kotor, dan rincian transaksi. Laba kotor dihitung dari omzet dikurangi HPP; transaksi yang belum memiliki data HPP ditandai agar laba tidak disalahartikan.
- Foto toko dan produk dipilih dari galeri perangkat; ukuran gambar dibatasi maksimal 512 KB.
- Akun serta katalog produk disimpan secara lokal di perangkat. Akun hanya bisa digunakan di HP yang sama; aplikasi belum tersambung ke server atau menyinkronkan data antarperangkat.
- Kata sandi disimpan sebagai hash, bukan teks biasa. Meski begitu, login lokal ini belum menggantikan sistem autentikasi server untuk penggunaan produksi.
