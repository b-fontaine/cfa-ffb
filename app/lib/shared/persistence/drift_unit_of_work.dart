import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:injectable/injectable.dart';

/// Unité de travail SQLite : une transaction. Toutes les écritures faites par
/// les repositories pendant [run] (même zone) sont validées ensemble ou
/// annulées ensemble si le corps lève une exception.
@LazySingleton(env: [Environment.prod])
class DriftUnitOfWork implements UnitOfWork {
  DriftUnitOfWork(this._db);

  final AppDatabase _db;

  @override
  Future<T> run<T>(Future<T> Function() body) => _db.transaction(body);
}
