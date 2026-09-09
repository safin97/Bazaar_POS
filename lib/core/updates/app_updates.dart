export 'updates_stub.dart' if (dart.library.js_interop) 'updates_web.dart';

const appVersion = '1.0.0';
const appBuildId = String.fromEnvironment(
  'APP_BUILD_ID',
  defaultValue: 'development',
);
