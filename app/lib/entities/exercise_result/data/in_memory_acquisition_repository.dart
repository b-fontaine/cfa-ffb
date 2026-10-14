import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/in_memory_journal.dart';
import 'package:injectable/injectable.dart';

/// Implémentation en mémoire (tests, BDD).
@LazySingleton(as: AcquisitionRepository, env: [Environment.test])
class InMemoryAcquisitionRepository implements AcquisitionRepository {
  final Map<AcquisitionId, BlockAcquisition> _acquisitions = {};

  @override
  Future<void> add(BlockAcquisition acquisition) async =>
      _acquisitions.journaledPut(acquisition.id, acquisition);

  @override
  Future<List<BlockAcquisition>> forStudent(StudentId studentId) async => [
    for (final acquisition in _acquisitions.values)
      if (acquisition.studentId == studentId) acquisition,
  ]..sort((a, b) => a.date.compareTo(b.date));

  @override
  Future<List<BlockAcquisition>> all() async => _acquisitions.values.toList();

  @override
  Future<void> delete(AcquisitionId id) async =>
      _acquisitions.journaledRemove(id);

  @override
  Future<void> eraseStudent(StudentId studentId) async {
    for (final acquisition in _acquisitions.values.toList()) {
      if (acquisition.studentId == studentId) {
        _acquisitions.journaledRemove(acquisition.id);
      }
    }
  }
}
