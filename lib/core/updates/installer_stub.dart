import 'github_updates.dart';
import 'update_installer.dart';

UpdateInstaller createInstaller() => _UnsupportedInstaller();

class _UnsupportedInstaller extends UpdateInstaller {
  @override
  Future<InstallCapability> prepare(String repository) async => InstallCapability.none;

  @override
  Future<InstallResult> install(GitHubRelease release,
      void Function(InstallProgress) onProgress) async {
    throw const UpdateException('updateInstallerUnavailable');
  }
}
