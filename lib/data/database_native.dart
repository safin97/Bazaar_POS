import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3/common.dart';

Future<CommonDatabase> openDatabase() async {
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return sqlite3.open('${dir.path}/Bazaar_POS.sqlite');
}

CommonDatabase memoryDatabase() => sqlite3.openInMemory();
