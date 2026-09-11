import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'github_updates.dart';
import 'update_installer.dart';

UpdateInstaller createInstaller() => _NativeInstaller();

class _NativeInstaller extends UpdateInstaller {
  static const _channel = MethodChannel('bazaar_pos/app_updates');

  @override
  Future<InstallCapability> prepare(String repository) async {
    if (defaultTargetPlatform != TargetPlatform.macOS ||
        repository != 'safin97/MarketBazaar') return InstallCapability.none;
    try {
      return await _channel.invokeMethod<String>('capabilities') == 'macos'
          ? InstallCapability.macos : InstallCapability.none;
    } on MissingPluginException {
      return InstallCapability.none;
    } on PlatformException {
      return InstallCapability.none;
    }
  }

  @override
  Future<InstallResult> install(GitHubRelease release,
      void Function(InstallProgress) onProgress) async {
    try {
      await _channel.invokeMethod<void>('installUpdate');
      return InstallResult.nativeDialog;
    } on PlatformException catch (error) {
      throw UpdateException(installErrorKey(error.code));
    } on MissingPluginException {
      throw const UpdateException('updateInstallerUnavailable');
    }
  }
}
