import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/common.dart';

import 'database_native.dart'
    if (dart.library.js_interop) 'database_web.dart'
    as platform;
import 'models.dart';
import 'initial_admin.dart';

class PosException implements Exception {
  const PosException(this.key);
  final String key;
  @override
  String toString() => key;
}

// Run password derivation off the UI isolate on every native platform.
Future<String> _derive(Map<String, String> args) async {
  final key =
      await Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 210000,
        bits: 256,
      ).deriveKey(
        secretKey: SecretKey(utf8.encode(args['password']!)),
        nonce: base64Decode(args['salt']!),
      );
  return base64Encode(await key.extractBytes());
}

class PosStore extends ChangeNotifier {
  PosStore(this._db, {bool provisionAdmin = true}) {
    _db.execute('PRAGMA foreign_keys = ON');
    _db.execute(
      kIsWeb ? 'PRAGMA journal_mode = MEMORY' : 'PRAGMA journal_mode = WAL',
    );
    _db.execute('PRAGMA synchronous = FULL');
    for (final table in [
      'products',
      'users',
      'sales',
      'preferences',
      'markets',
      'categories',
    ]) {
      _db.execute(
        'CREATE TABLE IF NOT EXISTS $table (id TEXT PRIMARY KEY, data TEXT NOT NULL)',
      );
    }
    _db.execute(
      'CREATE TABLE IF NOT EXISTS audit (id INTEGER PRIMARY KEY AUTOINCREMENT, time TEXT NOT NULL, actor TEXT NOT NULL, action TEXT NOT NULL, detail TEXT NOT NULL)',
    );
    _initializeMarkets();
    _reload();
    if (provisionAdmin) _provisionInitialAdmin();
  }
  final CommonDatabase _db;
  static Future<PosStore> open() async =>
      PosStore(await platform.openDatabase());
  factory PosStore.memory({bool provisionAdmin = true}) =>
      PosStore(platform.memoryDatabase(), provisionAdmin: provisionAdmin);
  List<Product> _products = [];
  List<StaffUser> _users = [];
  List<Sale> _sales = [];
  List<Market> _markets = [];
  List<ProductCategory> _categories = [];
  String _activeMarketId = defaultMarketId;
  String get activeMarketId => _activeMarketId;
  StoreSettings settings = const StoreSettings();
  String language = 'en';
  StaffUser? currentUser;
  int _failures = 0;
  DateTime? _lockedUntil;
  List<Product> get products =>
      List.unmodifiable(_products.where((p) => p.marketId == _activeMarketId));
  List<ProductCategory> get categories => List.unmodifiable(
    _categories.where((c) => c.marketId == _activeMarketId),
  );
  List<StaffUser> get users => List.unmodifiable(
    _users.where(
      (u) => u.marketId == _activeMarketId || u.role == UserRole.superManager,
    ),
  );
  List<Market> get markets => List.unmodifiable(
    _markets.where((m) => isOwner || m.id == _activeMarketId),
  );
  List<Sale> get sales => List.unmodifiable(
    _sales.where(
      (s) =>
          s.marketId == _activeMarketId &&
          (currentUser?.role != UserRole.cashier ||
              canViewReports ||
              s.cashierId == currentUser!.id),
    ),
  );
  bool get needsSetup => _users.isEmpty;
  bool get isManager =>
      currentUser != null &&
      [UserRole.admin, UserRole.superManager].contains(currentUser!.role);
  // Keep the existing alias for the global super administrator.
  bool get isOwner => currentUser?.role == UserRole.superManager;
  bool get canViewReports =>
      isManager ||
      currentUser?.role == UserRole.marketOwner ||
      _hasExtra(CashierPermission.viewReports);
  bool get canCheckout =>
      currentUser != null && currentUser!.role != UserRole.marketOwner;
  bool get canManageBrand => isManager;
  bool _hasExtra(CashierPermission permission) =>
      currentUser?.role == UserRole.cashier &&
      currentUser!.active &&
      currentUser!.marketId == _activeMarketId &&
      currentUser!.extraPermissions.contains(permission);
  bool get canViewInventory =>
      isManager || currentUser?.role == UserRole.cashier;
  bool get canManageCatalog =>
      isManager || _hasExtra(CashierPermission.manageCatalog);
  bool get canDiscount =>
      isManager || _hasExtra(CashierPermission.applyDiscounts);
  bool get canVoidSales => isManager || _hasExtra(CashierPermission.voidSales);
  List<Sale> get visibleSales => sales;

  void _initializeMarkets() {
    _db.execute('BEGIN IMMEDIATE');
    try {
      if (!_db
          .select('PRAGMA table_info(audit)')
          .any((r) => r['name'] == 'marketId')) {
        _db.execute(
          "ALTER TABLE audit ADD COLUMN marketId TEXT NOT NULL DEFAULT 'default'",
        );
      }
      if (_db.select('SELECT id FROM markets WHERE id = ?', [
        defaultMarketId,
      ]).isEmpty) {
        final previous = _db.select(
          "SELECT data FROM preferences WHERE id = 'settings'",
        );
        final settings = previous.isEmpty
            ? const StoreSettings()
            : StoreSettings.fromJson(
                jsonDecode(previous.single['data'] as String),
              );
        _put(
          'markets',
          defaultMarketId,
          Market(id: defaultMarketId, settings: settings).toJson(),
        );
      }
      if (_db
          .select(
            "SELECT id FROM preferences WHERE id = 'market-categories-v1'",
          )
          .isEmpty) {
        for (final c in starterCategories()) {
          _put('categories', c.id, c.toJson());
        }
        _put('preferences', 'market-categories-v1', {'applied': true});
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  // JavaScript bitwise operations are 32-bit: `1 << 32` becomes zero on
  // the web. A numeric literal keeps the random bound valid on every target.
  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x100000000)}';
  List<Map<String, dynamic>> _read(String table) => _db
      .select('SELECT data FROM $table')
      .map((row) => jsonDecode(row['data'] as String) as Map<String, dynamic>)
      .toList();
  void _put(String table, String id, Map<String, dynamic> data) => _db.execute(
    'INSERT INTO $table (id, data) VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET data=excluded.data',
    [id, jsonEncode(data)],
  );
  void _reload() {
    _markets = _read('markets').map(Market.fromJson).toList();
    _categories = _read('categories').map(ProductCategory.fromJson).toList();
    _products = _read('products').map(Product.fromJson).toList();
    _users = _read('users').map(StaffUser.fromJson).toList();
    _sales = _read('sales').map(Sale.fromJson).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final row in _db.select('SELECT id, data FROM preferences')) {
      final data = jsonDecode(row['data']);
      if (row['id'] == 'language') language = data['code'];
    }
    if (currentUser != null) {
      currentUser = _users
          .where((u) => u.id == currentUser!.id && u.active)
          .firstOrNull;
    }
    settings = _markets.firstWhere((m) => m.id == _activeMarketId).settings;
  }

  // Apply once to both new installations and databases created by earlier
  // versions. Preserve existing staff, inventory, receipts and store settings.
  // The marker prevents future launches from undoing an administrator's edits.
  void _provisionInitialAdmin() {
    if (_db.select('SELECT id FROM preferences WHERE id = ?', [
      initialAdminMigration,
    ]).isNotEmpty) {
      return;
    }
    final previous = _users
        .where((user) => user.username == initialAdminUsername)
        .firstOrNull;
    final freshStore =
        _users.isEmpty &&
        _products.isEmpty &&
        _sales.isEmpty &&
        _db.select("SELECT id FROM preferences WHERE id = 'settings'").isEmpty;
    final admin = StaffUser(
      id: previous?.id ?? newId(),
      name: previous?.name ?? initialAdminName,
      username: initialAdminUsername,
      role: UserRole.superManager,
      passwordHash: initialAdminPasswordHash,
      salt: initialAdminSalt,
      active: true,
      marketId: previous?.marketId ?? defaultMarketId,
    );
    _transaction(
      previous == null ? 'userAdded' : 'userUpdated',
      admin.name,
      () {
        _put('users', admin.id, admin.toJson());
        if (freshStore) {
          _put('preferences', 'settings', settings.toJson());
          for (final product in starterProducts()) {
            _put('products', product.id, product.toJson());
          }
        }
        _put('preferences', initialAdminMigration, {'applied': true});
      },
    );
  }

  void _transaction(String action, String detail, void Function() change) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      change();
      _db.execute(
        'INSERT INTO audit (time, actor, action, detail, marketId) VALUES (?, ?, ?, ?, ?)',
        [
          DateTime.now().toIso8601String(),
          currentUser?.name ?? 'Setup',
          action,
          detail,
          _activeMarketId,
        ],
      );
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
    _reload();
    notifyListeners();
  }

  void _require({
    bool manager = false,
    bool owner = false,
    bool reports = false,
    CashierPermission? permission,
  }) {
    if (currentUser == null ||
        !currentUser!.active ||
        (currentUser!.role != UserRole.superManager &&
            currentUser!.marketId != _activeMarketId) ||
        (manager && !isManager) ||
        (owner && !isOwner) ||
        (reports && !canViewReports) ||
        (permission != null && !isManager && !_hasExtra(permission))) {
      throw const PosException('permissionDenied');
    }
  }

  Future<StaffUser> _makeUser(
    String id,
    String name,
    String username,
    UserRole role,
    String password,
    bool active,
    StaffUser? previous,
    String marketId, {
    Set<CashierPermission> extraPermissions = const {},
  }) async {
    if (name.trim().isEmpty ||
        !RegExp(r'^[a-zA-Z0-9_.-]{3,40}$').hasMatch(username.trim())) {
      throw const PosException('invalidUser');
    }
    if (password.isEmpty && previous != null) {
      return StaffUser(
        id: id,
        name: name.trim(),
        username: username.trim().toLowerCase(),
        role: role,
        passwordHash: previous.passwordHash,
        salt: previous.salt,
        active: active,
        marketId: marketId,
        extraPermissions: extraPermissions,
      );
    }
    if (password.length < 8) throw const PosException('passwordLength');
    final random = Random.secure();
    final salt = base64Encode(List.generate(16, (_) => random.nextInt(256)));
    final hash = await compute(_derive, {'password': password, 'salt': salt});
    return StaffUser(
      id: id,
      name: name.trim(),
      username: username.trim().toLowerCase(),
      role: role,
      passwordHash: hash,
      salt: salt,
      active: active,
      marketId: marketId,
      extraPermissions: extraPermissions,
    );
  }

  Future<void> setup({
    required String storeName,
    required String name,
    required String username,
    required String password,
    required String currency,
    required bool sampleProducts,
  }) async {
    if (!needsSetup) throw const PosException('permissionDenied');
    if (storeName.trim().isEmpty || !['IQD', 'USD', 'EUR'].contains(currency)) {
      throw const PosException('invalidSettings');
    }
    final user = await _makeUser(
      newId(),
      name,
      username,
      UserRole.superManager,
      password,
      true,
      null,
      defaultMarketId,
    );
    if (!needsSetup) throw const PosException('permissionDenied');
    _transaction('setup', storeName.trim(), () {
      _put('users', user.id, user.toJson());
      _put(
        'markets',
        defaultMarketId,
        Market(
          id: defaultMarketId,
          settings: StoreSettings(name: storeName.trim(), currency: currency),
        ).toJson(),
      );
      if (sampleProducts) {
        for (final p in starterProducts()) {
          final j = p.toJson();
          if (currency != 'IQD') {
            j['price'] = (p.price / 1300).round();
            j['cost'] = (p.cost / 1300).round();
          }
          _put('products', p.id, j);
        }
      }
    });
    currentUser = user;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    if (_lockedUntil != null && DateTime.now().isBefore(_lockedUntil!)) {
      throw const PosException('tooManyAttempts');
    }
    final user = _users
        .where((u) => u.username == username.trim().toLowerCase() && u.active)
        .firstOrNull;
    var valid = false;
    if (user != null) {
      final actual = base64Decode(
        await compute(_derive, {'password': password, 'salt': user.salt}),
      );
      final expected = base64Decode(user.passwordHash);
      var difference = actual.length ^ expected.length;
      for (var i = 0; i < min(actual.length, expected.length); i++) {
        difference |= actual[i] ^ expected[i];
      }
      valid = difference == 0;
    }
    if (!valid) {
      _failures++;
      if (_failures >= 5) {
        _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
        _failures = 0;
      }
      throw const PosException('invalidCredentials');
    }
    _failures = 0;
    currentUser = user;
    _activeMarketId = user!.marketId;
    _reload();
    notifyListeners();
  }

  void logout() {
    currentUser = null;
    _activeMarketId = defaultMarketId;
    _reload();
    notifyListeners();
  }

  void setLanguage(String code) {
    if (!['en', 'ar', 'ku'].contains(code)) return;
    _put('preferences', 'language', {'code': code});
    language = code;
    notifyListeners();
  }

  void switchMarket(String id) {
    _require(owner: true);
    if (!_markets.any((m) => m.id == id)) {
      throw const PosException('invalidMarket');
    }
    _activeMarketId = id;
    _reload();
    notifyListeners();
  }

  String createMarket({
    required String name,
    required String currency,
    String? logo,
    int? usdToIqdRate,
  }) {
    _require(owner: true);
    if (name.trim().isEmpty || !['IQD', 'USD', 'EUR'].contains(currency)) {
      throw const PosException('invalidMarket');
    }
    _validatePhoto(logo);
    final settings = StoreSettings(
      name: name.trim(),
      currency: currency,
      logo: logo,
      usdToIqdRate: usdToIqdRate,
    );
    if (!settings.hasValidCurrencyDisplay) {
      throw const PosException('invalidExchangeRate');
    }
    final market = Market(id: newId(), settings: settings);
    _transaction('marketAdded', market.settings.name, () {
      _put('markets', market.id, market.toJson());
      for (final c in starterCategories(market.id)) {
        _put('categories', c.id, c.toJson());
      }
    });
    return market.id;
  }

  void _validatePhoto(String? photo) {
    if (photo == null) return;
    if (photo.length > 2800000) throw const PosException('photoTooLarge');
    try {
      final bytes = base64Decode(photo);
      final png =
          bytes.length >= 8 &&
          bytes[0] == 137 &&
          bytes[1] == 80 &&
          bytes[2] == 78 &&
          bytes[3] == 71;
      final jpeg =
          bytes.length >= 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255;
      final webp =
          bytes.length >= 12 &&
          ascii.decode(bytes.take(4).toList(), allowInvalid: true) == 'RIFF' &&
          ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP';
      if (!png && !jpeg && !webp) throw const FormatException();
    } on FormatException {
      throw const PosException('invalidPhoto');
    }
  }

  void saveCategory(ProductCategory category) {
    _require(permission: CashierPermission.manageCatalog);
    if (category.marketId != _activeMarketId ||
        _categories.any(
          (c) => c.id == category.id && c.marketId != _activeMarketId,
        )) {
      throw const PosException('permissionDenied');
    }
    if (category.name.trim().isEmpty || category.id.isEmpty) {
      throw const PosException('invalidCategory');
    }
    if (categories.any(
      (c) =>
          c.id != category.id &&
          c.name.trim().toLowerCase() == category.name.trim().toLowerCase(),
    )) {
      throw const PosException('duplicateCategory');
    }
    _validatePhoto(category.photo);
    _transaction(
      'categorySaved',
      category.name,
      () => _put('categories', category.id, category.toJson()),
    );
  }

  void deleteCategory(String id) {
    _require(permission: CashierPermission.manageCatalog);
    final category = categories.where((c) => c.id == id).firstOrNull;
    if (category == null) throw const PosException('permissionDenied');
    if (products.any((p) => p.category == id)) {
      throw const PosException('categoryInUse');
    }
    _transaction(
      'categoryDeleted',
      category.name,
      () => _db.execute('DELETE FROM categories WHERE id = ?', [id]),
    );
  }

  Future<void> saveUser({
    Set<CashierPermission>? extraPermissions,
    String? id,
    String? marketId,
    required String name,
    required String username,
    required UserRole role,
    required String password,
    required bool active,
  }) async {
    _require(manager: true);
    final actorId = currentUser!.id;
    final actorMarketId = _activeMarketId;
    final previous = _users.where((u) => u.id == id).firstOrNull;
    final assignedMarketId = marketId ?? previous?.marketId ?? actorMarketId;
    final assignedPermissions = Set<CashierPermission>.unmodifiable(
      role == UserRole.cashier
          ? extraPermissions ?? previous?.extraPermissions ?? const {}
          : const {},
    );
    void check() {
      _require(manager: true);
      if (!_markets.any((market) => market.id == assignedMarketId)) {
        throw const PosException('invalidMarket');
      }
      if ((previous != null && assignedMarketId != previous.marketId) ||
          (previous == null &&
              assignedMarketId != actorMarketId &&
              (!isOwner || role != UserRole.admin))) {
        throw const PosException('permissionDenied');
      }
      if (currentUser!.id != actorId ||
          _activeMarketId != actorMarketId ||
          (id != null &&
              (previous == null ||
                  previous.marketId != _activeMarketId &&
                      previous.role != UserRole.superManager)) ||
          (!isOwner &&
              (role != UserRole.cashier ||
                  (previous != null && previous.role != UserRole.cashier))) ||
          (id == currentUser!.id && (role != currentUser!.role || !active))) {
        throw const PosException('permissionDenied');
      }
      if (_users.any(
        (u) => u.id != id && u.username == username.trim().toLowerCase(),
      )) {
        throw const PosException('duplicateUsername');
      }
    }

    check();
    final user = await _makeUser(
      id ?? newId(),
      name,
      username,
      role,
      password,
      active,
      previous,
      assignedMarketId,
      extraPermissions: assignedPermissions,
    );
    check();
    _transaction(
      previous == null ? 'userAdded' : 'userUpdated',
      user.name,
      () => _put('users', user.id, user.toJson()),
    );
  }

  void deleteUser(String id) {
    _require(manager: true);
    final target = _users.where((u) => u.id == id).firstOrNull;
    if (target == null ||
        id == currentUser!.id ||
        (target.marketId != _activeMarketId &&
            target.role != UserRole.superManager) ||
        (!isOwner && target.role != UserRole.cashier)) {
      throw const PosException('permissionDenied');
    }
    _transaction(
      'userDeleted',
      target.name,
      () => _db.execute('DELETE FROM users WHERE id = ?', [id]),
    );
  }

  void saveProduct(Product product) {
    _require(permission: CashierPermission.manageCatalog);
    if (product.marketId != _activeMarketId ||
        _products.any(
          (p) => p.id == product.id && p.marketId != _activeMarketId,
        )) {
      throw const PosException('permissionDenied');
    }
    _validatePhoto(product.photo);
    if (product.name.trim().isEmpty ||
        product.barcode.trim().isEmpty ||
        !categories.any((c) => c.id == product.category) ||
        product.price < 0 ||
        product.cost < 0 ||
        product.price > 100000000000 ||
        product.cost > 100000000000 ||
        product.stock < 0 ||
        product.stock > 1000000 ||
        product.lowStock < 0) {
      throw const PosException('invalidProduct');
    }
    if (_products.any(
      (p) =>
          p.marketId == _activeMarketId &&
          p.id != product.id &&
          p.barcode == product.barcode,
    )) {
      throw const PosException('duplicateBarcode');
    }
    _transaction(
      'productSaved',
      product.name,
      () => _put('products', product.id, product.toJson()),
    );
  }

  void deleteProduct(String id) {
    _require(permission: CashierPermission.manageCatalog);
    final p = products.where((p) => p.id == id).firstOrNull;
    if (p == null) return;
    _transaction(
      'productDeleted',
      p.name,
      () => _db.execute('DELETE FROM products WHERE id = ?', [id]),
    );
  }

  void saveSettings(StoreSettings value) {
    _require(manager: true);
    if (!value.hasValidCurrencyDisplay) {
      throw const PosException('invalidExchangeRate');
    }
    if (value.name.trim().isEmpty ||
        value.taxBasisPoints < 0 ||
        value.taxBasisPoints > 10000 ||
        !['IQD', 'USD', 'EUR'].contains(value.currency) ||
        ![58, 80].contains(value.receiptWidth) ||
        (value.logo?.length ?? 0) > 2800000) {
      throw const PosException('invalidSettings');
    }
    // Currency is a denomination, not a conversion. Require an empty catalog/ledger to change it.
    if (value.currency != settings.currency &&
        (products.isNotEmpty || sales.isNotEmpty)) {
      throw const PosException('currencyLocked');
    }
    _transaction(
      'settingsUpdated',
      value.name,
      () => _put(
        'markets',
        _activeMarketId,
        Market(id: _activeMarketId, settings: value).toJson(),
      ),
    );
  }

  Sale checkout(
    Map<String, int> quantities, {
    int discount = 0,
    required String paymentMethod,
    required int tendered,
  }) {
    _require();
    if (!canCheckout) throw const PosException('permissionDenied');
    if (quantities.isEmpty) throw const PosException('emptyCart');
    if (!['cash', 'card'].contains(paymentMethod)) {
      throw const PosException('invalidPayment');
    }
    final lines = <SaleLine>[];
    for (final entry in quantities.entries) {
      final p = products.where((p) => p.id == entry.key).firstOrNull;
      if (p == null || entry.value < 1 || entry.value > p.stock) {
        throw const PosException('insufficientStock');
      }
      lines.add(
        SaleLine(
          productId: p.id,
          name: p.localizedName(language),
          quantity: entry.value,
          price: p.price,
          cost: p.cost,
        ),
      );
    }
    final subtotal = lines.fold(0, (sum, l) => sum + l.total);
    if (discount < 0 || discount > subtotal) {
      throw const PosException('invalidDiscount');
    }
    if (discount > 0 && !canDiscount) {
      throw const PosException('permissionDenied');
    }
    final tax =
        ((subtotal - discount) * settings.taxBasisPoints + 5000) ~/ 10000;
    final total = subtotal - discount + tax;
    if (tendered < total || tendered > 100000000000000) {
      throw const PosException('insufficientPayment');
    }
    final sale = Sale(
      id: newId(),
      number:
          'BZ-${(_sales.where((s) => s.marketId == _activeMarketId).length + 1).toString().padLeft(6, '0')}',
      marketId: _activeMarketId,
      createdAt: DateTime.now(),
      cashierId: currentUser!.id,
      cashierName: currentUser!.name,
      lines: lines,
      discount: discount,
      tax: tax,
      paymentMethod: paymentMethod,
      tendered: paymentMethod == 'card' ? total : tendered,
      settings: settings,
      language: language,
    );
    _transaction('saleCompleted', sale.number, () {
      for (final line in lines) {
        final p = _products.firstWhere((p) => p.id == line.productId);
        _put('products', p.id, p.withStock(p.stock - line.quantity).toJson());
      }
      _put('sales', sale.id, sale.toJson());
    });
    return sale;
  }

  void voidSale(String id, String reason) {
    _require(permission: CashierPermission.voidSales);
    final sale = sales.where((s) => s.id == id).firstOrNull;
    if (sale == null || sale.voided || reason.trim().isEmpty) {
      throw const PosException('invalidVoid');
    }
    _transaction('saleVoided', '${sale.number}: ${reason.trim()}', () {
      for (final line in sale.lines) {
        final p = products.where((p) => p.id == line.productId).firstOrNull;
        if (p != null) {
          _put('products', p.id, p.withStock(p.stock + line.quantity).toJson());
        }
      }
      _put('sales', id, {
        ...sale.toJson(),
        'voided': true,
        'voidReason': reason.trim(),
      });
    });
  }

  List<AuditEntry> get audit {
    _require(manager: true);
    return _db
        .select(
          'SELECT * FROM audit WHERE marketId = ? ORDER BY id DESC LIMIT 200',
          [_activeMarketId],
        )
        .map(
          (r) => AuditEntry(
            DateTime.parse(r['time']),
            r['actor'],
            r['action'],
            r['detail'],
          ),
        )
        .toList();
  }

  String exportSalesCsv(List<Sale> rows) {
    _require(reports: true);
    if (rows.any(
      (s) =>
          s.marketId != _activeMarketId ||
          !sales.any((saved) => saved.id == s.id),
    )) {
      throw const PosException('permissionDenied');
    }
    String cell(String s) {
      final safe = RegExp(r'^[=+@\-\t\r]').hasMatch(s) ? "'$s" : s;
      return '"${safe.replaceAll('"', '""')}"';
    }

    return [
      'Receipt,Date,Cashier,Currency,Subtotal,Discount,Tax,Total,Payment,Status,Market,Items,Cost,Gross profit',
      ...rows.map(
        (s) => [
          s.number,
          s.createdAt.toIso8601String(),
          s.cashierName,
          s.settings.currency,
          (s.subtotal / 100).toStringAsFixed(2),
          (s.discount / 100).toStringAsFixed(2),
          (s.tax / 100).toStringAsFixed(2),
          (s.total / 100).toStringAsFixed(2),
          s.paymentMethod,
          s.voided ? 'voided' : 'completed',
          s.settings.name,
          s.lines.fold(0, (sum, line) => sum + line.quantity).toString(),
          (s.cost / 100).toStringAsFixed(2),
          ((s.subtotal - s.discount - s.cost) / 100).toStringAsFixed(2),
        ].map(cell).join(','),
      ),
    ].join('\r\n');
  }

  static const backupTables = [
    'markets',
    'categories',
    'products',
    'users',
    'sales',
    'preferences',
  ];
  static const maxBackupBytes = 100 * 1024 * 1024;

  Uint8List createBackup() {
    _require(owner: true);
    _db.execute('BEGIN');
    try {
      final bytes = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'format': 'Bazaar_POS-backup',
            'version': 1,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'tables': {
              for (final table in backupTables)
                table: _db
                    .select('SELECT id, data FROM $table')
                    .map(
                      (row) => {
                        'id': row['id'],
                        'data': jsonDecode(row['data'] as String),
                      },
                    )
                    .toList(),
              'audit': _db
                  .select('SELECT * FROM audit')
                  .map((row) => Map<String, Object?>.from(row))
                  .toList(),
            },
          }),
        ),
      );
      if (bytes.length > maxBackupBytes) {
        throw const PosException('backupTooLarge');
      }
      _db.execute('COMMIT');
      return bytes;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  Map<String, dynamic> _validateBackup(Uint8List bytes) {
    if (bytes.length > maxBackupBytes) {
      throw const PosException('backupTooLarge');
    }
    try {
      final backup = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (backup['format'] != 'Bazaar_POS-backup' || backup['version'] != 1) {
        throw const FormatException();
      }
      DateTime.parse(backup['createdAt'] as String);
      final tables = backup['tables'] as Map<String, dynamic>;
      for (final table in backupTables) {
        final ids = <String>{};
        for (final entry in tables[table] as List) {
          final row = entry as Map<String, dynamic>;
          final id = row['id'] as String;
          final data = row['data'] as Map<String, dynamic>;
          if (id.isEmpty ||
              !ids.add(id) ||
              (table != 'preferences' && data['id'] != id)) {
            throw const FormatException();
          }
        }
      }
      Iterable<Map<String, dynamic>> data(String table) =>
          (tables[table] as List).map(
            (row) => row['data'] as Map<String, dynamic>,
          );
      final markets = data('markets').map(Market.fromJson).toList();
      final marketIds = markets.map((market) => market.id).toSet();
      if (!marketIds.contains(defaultMarketId)) throw const FormatException();
      void validateSettings(StoreSettings settings) {
        if (settings.name.trim().isEmpty ||
            !['USD', 'IQD', 'EUR'].contains(settings.currency) ||
            !settings.hasValidCurrencyDisplay ||
            ![58, 80].contains(settings.receiptWidth) ||
            settings.taxBasisPoints < 0 ||
            settings.taxBasisPoints > 10000) {
          throw const FormatException();
        }
        _validatePhoto(settings.logo);
      }

      for (final market in markets) {
        validateSettings(market.settings);
      }
      final categories = data('categories')
          .map(ProductCategory.fromJson)
          .toList();
      for (final category in categories) {
        if (!marketIds.contains(category.marketId)) {
          throw const FormatException();
        }
        _validatePhoto(category.photo);
      }
      for (final product in data('products').map(Product.fromJson)) {
        if (!marketIds.contains(product.marketId) ||
            product.price < 0 ||
            product.cost < 0 ||
            product.stock < 0 ||
            !categories.any(
              (category) =>
                  category.id == product.category &&
                  category.marketId == product.marketId,
            )) {
          throw const FormatException();
        }
        _validatePhoto(product.photo);
      }
      final users = data('users').map(StaffUser.fromJson).toList();
      if (!users.any(
        (user) => user.active && user.role == UserRole.superManager,
      )) {
        throw const FormatException();
      }
      final usernames = <String>{};
      for (final user in users) {
        if (!marketIds.contains(user.marketId) ||
            user.username.isEmpty ||
            !usernames.add(user.username.toLowerCase()) ||
            base64Decode(user.passwordHash).length != 32 ||
            base64Decode(user.salt).length < 16) {
          throw const FormatException();
        }
      }
      for (final sale in data('sales').map(Sale.fromJson)) {
        if (!marketIds.contains(sale.marketId) ||
            !['cash', 'card'].contains(sale.paymentMethod) ||
            !['en', 'ar', 'ku'].contains(sale.language) ||
            sale.total < 0 ||
            sale.tendered < sale.total ||
            sale.lines.any(
              (line) => line.quantity < 1 || line.price < 0 || line.cost < 0,
            )) {
          throw const FormatException();
        }
        validateSettings(sale.settings);
      }
      for (final row in tables['preferences'] as List) {
        if (row['id'] == 'language' &&
            !['en', 'ar', 'ku'].contains(row['data']['code'])) {
          throw const FormatException();
        }
      }
      final auditIds = <int>{};
      for (final entry in tables['audit'] as List) {
        final row = entry as Map<String, dynamic>;
        if (!auditIds.add(row['id'] as int) ||
            !marketIds.contains(row['marketId']) ||
            row['actor'] is! String ||
            row['action'] is! String ||
            row['detail'] is! String) {
          throw const FormatException();
        }
        DateTime.parse(row['time'] as String);
      }
      return tables;
    } catch (_) {
      throw const PosException('invalidBackup');
    }
  }

  void validateBackup(Uint8List bytes) {
    _require(owner: true);
    _validateBackup(bytes);
  }

  void restoreBackup(Uint8List bytes) {
    _require(owner: true);
    final tables = _validateBackup(bytes);
    final previousMarket = _activeMarketId;
    final previousUser = currentUser;
    final previousLanguage = language;
    _db.execute('BEGIN IMMEDIATE');
    try {
      for (final table in backupTables) {
        _db.execute('DELETE FROM $table');
        for (final row in tables[table] as List) {
          _put(table, row['id'] as String, row['data'] as Map<String, dynamic>);
        }
      }
      _db.execute('DELETE FROM audit');
      for (final row in tables['audit'] as List) {
        _db.execute(
          'INSERT INTO audit (id, time, actor, action, detail, marketId) VALUES (?, ?, ?, ?, ?, ?)',
          [
            row['id'],
            row['time'],
            row['actor'],
            row['action'],
            row['detail'],
            row['marketId'],
          ],
        );
      }
      _db.execute(
        'INSERT INTO audit (time, actor, action, detail, marketId) VALUES (?, ?, ?, ?, ?)',
        [
          DateTime.now().toIso8601String(),
          previousUser!.name,
          'backupRestored',
          'Device backup',
          defaultMarketId,
        ],
      );
      currentUser = null;
      _activeMarketId = defaultMarketId;
      language = 'en';
      // Parse restored records before committing so any failure rolls back.
      _reload();
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      currentUser = previousUser;
      _activeMarketId = previousMarket;
      language = previousLanguage;
      _reload();
      rethrow;
    }
    _failures = 0;
    _lockedUntil = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }
}
