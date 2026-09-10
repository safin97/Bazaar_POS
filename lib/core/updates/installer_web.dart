import 'dart:convert';
import 'dart:js_interop';

import 'github_updates.dart';
import 'update_installer.dart';

@JS('bazaarUpdateCapabilities')
external JSFunction? get _capabilities;
@JS('bazaarInstallWebUpdate')
external JSPromise<JSString> _install(JSString tag, JSFunction onProgress);

UpdateInstaller createInstaller() => _WebInstaller();

class _WebInstaller extends UpdateInstaller {
  bool _disposed = false;

  @override
  Future<InstallCapability> prepare(String repository) async {
    final probe = _capabilities;
    if (probe == null) return InstallCapability.none;
    try {
      final response = await (probe.callAsFunction() as JSPromise<JSString>).toDart;
      final data = jsonDecode(response.toDart) as Map<String, dynamic>;
      return data['kind'] == 'localWeb' && data['repository'] == repository
          ? InstallCapability.localWeb : InstallCapability.none;
    } catch (_) {
      return InstallCapability.none;
    }
  }

  @override
  Future<InstallResult> install(GitHubRelease release,
      void Function(InstallProgress) onProgress) async {
    final callback = ((JSString value) {
      if (_disposed) return;
      final data = jsonDecode(value.toDart) as Map<String, dynamic>;
      final stage = data['stage'];
      if (!const {'updateDownloading', 'updateVerifying', 'updateInstalling',
          'updateRestarting'}.contains(stage)) return;
      onProgress(InstallProgress(stage as String,
          (data['progress'] as num?)?.toDouble().clamp(0, 1)));
    }).toJS;
    final response = jsonDecode((await _install(release.tag.toJS, callback).toDart).toDart)
        as Map<String, dynamic>;
    if (response['ok'] != true) {
      throw UpdateException(installErrorKey(response['error'] as String?));
    }
    return InstallResult.reload;
  }

  @override
  void dispose() => _disposed = true;
}
