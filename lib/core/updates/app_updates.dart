export 'updates_stub.dart' if (dart.library.js_interop) 'updates_web.dart';

// Web must compare the running code's version, not version.json on a server
// that might already have been replaced. tool/build_web.sh supplies these.
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.3');
const appBuildNumber = String.fromEnvironment(
  'APP_BUILD_NUMBER',
  defaultValue: '4',
);
const appBuildId = String.fromEnvironment(
  'APP_BUILD_ID',
  defaultValue: 'development',
);
