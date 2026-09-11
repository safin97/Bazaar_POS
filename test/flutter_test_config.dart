import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    // Widget tests have no native host to answer package-info platform calls.
    PackageInfo.setMockInitialValues(
      appName: 'Bazaar_POS',
      packageName: 'com.example.Bazaar_POS',
      version: '1.0.1',
      buildNumber: '2',
      buildSignature: '',
    );
  });
  await testMain();
}
