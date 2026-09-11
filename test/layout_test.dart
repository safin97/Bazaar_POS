import 'dart:io';
import 'dart:ui' as ui;

import 'package:Bazaar_POS/data/pos_store.dart';
import 'package:Bazaar_POS/main.dart';
import 'package:Bazaar_POS/widgets/receipt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const capture = bool.fromEnvironment('CAPTURE_PREVIEWS');
Future<void> fonts() async {
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();

  for (final entry in {
    'NotoSans': ['NotoSans-Regular', 'NotoSans-Bold'],
    'NotoArabic': ['NotoSansArabic-Regular', 'NotoSansArabic-Bold'],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final name in entry.value) {
      loader.addFont(rootBundle.load('assets/fonts/$name.ttf'));
    }
    await loader.load();
  }
}

Future<void> preview(WidgetTester tester, String name) async {
  if (!capture) return;
  await tester.runAsync(() async {
    final context = tester.element(find.byType(BazaarApp));
    await Future.wait(
      tester
          .widgetList<Image>(find.byType(Image, skipOffstage: false))
          .map((widget) => precacheImage(widget.image, context)),
    );
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('preview')),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('docs/previews').create(recursive: true);
    await File('docs/previews/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(fonts);
  testWidgets('Welcome works on desktop and small phones in all languages', (
    tester,
  ) async {
    final store = PosStore.memory(provisionAdmin: false);
    addTearDown(store.dispose);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [1440.0, 390.0, 320.0]) {
      tester.view.physicalSize = Size(width, 900);
      for (final language in ['en', 'ar', 'ku']) {
        store.setLanguage(language);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('preview'),
            child: BazaarApp(store: store),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Welcome $width $language',
        );
        if (width == 1440 && language == 'en') {
          await preview(tester, 'welcome-desktop');
        }
      }
    }
  });
  testWidgets(
    'All manager screens fit desktop and phone layouts in three languages',
    (tester) async {
      final store = PosStore.memory(provisionAdmin: false);
      addTearDown(store.dispose);
      await tester.runAsync(
        () => store.setup(
          storeName: 'Market_Bazaar',
          name: 'Test Manager',
          username: 'manager',
          password: 'test-password',
          currency: 'IQD',
          sampleProducts: true,
        ),
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [1440.0, 390.0, 320.0]) {
        tester.view.physicalSize = Size(width, 960);
        for (final language in ['en', 'ar', 'ku']) {
          store.setLanguage(language);
          await tester.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('preview'),
              child: BazaarApp(store: store),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Shell $width $language',
          );
          for (final page in [
            'register',
            'overview',
            'inventory',
            'categories',
            'markets',
            'sales',
            'team',
            'settings',
            'panelSettings',
            'audit',
          ]) {
            if (width < 1050) {
              await tester.tap(find.byIcon(Icons.menu_rounded));
              await tester.pumpAndSettle();
            }
            final nav = find.byKey(ValueKey('nav-$page'));
            await tester.ensureVisible(nav);
            await tester.tap(nav);
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$page $width $language',
            );
            if (width == 1440 &&
                language == 'en' &&
                ['register', 'overview', 'settings'].contains(page)) {
              await preview(tester, '$page-desktop');
            }
            if (width == 390 && language == 'ku' && page == 'register') {
              await preview(tester, 'register-badini-mobile');
            }
          }
        }
      }
    },
  );
  testWidgets(
    'Checkout adds a product, collects cash and opens the saved receipt',
    (tester) async {
      final store = PosStore.memory(provisionAdmin: false);
      addTearDown(store.dispose);
      await tester.runAsync(
        () => store.setup(
          storeName: 'Bazaar',
          name: 'Owner',
          username: 'owner',
          password: 'test-password',
          currency: 'IQD',
          sampleProducts: true,
        ),
      );
      tester.view.physicalSize = const Size(1440, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(BazaarApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Red apples').first);
      await tester.pumpAndSettle();
      expect(find.text('2,500 IQD'), findsWidgets);
      await tester.tap(find.text('Charge'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complete sale'));
      await tester.pumpAndSettle();
      expect(find.byType(ReceiptPaper), findsWidgets);
      expect(store.sales, hasLength(1));
      expect(store.products.first.stock, 47);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'Receipt PDFs generate from bundled fonts for all three languages',
    () async {
      final store = PosStore.memory(provisionAdmin: false);
      await store.setup(
        storeName: 'Bazaar',
        name: 'Owner',
        username: 'owner',
        password: 'test-password',
        currency: 'IQD',
        sampleProducts: true,
      );
      for (final language in ['en', 'ar', 'ku']) {
        store.setLanguage(language);
        final sale = store.checkout(
          {store.products.first.id: 1},
          paymentMethod: 'cash',
          tendered: 250000,
        );
        final bytes = await receiptPdf(sale);
        expect(String.fromCharCodes(bytes.take(4)), '%PDF');
        expect(bytes.length, greaterThan(1000));
      }
      store.dispose();
    },
  );
}
