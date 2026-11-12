import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MinimarketApp());
}

const _green = Color(0xFF176B4D);
const _dark = Color(0xFF18352B);
const _muted = Color(0xFF75827C);
const _canvas = Color(0xFFF6F8F5);

class MinimarketApp extends StatefulWidget {
  const MinimarketApp({super.key});

  @override
  State<MinimarketApp> createState() => _MinimarketAppState();
}

class _MinimarketAppState extends State<MinimarketApp> {
  static const _accountsKey = 'kasir_kita_accounts_v1';
  static const _productsKey = 'kasir_kita_products_v1';
  static const _salesKey = 'kasir_kita_sales_v1';

  SharedPreferences? _preferences;
  List<_LocalAccount> _accounts = [];
  List<Product> _catalog = List.of(_products);
  List<SaleRecord> _sales = [];
  String? _activeUser;
  Object? _loadError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      final storedAccounts = preferences.getString(_accountsKey);
      final storedProducts = preferences.getString(_productsKey);
      final storedSales = preferences.getString(_salesKey);
      final accounts = storedAccounts == null
          ? <_LocalAccount>[]
          : (jsonDecode(storedAccounts) as List<dynamic>)
                .map(
                  (entry) => _LocalAccount.fromMap(
                    Map<String, dynamic>.from(entry as Map),
                  ),
                )
                .toList();
      final products = storedProducts == null
          ? List<Product>.of(_products)
          : (jsonDecode(storedProducts) as List<dynamic>)
                .map(
                  (entry) =>
                      Product.fromMap(Map<String, dynamic>.from(entry as Map)),
                )
                .toList();
      final sales = storedSales == null
          ? <SaleRecord>[]
          : (jsonDecode(storedSales) as List<dynamic>)
                .map(
                  (entry) => SaleRecord.fromMap(
                    Map<String, dynamic>.from(entry as Map),
                  ),
                )
                .toList();
      if (!mounted) return;
      setState(() {
        _preferences = preferences;
        _accounts = accounts;
        _catalog = products;
        _sales = sales;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<String?> _login(String id, String password) async {
    final normalizedId = id.trim().toLowerCase();
    _LocalAccount? account;
    for (final entry in _accounts) {
      if (entry.id.toLowerCase() == normalizedId) {
        account = entry;
        break;
      }
    }
    final matchedAccount = account;
    if (matchedAccount == null) return 'ID atau kata sandi salah.';
    final passwordHash = await _hashPassword(password, matchedAccount.salt);
    if (!_constantTimeEquals(passwordHash, matchedAccount.passwordHash)) {
      return 'ID atau kata sandi salah.';
    }
    if (mounted) setState(() => _activeUser = matchedAccount.id);
    return null;
  }

  Future<String?> _register(String id, String password) async {
    final normalizedId = id.trim();
    if (_accounts.any(
      (account) => account.id.toLowerCase() == normalizedId.toLowerCase(),
    )) {
      return 'ID tersebut sudah terdaftar.';
    }
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final account = _LocalAccount(
      id: normalizedId,
      salt: _toHex(salt),
      passwordHash: await _hashPassword(password, _toHex(salt)),
    );
    final updatedAccounts = [..._accounts, account];
    final saved = await _preferences!.setString(
      _accountsKey,
      jsonEncode(updatedAccounts.map((entry) => entry.toMap()).toList()),
    );
    if (!saved) throw StateError('Akun tidak berhasil disimpan di perangkat.');
    if (mounted) {
      setState(() {
        _accounts = updatedAccounts;
        _activeUser = account.id;
      });
    }
    return null;
  }

  Future<void> _addProduct(Product product) async {
    final updatedCatalog = [..._catalog, product];
    final saved = await _preferences!.setString(
      _productsKey,
      jsonEncode(updatedCatalog.map((entry) => entry.toMap()).toList()),
    );
    if (!saved) {
      throw StateError('Produk tidak berhasil disimpan di perangkat.');
    }
    if (mounted) setState(() => _catalog = updatedCatalog);
  }

  Future<void> _addSale(SaleRecord sale) async {
    final updatedSales = [..._sales, sale];
    final saved = await _preferences!.setString(
      _salesKey,
      jsonEncode(updatedSales.map((entry) => entry.toMap()).toList()),
    );
    if (!saved) throw StateError('Transaksi tidak berhasil disimpan.');
    if (mounted) setState(() => _sales = updatedSales);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kasir Kita',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _canvas,
        colorScheme: ColorScheme.fromSeed(seedColor: _green),
        fontFamily: 'Roboto',
      ),
      home: _loading
          ? const _LoadingPage()
          : _loadError != null
          ? _LoadErrorPage(error: _loadError!, onRetry: _loadData)
          : _activeUser == null
          ? LoginPage(
              accountIds: _accounts.map((account) => account.id).toList(),
              onLogin: _login,
              onRegister: _register,
            )
          : CashierPage(
              userId: _activeUser!,
              products: _catalog,
              sales: _sales,
              onAddProduct: _addProduct,
              onCompleteSale: _addSale,
              onLogout: () => setState(() => _activeUser = null),
            ),
    );
  }
}

class Product {
  const Product({
    required this.name,
    required this.category,
    this.hpp,
    required this.price,
    required this.icon,
    required this.color,
    required this.stock,
  });

  final String name;
  final String category;
  final int? hpp;
  final int price;
  final IconData icon;
  final Color color;
  final int stock;

  Map<String, Object?> toMap() => {
    'name': name,
    'category': category,
    'hpp': hpp,
    'price': price,
    'stock': stock,
  };

  factory Product.fromMap(Map<String, dynamic> map) {
    final category = map['category'] as String;
    return Product(
      name: map['name'] as String,
      category: category,
      hpp: map['hpp'] as int?,
      price: map['price'] as int,
      icon: _categoryIcon(category),
      color: _categoryColor(category),
      stock: map['stock'] as int,
    );
  }
}

class SaleLine {
  const SaleLine({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final String productName;
  final int quantity;
  final int unitPrice;

  int get total => quantity * unitPrice;

  Map<String, Object?> toMap() => {
    'productName': productName,
    'quantity': quantity,
    'unitPrice': unitPrice,
  };

  factory SaleLine.fromMap(Map<String, dynamic> map) => SaleLine(
    productName: map['productName'] as String,
    quantity: map['quantity'] as int,
    unitPrice: map['unitPrice'] as int,
  );
}

class SaleRecord {
  const SaleRecord({
    required this.receiptNumber,
    required this.soldAt,
    required this.items,
    required this.total,
    required this.cashReceived,
  });

  final String receiptNumber;
  final DateTime soldAt;
  final List<SaleLine> items;
  final int total;
  final int cashReceived;

  int get change => cashReceived - total;

  Map<String, Object?> toMap() => {
    'receiptNumber': receiptNumber,
    'soldAt': soldAt.toIso8601String(),
    'items': items.map((item) => item.toMap()).toList(),
    'total': total,
    'cashReceived': cashReceived,
  };

  factory SaleRecord.fromMap(Map<String, dynamic> map) => SaleRecord(
    receiptNumber: map['receiptNumber'] as String,
    soldAt: DateTime.parse(map['soldAt'] as String),
    items: (map['items'] as List<dynamic>)
        .map((item) => SaleLine.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList(),
    total: map['total'] as int,
    cashReceived: map['cashReceived'] as int,
  );
}

String generateDailySalesCsv(List<SaleRecord> sales, DateTime date) {
  final dailySales =
      sales
          .where(
            (sale) =>
                sale.soldAt.year == date.year &&
                sale.soldAt.month == date.month &&
                sale.soldAt.day == date.day,
          )
          .toList()
        ..sort((a, b) => a.soldAt.compareTo(b.soldAt));
  final rows = <List<String>>[
    [
      'Tanggal',
      'Waktu',
      'No Transaksi',
      'Produk',
      'Jumlah',
      'Harga Satuan',
      'Total Item',
      'Total Transaksi',
      'Tunai Diterima',
      'Kembalian',
    ],
  ];

  for (final sale in dailySales) {
    final dateText =
        '${sale.soldAt.day.toString().padLeft(2, '0')}/${sale.soldAt.month.toString().padLeft(2, '0')}/${sale.soldAt.year}';
    final timeText =
        '${sale.soldAt.hour.toString().padLeft(2, '0')}:${sale.soldAt.minute.toString().padLeft(2, '0')}:${sale.soldAt.second.toString().padLeft(2, '0')}';
    final items = sale.items.isEmpty ? <SaleLine?>[null] : sale.items;
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      rows.add([
        dateText,
        timeText,
        sale.receiptNumber,
        item?.productName ?? '',
        item?.quantity.toString() ?? '',
        item?.unitPrice.toString() ?? '',
        item?.total.toString() ?? '',
        index == 0 ? sale.total.toString() : '',
        index == 0 ? sale.cashReceived.toString() : '',
        index == 0 ? sale.change.toString() : '',
      ]);
    }
  }

  final dailyRevenue = dailySales.fold<int>(0, (sum, sale) => sum + sale.total);
  rows.add([
    '',
    '',
    '',
    'TOTAL HARIAN (${dailySales.length} transaksi)',
    '',
    '',
    '',
    dailyRevenue.toString(),
    '',
    '',
  ]);
  return rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
}

String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

const _productCategories = ['Sembako', 'Makanan', 'Minuman', 'Kebutuhan'];

IconData _categoryIcon(String category) => switch (category) {
  'Sembako' => Icons.rice_bowl_rounded,
  'Makanan' => Icons.bakery_dining_rounded,
  'Minuman' => Icons.local_drink_rounded,
  'Kebutuhan' => Icons.soap_rounded,
  _ => Icons.inventory_2_rounded,
};

Color _categoryColor(String category) => switch (category) {
  'Sembako' => const Color(0xFFEDE5D2),
  'Makanan' => const Color(0xFFF2DFCE),
  'Minuman' => const Color(0xFFE9DDF0),
  'Kebutuhan' => const Color(0xFFDDF0E8),
  _ => const Color(0xFFE8ECE8),
};

class _LocalAccount {
  const _LocalAccount({
    required this.id,
    required this.salt,
    required this.passwordHash,
  });

  final String id;
  final String salt;
  final String passwordHash;

  Map<String, String> toMap() => {
    'id': id,
    'salt': salt,
    'passwordHash': passwordHash,
  };

  factory _LocalAccount.fromMap(Map<String, dynamic> map) => _LocalAccount(
    id: map['id'] as String,
    salt: map['salt'] as String,
    passwordHash: map['passwordHash'] as String,
  );
}

Future<String> _hashPassword(String password, String salt) async {
  final algorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 120000,
    bits: 256,
  );
  final key = await algorithm.deriveKey(
    secretKey: SecretKey(utf8.encode(password)),
    nonce: _fromHex(salt),
  );
  return _toHex(await key.extractBytes());
}

bool _constantTimeEquals(String first, String second) {
  if (first.length != second.length) return false;
  var difference = 0;
  for (var index = 0; index < first.length; index++) {
    difference |= first.codeUnitAt(index) ^ second.codeUnitAt(index);
  }
  return difference == 0;
}

String _toHex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

List<int> _fromHex(String value) => [
  for (var index = 0; index < value.length; index += 2)
    int.parse(value.substring(index, index + 2), radix: 16),
];

const _products = [
  Product(
    name: 'Beras Setra Ramos 5kg',
    category: 'Sembako',
    price: 72500,
    icon: Icons.rice_bowl_rounded,
    color: Color(0xFFEDE5D2),
    stock: 18,
  ),
  Product(
    name: 'Minyak Goreng 1L',
    category: 'Sembako',
    price: 18500,
    icon: Icons.oil_barrel_rounded,
    color: Color(0xFFFFE8B4),
    stock: 24,
  ),
  Product(
    name: 'Susu UHT Cokelat',
    category: 'Minuman',
    price: 7500,
    icon: Icons.local_drink_rounded,
    color: Color(0xFFE9DDF0),
    stock: 32,
  ),
  Product(
    name: 'Roti Tawar Gandum',
    category: 'Makanan',
    price: 16000,
    icon: Icons.bakery_dining_rounded,
    color: Color(0xFFF2DFCE),
    stock: 12,
  ),
  Product(
    name: 'Mi Instan Goreng',
    category: 'Makanan',
    price: 3500,
    icon: Icons.ramen_dining_rounded,
    color: Color(0xFFFFE6C9),
    stock: 46,
  ),
  Product(
    name: 'Air Mineral 600ml',
    category: 'Minuman',
    price: 4000,
    icon: Icons.water_drop_rounded,
    color: Color(0xFFDCEEFF),
    stock: 40,
  ),
  Product(
    name: 'Telur Ayam 1kg',
    category: 'Sembako',
    price: 29000,
    icon: Icons.egg_alt_rounded,
    color: Color(0xFFFFF0D8),
    stock: 15,
  ),
  Product(
    name: 'Sabun Mandi',
    category: 'Kebutuhan',
    price: 5500,
    icon: Icons.soap_rounded,
    color: Color(0xFFDDF0E8),
    stock: 28,
  ),
  Product(
    name: 'Kopi Susu Kaleng',
    category: 'Minuman',
    price: 9000,
    icon: Icons.coffee_rounded,
    color: Color(0xFFE8DFD7),
    stock: 21,
  ),
  Product(
    name: 'Pisang Cavendish',
    category: 'Makanan',
    price: 12000,
    icon: Icons.eco_rounded,
    color: Color(0xFFF4EDC5),
    stock: 10,
  ),
];

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator(color: _green)),
  );
}

class _LoadErrorPage extends StatelessWidget {
  const _LoadErrorPage({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 42,
            ),
            const SizedBox(height: 12),
            const Text(
              'Data aplikasi tidak bisa dibuka.',
              style: TextStyle(color: _dark, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    ),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.accountIds,
    required this.onLogin,
    required this.onRegister,
    super.key,
  });

  final List<String> accountIds;
  final Future<String?> Function(String id, String password) onLogin;
  final Future<String?> Function(String id, String password) onRegister;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String? _error;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  String? _validateId(String? value) {
    final id = value?.trim() ?? '';
    if (id.length < 3 || id.length > 24) {
      return 'ID harus terdiri dari 3–24 karakter.';
    }
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(id)) {
      return 'Gunakan huruf, angka, titik, garis bawah, atau strip.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final error = _registering
          ? await widget.onRegister(
              _idController.text.trim(),
              _passwordController.text,
            )
          : await widget.onLogin(
              _idController.text.trim(),
              _passwordController.text,
            );
      if (mounted) setState(() => _error = error);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Tidak dapat menyimpan data: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _switchMode(bool registering) {
    setState(() {
      _registering = registering;
      _error = null;
      _obscurePassword = true;
      _obscureConfirmation = true;
      _passwordController.clear();
      _confirmationController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Container(
                  height: 310,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF104B38), _green, Color(0xFF368A65)],
                    ),
                  ),
                ),
                Expanded(child: Container(color: _canvas)),
              ],
            ),
          ),
          Positioned(
            top: -72,
            right: -48,
            child: IgnorePointer(
              child: Container(
                height: 220,
                width: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .08),
                    width: 34,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 30, 22, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 26),
                        child: Row(
                          children: [
                            Container(
                              height: 54,
                              width: 54,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .16),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: .22),
                                ),
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kasir Kita',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -.3,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'TEMAN USAHA ANDA',
                                  style: TextStyle(
                                    color: Color(0xFFD4E9DD),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Card(
                        color: Colors.white,
                        elevation: 14,
                        shadowColor: const Color(0x3318352B),
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                          side: const BorderSide(color: Color(0xFFE8ECE8)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _registering
                                      ? 'Mulai bersama kami'
                                      : 'Selamat datang 👋',
                                  style: const TextStyle(
                                    color: _dark,
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _registering
                                      ? 'Buat akun kasir untuk mengelola tokomu.'
                                      : 'Masuk untuk mulai mengelola tokomu.',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                TextFormField(
                                  key: const ValueKey('account-id'),
                                  controller: _idController,
                                  validator: _validateId,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  decoration: _authDecoration('ID akun')
                                      .copyWith(
                                        prefixIcon: const Icon(
                                          Icons.person_outline_rounded,
                                          size: 20,
                                        ),
                                      ),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  key: const ValueKey('account-password'),
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: _registering
                                      ? TextInputAction.next
                                      : TextInputAction.done,
                                  validator: (value) {
                                    final password = value ?? '';
                                    if (_registering && password.length < 8) {
                                      return 'Kata sandi minimal 8 karakter.';
                                    }
                                    if (password.isEmpty) {
                                      return 'Kata sandi wajib diisi.';
                                    }
                                    return null;
                                  },
                                  decoration: _authDecoration('Kata sandi')
                                      .copyWith(
                                        prefixIcon: const Icon(
                                          Icons.lock_outline_rounded,
                                          size: 20,
                                        ),
                                        suffixIcon: IconButton(
                                          tooltip: _obscurePassword
                                              ? 'Tampilkan kata sandi'
                                              : 'Sembunyikan kata sandi',
                                          onPressed: () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                ),
                                if (_registering) ...[
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    key: const ValueKey(
                                      'account-confirm-password',
                                    ),
                                    controller: _confirmationController,
                                    obscureText: _obscureConfirmation,
                                    textInputAction: TextInputAction.done,
                                    validator: (value) =>
                                        value != _passwordController.text
                                        ? 'Konfirmasi kata sandi tidak sama.'
                                        : null,
                                    decoration:
                                        _authDecoration(
                                          'Ulangi kata sandi',
                                        ).copyWith(
                                          prefixIcon: const Icon(
                                            Icons.verified_user_outlined,
                                            size: 20,
                                          ),
                                          suffixIcon: IconButton(
                                            tooltip: _obscureConfirmation
                                                ? 'Tampilkan kata sandi'
                                                : 'Sembunyikan kata sandi',
                                            onPressed: () => setState(
                                              () => _obscureConfirmation =
                                                  !_obscureConfirmation,
                                            ),
                                            icon: Icon(
                                              _obscureConfirmation
                                                  ? Icons.visibility_outlined
                                                  : Icons
                                                        .visibility_off_outlined,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                  ),
                                ],
                                if (!_registering &&
                                    widget.accountIds.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  const Text(
                                    'AKUN TERDAFTAR',
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: .9,
                                    ),
                                  ),
                                  const SizedBox(height: 9),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: widget.accountIds
                                        .map(
                                          (id) => ActionChip(
                                            avatar: const Icon(
                                              Icons.person_rounded,
                                              size: 15,
                                            ),
                                            label: Text(id),
                                            onPressed: () {
                                              _idController.text = id;
                                              setState(() => _error = null);
                                            },
                                            backgroundColor: const Color(
                                              0xFFEAF4EE,
                                            ),
                                            side: BorderSide.none,
                                            labelStyle: const TextStyle(
                                              color: _green,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                                if (_error != null) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    key: const ValueKey('auth-error'),
                                    padding: const EdgeInsets.all(11),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF0EF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _error!,
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 22),
                                SizedBox(
                                  height: 52,
                                  child: FilledButton(
                                    onPressed: _busy ? null : _submit,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _green,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _busy
                                        ? const SizedBox(
                                            height: 19,
                                            width: 19,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                _registering
                                                    ? 'Buat akun'
                                                    : 'Masuk',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _switchMode(!_registering),
                                  child: Text(
                                    _registering
                                        ? 'Sudah punya akun? Masuk'
                                        : 'Belum punya akun? Daftar akun',
                                    style: const TextStyle(
                                      color: _green,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.phone_android_rounded,
                                      size: 14,
                                      color: _muted,
                                    ),
                                    SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Data akun dan produk tersimpan di perangkat ini.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: _muted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Sederhanakan transaksi, fokus kembangkan usaha.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _authDecoration(String label) => InputDecoration(
  labelText: label,
  filled: true,
  fillColor: _canvas,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Color(0xFFE8ECE8)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Color(0xFFE8ECE8)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: _green, width: 1.5),
  ),
);

class CashierPage extends StatefulWidget {
  const CashierPage({
    required this.userId,
    required this.products,
    required this.sales,
    required this.onAddProduct,
    required this.onCompleteSale,
    required this.onLogout,
    super.key,
  });

  final String userId;
  final List<Product> products;
  final List<SaleRecord> sales;
  final Future<void> Function(Product product) onAddProduct;
  final Future<void> Function(SaleRecord sale) onCompleteSale;
  final VoidCallback onLogout;

  @override
  State<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage> {
  final _searchController = TextEditingController();
  final Map<Product, int> _cart = {};
  String _category = 'Semua';
  String _query = '';
  int _transactionNumber = 1;
  bool _storeOpen = false;
  int _openingCash = 0;
  int _revenue = 0;
  int _completedTransactions = 0;

  List<String> get _categories => [
    'Semua',
    ...{
      ..._productCategories,
      for (final product in widget.products) product.category,
    },
  ];

  int get _itemCount => _cart.values.fold(0, (sum, quantity) => sum + quantity);

  int get _subtotal => _cart.entries.fold(
    0,
    (sum, entry) => sum + entry.key.price * entry.value,
  );

  List<Product> get _visibleProducts => widget.products.where((product) {
    final matchesCategory =
        _category == 'Semua' || product.category == _category;
    final matchesQuery = product.name.toLowerCase().contains(
      _query.toLowerCase(),
    );
    return matchesCategory && matchesQuery;
  }).toList();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _transactionNumber = widget.sales.length + 1;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openStore());
  }

  Future<void> _openStore() async {
    while (mounted && !_storeOpen) {
      final openingCash = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const _OpeningCashDialog(),
      );
      if (!mounted) return;
      if (openingCash == null) continue;
      setState(() {
        _openingCash = openingCash;
        _storeOpen = true;
      });
    }
  }

  void _addProduct(Product product) {
    setState(
      () =>
          _cart.update(product, (quantity) => quantity + 1, ifAbsent: () => 1),
    );
  }

  void _changeQuantity(Product product, int amount) {
    setState(() {
      final quantity = (_cart[product] ?? 0) + amount;
      if (quantity <= 0) {
        _cart.remove(product);
      } else {
        _cart[product] = quantity;
      }
    });
  }

  Future<void> _showAddProductDialog() async {
    final product = await showDialog<Product>(
      context: context,
      builder: (context) => const AddProductDialog(),
    );
    if (!mounted || product == null) return;
    try {
      await widget.onAddProduct(product);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Produk berhasil ditambahkan.'),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
            content: Text('Produk tidak dapat disimpan: $error'),
          ),
        );
    }
  }

  String _rupiah(int amount) {
    final digits = amount.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[index]);
    }
    return 'Rp$buffer';
  }

  Future<void> _checkout() async {
    if (!_storeOpen || _cart.isEmpty) return;
    final total = _subtotal;
    final paid = await showDialog<int>(
      context: context,
      builder: (context) => PaymentDialog(
        total: total,
        availableCash: _openingCash + _revenue,
        formatRupiah: _rupiah,
      ),
    );
    if (!mounted || paid == null) return;
    final receiptNumber = _transactionNumber;
    final sale = SaleRecord(
      receiptNumber: receiptNumber.toString().padLeft(4, '0'),
      soldAt: DateTime.now(),
      items: _cart.entries
          .map(
            (entry) => SaleLine(
              productName: entry.key.name,
              quantity: entry.value,
              unitPrice: entry.key.price,
            ),
          )
          .toList(),
      total: total,
      cashReceived: paid,
    );
    try {
      await widget.onCompleteSale(sale);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
            content: Text('Transaksi tidak dapat disimpan: $error'),
          ),
        );
      return;
    }
    if (!mounted) return;
    setState(() {
      _transactionNumber++;
      _revenue += total;
      _completedTransactions++;
      _cart.clear();
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _dark,
          content: Text(
            'Transaksi #${receiptNumber.toString().padLeft(4, '0')} berhasil. Kembalian ${_rupiah(paid - total)}',
          ),
        ),
      );
  }

  Future<void> _downloadDailyReport() async {
    final now = DateTime.now();
    final dailySales =
        widget.sales
            .where(
              (sale) =>
                  sale.soldAt.year == now.year &&
                  sale.soldAt.month == now.month &&
                  sale.soldAt.day == now.day,
            )
            .toList()
          ..sort((a, b) => a.soldAt.compareTo(b.soldAt));
    final date = _dateStamp(now);
    final csv = generateDailySalesCsv(dailySales, now);
    try {
      final bytes = Uint8List.fromList(utf8.encode('\uFEFF$csv'));
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await FileSaver.instance.saveAs(
          name: 'laporan_penjualan_$date',
          bytes: bytes,
          fileExtension: 'csv',
          mimeType: MimeType.csv,
        );
      } else {
        await FileSaver.instance.saveToDownloads(
          name: 'laporan_penjualan_$date',
          bytes: bytes,
          fileExtension: 'csv',
          mimeType: MimeType.csv,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Laporan ${dailySales.length} transaksi tersimpan di folder Unduhan.',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
            content: Text('Laporan tidak dapat diunduh: $error'),
          ),
        );
    }
  }

  String _dateStamp(DateTime date) =>
      '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

  Future<void> _closeStore() async {
    if (!_storeOpen) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _StoreClosingDialog(
        openingCash: _openingCash,
        revenue: _revenue,
        transactionCount: _completedTransactions,
        uncompletedItemCount: _itemCount,
        formatRupiah: _rupiah,
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _storeOpen = false;
      _cart.clear();
    });
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(wide),
                Expanded(
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _buildCatalog(wide: true)),
                            Container(width: 1, color: const Color(0xFFE8ECE8)),
                            SizedBox(width: 360, child: _buildCart()),
                          ],
                        )
                      : _buildCatalog(wide: false),
                ),
                if (!wide) _buildMobileCartBar(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool wide) {
    final now = DateTime.now();
    final date =
        '${now.day.toString().padLeft(2, '0')} ${_monthName(now.month)} ${now.year}';
    return Container(
      padding: EdgeInsets.fromLTRB(wide ? 30 : 20, 18, wide ? 30 : 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECE8))),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kasir Kita',
                style: TextStyle(
                  color: _dark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'MINIMARKET • KASIR 01',
                style: TextStyle(
                  color: _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (wide)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _canvas,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 15,
                    color: _muted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    date,
                    style: const TextStyle(
                      color: _dark,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              widget.userId,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _green,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (wide)
            TextButton.icon(
              onPressed: _downloadDailyReport,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Laporan harian'),
              style: TextButton.styleFrom(foregroundColor: _green),
            )
          else
            IconButton(
              tooltip: 'Unduh laporan harian',
              onPressed: _downloadDailyReport,
              icon: const Icon(Icons.download_rounded, color: _green, size: 20),
            ),
          if (wide)
            TextButton.icon(
              onPressed: _closeStore,
              icon: const Icon(Icons.store_rounded, size: 18),
              label: const Text('Tutup toko'),
              style: TextButton.styleFrom(foregroundColor: _green),
            )
          else
            IconButton(
              tooltip: 'Tutup toko',
              onPressed: _closeStore,
              icon: const Icon(Icons.store_rounded, color: _green, size: 20),
            ),
        ],
      ),
    );
  }

  String _monthName(int month) => const [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ][month - 1];

  Widget _buildCatalog({required bool wide}) {
    final horizontalPadding = wide ? 30.0 : 20.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            22,
            horizontalPadding,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selamat ${_greeting()}, Kasir 👋',
                      style: const TextStyle(
                        color: _dark,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pilih produk untuk memulai transaksi',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (wide) _transactionBadge(),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            18,
            horizontalPadding,
            0,
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: InputDecoration(
              hintText: 'Cari nama produk...',
              hintStyle: const TextStyle(color: _muted, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: _muted),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus pencarian',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded, size: 19),
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE8ECE8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE8ECE8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _green, width: 1.5),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 58,
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              14,
              horizontalPadding,
              8,
            ),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = _categories[index];
              final selected = category == _category;
              return ChoiceChip(
                label: Text(category),
                selected: selected,
                onSelected: (_) => setState(() => _category = category),
                showCheckmark: false,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                backgroundColor: Colors.white,
                selectedColor: _green,
                side: BorderSide(
                  color: selected ? _green : const Color(0xFFE8ECE8),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            4,
            horizontalPadding,
            12,
          ),
          child: Row(
            children: [
              const Text(
                'Daftar Produk',
                style: TextStyle(
                  color: _dark,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '${_visibleProducts.length} produk',
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _showAddProductDialog,
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Tambah'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _green,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _visibleProducts.isEmpty
              ? _emptySearch()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = wide
                        ? (constraints.maxWidth / 190).floor().clamp(2, 5)
                        : (constraints.maxWidth / 155).floor().clamp(2, 3);
                    return GridView.builder(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        0,
                        horizontalPadding,
                        18,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: wide ? 0.94 : 0.83,
                      ),
                      itemCount: _visibleProducts.length,
                      itemBuilder: (context, index) {
                        final product = _visibleProducts[index];
                        return _ProductCard(
                          product: product,
                          countInCart: _cart[product] ?? 0,
                          price: _rupiah(product.price),
                          hpp: product.hpp == null
                              ? null
                              : _rupiah(product.hpp!),
                          onAdd: () => _addProduct(product),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'pagi';
    if (hour < 15) return 'siang';
    if (hour < 18) return 'sore';
    return 'malam';
  }

  Widget _transactionBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4EE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_rounded, color: _green, size: 17),
          const SizedBox(width: 7),
          Text(
            'TRX-${_transactionNumber.toString().padLeft(4, '0')}',
            style: const TextStyle(
              color: _green,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptySearch() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 42, color: Colors.grey.shade400),
          const SizedBox(height: 9),
          const Text(
            'Produk tidak ditemukan',
            style: TextStyle(color: _muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Coba kata kunci atau kategori lain',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCart() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 23, 22, 16),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF4EE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: _green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pesanan',
                        style: TextStyle(
                          color: _dark,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Transaksi baru',
                        style: TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _canvas,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_itemCount item',
                    style: const TextStyle(
                      color: _dark,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8ECE8)),
          Expanded(
            child: _cart.isEmpty
                ? _emptyCart()
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    children: [
                      for (final entry in _cart.entries)
                        _CartItem(
                          product: entry.key,
                          quantity: entry.value,
                          formattedTotal: _rupiah(
                            entry.key.price * entry.value,
                          ),
                          onMinus: () => _changeQuantity(entry.key, -1),
                          onPlus: () => _changeQuantity(entry.key, 1),
                        ),
                    ],
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE8ECE8))),
            ),
            child: Column(
              children: [
                _summaryRow('Subtotal', _rupiah(_subtotal)),
                const SizedBox(height: 9),
                _summaryRow('Pajak', 'Termasuk'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 13),
                  child: Divider(height: 1, color: Color(0xFFE8ECE8)),
                ),
                Row(
                  children: [
                    const Text(
                      'Total pembayaran',
                      style: TextStyle(
                        color: _dark,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _rupiah(_subtotal),
                      style: const TextStyle(
                        color: _green,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                _checkoutButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 74,
              width: 74,
              decoration: BoxDecoration(
                color: _canvas,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.shopping_basket_outlined,
                color: Color(0xFF9BA79F),
                size: 34,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Keranjang masih kosong',
              style: TextStyle(
                color: _dark,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Tambahkan produk dari daftar untuk mulai transaksi',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 11, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: _dark,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _checkoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 49,
      child: FilledButton.icon(
        onPressed: _cart.isEmpty ? null : _checkout,
        style: FilledButton.styleFrom(
          backgroundColor: _green,
          disabledBackgroundColor: const Color(0xFFC9D4CE),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        icon: const Icon(Icons.payments_outlined, size: 19),
        label: const Text(
          'Bayar Sekarang',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildMobileCartBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8ECE8))),
        boxShadow: [
          BoxShadow(
            color: Color(0x0C18352B),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_itemCount item di keranjang',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  _rupiah(_subtotal),
                  style: const TextStyle(
                    color: _dark,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 148,
            height: 46,
            child: FilledButton(
              onPressed: _cart.isEmpty ? null : _openMobileCart,
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                disabledBackgroundColor: const Color(0xFFC9D4CE),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shopping_bag_outlined, size: 18),
                    SizedBox(width: 7),
                    Text(
                      'Lihat Pesanan',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMobileCart() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.82,
          child: _buildCart(),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.countInCart,
    required this.price,
    required this.hpp,
    required this.onAdd,
  });

  final Product product;
  final int countInCart;
  final String price;
  final String? hpp;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: countInCart > 0
                  ? const Color(0xFFB7D9C5)
                  : const Color(0xFFE8ECE8),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: product.color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        product.icon,
                        size: 43,
                        color: _dark.withValues(alpha: 0.72),
                      ),
                    ),
                    if (countInCart > 0)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$countInCart',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _dark,
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Stok ${product.stock}',
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
              if (hpp != null) ...[
                const SizedBox(height: 3),
                Text(
                  'HPP $hpp',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
              ],
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _green,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    height: 27,
                    width: 27,
                    decoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartItem extends StatelessWidget {
  const _CartItem({
    required this.product,
    required this.quantity,
    required this.formattedTotal,
    required this.onMinus,
    required this.onPlus,
  });

  final Product product;
  final int quantity;
  final String formattedTotal;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 43,
            width: 43,
            decoration: BoxDecoration(
              color: product.color,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              product.icon,
              color: _dark.withValues(alpha: 0.72),
              size: 23,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _dark,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  formattedTotal,
                  style: const TextStyle(
                    color: _green,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    _QuantityButton(icon: Icons.remove_rounded, onTap: onMinus),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      child: Text(
                        '$quantity',
                        style: const TextStyle(
                          color: _dark,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _QuantityButton(icon: Icons.add_rounded, onTap: onPlus),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        height: 23,
        width: 25,
        decoration: BoxDecoration(
          color: _canvas,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFFE8ECE8)),
        ),
        child: Icon(icon, size: 15, color: _dark),
      ),
    );
  }
}

class AddProductDialog extends StatefulWidget {
  const AddProductDialog({super.key});

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hppController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _categoryController = TextEditingController(
    text: _productCategories.first,
  );

  @override
  void dispose() {
    _nameController.dispose();
    _hppController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  String? _validateAmount(String? value, {required bool allowZero}) {
    final amount = int.tryParse(value ?? '');
    if (amount == null || amount < (allowZero ? 0 : 1)) {
      return allowZero
          ? 'Masukkan stok 0 atau lebih.'
          : 'Masukkan nominal lebih dari 0.';
    }
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final category = _categoryController.text.trim();
    Navigator.pop(
      context,
      Product(
        name: _nameController.text.trim(),
        category: category,
        hpp: int.parse(_hppController.text),
        price: int.parse(_priceController.text),
        icon: _categoryIcon(category),
        color: _categoryColor(category),
        stock: int.parse(_stockController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    scrollable: true,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    title: const Text(
      'Tambah produk',
      style: TextStyle(color: _dark, fontSize: 18, fontWeight: FontWeight.w800),
    ),
    content: SizedBox(
      width: 380,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const ValueKey('product-name'),
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Nama produk wajib diisi.'
                  : null,
              decoration: _authDecoration('Nama produk'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('product-category'),
              controller: _categoryController,
              textCapitalization: TextCapitalization.words,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Kategori wajib diisi.'
                  : null,
              decoration: _authDecoration('Kategori').copyWith(
                hintText: 'Ketik atau pilih kategori',
                suffixIcon: PopupMenuButton<String>(
                  tooltip: 'Pilih kategori umum',
                  onSelected: (category) {
                    _categoryController.text = category;
                  },
                  itemBuilder: (context) => _productCategories
                      .map(
                        (category) => PopupMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  icon: const Icon(Icons.arrow_drop_down_rounded),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('product-hpp'),
              controller: _hppController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) => _validateAmount(value, allowZero: false),
              decoration: _authDecoration('HPP / harga modal')
                  .copyWith(prefixText: 'Rp '),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('product-price'),
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) => _validateAmount(value, allowZero: false),
              decoration: _authDecoration('Harga jual')
                  .copyWith(prefixText: 'Rp '),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('product-stock'),
              controller: _stockController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) => _validateAmount(value, allowZero: true),
              decoration: _authDecoration('Stok awal'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal', style: TextStyle(color: _muted)),
      ),
      FilledButton(
        onPressed: _save,
        style: FilledButton.styleFrom(backgroundColor: _green),
        child: const Text('Simpan produk'),
      ),
    ],
  );
}

class _OpeningCashDialog extends StatefulWidget {
  const _OpeningCashDialog();

  @override
  State<_OpeningCashDialog> createState() => _OpeningCashDialogState();
}

class _OpeningCashDialogState extends State<_OpeningCashDialog> {
  final _cashController = TextEditingController();
  int? _openingCash;

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text(
        'Buka toko',
        style: TextStyle(
          color: _dark,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan kas awal untuk menyediakan uang kembalian pembayaran tunai.',
              style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cashController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) => setState(
                () => _openingCash = value.isEmpty ? null : int.tryParse(value),
              ),
              decoration: InputDecoration(
                labelText: 'Kas awal',
                prefixText: 'Rp ',
                hintText: 'Contoh: 200000',
                filled: true,
                fillColor: _canvas,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE8ECE8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE8ECE8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _green, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: _openingCash == null
              ? null
              : () => Navigator.pop(context, _openingCash),
          style: FilledButton.styleFrom(
            backgroundColor: _green,
            disabledBackgroundColor: const Color(0xFFC9D4CE),
          ),
          child: const Text('Mulai toko'),
        ),
      ],
    );
  }
}

class _StoreClosingDialog extends StatelessWidget {
  const _StoreClosingDialog({
    required this.openingCash,
    required this.revenue,
    required this.transactionCount,
    required this.uncompletedItemCount,
    required this.formatRupiah,
  });

  final int openingCash;
  final int revenue;
  final int transactionCount;
  final int uncompletedItemCount;
  final String Function(int) formatRupiah;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text(
        'Rekap penutupan toko',
        style: TextStyle(
          color: _dark,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _closingSummaryRow('Jumlah transaksi', '$transactionCount'),
            const SizedBox(height: 12),
            _closingSummaryRow('Kas awal', formatRupiah(openingCash)),
            const SizedBox(height: 12),
            _closingSummaryRow('Pendapatan tunai', formatRupiah(revenue)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, color: Color(0xFFE8ECE8)),
            ),
            _closingSummaryRow(
              'Perkiraan kas di laci',
              formatRupiah(openingCash + revenue),
              emphasize: true,
            ),
            if (uncompletedItemCount > 0) ...[
              const SizedBox(height: 14),
              Text(
                '$uncompletedItemCount item di keranjang belum dibayar dan akan dibatalkan saat toko ditutup.',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Kembali berjualan',
            style: TextStyle(color: _muted),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: _green),
          child: const Text('Tutup toko'),
        ),
      ],
    );
  }

  Widget _closingSummaryRow(
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasize ? _dark : _muted,
              fontSize: emphasize ? 13 : 12,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: emphasize ? _green : _dark,
            fontSize: emphasize ? 15 : 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class PaymentDialog extends StatefulWidget {
  const PaymentDialog({
    required this.total,
    required this.availableCash,
    required this.formatRupiah,
    super.key,
  });

  final int total;
  final int availableCash;
  final String Function(int) formatRupiah;

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _cashController = TextEditingController();
  int? _cash;

  int get _change => (_cash ?? 0) - widget.total;

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  void _selectCash(int amount) {
    setState(() {
      _cash = amount;
      _cashController.text = amount.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final presets = {
      widget.total,
      ((widget.total + 9999) ~/ 10000) * 10000,
      ((widget.total + 49999) ~/ 50000) * 50000,
    }.toList()..sort();
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titlePadding: const EdgeInsets.fromLTRB(24, 23, 24, 5),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 6, 24, 20),
      title: const Text(
        'Pembayaran Tunai',
        style: TextStyle(
          color: _dark,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4EE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL TAGIHAN',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.formatRupiah(widget.total),
                    style: const TextStyle(
                      color: _green,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 17),
            const Text(
              'Uang diterima',
              style: TextStyle(
                color: _dark,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            TextField(
              controller: _cashController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) => setState(() => _cash = int.tryParse(value)),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                hintText: 'Masukkan nominal',
                filled: true,
                fillColor: _canvas,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE8ECE8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE8ECE8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _green, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'Kas tersedia untuk kembalian: ${widget.formatRupiah(widget.availableCash)}',
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: presets
                  .map(
                    (amount) => ActionChip(
                      label: Text(
                        widget.formatRupiah(amount),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () => _selectCash(amount),
                      side: const BorderSide(color: Color(0xFFE8ECE8)),
                      backgroundColor: Colors.white,
                    ),
                  )
                  .toList(),
            ),
            if (_cash != null) ...[
              const SizedBox(height: 15),
              Row(
                children: [
                  Text(
                    _change < 0 ? 'Kurang' : 'Kembalian',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    widget.formatRupiah(_change.abs()),
                    style: TextStyle(
                      color: _change < 0 ? Colors.red.shade700 : _green,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (_change > widget.availableCash) ...[
                const SizedBox(height: 8),
                Text(
                  'Kas untuk kembalian tidak mencukupi.',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal', style: TextStyle(color: _muted)),
        ),
        FilledButton(
          onPressed:
              _cash != null &&
                  _cash! >= widget.total &&
                  _change <= widget.availableCash
              ? () => Navigator.pop(context, _cash)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: _green,
            disabledBackgroundColor: const Color(0xFFC9D4CE),
          ),
          child: const Text('Selesaikan'),
        ),
      ],
    );
  }
}
