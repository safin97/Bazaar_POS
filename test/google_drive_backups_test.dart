import 'dart:convert';
import 'dart:typed_data';

import 'package:bazaar_pos/core/backups/google_drive_backups.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeDriveAuth extends DriveAuth {
  @override
  bool get supported => true;
  @override
  bool get configured => true;
  @override
  Future<DriveToken> connect() async =>
      DriveToken('test-token', DateTime.now().add(const Duration(hours: 1)));
}

http.Response profile() => http.Response(
  jsonEncode({'email': 'test@example.com', 'email_verified': true}),
  200,
);

void main() {
  test(
    'connects, uploads only to app data, lists and downloads backups',
    () async {
      final bytes = Uint8List.fromList(utf8.encode('{"backup":"test"}'));
      var step = 0;
      final drive = GoogleDriveBackups(
        auth: FakeDriveAuth(),
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test-token');
          switch (step++) {
            case 0:
              expect(request.url.host, 'openidconnect.googleapis.com');
              return profile();
            case 1:
              final metadata = jsonDecode(request.body) as Map<String, dynamic>;
              expect(metadata['parents'], ['appDataFolder']);
              expect(metadata['appProperties'], {'bazaarBackup': '1'});
              expect(request.url.queryParameters['uploadType'], 'resumable');
              return http.Response(
                '',
                200,
                headers: {
                  'location': 'https://www.googleapis.com/upload/drive/v3/files?upload_id=test',
                },
              );
            case 2:
              expect(request.method, 'PUT');
              expect(request.bodyBytes, bytes);
              return http.Response('{"id":"backup-1"}', 200);
            case 3:
              expect(request.url.queryParameters['spaces'], 'appDataFolder');
              return http.Response(
                jsonEncode({
                  'files': [
                    {
                      'id': 'backup-1',
                      'name': 'backup.json',
                      'createdTime': '2026-09-10T00:00:00Z',
                    },
                  ],
                }),
                200,
              );
            case 4:
              expect(request.url.path, '/drive/v3/files/backup-1');
              expect(request.url.queryParameters['alt'], 'media');
              return http.Response.bytes(bytes, 200);
            default:
              throw StateError('Unexpected request');
          }
        }),
      );
      addTearDown(drive.dispose);
      await drive.connect();
      expect(drive.email, 'test@example.com');
      await drive.upload(bytes, 'backup.json');
      final backups = await drive.listBackups();
      expect(await drive.download(backups.single), bytes);
      expect(step, 5);
    },
  );

  test('never forwards an access token to an untrusted upload URL', () async {
    var calls = 0;
    final drive = GoogleDriveBackups(
      auth: FakeDriveAuth(),
      client: MockClient((request) async {
        if (calls++ == 0) return profile();
        expect(request.url.host, 'www.googleapis.com');
        return http.Response(
          '',
          200,
          headers: {'location': 'https://example.com/upload'},
        );
      }),
    );
    addTearDown(drive.dispose);
    await drive.connect();
    await expectLater(
      drive.upload(Uint8List.fromList([1]), 'backup.json'),
      throwsA(isA<DriveException>()),
    );
    expect(calls, 2);
  });

  test(
    'expired authorization clears the account and requests reconnecting',
    () async {
      var calls = 0;
      final drive = GoogleDriveBackups(
        auth: FakeDriveAuth(),
        client: MockClient(
          (_) async => calls++ == 0 ? profile() : http.Response('{}', 401),
        ),
      );
      addTearDown(drive.dispose);
      await drive.connect();
      await expectLater(
        drive.listBackups(),
        throwsA(
          isA<DriveException>().having(
            (error) => error.key,
            'key',
            'driveSessionExpired',
          ),
        ),
      );
      expect(drive.connected, isFalse);
      expect(drive.email, isNull);
    },
  );
}
