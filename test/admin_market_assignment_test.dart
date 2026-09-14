import 'package:Bazaar_POS/data/models.dart';
import 'package:Bazaar_POS/data/pos_store.dart';
import 'package:Bazaar_POS/main.dart';
import 'package:Bazaar_POS/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

// The widget test checks form wiring; the test below separately verifies real
// password derivation, persistence and login for the assigned market.
class AssignmentStore extends PosStore {
  AssignmentStore() : super(sqlite3.openInMemory(), provisionAdmin: false);
  String? assignedMarketId;
  UserRole? assignedRole;
  Set<CashierPermission>? assignedPermissions;
  MarketBranding? assignedBranding;
  @override
  Future<void> saveUser({
    Set<CashierPermission>? extraPermissions,
    MarketBranding? marketBranding,
    String? id,
    String? marketId,
    required String name,
    required String username,
    required UserRole role,
    required String password,
    required bool active,
  }) async {
    assignedMarketId = marketId;
    assignedRole = role;
    assignedPermissions = extraPermissions;
    assignedBranding = marketBranding;
  }
}

Future<void> setup(PosStore store) => store.setup(
  storeName: 'Original Market',
  name: 'Super',
  username: 'super',
  password: 'test-super-pass',
  currency: 'IQD',
  sampleProducts: false,
);

void main() {
  test('Only the super admin can create an admin assigned to another existing market', () async {
    final store = PosStore.memory(provisionAdmin: false);
    addTearDown(store.dispose);
    await setup(store);
    final branch = store.createMarket(name: 'Branch Market', currency: 'USD');
    await expectLater(
      store.saveUser(
        name: 'Invalid',
        username: 'invalid',
        role: UserRole.admin,
        password: 'test-admin-pass',
        active: true,
        marketId: 'missing',
      ),
      throwsA(isA<PosException>()),
    );
    await store.saveUser(
      name: 'Branch Admin',
      username: 'branch-admin',
      role: UserRole.admin,
      password: 'test-admin-pass',
      active: true,
      marketId: branch,
    );
    expect(store.activeMarketId, defaultMarketId);
    store.logout();
    await store.login('branch-admin', 'test-admin-pass');
    expect(store.activeMarketId, branch);
    expect(store.settings.name, 'Branch Market');
    expect(store.settings.currency, 'USD');
    for (final role in [UserRole.admin, UserRole.cashier]) {
      await expectLater(
        store.saveUser(
          name: 'Unauthorized',
          username: 'unauthorized',
          role: role,
          password: 'test-staff-pass',
          active: true,
          marketId: defaultMarketId,
        ),
        throwsA(
          isA<PosException>().having((e) => e.key, 'key', 'permissionDenied'),
        ),
      );
    }
    await store.saveUser(
      name: 'Local Sales',
      username: 'local-sales',
      role: UserRole.cashier,
      password: 'test-staff-pass',
      active: true,
    );
    expect(
      store.users.firstWhere((u) => u.username == 'local-sales').marketId,
      branch,
    );
  });

  testWidgets(
    'Add team member sends the selected market when creating an admin',
    (tester) async {
      final store = AssignmentStore();
      addTearDown(store.dispose);
      await tester.runAsync(() => setup(store));
      final branch = store.createMarket(name: 'Branch Market', currency: 'USD');
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(BazaarApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-team')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add team member'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('admin-market-selector')), findsNothing);
      for (final entry in {
        'fullName': 'Branch Admin',
        'username': 'branch-admin',
        'password': 'test-admin-pass',
      }.entries) {
        final field = find.byWidgetPredicate(
          (w) => w is Field && w.label == entry.key,
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
        await tester.pumpAndSettle();
      }
      final role = find.byType(DropdownButtonFormField<UserRole>);
      await tester.ensureVisible(role);
      await tester.pumpAndSettle();
      await tester.tap(role);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Admin').last);
      await tester.pumpAndSettle();
      final market = find.byKey(const ValueKey('admin-market-selector'));
      expect(market, findsOneWidget);
      await tester.ensureVisible(market);
      await tester.pumpAndSettle();
      await tester.tap(market);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Branch Market').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes').last);
      await tester.pumpAndSettle();
      expect(store.assignedMarketId, branch);
      expect(store.assignedRole, UserRole.admin);
      expect(store.activeMarketId, defaultMarketId);
      expect(find.byKey(const ValueKey('admin-market-selector')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Cashier form saves only selected extra permissions', (
    tester,
  ) async {
    final store = AssignmentStore();
    addTearDown(store.dispose);
    await tester.runAsync(() => setup(store));
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(BazaarApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-team')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add team member'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .every((c) => c.value == false),
      isTrue,
    );
    for (final entry in {
      'fullName': 'Cashier',
      'username': 'cashier',
      'password': 'cashier-password',
    }.entries) {
      final field = find.byWidgetPredicate(
        (w) => w is Field && w.label == entry.key,
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
      await tester.pumpAndSettle();
    }
    for (final permission in [
      CashierPermission.viewReports,
      CashierPermission.applyDiscounts,
    ]) {
      final checkbox = find.byKey(
        ValueKey('cashier-permission-${permission.name}'),
      );
      await tester.ensureVisible(checkbox);
      await tester.pumpAndSettle();
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Save changes').last);
    await tester.pumpAndSettle();
    expect(store.assignedRole, UserRole.cashier);
    expect(store.assignedPermissions, {
      CashierPermission.viewReports,
      CashierPermission.applyDiscounts,
    });
    expect(tester.takeException(), isNull);
  });
}
