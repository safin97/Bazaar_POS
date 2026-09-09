import 'dart:io';

import 'package:bazaar_pos/data/initial_admin.dart';
import 'package:bazaar_pos/data/models.dart';
import 'package:bazaar_pos/data/pos_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'A fresh store provisions the configured super admin without signing in',
    () {
      final store = PosStore.memory();
      addTearDown(store.dispose);
      final admin = store.users.single;
      expect(admin.username, 'safin97');
      expect(admin.role, UserRole.superManager);
      expect(admin.active, isTrue);
      expect(admin.passwordHash, initialAdminPasswordHash);
      expect(admin.salt, initialAdminSalt);
      expect(store.currentUser, isNull);
      expect(store.products, hasLength(12));
      expect(store.sales, isEmpty);
      expect(store.needsSetup, isFalse);
    },
  );

  test('Password revision upgrades a provisioned account and retains the store ledger', () async {
    final dir = await Directory.systemTemp.createTemp(
      'bazaar-admin-migration-',
    );
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/store.sqlite';
    final oldDb = sqlite3.open(path);
    final old = PosStore(oldDb, provisionAdmin: false);
    await old.setup(
      storeName: 'Existing Market',
      name: 'Original owner',
      username: 'owner',
      password: 'original-password',
      currency: 'IQD',
      sampleProducts: true,
    );
    await old.saveUser(
      name: 'Safin',
      username: initialAdminUsername,
      role: UserRole.cashier,
      password: 'previous-password',
      active: false,
    );
    final previous = old.users.firstWhere(
      (u) => u.username == initialAdminUsername,
    );
    final product = old.products.first;
    final sale = old.checkout(
      {product.id: 1},
      paymentMethod: 'cash',
      tendered: product.price,
    );
    old.setLanguage('ku');
    // Simulate a device that already applied the previous account migrations.
    for (final revision in [1, 2]) {
      oldDb.execute('INSERT INTO preferences (id, data) VALUES (?, ?)', [
        'super-admin-safin97-v$revision',
        '{"applied":true}',
      ]);
    }
    old.dispose();

    final upgraded = PosStore(sqlite3.open(path));
    addTearDown(upgraded.dispose);
    final admin = upgraded.users.firstWhere(
      (u) => u.username == initialAdminUsername,
    );
    expect(admin.id, previous.id);
    expect(admin.role, UserRole.superManager);
    expect(admin.active, isTrue);
    expect(admin.passwordHash, initialAdminPasswordHash);
    expect(upgraded.users, hasLength(2));
    expect(upgraded.settings.name, 'Existing Market');
    expect(upgraded.language, 'ku');
    expect(upgraded.sales.single.id, sale.id);
    expect(upgraded.products.first.stock, product.stock - 1);
    expect(upgraded.currentUser, isNull);
    await expectLater(
      upgraded.login(initialAdminUsername, 'previous-password'),
      throwsA(isA<PosException>()),
    );
  });

  test(
    'Provisioning is one-time and never restores edited or deleted credentials',
    () async {
      final dir = await Directory.systemTemp.createTemp('bazaar-admin-once-');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/store.sqlite';
      final old = PosStore(sqlite3.open(path), provisionAdmin: false);
      await old.setup(
        storeName: 'Market',
        name: 'Owner',
        username: 'owner',
        password: 'original-password',
        currency: 'IQD',
        sampleProducts: false,
      );
      old.dispose();

      final migrated = PosStore(sqlite3.open(path));
      await migrated.login('owner', 'original-password');
      final admin = migrated.users.firstWhere(
        (u) => u.username == initialAdminUsername,
      );
      await migrated.saveUser(
        id: admin.id,
        name: 'Safin',
        username: initialAdminUsername,
        role: UserRole.superManager,
        password: 'new-local-password',
        active: true,
      );
      final newHash = migrated.users
          .firstWhere((u) => u.id == admin.id)
          .passwordHash;
      migrated.dispose();

      final reopened = PosStore(sqlite3.open(path));
      expect(
        reopened.users.firstWhere((u) => u.id == admin.id).passwordHash,
        newHash,
      );
      await reopened.login(initialAdminUsername, 'new-local-password');
      expect(reopened.isOwner, isTrue);
      reopened.logout();
      await reopened.login('owner', 'original-password');
      reopened.deleteUser(admin.id);
      reopened.dispose();

      final again = PosStore(sqlite3.open(path));
      expect(
        again.users.any((u) => u.username == initialAdminUsername),
        isFalse,
      );
      again.dispose();
    },
  );
}
