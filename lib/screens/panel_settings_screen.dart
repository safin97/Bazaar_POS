import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/updates/app_updates.dart';
import '../widgets/common.dart';

class PanelSettingsScreen extends StatefulWidget {
  const PanelSettingsScreen({super.key});
  @override
  State<PanelSettingsScreen> createState() => _PanelSettingsScreenState();
}

class _PanelSettingsScreenState extends State<PanelSettingsScreen> {
  bool _checking = false;
  String? _status;
  bool _available = false;

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
              Text('${context.tr('installedVersion')}: $appVersion'),
              if (appBuildId != 'development')
                Text('${context.tr('appBuild')}: $appBuildId'),
              const SizedBox(height: 16),
              Text(
                context.tr(
                  supportsUpdates ? 'webUpdateHint' : 'nativeUpdateHint',
                ),
              ),
              if (supportsUpdates) ...[
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('check-updates'),
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
                          _checking ? 'checkingUpdates' : 'checkUpdates',
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
    ],
  );
}
