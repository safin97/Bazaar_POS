import 'dart:convert';
import 'dart:ui' as ui;

import 'package:Bazaar_POS/data/models.dart';
import 'package:Bazaar_POS/data/pos_store.dart';
import 'package:Bazaar_POS/main.dart';
import 'package:Bazaar_POS/screens/inventory_screen.dart';
import 'package:Bazaar_POS/widgets/photo_picker.dart';
import 'package:Bazaar_POS/widgets/common.dart';
import 'package:Bazaar_POS/widgets/receipt.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _PhotoFiles extends FilePicker {
  Uint8List? bytes;
  bool cancel = false;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => cancel
      ? null
      : FilePickerResult([
          PlatformFile(name: 'photo.png', size: bytes!.length, bytes: bytes),
        ]);
}

Future<void> _setup(PosStore store) => store.setup(
  storeName: 'Test Market',
  name: 'Test Seller',
  username: 'super',
  password: 'test-super-password',
  currency: 'IQD',
  sampleProducts: false,
);

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final field = find.byWidgetPredicate(
    (widget) => widget is Field && widget.label == label,
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Category upload overrides product art and removal restores it', (
    tester,
  ) async {
    final store = PosStore.memory(provisionAdmin: false);
    addTearDown(store.dispose);
    const photo =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=';
    await tester.runAsync(() async {
      await _setup(store);
      store.saveCategory(
        const ProductCategory(id: 'shared', name: 'Shared', photo: photo),
      );
      for (final id in ['one', 'two']) {
        store.saveProduct(
          Product(
            id: id,
            name: id,
            barcode: id,
            category: 'shared',
            emoji: '🍿',
            price: 100,
            cost: 50,
            stock: 10,
          ),
        );
      }
    });
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(BazaarApp(store: store));
    await tester.pumpAndSettle();
    final art = find.descendant(
      of: find.byType(CatalogProductArt),
      matching: find.byType(ProductArt),
    );
    expect(art, findsNWidgets(2));
    expect(
      tester.widgetList<ProductArt>(art).every((a) => a.photo == photo),
      isTrue,
    );
    store.saveCategory(const ProductCategory(id: 'shared', name: 'Shared'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<ProductArt>(art)
          .every((a) => a.photo == null && a.emoji == '🍿'),
      isTrue,
    );
    store.saveCategory(
      const ProductCategory(id: 'shared', name: 'Shared', photo: photo),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-inventory')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('one').first);
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('use-category-icon'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    final custom = find.byKey(const ValueKey('custom-product-icon'));
    await tester.ensureVisible(custom);
    await tester.enterText(custom, '🍪');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes').last);
    await tester.pumpAndSettle();
    final saved = store.products.firstWhere((p) => p.id == 'one');
    expect(saved.useCategoryIcon, isFalse);
    expect(
      Product.fromJson(saved.toJson()).withStock(9).useCategoryIcon,
      isFalse,
    );
    expect(saved.emoji, '🍪');
    final icons = tester.widgetList<ProductArt>(art).toList();
    expect(icons.where((a) => a.photo == photo), hasLength(1));
    expect(
      icons.where((a) => a.photo == null && a.emoji == '🍪'),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Cashiers can browse inventory without editing at desktop and mobile sizes',
    (tester) async {
      final store = PosStore.memory(provisionAdmin: false);
      addTearDown(store.dispose);
      await tester.runAsync(() async {
        await store.setup(
          storeName: 'Market',
          name: 'Super',
          username: 'super',
          password: 'test-password',
          currency: 'USD',
          sampleProducts: true,
        );
        await store.saveUser(
          name: 'Cashier',
          username: 'cashier',
          password: 'cashier-password',
          role: UserRole.cashier,
          active: true,
        );
        store.logout();
        await store.login('cashier', 'cashier-password');
      });
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(1440, 1000);
      await tester.pumpWidget(BazaarApp(store: store));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav-inventory')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-categories')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('nav-inventory')));
      await tester.pumpAndSettle();
      for (final width in [1440.0, 390.0]) {
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpAndSettle();
        expect(find.text('Add product'), findsNothing);
        expect(
          find.descendant(
            of: find.byType(InventoryScreen),
            matching: find.byType(PopupMenuButton<String>),
          ),
          findsNothing,
        );
        expect(find.text('Stock value'), findsNothing);
        expect(tester.takeException(), isNull);
      }
      expect(store.canViewInventory, isTrue);
      expect(store.canManageCatalog, isFalse);
    },
  );

  test(
    'Photo import preserves aspect ratio, encodes PNG and handles cancellation',
    () async {
      final picker = _PhotoFiles();
      FilePicker.platform = picker;
      picker.bytes = (await rootBundle.load('assets/branding/shop-logo.png'))
          .buffer
          .asUint8List();
      final photo = await pickItemPhoto();
      expect(photo, isNotNull);
      final codec = await ui.instantiateImageCodec(base64Decode(photo!));
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 512);
      expect(frame.image.height, 490);
      frame.image.dispose();
      codec.dispose();
      picker.cancel = true;
      expect(await pickItemPhoto(), isNull);
      picker.cancel = false;
      picker.bytes = Uint8List.fromList([1, 2, 3]);
      await expectLater(pickItemPhoto(), throwsA(isA<PosException>()));
    },
  );

  testWidgets(
    'Super admin creates a dollar market, custom category and product through the UI',
    (tester) async {
      final store = PosStore.memory(provisionAdmin: false);
      addTearDown(store.dispose);
      await tester.runAsync(() => _setup(store));
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(BazaarApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-markets')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-market')));
      await tester.pumpAndSettle();
      await _enter(tester, 'storeName', 'Dollar Market');
      await tester.tap(find.text('Save changes').last);
      await tester.pumpAndSettle();
      expect(store.settings.name, 'Dollar Market');
      expect(store.settings.currency, 'USD');
      expect(store.activeMarketId, isNot(defaultMarketId));
      await tester.tap(find.byKey(const ValueKey('nav-categories')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add category'));
      await tester.pumpAndSettle();
      await _enter(tester, 'categoryName', 'Snacks');
      await tester.ensureVisible(find.byTooltip('🍎'));
      await tester.tap(find.byTooltip('🍎'));
      final customIcon = find.byKey(const ValueKey('custom-category-icon'));
      await tester.ensureVisible(customIcon);
      await tester.enterText(customIcon, '🍿');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes').last);
      await tester.pumpAndSettle();
      final category = store.categories.firstWhere((c) => c.name == 'Snacks');
      expect(category.emoji, '🍿');
      await tester.tap(find.byKey(const ValueKey('nav-inventory')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add product'));
      await tester.pumpAndSettle();
      await _enter(tester, 'productName', 'Snack Pack');
      await _enter(tester, 'barcode', '123456');
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Snacks').last);
      await tester.pumpAndSettle();
      await _enter(tester, 'price', '4.25');
      await _enter(tester, 'cost', '2.00');
      await _enter(tester, 'stock', '8');
      await tester.tap(find.text('Save changes').last);
      await tester.pumpAndSettle();
      expect(store.products.single.category, category.id);
      expect(store.products.single.price, 425);
      expect(store.products.single.cost, 200);
      expect(store.products.single.marketId, store.activeMarketId);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Market owner opens reports and receipts without management or checkout',
    (tester) async {
      final store = PosStore.memory(provisionAdmin: false);
      addTearDown(store.dispose);
      await tester.runAsync(() async {
        await _setup(store);
        await store.saveUser(
          name: 'Market Owner',
          username: 'owner',
          role: UserRole.marketOwner,
          password: 'test-owner-password',
          active: true,
        );
        store.saveProduct(
          Product(
            id: 'milk',
            name: 'Milk',
            barcode: '123',
            category: 'dairy',
            price: 1000,
            cost: 500,
            stock: 10,
          ),
        );
        store.checkout({'milk': 3}, paymentMethod: 'cash', tendered: 3000);
        store.logout();
        await store.login('owner', 'test-owner-password');
      });
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(BazaarApp(store: store));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav-overview')), findsOneWidget);
      for (final page in [
        'register',
        'inventory',
        'categories',
        'team',
        'markets',
        'settings',
        'audit',
      ]) {
        expect(find.byKey(ValueKey('nav-$page')), findsNothing);
      }
      expect(find.text('Gross profit'), findsOneWidget);
      final staff = find.byType(ExpansionTile);
      await tester.ensureVisible(staff);
      await tester.tap(staff);
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('3 ×'), findsOneWidget);
      final receipt = find.text('BZ-000001').first;
      await tester.ensureVisible(receipt);
      await tester.tap(receipt);
      await tester.pumpAndSettle();
      expect(find.byType(ReceiptPaper), findsOneWidget);
      expect(find.text('Test Seller'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
