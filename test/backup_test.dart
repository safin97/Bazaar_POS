import 'dart:convert';
import 'dart:typed_data';

import 'package:bazaar_pos/data/models.dart';
import 'package:bazaar_pos/data/pos_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'market_currency_display_test.dart' show createStore, logo;

void main() {
  test(
    'backup restores all markets, media, rates, sales, accounts and settings',
    () async {
      final store = await createStore();
      addTearDown(store.dispose);
      final market = store.createMarket(
        name: 'Second',
        currency: 'IQD',
        logo: logo,
        usdToIqdRate: 131000,
      );
      store.switchMarket(market);
      store.saveProduct(
        Product(
          id: 'milk',
          marketId: market,
          name: 'Milk',
          barcode: '123',
          category: store.categories.first.id,
          price: 327500,
          cost: 100000,
          stock: 4,
        ),
      );
      final sale = store.checkout(
        {'milk': 2},
        paymentMethod: 'cash',
        tendered: 700000,
      );
      store.setLanguage('ku');
      final backup = store.createBackup();
      store.createMarket(name: 'Added after backup', currency: 'EUR');
      store.restoreBackup(backup);
      expect(store.currentUser, isNull);
      await store.login('owner', 'test-password');
      expect(store.markets, hasLength(2));
      store.switchMarket(market);
      expect(store.settings.logo, logo);
      expect(store.settings.usdToIqdRate, 131000);
      expect(store.products.single.stock, 2);
      expect(store.sales.single.id, sale.id);
      expect(store.sales.single.tendered, 700000);
      expect(store.language, 'ku');
      expect(store.audit, isNotEmpty);
    },
  );

  test(
    'malformed, incomplete and unsupported backups never replace current data',
    () async {
      final store = await createStore();
      addTearDown(store.dispose);
      final baseline =
          jsonDecode(utf8.decode(store.createBackup())) as Map<String, dynamic>;
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (data) => data['version'] = 999,
        (data) => (data['tables'] as Map).remove('products'),
        (data) => data['tables']['users'] = [],
        (data) => data['tables']['markets'] = [],
        (data) =>
            data['tables']['markets'][0]['data']['settings']['usdToIqdRate'] =
                -1,
        (data) =>
            data['tables']['users'][0]['data']['passwordHash'] = 'invalid',
      ]) {
        final changed =
            jsonDecode(jsonEncode(baseline)) as Map<String, dynamic>;
        mutate(changed);
        expect(
          () => store.restoreBackup(
            Uint8List.fromList(utf8.encode(jsonEncode(changed))),
          ),
          throwsA(isA<PosException>()),
        );
        expect(store.currentUser!.username, 'owner');
        expect(store.settings.name, 'Original');
        expect(store.markets, hasLength(1));
      }
      expect(
        () => store.restoreBackup(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<PosException>()),
      );
    },
  );

  test(
    'only super managers can read or replace complete-device backups',
    () async {
      final store = await createStore();
      addTearDown(store.dispose);
      await store.saveUser(
        name: 'Admin',
        username: 'admin',
        role: UserRole.admin,
        password: 'admin-password',
        active: true,
      );
      final backup = store.createBackup();
      store.logout();
      await store.login('admin', 'admin-password');
      expect(() => store.createBackup(), throwsA(isA<PosException>()));
      expect(() => store.validateBackup(backup), throwsA(isA<PosException>()));
      expect(() => store.restoreBackup(backup), throwsA(isA<PosException>()));
    },
  );
}
