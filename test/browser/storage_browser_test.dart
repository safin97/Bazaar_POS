@TestOn('browser')
library;

import 'package:Bazaar_POS/data/models.dart';
import 'package:Bazaar_POS/data/pos_store.dart';
import 'package:Bazaar_POS/main.dart';
import 'package:Bazaar_POS/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/wasm.dart';

void main() {
  testWidgets(
    'Browser storage opens and reaches the super admin login screen',
    (tester) async {
      final store = await tester.runAsync(PosStore.open);
      expect(store, isNotNull);
      addTearDown(store!.dispose);
      expect(store.users.any((user) => user.username == 'safin97'), isTrue);
      expect(store.currentUser, isNull);
      await tester.pumpWidget(BazaarApp(store: store));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('login-username')), findsOneWidget);
      expect(find.byKey(const ValueKey('login-password')), findsOneWidget);
      expect(find.text('Unable to open local storage'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Browser IDs support staff creation, authentication and checkout',
    () async {
      final sqlite = await WasmSqlite3.loadFromUrl(
        Uri.base.resolve('sqlite3.wasm'),
      );
      sqlite.registerVirtualFileSystem(InMemoryFileSystem(), makeDefault: true);
      final store = PosStore(sqlite.openInMemory(), provisionAdmin: false);
      addTearDown(store.dispose);
      await store.setup(
        storeName: 'Browser test market',
        name: 'Test owner',
        username: 'test-owner',
        password: 'browser-owner-test-password',
        currency: 'IQD',
        sampleProducts: true,
      );
      await store.saveUser(
        name: 'Test cashier',
        username: 'test-cashier',
        role: UserRole.cashier,
        password: 'browser-cashier-test-password',
        active: true,
      );
      store.logout();
      await store.login('test-cashier', 'browser-cashier-test-password');
      final product = store.products.first;
      final sale = store.checkout(
        {product.id: 1},
        paymentMethod: 'cash',
        tendered: product.price,
      );
      expect(sale.id, isNotEmpty);
      expect(sale.cashierName, 'Test cashier');
      expect(store.sales.single.id, sale.id);
      expect(store.products.first.stock, product.stock - 1);
    },
  );
  test(
    'Browser markets keep dollar sales and owner reports separate',
    () async {
      final sqlite = await WasmSqlite3.loadFromUrl(
        Uri.base.resolve('sqlite3.wasm'),
      );
      sqlite.registerVirtualFileSystem(InMemoryFileSystem(), makeDefault: true);
      final store = PosStore(sqlite.openInMemory(), provisionAdmin: false);
      addTearDown(store.dispose);
      await store.setup(
        storeName: 'Local Market',
        name: 'Super',
        username: 'super',
        password: 'test-super-password',
        currency: 'IQD',
        sampleProducts: false,
      );
      final usdMarket = store.createMarket(
        name: 'Dollar Market',
        currency: 'USD',
      );
      store.switchMarket(usdMarket);
      await store.saveUser(
        name: 'Market Owner',
        username: 'owner',
        role: UserRole.marketOwner,
        password: 'test-owner-password',
        active: true,
      );
      final category = ProductCategory(
        id: PosStore.newId(),
        name: 'Custom category',
        marketId: usdMarket,
        emoji: '🥛',
      );
      store.saveCategory(category);
      final product = Product(
        id: PosStore.newId(),
        name: 'Milk',
        barcode: '123',
        category: category.id,
        marketId: usdMarket,
        price: 350,
        cost: 200,
        stock: 10,
        photo: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l1sAAAAASUVORK5CYII=',
      );
      store.saveProduct(product);
      final sale = store.checkout(
        {product.id: 2},
        paymentMethod: 'cash',
        tendered: 1000,
      );
      expect(sale.settings.currency, 'USD');
      expect(sale.change, 300);
      expect(sale.subtotal - sale.cost, 300);
      expect(store.products.single.photo, product.photo);
      store.switchMarket(defaultMarketId);
      expect(store.sales, isEmpty);
      expect(store.products, isEmpty);
      store.logout();
      await store.login('owner', 'test-owner-password');
      expect(store.activeMarketId, usdMarket);
      expect(store.canViewReports, isTrue);
      expect(store.visibleSales.single.cashierName, 'Super');
      expect(store.canCheckout, isFalse);
      expect(
        () => store.switchMarket(defaultMarketId),
        throwsA(isA<PosException>()),
      );
      expect(() => store.saveCategory(category), throwsA(isA<PosException>()));
    },
  );
}
