import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/in_memory_journal.dart';
import 'package:injectable/injectable.dart';

/// Unité de travail des implémentations en mémoire : les écritures des dépôts
/// en mémoire sont journalisées (`InMemoryJournal`) et annulées si le corps
/// lève une exception, comme la transaction SQLite.
@LazySingleton(as: UnitOfWork, env: [Environment.test])
class InMemoryUnitOfWork implements UnitOfWork {
  @override
  Future<T> run<T>(Future<T> Function() body) => InMemoryJournal().run(body);
}
