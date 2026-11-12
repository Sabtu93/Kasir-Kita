# Kasir Kita

## Menjalankan aplikasi

Hubungkan HP Android dengan USB debugging aktif, lalu jalankan dari folder proyek:

```bash
flutter pub get
flutter run
```

## Akun dan produk

- Pada penggunaan pertama, pilih **Daftar akun**. ID akun harus 3–24 karakter; kata sandi minimal 8 karakter.
- Setelah masuk, pilih **Tambah** di bagian **Daftar Produk** untuk mengisi nama, kategori, HPP/harga modal, harga jual, dan stok.
- Akun serta katalog produk disimpan secara lokal di perangkat. Akun hanya bisa digunakan di HP yang sama; aplikasi belum tersambung ke server atau menyinkronkan data antarperangkat.
- Kata sandi disimpan sebagai hash, bukan teks biasa. Meski begitu, login lokal ini belum menggantikan sistem autentikasi server untuk penggunaan produksi.
