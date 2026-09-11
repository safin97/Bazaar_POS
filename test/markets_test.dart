import 'dart:convert';
import 'dart:io';

import 'package:Bazaar_POS/data/models.dart';
import 'package:Bazaar_POS/data/pos_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

const _photo =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l1sAAAAASUVORK5CYII=';
const _otherPhoto =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

Matcher _error(String key) =>
    isA<PosException>().having((error) => error.key, 'key', key);

Future<void> _setup(PosStore store, {bool samples = false}) => store.setup(
  storeName: 'First Market',
  name: 'Super Admin',
  username: 'superadmin',
  password: 'super-password',
  currency: 'USD',
  sampleProducts: samples,
);

Future<void> _user(PosStore store, String username, UserRole role) =>
    store.saveUser(
      name: username,
      username: username,
      role: role,
      password: 'staff-password',
      active: true,
    );

Product _product(
  PosStore store,
  String id, {
  String? category,
  String? photo,
}) => Product(
  id: id,
  marketId: store.activeMarketId,
  name: 'Milk $id',
  barcode: 'shared-barcode',
  category: category ?? store.categories.first.id,
  price: 350,
  cost: 200,
  stock: 20,
  emoji: '🥛',
  photo: photo,
);

void main() {
  test(
    'Two market admins have separate staff, catalog, branding and receipts',
    () async {
      final store = PosStore.memory(provisionAdmin: false);
      addTearDown(store.dispose);
      await _setup(store);
      await _user(store, 'admin-one', UserRole.admin);
      final firstProduct = _product(store, 'product-one');
      store.saveProduct(firstProduct);
      final secondMarket = store.createMarket(
        name: 'Second Market',
        currency: 'IQD',
      );
      store.switchMarket(secondMarket);
      expect(store.products, isEmpty);
      expect(store.sales, isEmpty);
      await _user(store, 'admin-two', UserRole.admin);
      final secondProduct = _product(store, 'product-two');
      store.saveProduct(secondProduct);
      // A physical barcode can be used independently by both markets.
      expect(secondProduct.barcode, firstProduct.barcode);
      final foreignCategory = store.categories.first;
      store.logout();

      await store.login('admin-one', 'staff-password');
      expect(store.activeMarketId, defaultMarketId);
      expect(store.markets.single.id, defaultMarketId);
      expect(store.products.single.id, firstProduct.id);
      expect(store.users.any((user) => user.username == 'admin-two'), isFalse);
      expect(
        () => store.switchMarket(secondMarket),
        throwsA(_error('permissionDenied')),
      );
      expect(
        () => store.createMarket(name: 'Unauthorized', currency: 'USD'),
        throwsA(_error('permissionDenied')),
      );
      expect(
        () => store.saveProduct(secondProduct),
        throwsA(_error('permissionDenied')),
      );
      expect(
        () => store.saveProduct(
          Product.fromJson({
            ...secondProduct.toJson(),
            'marketId': defaultMarketId,
            'category': store.categories.first.id,
          }),
        ),
        throwsA(_error('permissionDenied')),
      );
      expect(
        () => store.saveCategory(foreignCategory),
        throwsA(_error('permissionDenied')),
      );
      store.deleteProduct(secondProduct.id);
      await _user(store, 'sales-one', UserRole.cashier);
      expect(
        store.users.firstWhere((user) => user.username == 'sales-one').marketId,
        defaultMarketId,
      );
      store.saveSettings(
        StoreSettings.fromJson({
          ...store.settings.toJson(),
          'name': 'One Groceries',
          'address': 'First address',
          'phone': '111',
          'logo': _photo,
          'receiptHeader': 'One receipt',
          'receiptFooter': 'Thanks from One',
        }),
      );
      final firstSale = store.checkout(
        {firstProduct.id: 2},
        discount: 50,
        paymentMethod: 'cash',
        tendered: 700,
      );
      store.saveSettings(
        StoreSettings.fromJson({
          ...store.settings.toJson(),
          'name': 'One Groceries New Name',
          'logo': _otherPhoto,
          'receiptFooter': 'New footer',
        }),
      );
      expect(firstSale.cashierName, 'admin-one');
      expect(firstSale.marketId, defaultMarketId);
      expect(store.sales.single.settings.name, 'One Groceries');
      expect(store.sales.single.settings.logo, _photo);
      expect(store.sales.single.settings.receiptFooter, 'Thanks from One');
      expect(store.sales.single.settings.currency, 'USD');
      store.logout();

      await store.login('admin-two', 'staff-password');
      expect(store.activeMarketId, secondMarket);
      expect(store.products.single.id, secondProduct.id);
      expect(store.products.single.stock, secondProduct.stock);
      expect(store.sales, isEmpty);
      expect(store.settings.name, 'Second Market');
      expect(store.users.any((user) => user.username == 'sales-one'), isFalse);
      store.saveSettings(
        StoreSettings.fromJson({
          ...store.settings.toJson(),
          'name': 'Two Groceries',
          'address': 'Second address',
          'phone': '222',
          'logo': _otherPhoto,
          'receiptHeader': 'Two receipt',
        }),
      );
      final secondSale = store.checkout(
        {secondProduct.id: 1},
        paymentMethod: 'cash',
        tendered: secondProduct.price,
      );
      expect(secondSale.settings.currency, 'IQD');
      expect(secondSale.settings.logo, _otherPhoto);
      expect(secondSale.settings.address, 'Second address');
      expect(secondSale.cashierName, 'admin-two');
      expect(
        () => store.voidSale(firstSale.id, 'Foreign sale'),
        throwsA(_error('invalidVoid')),
      );
      expect(
        () => store.exportSalesCsv([firstSale]),
        throwsA(_error('permissionDenied')),
      );
      store.logout();
      await store.login('superadmin', 'super-password');
      expect(store.markets, hasLength(2));
      expect(store.settings.name, 'One Groceries New Name');
      expect(store.sales.single.id, firstSale.id);
      store.switchMarket(secondMarket);
      expect(store.settings.name, 'Two Groceries');
      expect(store.sales.single.id, secondSale.id);
    },
  );

  test(
    'Market owners can report and export their market but cannot mutate it',
    () async {
      final store = PosStore.memory(provisionAdmin: false);
      addTearDown(store.dispose);
      await _setup(store);
      await _user(store, 'market-owner', UserRole.marketOwner);
      final product = _product(store, 'owner-product');
      store.saveProduct(product);
      final sale = store.checkout(
        {product.id: 3},
        discount: 50,
        paymentMethod: 'card',
        tendered: 1000,
      );
      final foreignMarket = store.createMarket(
        name: 'Other Market',
        currency: 'USD',
      );
      store.switchMarket(foreignMarket);
      final foreignProduct = _product(store, 'foreign-product');
      store.saveProduct(foreignProduct);
      final foreignSale = store.checkout(
        {foreignProduct.id: 1},
        paymentMethod: 'cash',
        tendered: foreignProduct.price,
      );
      store.logout();
      await store.login('market-owner', 'staff-password');
      expect(store.canViewReports, isTrue);
      expect(store.canCheckout, isFalse);
      expect(store.isManager, isFalse);
      expect(store.isOwner, isFalse);
      expect(store.canManageBrand, isFalse);
      expect(store.sales.single.id, sale.id);
      expect(store.visibleSales.single.cashierName, 'Super Admin');
      expect(store.visibleSales.single.lines.single.quantity, 3);
      expect(sale.subtotal - sale.discount - sale.cost, 400);
      final csv = store.exportSalesCsv(store.visibleSales);
      expect(csv, contains('Super Admin'));
      expect(csv, contains('USD'));
      expect(csv, contains('10.00'));
      expect(
        () => store.exportSalesCsv([foreignSale]),
        throwsA(_error('permissionDenied')),
      );
      expect(
        () => store.checkout(
          {product.id: 1},
          paymentMethod: 'cash',
          tendered: 350,
        ),
        throwsA(_error('permissionDenied')),
      );
      for (final mutate in <void Function()>[
        () => store.saveProduct(product),
        () => store.deleteProduct(product.id),
        () => store.saveCategory(store.categories.first),
        () => store.deleteCategory(store.categories.first.id),
        () => store.saveSettings(store.settings),
        () => store.deleteUser(store.currentUser!.id),
        () => store.voidSale(sale.id, 'Owner cannot void'),
        () => store.switchMarket(foreignMarket),
        () => store.createMarket(name: 'Unauthorized', currency: 'USD'),
      ]) {
        expect(mutate, throwsA(_error('permissionDenied')));
      }
      await expectLater(
        _user(store, 'unauthorized-user', UserRole.cashier),
        throwsA(_error('permissionDenied')),
      );
      expect(store.products.single.stock, 17);
      expect(store.sales.single.voided, isFalse);
    },
  );

  test(
    'Legacy records migrate to default market and new category media persist',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'Market_Bazaars-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/store.sqlite';
      final original = PosStore(sqlite3.open(path), provisionAdmin: false);
      await _setup(original, samples: true);
      final originalProduct = original.products.first;
      final originalSale = original.checkout(
        {originalProduct.id: 1},
        paymentMethod: 'cash',
        tendered: originalProduct.price,
      );
      final originalUser = original.currentUser!;
      final originalSettings = original.settings;
      original.dispose();

      // Recreate the JSON and preferences layout from before markets existed.
      final legacy = sqlite3.open(path);
      for (final table in ['products', 'users', 'sales']) {
        for (final row in legacy.select('SELECT id, data FROM $table')) {
          final json =
              jsonDecode(row['data'] as String) as Map<String, dynamic>;
          json.remove('marketId');
          if (table == 'products') json.remove('photo');
          legacy.execute('UPDATE $table SET data = ? WHERE id = ?', [
            jsonEncode(json),
            row['id'],
          ]);
        }
      }
      legacy.execute('DROP TABLE markets');
      legacy.execute('DROP TABLE categories');
      legacy.execute('ALTER TABLE audit DROP COLUMN marketId');
      legacy.execute(
        "DELETE FROM preferences WHERE id = 'market-categories-v1'",
      );
      legacy.execute(
        'INSERT OR REPLACE INTO preferences (id, data) VALUES (?, ?)',
        ['settings', jsonEncode(originalSettings.toJson())],
      );
      legacy.close();

      final upgraded = PosStore(sqlite3.open(path), provisionAdmin: false);
      await upgraded.login('superadmin', 'super-password');
      expect(upgraded.activeMarketId, defaultMarketId);
      expect(upgraded.users.single.id, originalUser.id);
      expect(upgraded.users.single.marketId, defaultMarketId);
      expect(upgraded.products, hasLength(12));
      expect(
        upgraded.products.every((p) => p.marketId == defaultMarketId),
        isTrue,
      );
      expect(upgraded.products.first.photo, isNull);
      expect(upgraded.sales.single.id, originalSale.id);
      expect(upgraded.sales.single.marketId, defaultMarketId);
      expect(upgraded.settings.name, originalSettings.name);
      expect(upgraded.settings.currency, originalSettings.currency);
      expect(upgraded.audit, isNotEmpty);
      expect(
        upgraded.categories.any((c) => c.id == originalProduct.category),
        isTrue,
      );

      final newMarket = upgraded.createMarket(
        name: 'New Market',
        currency: 'USD',
      );
      upgraded.switchMarket(newMarket);
      final category = ProductCategory(
        id: 'custom-category',
        marketId: newMarket,
        name: 'Fresh food',
        arabicName: 'طعام طازج',
        kurdishName: 'خوارنا تازە',
        emoji: '🥬',
        photo: _photo,
      );
      upgraded.saveCategory(category);
      upgraded.saveCategory(
        ProductCategory.fromJson({
          ...category.toJson(),
          'name': 'Fresh produce',
          'emoji': '🍎',
          'photo': _otherPhoto,
        }),
      );
      final mediaProduct = _product(
        upgraded,
        'media-product',
        category: category.id,
        photo: _photo,
      );
      upgraded.saveProduct(mediaProduct);
      expect(
        () => upgraded.deleteCategory(category.id),
        throwsA(_error('categoryInUse')),
      );
      expect(
        () => upgraded.saveCategory(
          ProductCategory.fromJson({
            ...category.toJson(),
            'id': 'invalid-image',
            'name': 'Invalid image',
            'photo': base64Encode(utf8.encode('not an image')),
          }),
        ),
        throwsA(_error('invalidPhoto')),
      );
      final temporaryCategory = ProductCategory(
        id: 'temporary-category',
        name: 'Temporary',
        marketId: newMarket,
      );
      upgraded.saveCategory(temporaryCategory);
      upgraded.deleteCategory(temporaryCategory.id);
      expect(
        upgraded.categories.any((c) => c.id == temporaryCategory.id),
        isFalse,
      );
      upgraded.dispose();

      final reopened = PosStore(sqlite3.open(path), provisionAdmin: false);
      addTearDown(reopened.dispose);
      await reopened.login('superadmin', 'super-password');
      expect(reopened.markets, hasLength(2));
      expect(reopened.products, hasLength(12));
      expect(reopened.sales.single.id, originalSale.id);
      expect(reopened.sales.single.settings.name, originalSettings.name);
      reopened.switchMarket(newMarket);
      expect(reopened.settings.name, 'New Market');
      expect(reopened.sales, isEmpty);
      final savedCategory = reopened.categories.firstWhere(
        (c) => c.id == category.id,
      );
      expect(savedCategory.name, 'Fresh produce');
      expect(savedCategory.arabicName, category.arabicName);
      expect(savedCategory.kurdishName, category.kurdishName);
      expect(savedCategory.photo, _otherPhoto);
      expect(savedCategory.emoji, '🍎');
      expect(reopened.products.single.photo, _photo);
      expect(reopened.products.single.emoji, '🥛');
      expect(reopened.products.single.marketId, newMarket);
      expect(
        reopened.categories.any((c) => c.id == temporaryCategory.id),
        isFalse,
      );
      reopened.deleteProduct(mediaProduct.id);
      reopened.deleteCategory(category.id);
      expect(reopened.categories.any((c) => c.id == category.id), isFalse);
    },
  );
}
