import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/backups/google_drive_backups.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../data/pos_store.dart';
import 'common.dart';

class BackupSettingsCard extends StatefulWidget {
  const BackupSettingsCard({super.key, this.drive});
  final GoogleDriveBackups? drive;

  @override
  State<BackupSettingsCard> createState() => _BackupSettingsCardState();
}

class _BackupSettingsCardState extends State<BackupSettingsCard> {
  late final _drive = widget.drive ?? GoogleDriveBackups();
  bool _busy = false;
  bool _ready = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    if (_drive.supported && _drive.configured) _prepare();
  }

  Future<void> _prepare() async {
    try {
      await _drive.prepare();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _status = 'driveConnectionFailed');
    }
  }

  @override
  void dispose() {
    _drive.dispose();
    super.dispose();
  }

  String get _filename =>
      'bazaar-pos-backup-${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}.json';

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _status = switch (error) {
            PosException() => error.key,
            DriveException() => error.key,
            _ => 'backupActionFailed',
          },
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveLocal() async {
    final bytes = context.store.createBackup();
    final path = await FilePicker.platform.saveFile(
      fileName: _filename,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
    if (mounted && (kIsWeb || path != null)) {
      setState(
        () => _status = kIsWeb ? 'backupDownloadStarted' : 'backupSaved',
      );
    }
  }

  Future<void> _confirmRestore(Uint8List bytes) async {
    if (!mounted) return;
    final store = context.store;
    store.validateBackup(bytes);
    final confirmed = await confirmAction(
      context,
      title: 'restoreBackup',
      message: 'restoreBackupHint',
      action: 'restoreBackup',
    );
    if (confirmed && mounted) store.restoreBackup(bytes);
  }

  Future<void> _restoreLocal() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || !mounted) return;
    final file = result.files.single;
    if (file.size > PosStore.maxBackupBytes) {
      throw const PosException('backupTooLarge');
    }
    if (file.bytes == null) throw const PosException('invalidBackup');
    await _confirmRestore(file.bytes!);
  }

  Future<void> _upload() async {
    final bytes = context.store.createBackup();
    await _drive.upload(bytes, _filename);
    if (mounted) setState(() => _status = 'driveBackupSaved');
  }

  Future<void> _restoreDrive() async {
    final backups = await _drive.listBackups();
    if (!mounted) return;
    if (backups.isEmpty) {
      setState(() => _status = 'noDriveBackups');
      return;
    }
    final selected = await showDialog<DriveBackup>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('driveBackups')),
        content: SizedBox(
          width: 480,
          child: ListView(
            shrinkWrap: true,
            children: backups
                .map(
                  (backup) => ListTile(
                    leading: const Icon(Icons.restore),
                    title: Text(dateLabel(backup.createdAt.toLocal())),
                    subtitle: Text(backup.name),
                    onTap: () => Navigator.pop(context, backup),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel')),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    final bytes = await _drive.download(selected);
    await _confirmRestore(bytes);
  }

  @override
  Widget build(BuildContext context) {
    if (!context.store.isOwner) return const SizedBox.shrink();
    return Card(
      key: const ValueKey('backup-settings'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('backups'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(context.tr('backupScopeHint')),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  key: const ValueKey('create-backup'),
                  onPressed: _busy ? null : () => _run(_saveLocal),
                  icon: const Icon(Icons.save_alt),
                  label: Text(context.tr('createBackup')),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('restore-backup'),
                  onPressed: _busy ? null : () => _run(_restoreLocal),
                  icon: const Icon(Icons.restore),
                  label: Text(context.tr('restoreBackup')),
                ),
              ],
            ),
            const Divider(height: 36),
            Text(
              context.tr('googleDrive'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(context.tr('driveBackupHint')),
            if (!_drive.supported || !_drive.configured) ...[
              const SizedBox(height: 10),
              Text(
                context.tr(
                  _drive.supported ? 'driveNeedsSetup' : 'driveUnsupported',
                ),
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
            if (_drive.email case final email?) ...[
              const SizedBox(height: 12),
              Text('${context.tr('connectedGoogleAccount')}: $email'),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (!_drive.connected)
                  OutlinedButton.icon(
                    key: const ValueKey('connect-google-drive'),
                    onPressed: _busy || !_drive.configured || !_drive.supported
                        ? null
                        : _ready
                        ? () => _run(_drive.connect)
                        : () => _run(_prepare),
                    icon: const Icon(Icons.account_circle_outlined),
                    label: Text(
                      context.tr(
                        _ready ? 'connectGoogleDrive' : 'prepareGoogleDrive',
                      ),
                    ),
                  )
                else ...[
                  FilledButton.icon(
                    key: const ValueKey('backup-google-drive'),
                    onPressed: _busy ? null : () => _run(_upload),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(context.tr('backupToDrive')),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(_restoreDrive),
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: Text(context.tr('restoreFromDrive')),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _run(_drive.disconnect),
                    child: Text(context.tr('disconnectGoogleDrive')),
                  ),
                ],
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 18),
              const LinearProgressIndicator(),
            ],
            if (_status != null) ...[
              const SizedBox(height: 12),
              Semantics(liveRegion: true, child: Text(context.tr(_status!))),
            ],
          ],
        ),
      ),
    );
  }
}
