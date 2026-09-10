import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'drive_types.dart';

DriveAuth createDriveAuth() => _DesktopDriveAuth();

class _DesktopDriveAuth extends DriveAuth {
  Completer<String>? _pending;
  bool _cancelled = false;
  @override
  bool get supported =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  String _random() => base64UrlEncode(
    List<int>.generate(32, (_) => Random.secure().nextInt(256)),
  ).replaceAll('=', '');

  @override
  Future<DriveToken> connect() async {
    if (!supported) throw const DriveException('driveUnsupported');
    if (!configured) throw const DriveException('driveNeedsSetup');
    _cancelled = false;
    final verifier = _random();
    final challenge = base64UrlEncode(
      (await Sha256().hash(utf8.encode(verifier))).bytes,
    ).replaceAll('=', '');
    final state = _random();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = http.Client();
    final pending = Completer<String>();
    _pending = pending;
    final redirect = 'http://127.0.0.1:${server.port}/';
    // Attach an error listener before starting the browser or receiving callbacks.
    final codeFuture = pending.future.timeout(const Duration(minutes: 2));
    unawaited(codeFuture.then<void>((_) {}, onError: (Object _) {}));
    server.listen((request) async {
      if (request.method != 'GET' ||
          request.uri.path != '/' ||
          request.uri.queryParameters['state'] != state) {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
        return;
      }
      final code = request.uri.queryParameters['code'];
      request.response.headers.contentType = ContentType.text;
      request.response.headers.set('Cache-Control', 'no-store');
      request.response.write(
        'Return to Bazaar POS to finish connecting Google Drive.',
      );
      await request.response.close();
      if (pending.isCompleted) return;
      if (code == null || request.uri.queryParameters.containsKey('error')) {
        pending.completeError(const DriveException('driveSignInCancelled'));
      } else {
        pending.complete(code);
      }
    });
    try {
      if (_cancelled) throw const DriveException('driveSignInCancelled');
      final opened = await launchUrl(
        Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
          'client_id': googleDriveClientId,
          'redirect_uri': redirect,
          'response_type': 'code',
          'scope': driveScopes,
          'state': state,
          'code_challenge': challenge,
          'code_challenge_method': 'S256',
          'access_type': 'online',
          'prompt': 'select_account',
        }),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw const DriveException('driveOpenFailed');
      final code = await codeFuture;
      const clientSecret = String.fromEnvironment('GOOGLE_DRIVE_CLIENT_SECRET');
      final response = await client
          .post(
            Uri.https('oauth2.googleapis.com', '/token'),
            body: {
              'client_id': googleDriveClientId,
              if (clientSecret.isNotEmpty) 'client_secret': clientSecret,
              'code': code,
              'code_verifier': verifier,
              'grant_type': 'authorization_code',
              'redirect_uri': redirect,
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw const DriveException('driveConnectionFailed');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (!(json['scope'] as String? ?? '')
              .split(' ')
              .contains(driveBackupScope) ||
          json['access_token'] is! String ||
          json['expires_in'] is! int) {
        throw const DriveException('drivePermissionMissing');
      }
      return DriveToken(
        json['access_token'] as String,
        DateTime.now().add(Duration(seconds: json['expires_in'] as int)),
      );
    } finally {
      if (!pending.isCompleted) {
        pending.completeError(const DriveException('driveSignInCancelled'));
      }
      _pending = null;
      client.close();
      await server.close(force: true);
    }
  }

  @override
  void cancel() {
    _cancelled = true;
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const DriveException('driveSignInCancelled'));
    }
  }
}
