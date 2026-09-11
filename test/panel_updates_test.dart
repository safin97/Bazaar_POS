import 'dart:async';

import 'package:Bazaar_POS/core/strings.dart';
import 'package:Bazaar_POS/core/theme.dart';
import 'package:Bazaar_POS/core/updates/github_updates.dart';
import 'package:Bazaar_POS/data/pos_store.dart';
import 'package:Bazaar_POS/screens/panel_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'github_updates_test.dart' show release, releaseJson;

class FakeUpdates extends GitHubUpdates {
  GitHubRelease latest = release();
  Object? error;
  Completer<GitHubRelease>? pending;
  bool opens = true;
  int checks = 0;
  Uri? opened;
  UpdatePlatform device = UpdatePlatform.android;

  @override
  UpdatePlatform get platform => device;

  @override
  Future<InstalledVersion> installedVersion() async =>
      const InstalledVersion('1.0.1', '2');

  @override
  Future<GitHubRelease> latestRelease() async {
    checks++;
    if (error != null) throw error!;
    return pending == null ? latest : pending!.future;
  }

  @override
  Future<bool> openUrl(Uri url) async {
    opened = url;
    return opens;
  }
}

Future<PosStore> showPanel(
  WidgetTester tester,
  FakeUpdates updates, {
  String language = 'en',
}) async {
  final store = PosStore.memory();
  store.setLanguage(language);
  addTearDown(store.dispose);
  await tester.pumpWidget(
    PosScope(
      store: store,
      child: MaterialApp(
        theme: buildTheme(),
        home: Directionality(
          textDirection: language == 'en'
              ? TextDirection.ltr
              : TextDirection.rtl,
          child: Scaffold(body: PanelSettingsScreen(updates: updates)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final button = find.byKey(ValueKey(key));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('checks on demand and downloads the newer device installer', (
    tester,
  ) async {
    final updates = FakeUpdates();
    final store = await showPanel(tester, updates);
    final products = store.products.length;
    expect(updates.checks, 0);
    expect(find.text('Installed version: 1.0.1+2'), findsOneWidget);
    expect(find.byKey(const ValueKey('download-github-update')), findsNothing);
    await tapKey(tester, 'check-updates');
    expect(updates.checks, 1);
    expect(
      find.text('A newer version is available on GitHub.'),
      findsOneWidget,
    );
    expect(find.text('Latest version: v1.0.2+3'), findsOneWidget);
    await tapKey(tester, 'download-github-update');
    expect(updates.opened, updates.latest.downloadFor(UpdatePlatform.android));
    expect(store.products.length, products);
    expect(store.sales, isEmpty);
    // Opening a download never claims the running app has been updated.
    expect(find.text('Installed version: 1.0.1+2'), findsOneWidget);
  });

  testWidgets('equal or older releases do not offer an update', (tester) async {
    final updates = FakeUpdates()..latest = release(tag: 'v1.0.0');
    await showPanel(tester, updates);
    await tapKey(tester, 'check-updates');
    expect(
      find.text('Your app is up to date with the latest GitHub release.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('download-github-update')), findsNothing);
  });

  testWidgets('checks and downloads releases with a four-part version tag', (
    tester,
  ) async {
    final updates = FakeUpdates()..latest = release(tag: 'v1.0.1.3');
    await showPanel(tester, updates);
    await tapKey(tester, 'check-updates');
    expect(find.text('Latest version: v1.0.1.3'), findsOneWidget);
    expect(
      find.text('A newer version is available on GitHub.'),
      findsOneWidget,
    );
    await tapKey(tester, 'download-github-update');
    expect(
      updates.opened.toString(),
      'https://github.com/safin97/Bazaar_POS/releases/download/v1.0.1.3/Bazaar_POS-android.apk',
    );
  });

  testWidgets('a failed check shows feedback and can be retried', (
    tester,
  ) async {
    final updates = FakeUpdates()
      ..error = const UpdateException('noGitHubRelease');
    await showPanel(tester, updates);
    await tapKey(tester, 'check-updates');
    expect(
      find.textContaining('No public release is available.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('download-github-update')), findsNothing);
    updates.error = null;
    await tapKey(tester, 'check-updates');
    expect(updates.checks, 2);
    expect(
      find.byKey(const ValueKey('download-github-update')),
      findsOneWidget,
    );
    updates.error = const UpdateException('githubCheckFailed');
    await tapKey(tester, 'check-updates');
    expect(find.byKey(const ValueKey('download-github-update')), findsNothing);
  });

  testWidgets('missing installer offers release instructions, including iOS', (
    tester,
  ) async {
    final updates = FakeUpdates()..device = UpdatePlatform.ios;
    updates.latest = GitHubRelease.fromJson({
      ...releaseJson(),
      'assets': [],
    }, repository: githubRepository);
    await showPanel(tester, updates);
    await tapKey(tester, 'check-updates');
    expect(
      find.textContaining('no direct download for this device'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('download-github-update')), findsNothing);
    await tapKey(tester, 'github-releases');
    expect(updates.opened, updates.latest.pageUrl);
  });

  testWidgets('browser launch failure exposes a copyable download link', (
    tester,
  ) async {
    final updates = FakeUpdates()..opens = false;
    await showPanel(tester, updates);
    await tapKey(tester, 'check-updates');
    await tapKey(tester, 'download-github-update');
    expect(find.textContaining('Could not open the browser.'), findsOneWidget);
    expect(
      find.widgetWithText(
        SelectableText,
        updates.latest.downloadFor(UpdatePlatform.android).toString(),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'pending checks disable repeat taps and tolerate leaving the page',
    (tester) async {
      final updates = FakeUpdates()..pending = Completer<GitHubRelease>();
      await showPanel(tester, updates);
      final button = find.byKey(const ValueKey('check-updates'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(updates.checks, 1);
      await tester.pumpWidget(const SizedBox());
      updates.pending!.complete(updates.latest);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'ar', 'ku']) {
    testWidgets('update controls fit a narrow $language screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final updates = FakeUpdates()..device = UpdatePlatform.web;
      await showPanel(tester, updates, language: language);
      await tapKey(tester, 'check-updates');
      await tapKey(tester, 'download-github-update');
      expect(updates.opened, updates.latest.downloadFor(UpdatePlatform.web));
      expect(tester.takeException(), isNull);
    });
  }
}
