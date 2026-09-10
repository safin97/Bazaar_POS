import 'github_updates.dart';
import 'installer_stub.dart'
    if (dart.library.io) 'installer_native.dart'
    if (dart.library.js_interop) 'installer_web.dart' as platform;

enum InstallCapability { none, macos, localWeb }
enum InstallResult { nativeDialog, reload }

class InstallProgress {
  const InstallProgress(this.stage, [this.fraction]);
  final String stage;
  final double? fraction;
}

abstract class UpdateInstaller {
  Future<InstallCapability> prepare(String repository);
  Future<InstallResult> install(
    GitHubRelease release,
    void Function(InstallProgress) onProgress,
  );
  void dispose() {}
}

UpdateInstaller createUpdateInstaller() => platform.createInstaller();

const installErrorKeys = {
  'updateInstallerUnavailable', 'updateInstallFailed', 'updateArchiveInvalid',
  'updateDigestMissing', 'updateNotNewer', 'updateReleaseChanged', 'updateBusy',
  'invalidGitHubRelease', 'githubNoInstallerHint',
};

String installErrorKey(String? key) =>
    installErrorKeys.contains(key) ? key! : 'updateInstallFailed';
