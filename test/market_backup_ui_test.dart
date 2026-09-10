import 'dart:convert';

import 'package:bazaar_pos/core/strings.dart';
import 'package:bazaar_pos/core/theme.dart';
import 'package:bazaar_pos/screens/markets_screen.dart';
import 'package:bazaar_pos/widgets/backup_settings_card.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'market_currency_display_test.dart' show createStore;

class BackupFiles extends FilePicker {
  Uint8List? selected;
  Uint8List? saved;
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
  }) async => selected == null
      ? null
      : FilePickerResult([
          PlatformFile(
            name: 'selected.json',
            size: selected!.length,
            bytes: selected,
          ),
        ]);

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    saved = bytes;
    return 'saved-backup.json';
  }
}

Future<void> tap(
  WidgetTester tester,
  Finder target, {
  bool waitForIdle = true,
}) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  if (waitForIdle) {
    await tester.pumpAndSettle();
  } else {
    // Restore stays busy while the confirmation dialog is open.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }
}

void main() {
  testWidgets(
    'Add market uploads a logo and enables optional display currencies',
    (tester) async {
      final store = await tester.runAsync(createStore);
      addTearDown(store!.dispose);
      final files = BackupFiles();
      FilePicker.platform = files;
      files.selected = (await rootBundle.load('assets/branding/shop-logo.png'))
          .buffer
          .asUint8List();
      String? created;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        PosScope(
          store: store,
          child: MaterialApp(
            theme: buildTheme(),
            home: Scaffold(body: MarketsScreen(onOpen: (id) => created = id)),
          ),
        ),
      );
      await tap(tester, find.byKey(const ValueKey('add-market')));
      await tester.enterText(find.byType(TextFormField).first, 'Logo market');
      await tester.runAsync(() async {
        final pick =
            tester
                    .widget<OutlinedButton>(
                      find.byKey(const ValueKey('market-upload-logo')),
                    )
                    .onPressed!
                as Future<void> Function();
        await pick();
      });
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('display-both-currencies')));
      await tap(tester, find.widgetWithText(FilledButton, 'Save changes'));
      expect(created, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('usd-iqd-exchange-rate')),
        '1310',
      );
      await tap(tester, find.widgetWithText(FilledButton, 'Save changes'));
      final market = store.markets.firstWhere((market) => market.id == created);
      expect(market.settings.logo, isNotNull);
      expect(market.settings.currency, 'USD');
      expect(market.settings.secondaryCurrency, 'IQD');
      expect(market.settings.usdToIqdRate, 131000);
    },
  );

  testWidgets(
    'local backup saves data and restoring requires explicit confirmation',
    (tester) async {
      final store = await tester.runAsync(createStore);
      addTearDown(store!.dispose);
      final files = BackupFiles();
      FilePicker.platform = files;
      await tester.pumpWidget(
        PosScope(
          store: store,
          child: MaterialApp(
            theme: buildTheme(),
            home: const Scaffold(
              body: SingleChildScrollView(child: BackupSettingsCard()),
            ),
          ),
        ),
      );
      await tap(tester, find.byKey(const ValueKey('create-backup')));
      expect(
        jsonDecode(utf8.decode(files.saved!))['format'],
        'bazaar-pos-backup',
      );
      files.selected = files.saved;
      store.createMarket(name: 'Keep until confirmed', currency: 'USD');
      await tester.pumpAndSettle();
      await tap(
        tester,
        find.byKey(const ValueKey('restore-backup')),
        waitForIdle: false,
      );
      expect(find.byType(AlertDialog), findsOneWidget);
      await tap(tester, find.widgetWithText(TextButton, 'Cancel'));
      expect(store.markets, hasLength(2));
      expect(store.currentUser, isNotNull);
      await tap(
        tester,
        find.byKey(const ValueKey('restore-backup')),
        waitForIdle: false,
      );
      await tap(tester, find.widgetWithText(FilledButton, 'Restore backup'));
      expect(store.currentUser, isNull);
      await tester.runAsync(() => store.login('owner', 'test-password'));
      expect(store.markets, hasLength(1));
    },
  );
}
