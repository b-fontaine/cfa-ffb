import 'package:billard_cfa/entities/exercise_result/domain/acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/change_feed.dart';
import 'package:billard_cfa/shared/persistence/in_memory_journal.dart';
import 'package:injectable/injectable.dart';

/// Implémentation en mémoire (tests, BDD).
@LazySingleton(as: AcknowledgementRepository, env: [Environment.test])
class InMemoryAcknowledgementRepository implements AcknowledgementRepository {
  final ObservedMap<AcknowledgementId, AlertAcknowledgement> _acknowledgements =
      ObservedMap();

  @override
  Future<void> add(AlertAcknowledgement acknowledgement) async =>
      _acknowledgements.journaledPut(acknowledgement.id, acknowledgement);

  @override
  Future<List<AlertAcknowledgement>> forStudent(StudentId studentId) async => [
    for (final acknowledgement in _acknowledgements.values)
      if (acknowledgement.studentId == studentId) acknowledgement,
  ]..sort((a, b) => a.date.compareTo(b.date));

  @override
  Future<List<AlertAcknowledgement>> all() async =>
      _acknowledgements.values.toList();

  @override
  Future<void> delete(AcknowledgementId id) async =>
      _acknowledgements.journaledRemove(id);

  @override
  Future<void> eraseStudent(StudentId studentId) async {
    for (final acknowledgement in _acknowledgements.values.toList()) {
      if (acknowledgement.studentId == studentId) {
        _acknowledgements.journaledRemove(acknowledgement.id);
      }
    }
  }

  @override
  Future<void> eraseAll() async {
    _acknowledgements.keys.toList().forEach(_acknowledgements.journaledRemove);
  }

  @override
  Stream<List<AlertAcknowledgement>> watchForStudent(StudentId studentId) =>
      _acknowledgements.watch(() => forStudent(studentId));

  @override
  Stream<List<AlertAcknowledgement>> watchAll() => _acknowledgements.watch(all);
}
