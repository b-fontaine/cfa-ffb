import 'dart:io';

import 'package:billard_cfa/shared/persistence/local_store_handle.dart';
import 'package:billard_cfa/shared/persistence/open_app_database.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Le fichier de la base locale, à l'emplacement où `openAppDatabase` (drift
/// Flutter) le met : jamais créé ici.
Future<File> localStoreFile(DatabaseSettings settings) async {
  final native = settings.native;
  if (native?.databasePath case final lookup?) return File(await lookup());
  final resolved =
      await (native?.databaseDirectory ?? getApplicationDocumentsDirectory)();
  final directory = switch (resolved) {
    Directory(:final path) => path,
    final String path => path,
    final other => throw ArgumentError.value(other, 'databaseDirectory'),
  };
  return File('$directory${Platform.pathSeparator}$appDatabaseName.sqlite');
}

/// La base **si le fichier existe**, `null` sinon (rien n'est créé), ouverte
/// par SQLite en **lecture seule** (`SQLITE_OPEN_READONLY`) : SQLite ne crée
/// pas un fichier qui a disparu depuis le test d'existence, et ne peut pas
/// rejouer un journal en attente (ce qui écrirait dans la base).
Future<LocalStoreHandle?> openExistingLocalStore(
  DatabaseSettings settings,
) async {
  final file = await localStoreFile(settings);
  // Un dossier à la place du fichier n'est pas « absent » : illisible.
  if (FileSystemEntity.typeSync(file.path) == FileSystemEntityType.notFound) {
    return null;
  }
  final Database database;
  try {
    database = sqlite3.open(file.path, mode: OpenMode.readOnly);
  } on SqliteException {
    // Le fichier a disparu entre le test et l'ouverture : il est absent.
    if (FileSystemEntity.typeSync(file.path) == FileSystemEntityType.notFound) {
      return null;
    }
    rethrow;
  }
  return LocalStoreHandle(NativeDatabase.opened(database));
}
