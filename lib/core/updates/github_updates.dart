import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_updates.dart';

const githubRepository = String.fromEnvironment(
  'GITHUB_REPOSITORY',
  defaultValue: 'safin97/MarketBazaar',
);

enum UpdatePlatform { android, ios, macos, windows, linux, web, unsupported }

class InstalledVersion {
  const InstalledVersion(this.version, this.buildNumber);

  final String version;
  final String buildNumber;

  String get label => buildNumber.isEmpty ? version : '$version+$buildNumber';
}

class UpdateException implements Exception {
  const UpdateException(this.messageKey);
  final String messageKey;
}

class GitHubRelease {
  const GitHubRelease({
    required this.tag,
    required this.version,
    required this.pageUrl,
    required this.notes,
    required this.assets,
  });

  final String tag;
  final Version version;
  final Uri pageUrl;
  final String notes;
  final Map<String, Uri> assets;

  factory GitHubRelease.fromJson(
    Map<String, dynamic> json, {
    required String repository,
  }) {
    final tag = json['tag_name'];
    if (json['draft'] != false ||
        json['prerelease'] != false ||
        tag is! String) {
      throw const UpdateException('invalidGitHubRelease');
    }
    final match = RegExp(r'^v?(\d+\.\d+\.\d+)(?:[.+](\d+))?$').firstMatch(tag);
    if (match == null || match.end != tag.length) {
      throw const UpdateException('invalidGitHubRelease');
    }
    // Accept four-part desktop tags as major.minor.patch.build, while keeping
    // the original tag for GitHub's release and download URLs.
    final build = match.group(2);
    final version = Version.parse(
      '${match.group(1)}${build == null ? '' : '+$build'}',
    );
    final rawAssets = json['assets'];
    if (rawAssets is! List) {
      throw const UpdateException('invalidGitHubRelease');
    }
    final assets = <String, Uri>{};
    for (final asset in rawAssets) {
      if (asset is! Map<String, dynamic> || asset['state'] != 'uploaded') {
        continue;
      }
      final name = asset['name'];
      final url = asset['browser_download_url'];
      if (name is! String || url is! String) continue;
      final uri = Uri.tryParse(url);
      // Only accept downloads attached to this release in our repository.
      final expected = Uri.https(
        'github.com',
        '/$repository/releases/download/$tag/$name',
      );
      if (uri == expected) assets[name] = uri!;
    }
    return GitHubRelease(
      tag: tag,
      version: version,
      pageUrl: Uri.https('github.com', '/$repository/releases/tag/$tag'),
      notes: json['body'] is String ? json['body'] as String : '',
      assets: Map.unmodifiable(assets),
    );
  }

  bool isNewerThan(InstalledVersion installed) {
    final current = Version.parse(installed.version);
    // Ignore build metadata when comparing semantic versions. A numeric +build
    // or fourth component in the release tag can update the same app version.
    final latestBase = Version(version.major, version.minor, version.patch);
    final currentBase = Version(
      current.major,
      current.minor,
      current.patch,
      pre: current.preRelease.isEmpty ? null : current.preRelease.join('.'),
    );
    final comparison = latestBase.compareTo(currentBase);
    if (comparison != 0) return comparison > 0;
    final releaseBuild = int.tryParse(version.build.join('.'));
    final installedBuild = int.tryParse(installed.buildNumber);
    return releaseBuild != null &&
        installedBuild != null &&
        releaseBuild > installedBuild;
  }

  Uri? downloadFor(UpdatePlatform platform) {
    final names = switch (platform) {
      UpdatePlatform.android => ['bazaar-pos-android.apk'],
      UpdatePlatform.macos => [
        'bazaar-pos-macos.dmg',
        'bazaar-pos-macos.zip',
        'Bazaar.POS.app.zip',
      ],
      UpdatePlatform.windows => [
        'bazaar-pos-windows.exe',
        'bazaar-pos-windows.msix',
        'bazaar-pos-windows.zip',
      ],
      UpdatePlatform.linux => [
        'bazaar-pos-linux.AppImage',
        'bazaar-pos-linux.tar.gz',
      ],
      UpdatePlatform.web => ['bazaar-pos-web.zip'],
      UpdatePlatform.ios || UpdatePlatform.unsupported => <String>[],
    };
    for (final name in names) {
      if (assets.containsKey(name)) return assets[name];
    }
    return null;
  }
}

class GitHubUpdates {
  const GitHubUpdates({this.repository = githubRepository, this.clientFactory});

  final String repository;
  final http.Client Function()? clientFactory;

  Uri get releasesUrl => Uri.https('github.com', '/$repository/releases');

  UpdatePlatform get platform {
    if (kIsWeb) return UpdatePlatform.web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => UpdatePlatform.android,
      TargetPlatform.iOS => UpdatePlatform.ios,
      TargetPlatform.macOS => UpdatePlatform.macos,
      TargetPlatform.windows => UpdatePlatform.windows,
      TargetPlatform.linux => UpdatePlatform.linux,
      TargetPlatform.fuchsia => UpdatePlatform.unsupported,
    };
  }

  Future<InstalledVersion> installedVersion() async {
    if (kIsWeb) return const InstalledVersion(appVersion, appBuildNumber);
    try {
      final info = await PackageInfo.fromPlatform().timeout(
        const Duration(seconds: 12),
      );
      Version.parse(info.version);
      return InstalledVersion(info.version, info.buildNumber);
    } catch (_) {
      throw const UpdateException('installedVersionFailed');
    }
  }

  Future<GitHubRelease> latestRelease() async {
    if (!RegExp(r'^[\w.-]+/[\w.-]+$').hasMatch(repository)) {
      throw const UpdateException('invalidGitHubRepository');
    }
    final client = (clientFactory ?? http.Client.new)();
    try {
      final response = await client
          .get(
            Uri.https('api.github.com', '/repos/$repository/releases/latest'),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 404) {
        throw const UpdateException('noGitHubRelease');
      }
      if (response.statusCode == 403 || response.statusCode == 429) {
        throw const UpdateException('githubRateLimited');
      }
      if (response.statusCode != 200) {
        throw const UpdateException('githubCheckFailed');
      }
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) {
        throw const UpdateException('invalidGitHubRelease');
      }
      return GitHubRelease.fromJson(json, repository: repository);
    } on UpdateException {
      rethrow;
    } on FormatException {
      throw const UpdateException('invalidGitHubRelease');
    } catch (_) {
      throw const UpdateException('githubCheckFailed');
    } finally {
      client.close();
    }
  }

  Future<bool> openUrl(Uri url) => launchUrl(
    url,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
}
