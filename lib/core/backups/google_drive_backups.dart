import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../data/pos_store.dart';
import 'drive_auth_stub.dart'
    if (dart.library.io) 'drive_auth_native.dart'
    if (dart.library.js_interop) 'drive_auth_web.dart'
    as platform;
import 'drive_types.dart';

export 'drive_types.dart';

class GoogleDriveBackups {
  GoogleDriveBackups({DriveAuth? auth, http.Client? client})
    : _auth = auth ?? platform.createDriveAuth(),
      _client = client ?? http.Client();

  final DriveAuth _auth;
  final http.Client _client;
  DriveToken? _token;
  String? _email;
  bool _disposed = false;

  bool get supported => _auth.supported;
  bool get configured => _auth.configured;
  bool get connected =>
      _token != null &&
      DateTime.now().isBefore(
        _token!.expiresAt.subtract(const Duration(seconds: 30)),
      );
  String? get email => connected ? _email : null;

  Future<void> prepare() => _auth.prepare();

  Future<void> connect() async {
    if (!supported) throw const DriveException('driveUnsupported');
    if (!configured) throw const DriveException('driveNeedsSetup');
    final token = await _auth.connect();
    if (_disposed) return;
    final response = await _client
        .get(
          Uri.https('openidconnect.googleapis.com', '/v1/userinfo'),
          headers: {'Authorization': 'Bearer ${token.accessToken}'},
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw const DriveException('driveConnectionFailed');
    }
    final profile = jsonDecode(response.body) as Map<String, dynamic>;
    if (profile['email'] is! String || profile['email_verified'] != true) {
      throw const DriveException('driveConnectionFailed');
    }
    if (!_disposed) {
      _token = token;
      _email = profile['email'] as String;
    }
  }

  Map<String, String> get _headers {
    if (!connected) {
      _token = null;
      _email = null;
      throw const DriveException('driveSessionExpired');
    }
    return {'Authorization': 'Bearer ${_token!.accessToken}'};
  }

  void _checkStatus(int code) {
    if (code == 401) {
      _token = null;
      _email = null;
      throw const DriveException('driveSessionExpired');
    }
    if (code == 403) throw const DriveException('drivePermissionMissing');
    if (code < 200 || code >= 300) {
      throw const DriveException('driveRequestFailed');
    }
  }

  Future<void> upload(Uint8List bytes, String name) async {
    if (bytes.length > PosStore.maxBackupBytes) {
      throw const PosException('backupTooLarge');
    }
    final headers = _headers;
    final response = await _client
        .post(
          Uri.https('www.googleapis.com', '/upload/drive/v3/files', {
            'uploadType': 'resumable',
            'fields': 'id',
          }),
          headers: {
            ...headers,
            'Content-Type': 'application/json; charset=UTF-8',
            'X-Upload-Content-Type': 'application/json',
            'X-Upload-Content-Length': bytes.length.toString(),
          },
          body: jsonEncode({
            'name': name,
            'mimeType': 'application/json',
            'parents': ['appDataFolder'],
            'appProperties': {'bazaarBackup': '1'},
          }),
        )
        .timeout(const Duration(seconds: 20));
    _checkStatus(response.statusCode);
    final location = Uri.tryParse(response.headers['location'] ?? '');
    if (location == null ||
        location.scheme != 'https' ||
        location.host != 'www.googleapis.com' ||
        location.userInfo.isNotEmpty ||
        location.port != 443 ||
        location.path != '/upload/drive/v3/files') {
      throw const DriveException('driveRequestFailed');
    }
    final uploaded = await _client
        .put(
          location,
          headers: {...headers, 'Content-Type': 'application/json'},
          body: bytes,
        )
        .timeout(const Duration(minutes: 2));
    _checkStatus(uploaded.statusCode);
    if ((jsonDecode(uploaded.body) as Map<String, dynamic>)['id'] is! String) {
      throw const DriveException('driveRequestFailed');
    }
  }

  Future<List<DriveBackup>> listBackups() async {
    final response = await _client
        .get(
          Uri.https('www.googleapis.com', '/drive/v3/files', {
            'spaces': 'appDataFolder',
            'q': "trashed = false and appProperties has { key='bazaarBackup' and value='1' }",
            'fields': 'files(id,name,createdTime)',
            'orderBy': 'createdTime desc',
            'pageSize': '20',
          }),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 20));
    _checkStatus(response.statusCode);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['files'] as List)
        .map(
          (file) => DriveBackup(
            id: file['id'] as String,
            name: file['name'] as String,
            createdAt: DateTime.parse(file['createdTime'] as String),
          ),
        )
        .toList();
  }

  Future<Uint8List> download(DriveBackup backup) async {
    if (!RegExp(r'^[\w-]+$').hasMatch(backup.id)) {
      throw const DriveException('driveRequestFailed');
    }
    final request = http.Request(
      'GET',
      Uri.https('www.googleapis.com', '/drive/v3/files/${backup.id}', {
        'alt': 'media',
      }),
    )..headers.addAll(_headers);
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        (response.contentLength ?? 0) > PosStore.maxBackupBytes) {
      await response.stream.listen((_) {}).cancel();
      _checkStatus(response.statusCode);
      throw const PosException('backupTooLarge');
    }
    _checkStatus(response.statusCode);
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
      if (bytes.length + chunk.length > PosStore.maxBackupBytes) {
        throw const PosException('backupTooLarge');
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  Future<void> disconnect() async {
    final token = _token;
    _token = null;
    _email = null;
    if (token == null) return;
    final response = await _client
        .post(
          Uri.https('oauth2.googleapis.com', '/revoke'),
          body: {'token': token.accessToken},
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw const DriveException('driveRevokeFailed');
    }
  }

  void dispose() {
    _disposed = true;
    _auth.cancel();
    _token = null;
    _email = null;
    _client.close();
  }
}
