import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/data_owner.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';

/// Correspondance bloc acquis <-> document `clubs/{c}/acquisitions/{id}` (liste
/// blanche de `acquisitionShape` + `studentOwned`).
abstract final class AcquisitionDocument {
  static Fields encode(BlockAcquisition acquisition, DataOwner owner) => {
    'groupId': owner.group.value,
    'seasonId': owner.season.value,
    'studentId': acquisition.studentId.value,
    'blockId': acquisition.blockId,
    'date': DocumentValues.encodeDate(acquisition.date),
    'source': acquisition.source.name,
  };

  static BlockAcquisition decode(StoredDocument document) {
    final values = DocumentValues(document.path, document.fields);
    final source = values.string('source');
    final known = AcquisitionSource.values.where((s) => s.name == source);
    if (known.isEmpty) {
      throw ServiceFailure(
        ServiceFailureCode.other,
        'malformed document ${document.path}: unknown source',
      );
    }
    try {
      return BlockAcquisition(
        id: AcquisitionId(document.id),
        studentId: StudentId(values.string('studentId')),
        blockId: values.string('blockId'),
        date: values.date('date'),
        source: known.first,
      );
    } on InvariantViolation catch (violation) {
      throw ServiceFailure(
        ServiceFailureCode.other,
        'malformed document ${document.path}: ${violation.code.name}',
      );
    }
  }

  /// Ordre canonique : jour, puis identifiant (l'ordre d'enregistrement
  /// n'existe pas côté serveur).
  static int compare(BlockAcquisition a, BlockAcquisition b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.id.value.compareTo(b.id.value);
  }
}
