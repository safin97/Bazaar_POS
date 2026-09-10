import 'drive_types.dart';

DriveAuth createDriveAuth() => _UnavailableAuth();

class _UnavailableAuth extends DriveAuth {
  @override
  bool get supported => false;
  @override
  Future<DriveToken> connect() =>
      Future.error(const DriveException('driveUnsupported'));
}
