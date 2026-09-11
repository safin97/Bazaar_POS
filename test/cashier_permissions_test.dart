import 'dart:io';

import 'package:Bazaar_POS/data/models.dart';
import 'package:Bazaar_POS/data/pos_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

Matcher get denied =>
    isA<PosException>().having((e) => e.key, 'key', 'permissionDenied');
Future<void> setup(PosStore store) => store.setup(
  storeName: 'Market',
  name: 'Super',
  username: 'super',
  password: 'test-super-pass',
  currency: 'IQD',
  sampleProducts: true,
);

void main() {
  test('Granted cashier actions stay in the assigned market, persist, and can be revoked', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cashier-permissions-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/store.sqlite';
    final store = PosStore(sqlite3.open(path), provisionAdmin: false);
    await setup(store);
    final product = store.products.first;
    final managerSale = store.checkout(
      {product.id: 1},
      paymentMethod: 'cash',
      tendered: product.price,
    );
    final otherMarket = store.createMarket(
      name: 'Other Market',
      currency: 'USD',
    );
    await store.saveUser(
      name: 'Cashier',
      username: 'cashier',
      role: UserRole.cashier,
      password: 'cashier-password',
      active: true,
      extraPermissions: CashierPermission.values.toSet(),
    );
    final cashier = store.users.firstWhere((u) => u.username == 'cashier');
    store.dispose();

    final reopened = PosStore(sqlite3.open(path), provisionAdmin: false);
    await reopened.login('cashier', 'cashier-password');
    expect(
      reopened.currentUser!.extraPermissions,
      CashierPermission.values.toSet(),
    );
    expect(reopened.isManager, isFalse);
    expect(reopened.canViewReports, isTrue);
    expect(reopened.sales.single.id, managerSale.id);
    expect(
      reopened.exportSalesCsv(reopened.sales),
      contains(managerSale.number),
    );
    final category = ProductCategory(id: 'new-category', name: 'New category');
    reopened.saveCategory(category);
    reopened.saveProduct(Product.fromJson({...product.toJson(), 'stock': 20}));
    final sale = reopened.checkout(
      {product.id: 2},
      discount: 100,
      paymentMethod: 'cash',
      tendered: product.price * 2,
    );
    expect(sale.discount, 100);
    reopened.voidSale(sale.id, 'Return');
    expect(reopened.products.first.stock, 20);
    reopened.deleteCategory(category.id);
    for (final action in <void Function()>[
      () => reopened.switchMarket(otherMarket),
      () => reopened.createMarket(name: 'Not allowed', currency: 'USD'),
      () => reopened.saveSettings(reopened.settings),
      () => reopened.deleteUser(cashier.id),
    ]) {
      expect(action, throwsA(denied));
    }
    await expectLater(
      reopened.saveUser(
        id: cashier.id,
        name: 'Cashier',
        username: 'cashier',
        role: UserRole.admin,
        password: '',
        active: true,
      ),
      throwsA(denied),
    );
    reopened.logout();
    await reopened.login('super', 'test-super-pass');
    await reopened.saveUser(
      id: cashier.id,
      name: 'Cashier renamed',
      username: 'cashier',
      role: UserRole.cashier,
      password: '',
      active: true,
    );
    expect(
      reopened.users.firstWhere((u) => u.id == cashier.id).extraPermissions,
      CashierPermission.values.toSet(),
    );
    await reopened.saveUser(
      id: cashier.id,
      name: 'Cashier',
      username: 'cashier',
      role: UserRole.cashier,
      password: '',
      active: true,
      extraPermissions: {},
    );
    reopened.dispose();

    final revoked = PosStore(sqlite3.open(path), provisionAdmin: false);
    addTearDown(revoked.dispose);
    await revoked.login('cashier', 'cashier-password');
    expect(revoked.currentUser!.extraPermissions, isEmpty);
    expect(revoked.canViewReports, isFalse);
    expect(revoked.canManageCatalog, isFalse);
    expect(revoked.canDiscount, isFalse);
    expect(revoked.canVoidSales, isFalse);
    expect(revoked.sales.any((s) => s.id == managerSale.id), isFalse);
    expect(() => revoked.saveProduct(product), throwsA(denied));
    expect(() => revoked.saveCategory(category), throwsA(denied));
    expect(() => revoked.exportSalesCsv(revoked.sales), throwsA(denied));
    expect(
      () => revoked.voidSale(managerSale.id, 'Not allowed'),
      throwsA(denied),
    );
    expect(
      () => revoked.checkout(
        {product.id: 1},
        discount: 1,
        paymentMethod: 'cash',
        tendered: product.price,
      ),
      throwsA(denied),
    );
  });

  test(
    'Admins can grant individual permissions without granting other powers',
    () async {
      final store = PosStore.memory(provisionAdmin: false);
      addTearDown(store.dispose);
      await setup(store);
      await store.saveUser(
        name: 'Admin',
        username: 'admin',
        role: UserRole.admin,
        password: 'admin-password',
        active: true,
      );
      for (final permission in CashierPermission.values) {
        store.logout();
        await store.login('admin', 'admin-password');
        await store.saveUser(
          name: permission.name,
          username: permission.name.toLowerCase(),
          role: UserRole.cashier,
          password: 'cashier-password',
          active: true,
          extraPermissions: {permission},
        );
        store.logout();
        await store.login(permission.name.toLowerCase(), 'cashier-password');
        expect(
          store.canViewReports,
          permission == CashierPermission.viewReports,
        );
        expect(
          store.canManageCatalog,
          permission == CashierPermission.manageCatalog,
        );
        expect(
          store.canDiscount,
          permission == CashierPermission.applyDiscounts,
        );
        expect(store.canVoidSales, permission == CashierPermission.voidSales);
        expect(store.canManageBrand, isFalse);
        expect(store.isManager, isFalse);
      }
    },
  );
}
