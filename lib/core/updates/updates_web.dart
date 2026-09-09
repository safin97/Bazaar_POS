import 'dart:js_interop';

const supportsUpdates = true;
@JS('bazaarFetchBuildId')
external JSPromise<JSString> _fetchBuildId();
@JS('bazaarReloadApp')
external void _reloadApp();
Future<String> fetchBuildId() async =>
    (await _fetchBuildId().toDart.timeout(const Duration(seconds: 12))).toDart;
void reloadApp() => _reloadApp();
