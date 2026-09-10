import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bazaar_pos/core/updates/app_updates.dart';
import 'package:bazaar_pos/core/updates/github_updates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

Map<String, dynamic> releaseJson({String tag = 'v1.0.2+3'}) => {
  'tag_name': tag,
  'draft': false,
  'prerelease': false,
  'body': 'Improved checkout.',
  'assets': [
    for (final name in [
      'bazaar-pos-android.apk',
      'bazaar-pos-macos.zip',
      'bazaar-pos-windows.zip',
      'bazaar-pos-web.zip',
    ])
      {
        'name': name,
        'state': 'uploaded',
        'browser_download_url':
            'https://github.com/safin97/flutter-pos/releases/download/$tag/$name',
      },
  ],
};

GitHubRelease release({String tag = 'v1.0.2+3'}) =>
    GitHubRelease.fromJson(releaseJson(tag: tag), repository: githubRepository);

Matcher updateError(String key) => isA<UpdateException>().having(
  (error) => error.messageKey,
  'messageKey',
  key,
);

class TrackingClient extends MockClient {
  TrackingClient(super.fn);
  bool closed = false;

  @override
  void close() {
    closed = true;
    super.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('development web version matches pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect('$appVersion+$appBuildNumber', version);
  });

  test(
    'reads the installed native version instead of a hardcoded value',
    () async {
      PackageInfo.setMockInitialValues(
        appName: 'Bazaar POS',
        packageName: 'com.example.bazaar_pos',
        version: '2.3.4',
        buildNumber: '15',
        buildSignature: '',
      );
      expect(
        (await const GitHubUpdates().installedVersion()).label,
        '2.3.4+15',
      );
    },
  );

  test(
    'compares versions numerically, supports builds, prevents downgrades',
    () {
      for (final (tag, current, build, newer) in [
        ('v1.0.10', '1.0.9', '9', true),
        ('v1.0.2', '1.0.1', '200', true),
        ('1.0.1', '1.0.1', '2', false),
        ('v1.0.1+3', '1.0.1', '2', true),
        ('v1.0.1+2', '1.0.1', '2', false),
        ('v1.0.1+1', '1.0.1', '2', false),
        ('v1.0.1+99', '1.0.2', '1', false),
        ('v1.0.1.3', '1.0.1', '2', true),
        ('v1.0.1.10', '1.0.1', '9', true),
        ('v1.0.1.3', '1.0.1', '3', false),
        ('v1.0.0.3', '1.0.2', '3', false),
        ('v1.0.1', '2.0.0', '1', false),
        ('v1.0.1', '1.0.1-beta.1', '1', true),
      ]) {
        expect(
          release(tag: tag).isNewerThan(InstalledVersion(current, build)),
          newer,
          reason: '$tag against $current+$build',
        );
      }
    },
  );

  test('four-part release tags retain their original download URLs', () {
    final latest = release(tag: 'v1.0.0.3');
    expect(latest.version.toString(), '1.0.0+3');
    expect(latest.pageUrl.path, '/safin97/flutter-pos/releases/tag/v1.0.0.3');
    expect(
      latest.downloadFor(UpdatePlatform.web).toString(),
      'https://github.com/safin97/flutter-pos/releases/download/v1.0.0.3/bazaar-pos-web.zip',
    );
  });

  test('selects the platform package, never source archives or iOS IPAs', () {
    final latest = release();
    for (final (platform, file) in [
      (UpdatePlatform.android, 'bazaar-pos-android.apk'),
      (UpdatePlatform.macos, 'bazaar-pos-macos.zip'),
      (UpdatePlatform.windows, 'bazaar-pos-windows.zip'),
      (UpdatePlatform.web, 'bazaar-pos-web.zip'),
    ]) {
      expect(latest.downloadFor(platform)!.pathSegments.last, file);
    }
    expect(latest.downloadFor(UpdatePlatform.ios), isNull);
    expect(latest.downloadFor(UpdatePlatform.linux), isNull);
    expect(latest.pageUrl.path, '/safin97/flutter-pos/releases/tag/v1.0.2+3');
  });

  test('recognizes the existing Mac release package only for macOS', () {
    final latest = GitHubRelease.fromJson({
      ...releaseJson(tag: 'v1.0.0.3'),
      'assets': [
        {
          'name': 'Bazaar.POS.app.zip',
          'state': 'uploaded',
          'browser_download_url': 'https://github.com/safin97/flutter-pos/releases/download/v1.0.0.3/Bazaar.POS.app.zip',
        },
      ],
    }, repository: githubRepository);
    expect(
      latest.downloadFor(UpdatePlatform.macos)!.pathSegments.last,
      'Bazaar.POS.app.zip',
    );
    expect(latest.downloadFor(UpdatePlatform.web), isNull);
    expect(latest.downloadFor(UpdatePlatform.windows), isNull);
  });

  test('rejects malformed, draft and prerelease metadata', () {
    for (final changes in [
      {'tag_name': 'latest'},
      {'tag_name': 'v1.0.2-beta.1'},
      {'tag_name': 'v1.0.2\n'},
      {'tag_name': 'v1.0.2.3\n'},
      {'tag_name': 'v1.0.2.3+4'},
      {'tag_name': 'v1.0.2.3.4'},
      {'draft': true},
      {'prerelease': true},
      {'assets': null},
    ]) {
      expect(
        () => GitHubRelease.fromJson({
          ...releaseJson(),
          ...changes,
        }, repository: githubRepository),
        throwsA(updateError('invalidGitHubRelease')),
      );
    }
  });

  test('ignores downloads outside the exact repository and release', () {
    for (final url in [
      'https://example.com/bazaar-pos-android.apk',
      'http://github.com/safin97/flutter-pos/releases/download/v1.0.2+3/bazaar-pos-android.apk',
      'https://github.com/other/app/releases/download/v1.0.2+3/bazaar-pos-android.apk',
      'https://github.com/safin97/flutter-pos/releases/download/v1.0.1/bazaar-pos-android.apk',
      'https://github.com/safin97/flutter-pos/releases/download/v1.0.2+3/bazaar-pos-android.apk?redirect=bad',
      'javascript:alert(1)',
    ]) {
      final json = releaseJson();
      (json['assets'] as List).first['browser_download_url'] = url;
      expect(
        GitHubRelease.fromJson(
          json,
          repository: githubRepository,
        ).downloadFor(UpdatePlatform.android),
        isNull,
      );
    }
  });

  test(
    'checks the configured public GitHub API and closes the client',
    () async {
      final client = TrackingClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'https://api.github.com/repos/safin97/flutter-pos/releases/latest',
        );
        expect(request.headers['Accept'], 'application/vnd.github+json');
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response(jsonEncode(releaseJson()), 200);
      });
      final latest = await GitHubUpdates(clientFactory: () => client)
          .latestRelease();
      expect(latest.tag, 'v1.0.2+3');
      expect(client.closed, isTrue);
    },
  );

  test(
    'maps missing releases, rate limits and server errors for the UI',
    () async {
      for (final (status, key) in [
        (404, 'noGitHubRelease'),
        (403, 'githubRateLimited'),
        (429, 'githubRateLimited'),
        (500, 'githubCheckFailed'),
      ]) {
        final client = TrackingClient((_) async => http.Response('{}', status));
        await expectLater(
          GitHubUpdates(clientFactory: () => client).latestRelease(),
          throwsA(updateError(key)),
        );
        expect(client.closed, isTrue);
      }
    },
  );

  test('handles invalid JSON and offline connections', () async {
    for (final body in ['not json', '[]', '{}']) {
      await expectLater(
        GitHubUpdates(
          clientFactory: () =>
              MockClient((_) async => http.Response(body, 200)),
        ).latestRelease(),
        throwsA(updateError('invalidGitHubRelease')),
      );
    }
    final client = TrackingClient(
      (_) async => throw http.ClientException('offline'),
    );
    await expectLater(
      GitHubUpdates(clientFactory: () => client).latestRelease(),
      throwsA(updateError('githubCheckFailed')),
    );
    expect(client.closed, isTrue);
  });

  testWidgets('a stalled check times out and closes its connection', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    final client = TrackingClient((_) => pending.future);
    final checked = expectLater(
      GitHubUpdates(clientFactory: () => client).latestRelease(),
      throwsA(updateError('githubCheckFailed')),
    );
    await tester.pump(const Duration(seconds: 13));
    await checked;
    expect(client.closed, isTrue);
    pending.complete(http.Response('{}', 500));
    await tester.pump();
  });
}
