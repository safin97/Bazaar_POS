import 'package:sqlite3/wasm.dart';

Future<CommonDatabase> openDatabase() async {
  final sqlite = await WasmSqlite3.loadFromUrl(
    Uri.base.resolve('sqlite3.wasm'),
  );
  sqlite.registerVirtualFileSystem(
    await IndexedDbFileSystem.open(dbName: 'bazaar-pos-v1'),
    makeDefault: true,
  );
  return sqlite.open('/bazaar.sqlite');
}

CommonDatabase memoryDatabase() =>
    throw UnsupportedError('Use native Flutter tests for in-memory databases.');
