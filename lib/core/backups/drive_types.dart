const driveBackupScope = 'https://www.googleapis.com/auth/drive.appdata';
const driveScopes = 'openid email $driveBackupScope';
const googleDriveClientId = String.fromEnvironment('GOOGLE_DRIVE_CLIENT_ID');

class DriveException implements Exception {
  const DriveException(this.key);
  final String key;
}

class DriveToken {
  const DriveToken(this.accessToken, this.expiresAt);
  final String accessToken;
  final DateTime expiresAt;
}

abstract class DriveAuth {
  bool get supported;
  bool get configured => googleDriveClientId.isNotEmpty;
  Future<void> prepare() async {}
  Future<DriveToken> connect();
  void cancel() {}
}

class DriveBackup {
  const DriveBackup({
    required this.id,
    required this.name,
    required this.createdAt,
  });
  final String id;
  final String name;
  final DateTime createdAt;
}
