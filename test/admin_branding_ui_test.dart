import 'dart:convert';
import 'dart:typed_data';

import 'package:Bazaar_POS/data/models.dart';
import 'package:Bazaar_POS/data/pos_store.dart';
import 'package:Bazaar_POS/main.dart';
import 'package:Bazaar_POS/widgets/common.dart';
import 'package:Bazaar_POS/widgets/market_branding_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_branding_test.dart' show addAdmin, logoPhoto, backgroundPhoto;
import 'admin_market_assignment_test.dart' show AssignmentStore, setup;
import 'layout_test.dart' show fonts, preview;

class _BrandingFiles extends FilePicker {
  Uint8List? bytes;
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
  }) async => bytes == null
      ? null
      : FilePickerResult([
          PlatformFile(name: 'image.png', size: bytes!.length, bytes: bytes),
        ]);
}

void main() {
  setUpAll(fonts);
  testWidgets(
    'Admin image uploads preview, cancel, remove and follow the selected market',
    (tester) async {
      final store = AssignmentStore();
      addTearDown(store.dispose);
      await tester.runAsync(() => setup(store));
      final branch = store.createMarket(name: 'Branch', currency: 'USD');
      final files = _BrandingFiles();
      FilePicker.platform = files;
      addTearDown(() => FilePicker.platform = _BrandingFiles());
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('preview'),
          child: BazaarApp(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-team')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add team member'));
      await tester.pumpAndSettle();
      expect(find.byType(MarketBrandingEditor), findsNothing);
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
      }
      final role = find.byType(DropdownButtonFormField<UserRole>);
      await tester.ensureVisible(role);
      await tester.tap(role);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Admin').last);
      await tester.pumpAndSettle();

      Future<void> chooseMarket(String name) async {
        final market = find.byKey(const ValueKey('admin-market-selector'));
        await tester.ensureVisible(market);
        await tester.tap(market);
        await tester.pumpAndSettle();
        await tester.tap(find.text(name).last);
        await tester.pumpAndSettle();
      }

      Future<void> upload(String key, String? photo) async {
        files.bytes = photo == null ? null : base64Decode(photo);
        final finder = find.byKey(ValueKey(key));
        await tester.ensureVisible(finder);
        // Await the actual async upload callback, including native image decoding.
        final action = tester.widget<OutlinedButton>(finder).onPressed!;
        await tester.runAsync(() async => await (action as dynamic)());
        await tester.pumpAndSettle();
      }

      MarketBranding draft() => tester
          .widget<MarketBrandingEditor>(find.byType(MarketBrandingEditor))
          .branding;

      await chooseMarket('Branch');
      await upload('admin-upload-logo', logoPhoto);
      await upload('admin-upload-background', backgroundPhoto);
      final savedLogo = draft().logo;
      final savedBackground = draft().background;
      expect(savedLogo, isNotNull);
      expect(savedBackground, isNotNull);
      await upload('admin-upload-background', null);
      expect(draft().background, savedBackground);
      await chooseMarket('Original Market');
      expect(draft().logo, isNull);
      expect(draft().background, isNull);
      await chooseMarket('Branch');
      expect(draft().logo, savedLogo);
      expect(draft().background, savedBackground);
      final remove = find.byKey(const ValueKey('admin-remove-background'));
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(draft().background, isNull);
      expect(draft().logo, savedLogo);
      await upload('admin-upload-background', backgroundPhoto);
      for (final width in [1440.0, 390.0, 320.0]) {
        tester.view.physicalSize = Size(width, 1000);
        for (final language in ['en', 'ar', 'ku']) {
          store.setLanguage(language);
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byKey(const ValueKey('admin-upload-background')),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$width $language');
          if (width == 1440 && language == 'en')
            await preview(tester, 'admin-branding-desktop');
        }
      }
      store.setLanguage('en');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes').last);
      await tester.pumpAndSettle();
      expect(store.assignedMarketId, branch);
      expect(store.assignedBranding?.logo, savedLogo);
      expect(store.assignedBranding?.background, savedBackground);
      expect(store.activeMarketId, defaultMarketId);
      expect(store.settings.background, isNull);
    },
  );

  testWidgets(
    'Welcome uses the entered username market artwork and retains the app title',
    (tester) async {
      final store = PosStore.memory(provisionAdmin: false);
      addTearDown(store.dispose);
      await tester.runAsync(() async {
        await setup(store);
        final branch = store.createMarket(name: 'Branch', currency: 'USD');
        await addAdmin(store, branch);
        store.logout();
      });
      await tester.pumpWidget(BazaarApp(store: store));
      await tester.pumpAndSettle();
      ImageProvider provider(String key) =>
          tester.widget<Image>(find.byKey(ValueKey(key))).image;
      expect(provider('welcome-logo'), isA<AssetImage>());
      expect(provider('welcome-background'), isA<AssetImage>());
      await tester.enterText(
        find.byKey(const ValueKey('login-username')),
        ' BRANCH-ADMIN ',
      );
      await tester.pumpAndSettle();
      expect(
        (provider('welcome-logo') as MemoryImage).bytes,
        base64Decode(logoPhoto),
      );
      expect(
        (provider('welcome-background') as MemoryImage).bytes,
        base64Decode(backgroundPhoto),
      );
      expect(find.text('Bazaar_POS'), findsOneWidget);
      expect(store.currentUser, isNull);
      expect(store.activeMarketId, defaultMarketId);
      await tester.enterText(
        find.byKey(const ValueKey('login-username')),
        'unknown',
      );
      await tester.pumpAndSettle();
      expect(provider('welcome-logo'), isA<AssetImage>());
      expect(provider('welcome-background'), isA<AssetImage>());
      expect(tester.takeException(), isNull);
    },
  );
}
