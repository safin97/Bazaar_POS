import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/updates/app_updates.dart';
import '../core/updates/github_updates.dart';
import '../widgets/common.dart';

class PanelSettingsScreen extends StatefulWidget {
  const PanelSettingsScreen({super.key, this.updates = const GitHubUpdates()});

  final GitHubUpdates updates;
  @override
  State<PanelSettingsScreen> createState() => _PanelSettingsScreenState();
}

class _PanelSettingsScreenState extends State<PanelSettingsScreen> {
  bool _checking = false;
  String? _status;
  bool _available = false;
  InstalledVersion? _installed;
  GitHubRelease? _release;
  bool _checkingGitHub = false;
  bool _opening = false;
  String? _githubStatus;
  String? _openStatus;
  Uri? _failedUrl;

  bool get _githubAvailable =>
      _release != null &&
      _installed != null &&
      _release!.isNewerThan(_installed!);

  @override
  void initState() {
    super.initState();
    _loadInstalledVersion();
  }

  Future<void> _loadInstalledVersion() async {
    try {
      final installed = await widget.updates.installedVersion();
      if (mounted) setState(() => _installed = installed);
    } catch (_) {
      if (mounted) setState(() => _githubStatus = 'installedVersionFailed');
    }
  }

  Future<void> _checkGitHub() async {
    setState(() {
      _checkingGitHub = true;
      _githubStatus = null;
      _openStatus = null;
      _failedUrl = null;
      _release = null;
    });
    try {
      final installed = _installed ?? await widget.updates.installedVersion();
      final release = await widget.updates.latestRelease();
      final available = release.isNewerThan(installed);
      if (!mounted) return;
      setState(() {
        _installed = installed;
        _release = release;
        _githubStatus = available ? 'githubUpdateAvailable' : 'githubUpToDate';
      });
    } on UpdateException catch (error) {
      if (mounted) setState(() => _githubStatus = error.messageKey);
    } catch (_) {
      if (mounted) setState(() => _githubStatus = 'githubCheckFailed');
    } finally {
      if (mounted) setState(() => _checkingGitHub = false);
    }
  }

  Future<void> _openGitHub(Uri url) async {
    setState(() {
      _opening = true;
      _openStatus = null;
      _failedUrl = null;
    });
    try {
      // Invoke directly from the tap so browser popup protection allows it.
      final opened = await widget.updates.openUrl(url);
      if (!opened && mounted) {
        setState(() {
          _openStatus = 'githubOpenFailed';
          _failedUrl = url;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _openStatus = 'githubOpenFailed';
          _failedUrl = url;
        });
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _status = null;
      _available = false;
    });
    try {
      final latest = await fetchBuildId();
      if (!mounted) return;
      setState(() {
        _available =
            appBuildId == 'development' || latest.compareTo(appBuildId) > 0;
        _status = _available ? 'updateAvailable' : 'appUpToDate';
      });
    } catch (_) {
      if (mounted) setState(() => _status = 'updateCheckFailed');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _apply() async {
    if (await confirmAction(
          context,
          title: 'loadUpdate',
          message: 'updateReloadHint',
          action: 'loadUpdate',
        ) &&
        mounted) {
      reloadApp();
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(28),
    children: [
      const PageHeading(title: 'panelSettings', subtitle: 'panelSettingsHint'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: DropdownButtonFormField<String>(
            initialValue: context.store.language,
            key: ValueKey(context.store.language),
            decoration: InputDecoration(labelText: context.tr('language')),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'ar', child: Text('العربية')),
              DropdownMenuItem(value: 'ku', child: Text('کوردی بادینی')),
            ],
            onChanged: (value) {
              if (value != null) context.store.setLanguage(value);
            },
          ),
        ),
      ),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('appUpdates'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                '${context.tr('installedVersion')}: ${_installed?.label ?? '—'}',
              ),
              if (appBuildId != 'development')
                Text('${context.tr('appBuild')}: $appBuildId'),
              const SizedBox(height: 16),
              Text(
                '${context.tr('updateSource')}: ${widget.updates.repository}',
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  widget.updates.platform == UpdatePlatform.web
                      ? 'githubWebUpdateHint'
                      : 'githubNativeUpdateHint',
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('check-updates'),
                    onPressed: _checkingGitHub || _opening
                        ? null
                        : _checkGitHub,
                    icon: _checkingGitHub
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.system_update_alt),
                    label: Text(
                      context.tr(
                        _checkingGitHub
                            ? 'checkingUpdates'
                            : 'checkGitHubUpdates',
                      ),
                    ),
                  ),
                  if (_githubAvailable &&
                      _release!.downloadFor(widget.updates.platform) != null)
                    FilledButton.icon(
                      key: const ValueKey('download-github-update'),
                      onPressed: _opening
                          ? null
                          : () => _openGitHub(
                              _release!.downloadFor(widget.updates.platform)!,
                            ),
                      icon: const Icon(Icons.download_rounded),
                      label: Text(context.tr('downloadUpdate')),
                    ),
                  TextButton.icon(
                    key: const ValueKey('github-releases'),
                    onPressed: _opening
                        ? null
                        : () => _openGitHub(
                            _release?.pageUrl ?? widget.updates.releasesUrl,
                          ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(context.tr('githubReleases')),
                  ),
                ],
              ),
              if (_githubStatus != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(context.tr(_githubStatus!)),
                ),
              ],
              if (_release != null) ...[
                const SizedBox(height: 8),
                Text('${context.tr('latestVersion')}: ${_release!.tag}'),
                if (_githubAvailable &&
                    _release!.downloadFor(widget.updates.platform) == null) ...[
                  const SizedBox(height: 8),
                  Text(context.tr('githubNoInstallerHint')),
                ],
                if (_release!.notes.trim().isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(context.tr('releaseNotes')),
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: SelectableText(_release!.notes),
                      ),
                    ],
                  ),
              ],
              if (_openStatus != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(context.tr(_openStatus!)),
                ),
                SelectableText(_failedUrl.toString()),
              ],
              if (supportsUpdates) ...[
                const Divider(height: 36),
                Text(context.tr('webUpdateHint')),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('check-web-updates'),
                      onPressed: _checking ? null : _check,
                      icon: _checking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.system_update_alt),
                      label: Text(
                        context.tr(
                          _checking ? 'checkingUpdates' : 'checkWebUpdates',
                        ),
                      ),
                    ),
                    if (_available)
                      FilledButton.icon(
                        onPressed: _apply,
                        icon: const Icon(Icons.refresh),
                        label: Text(context.tr('loadUpdate')),
                      ),
                  ],
                ),
              ],
              if (_status != null) ...[
                const SizedBox(height: 16),
                Semantics(liveRegion: true, child: Text(context.tr(_status!))),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      Card(
        key: const ValueKey('about-us-table'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('aboutUs'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(3),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: TableBorder(
                  horizontalInside: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                children:
                    [
                          (context.tr('aboutAppName'), 'Bazaar POS'),
                          (
                            context.tr('storeName'),
                            context.store.settings.name,
                          ),
                          (
                            context.tr('aboutPurpose'),
                            context.tr('aboutPurposeValue'),
                          ),
                          (
                            context.tr('installedVersion'),
                            _installed?.label ?? '—',
                          ),
                          (
                            context.tr('language'),
                            'English · العربية · کوردی بادینی',
                          ),
                          (
                            context.tr('aboutStorage'),
                            context.tr('aboutStorageValue'),
                          ),
                        ]
                        .map(
                          (row) => TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                  0,
                                  12,
                                  12,
                                  12,
                                ),
                                child: Text(
                                  row.$1,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Text(row.$2),
                              ),
                            ],
                          ),
                        )
                        .toList(),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
