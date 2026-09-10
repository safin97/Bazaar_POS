import 'dart:convert';
import 'dart:js_interop';

import 'drive_types.dart';

@JS('bazaarDrivePrepare')
external JSPromise<JSAny?> _prepare();
@JS('bazaarDriveConnect')
external JSPromise<JSString> _connect(JSString clientId);
@JS('bazaarDriveCancel')
external JSFunction? get _cancel;

DriveAuth createDriveAuth() => _WebDriveAuth();

class _WebDriveAuth extends DriveAuth {
  @override
  bool get supported => true;
  @override
  Future<void> prepare() async {
    await _prepare().toDart;
  }

  @override
  Future<DriveToken> connect() async {
    // The JavaScript bridge opens Google's popup immediately on this tap.
    final response = jsonDecode(
      (await _connect(googleDriveClientId.toJS).toDart).toDart,
    ) as Map<String, dynamic>;
    if (response['error'] is String) {
      throw DriveException(response['error'] as String);
    }
    return DriveToken(
      response['accessToken'] as String,
      DateTime.now().add(Duration(seconds: response['expiresIn'] as int)),
    );
  }

  @override
  void cancel() => _cancel?.callAsFunction();
}
