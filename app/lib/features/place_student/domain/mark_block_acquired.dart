import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : marquer un bloc entier acquis au positionnement d'un élève
/// (ADR 0008). Aucun passage fictif : le marqueur est un état distinct.
@injectable
class MarkBlockAcquired {
  MarkBlockAcquired(
    this._students,
    this._acquisitions,
    this._catalogue,
    this._ids,
    this._unitOfWork,
  );

  final StudentRepository _students;
  final AcquisitionRepository _acquisitions;
  final CatalogueRepository _catalogue;
  final IdGenerator _ids;
  final UnitOfWork _unitOfWork;

  /// [today] borne la date du positionnement (jamais dans le futur) ; [date]
  /// est normalisée au jour.
  Future<Result<BlockAcquisition>> call({
    required StudentId studentId,
    required String blockId,
    required DateTime date,
    required DateTime today,
  }) => runGuarded(() async {
    if (await _students.byId(studentId) == null) {
      throw NotFound('student', studentId.value);
    }
    final catalogue = await _catalogue.load();
    if (catalogue.blockById(blockId) == null) {
      throw const InvariantViolation(InvariantCode.unknownBlock);
    }
    final day = date.dateOnly;
    if (day.isAfter(today.dateOnly)) {
      throw const InvariantViolation(InvariantCode.dateInFuture);
    }
    return await _unitOfWork.run(() async {
      final existing = await _acquisitions.forStudent(studentId);
      if (existing.any((a) => a.blockId == blockId)) {
        throw const InvariantViolation(InvariantCode.blockAlreadyAcquired);
      }
      final acquisition = BlockAcquisition(
        id: AcquisitionId(_ids.next()),
        studentId: studentId,
        blockId: blockId,
        date: day,
        source: AcquisitionSource.placement,
      );
      await _acquisitions.add(acquisition);
      return acquisition;
    });
  });
}
