import 'dart:convert';
import 'dart:io';

import 'package:Bazaar_POS/data/models.dart';
import 'package:Bazaar_POS/data/pos_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'admin_market_assignment_test.dart' show setup;

const logoPhoto =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=';
const backgroundPhoto =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
const artwork = MarketBranding(logo: logoPhoto, background: backgroundPhoto);

Future<void> addAdmin(
  PosStore store,
  String market, {
  String username = 'branch-admin',
  MarketBranding? branding = artwork,
}) => store.saveUser(
  name: 'Branch Admin',
  username: username,
  password: 'test-admin-pass',
  role: UserRole.admin,
  active: true,
  marketId: market,
  marketBranding: branding,
);

void main() {
  test(
    'Admin branding stays in its market across reopen and backup restore',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'bazaar-admin-branding-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/store.sqlite';
      var store = PosStore(sqlite3.open(path), provisionAdmin: false);
      addTearDown(() => store.dispose());
      await setup(store);
      final branch = store.createMarket(
        name: 'Branch',
        currency: 'USD',
        usdToIqdRate: 131000,
      );
      await addAdmin(store, branch);
      expect(store.settings.logo, isNull);
      expect(store.settings.background, isNull);
      expect(store.activeMarketId, defaultMarketId);
      // Adding another admin without choosing images retains the existing artwork.
      await addAdmin(store, branch, username: 'second-admin', branding: null);
      final backup = store.createBackup();
      store.dispose();
      store = PosStore(sqlite3.open(path), provisionAdmin: false);
      final branding = store.welcomeBrandingForUsername(' BRANCH-ADMIN ');
      expect(branding.logo, logoPhoto);
      expect(branding.background, backgroundPhoto);
      for (final username in ['', 'unknown', 'super']) {
        expect(store.welcomeBrandingForUsername(username).logo, isNull);
        expect(store.welcomeBrandingForUsername(username).background, isNull);
      }
      await store.login('branch-admin', 'test-admin-pass');
      expect(store.settings.logo, logoPhoto);
      expect(store.settings.background, backgroundPhoto);
      expect(store.settings.currency, 'USD');
      expect(store.settings.usdToIqdRate, 131000);
      store.saveProduct(
        Product(
          id: 'milk',
          marketId: branch,
          name: 'Milk',
          barcode: '123',
          category: store.categories.first.id,
          price: 100,
          cost: 50,
          stock: 3,
        ),
      );
      final sale = store.checkout(
        {'milk': 1},
        paymentMethod: 'cash',
        tendered: 100,
      );
      expect(sale.settings.logo, logoPhoto);
      expect(sale.settings.background, isNull);
      expect(store.sales.single.settings.background, isNull);
      expect(store.settings.background, backgroundPhoto);
      store.logout();
      await store.login('super', 'test-super-pass');
      store.restoreBackup(backup);
      await store.login('branch-admin', 'test-admin-pass');
      expect(store.settings.background, backgroundPhoto);
      expect(store.settings.logo, logoPhoto);
    },
  );

  test(
    'Invalid images, unauthorized branding and failed saves change nothing',
    () async {
      final db = sqlite3.openInMemory();
      final store = PosStore(db, provisionAdmin: false);
      addTearDown(store.dispose);
      await setup(store);
      final branch = store.createMarket(name: 'Branch', currency: 'USD');
      for (final bad in [
        const MarketBranding(logo: 'invalid'),
        const MarketBranding(background: 'invalid'),
        MarketBranding(background: 'A' * 2800001),
      ]) {
        await expectLater(
          addAdmin(store, branch, branding: bad),
          throwsA(isA<PosException>()),
        );
      }
      await expectLater(
        store.saveUser(
          name: 'Cashier',
          username: 'cashier',
          password: 'cashier-pass',
          role: UserRole.cashier,
          active: true,
          marketBranding: artwork,
        ),
        throwsA(isA<PosException>()),
      );
      // Force failure after the user INSERT to verify the shared transaction rolls back.
      db.execute(
        "CREATE TRIGGER fail_branding BEFORE UPDATE ON markets BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      await expectLater(
        addAdmin(store, branch),
        throwsA(isA<SqliteException>()),
      );
      expect(db.select('SELECT id FROM users'), hasLength(1));
      expect(
        store.markets.firstWhere((m) => m.id == branch).settings.logo,
        isNull,
      );
      db.execute('DROP TRIGGER fail_branding');
      await addAdmin(store, branch);
      await expectLater(
        addAdmin(store, branch, branding: const MarketBranding()),
        throwsA(isA<PosException>()),
      );
      expect(
        store.markets.firstWhere((m) => m.id == branch).settings.background,
        backgroundPhoto,
      );
      store.logout();
      await store.login('branch-admin', 'test-admin-pass');
      await expectLater(
        store.saveUser(
          name: 'Cashier',
          username: 'cashier',
          password: 'cashier-pass',
          role: UserRole.cashier,
          active: true,
          marketBranding: artwork,
        ),
        throwsA(isA<PosException>()),
      );
      expect(store.settings.background, backgroundPhoto);
    },
  );

  test('Clearing images restores defaults and malformed backup artwork is rejected', () async {
    final store = PosStore.memory(provisionAdmin: false);
    addTearDown(store.dispose);
    await setup(store);
    await addAdmin(store, defaultMarketId);
    final backup = jsonDecode(utf8.decode(store.createBackup()));
    backup['tables']['markets'][0]['data']['settings']['background'] =
        'invalid';
    expect(
      () => store.validateBackup(utf8.encode(jsonEncode(backup))),
      throwsA(isA<PosException>()),
    );
    final user = store.users.firstWhere((u) => u.username == 'branch-admin');
    await store.saveUser(
      id: user.id,
      name: user.name,
      username: user.username,
      role: user.role,
      password: '',
      active: true,
      marketBranding: const MarketBranding(),
    );
    expect(store.settings.logo, isNull);
    expect(store.settings.background, isNull);
    final legacy = const StoreSettings().toJson()..remove('background');
    expect(StoreSettings.fromJson(legacy).background, isNull);
  });
}
