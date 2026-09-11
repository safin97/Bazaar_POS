import 'dart:io';

import 'package:Bazaar_POS/core/strings.dart';
import 'package:Bazaar_POS/data/models.dart';
import 'package:Bazaar_POS/data/pos_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

Future<void> setupOwner(PosStore s, {bool samples = true}) => s.setup(
  storeName: 'Test Market',
  name: 'Owner',
  username: 'owner',
  password: 'test-password',
  currency: 'IQD',
  sampleProducts: samples,
);
Matcher errorKey(String key) =>
    isA<PosException>().having((e) => e.key, 'key', key);
void main() {
  late PosStore store;
  setUp(() {
    store = PosStore.memory(provisionAdmin: false);
  });
  tearDown(() {
    store.dispose();
  });

  test(
    'Setup creates a hashed owner, seeds only inventory, and cannot repeat',
    () async {
      await setupOwner(store);
      expect(store.currentUser!.role, UserRole.superManager);
      expect(store.users.single.passwordHash, isNot('test-password'));
      expect(store.products, hasLength(12));
      expect(store.sales, isEmpty);
      await expectLater(
        setupOwner(store),
        throwsA(errorKey('permissionDenied')),
      );
      store.logout();
      await expectLater(
        store.login('owner', 'wrong'),
        throwsA(errorKey('invalidCredentials')),
      );
      await store.login('OWNER', 'test-password');
      expect(store.isOwner, isTrue);
    },
  );
  test('Stock, tax rounding, discount, payment and receipt snapshot are consistent', () async {
    await setupOwner(store);
    store.saveSettings(
      StoreSettings.fromJson({
        ...store.settings.toJson(),
        'taxBasisPoints': 750,
      }),
    );
    final p = store.products.first;
    final sale = store.checkout(
      {p.id: 2},
      discount: 10000,
      paymentMethod: 'cash',
      tendered: 600000,
    );
    expect(sale.subtotal, 500000);
    expect(sale.discount, 10000);
    expect(sale.tax, 36750);
    expect(sale.total, 526750);
    expect(sale.change, 73250);
    expect(store.products.first.stock, p.stock - 2);
    store.saveSettings(
      StoreSettings.fromJson({
        ...store.settings.toJson(),
        'name': 'New Brand',
        'taxBasisPoints': 1000,
      }),
    );
    expect(store.sales.single.settings.name, 'Test Market');
    expect(store.sales.single.settings.taxBasisPoints, 750);
    expect(store.audit.first.action, 'settingsUpdated');
  });
  test('Checkout validation cannot partially change stock or ledger', () async {
    await setupOwner(store);
    final p = store.products.first;
    expect(
      () => store.checkout(
        {p.id: 1, 'missing': 1},
        paymentMethod: 'cash',
        tendered: 99999999,
      ),
      throwsA(errorKey('insufficientStock')),
    );
    expect(
      () => store.checkout(
        {p.id: p.stock + 1},
        paymentMethod: 'cash',
        tendered: 99999999,
      ),
      throwsA(errorKey('insufficientStock')),
    );
    expect(
      () => store.checkout({p.id: 1}, paymentMethod: 'cash', tendered: 1),
      throwsA(errorKey('insufficientPayment')),
    );
    expect(
      () => store.checkout(
        {p.id: 1},
        discount: p.price + 1,
        paymentMethod: 'cash',
        tendered: 9999999,
      ),
      throwsA(errorKey('invalidDiscount')),
    );
    expect(store.products.first.stock, p.stock);
    expect(store.sales, isEmpty);
  });
  test('SQLite failure rolls back stock and sale as one transaction', () async {
    final db = sqlite3.openInMemory();
    final other = PosStore(db, provisionAdmin: false);
    await setupOwner(other);
    final p = other.products.first;
    db.execute(
      "CREATE TRIGGER reject_sale BEFORE INSERT ON sales BEGIN SELECT RAISE(ABORT, 'simulated full disk'); END",
    );
    expect(
      () => other.checkout({p.id: 2}, paymentMethod: 'cash', tendered: 900000),
      throwsA(isA<SqliteException>()),
    );
    expect(other.products.first.stock, p.stock);
    expect(db.select('SELECT count(*) AS n FROM sales').single['n'], 0);
    db.execute('DROP TRIGGER reject_sale');
    other.checkout({p.id: 1}, paymentMethod: 'cash', tendered: 900000);
    expect(other.products.first.stock, p.stock - 1);
    other.dispose();
  });
  test(
    'Voiding restores stock exactly once and preserves the receipt',
    () async {
      await setupOwner(store);
      final p = store.products.first;
      final sale = store.checkout(
        {p.id: 3},
        paymentMethod: 'card',
        tendered: p.price * 3,
      );
      store.voidSale(sale.id, 'Customer returned order');
      expect(store.products.first.stock, p.stock);
      expect(store.sales.single.voided, isTrue);
      expect(store.sales.single.number, sale.number);
      expect(
        () => store.voidSale(sale.id, 'Again'),
        throwsA(errorKey('invalidVoid')),
      );
      expect(store.products.first.stock, p.stock);
    },
  );
  test(
    'Cashiers cannot manage stock, staff, settings, discounts or void sales',
    () async {
      await setupOwner(store);
      await store.saveUser(
        name: 'Cashier',
        username: 'cashier',
        role: UserRole.cashier,
        password: 'cashier-pass',
        active: true,
      );
      final p = store.products.first;
      final ownerSale = store.checkout(
        {p.id: 1},
        paymentMethod: 'cash',
        tendered: p.price,
      );
      store.logout();
      await store.login('cashier', 'cashier-pass');
      expect(() => store.saveProduct(p), throwsA(errorKey('permissionDenied')));
      expect(
        () => store.deleteProduct(p.id),
        throwsA(errorKey('permissionDenied')),
      );
      expect(
        () => store.saveSettings(store.settings),
        throwsA(errorKey('permissionDenied')),
      );
      expect(
        () => store.voidSale(ownerSale.id, 'No'),
        throwsA(errorKey('permissionDenied')),
      );
      expect(
        () => store.checkout(
          {p.id: 1},
          discount: 1,
          paymentMethod: 'cash',
          tendered: p.price,
        ),
        throwsA(errorKey('permissionDenied')),
      );
      await expectLater(
        store.saveUser(
          name: 'Bad',
          username: 'bad',
          role: UserRole.admin,
          password: 'bad-password',
          active: true,
        ),
        throwsA(errorKey('permissionDenied')),
      );
      store.checkout({p.id: 1}, paymentMethod: 'cash', tendered: p.price);
      expect(store.visibleSales, hasLength(1));
      expect(store.visibleSales.single.cashierName, 'Cashier');
    },
  );
  test(
    'Admins manage cashiers but cannot promote accounts or delete the owner',
    () async {
      await setupOwner(store);
      final owner = store.currentUser!;
      await store.saveUser(
        name: 'Admin',
        username: 'admin',
        role: UserRole.admin,
        password: 'admin-pass',
        active: true,
      );
      store.logout();
      await store.login('admin', 'admin-pass');
      await store.saveUser(
        name: 'Sales',
        username: 'sales',
        role: UserRole.cashier,
        password: 'sales-pass',
        active: true,
      );
      final cashier = store.users.firstWhere((u) => u.username == 'sales');
      await expectLater(
        store.saveUser(
          id: cashier.id,
          name: 'Sales',
          username: 'sales',
          role: UserRole.superManager,
          password: '',
          active: true,
        ),
        throwsA(errorKey('permissionDenied')),
      );
      expect(
        () => store.deleteUser(owner.id),
        throwsA(errorKey('permissionDenied')),
      );
      expect(
        () => store.deleteUser(store.currentUser!.id),
        throwsA(errorKey('permissionDenied')),
      );
      store.deleteUser(cashier.id);
      expect(store.users.any((u) => u.id == cashier.id), isFalse);
    },
  );
  test('Disabling accounts blocks login, empty edits preserve password, duplicate IDs rejected', () async {
    await setupOwner(store);
    await store.saveUser(
      name: 'Sales',
      username: 'sales',
      role: UserRole.cashier,
      password: 'sales-pass',
      active: true,
    );
    final u = store.users.last;
    await store.saveUser(
      id: u.id,
      name: 'Sales 2',
      username: 'sales',
      role: UserRole.cashier,
      password: '',
      active: false,
    );
    expect(store.users.last.passwordHash, u.passwordHash);
    await expectLater(
      store.saveUser(
        name: 'Duplicate',
        username: 'SALES',
        role: UserRole.cashier,
        password: 'another-pass',
        active: true,
      ),
      throwsA(errorKey('duplicateUsername')),
    );
    final p = store.products.first;
    expect(
      () => store.saveProduct(
        Product.fromJson({...p.toJson(), 'id': 'duplicate'}),
      ),
      throwsA(errorKey('duplicateBarcode')),
    );
    store.logout();
    await expectLater(
      store.login('sales', 'sales-pass'),
      throwsA(errorKey('invalidCredentials')),
    );
  });
  test('Currency stays consistent and monetary parsing handles Arabic digits exactly', () async {
    await setupOwner(store);
    expect(
      () => store.saveSettings(
        StoreSettings.fromJson({...store.settings.toJson(), 'currency': 'USD'}),
      ),
      throwsA(errorKey('currencyLocked')),
    );
    expect(parseMoney('١٢٣٫٤٥'), 12345);
    expect(parseMoney('۱۲۳.۴۵'), 12345);
    expect(parseMoney('0.29'), 29);
    for (final value in ['NaN', 'Infinity', '-1', '1.999', '1e8', '']) {
      expect(parseMoney(value), isNull);
    }
  });
  test('All translations have English, Arabic and Badini text', () {
    for (final entry in translations.entries) {
      expect(entry.value, hasLength(3), reason: entry.key);
      expect(
        entry.value.every((s) => s.trim().isNotEmpty),
        isTrue,
        reason: entry.key,
      );
    }
  });
  test(
    'Persistent database survives reopening and sessions require login',
    () async {
      final dir = await Directory.systemTemp.createTemp('bazaar-test-');
      final path = '${dir.path}/pos.sqlite';
      final first = PosStore(sqlite3.open(path), provisionAdmin: false);
      await setupOwner(first);
      final p = first.products.first;
      first.checkout({p.id: 1}, paymentMethod: 'cash', tendered: p.price);
      first.setLanguage('ku');
      first.dispose();
      final second = PosStore(sqlite3.open(path), provisionAdmin: false);
      expect(second.needsSetup, isFalse);
      expect(second.currentUser, isNull);
      expect(second.language, 'ku');
      expect(second.products.first.stock, p.stock - 1);
      expect(second.sales, hasLength(1));
      await second.login('owner', 'test-password');
      expect(second.isOwner, isTrue);
      second.dispose();
      await dir.delete(recursive: true);
    },
  );
}
