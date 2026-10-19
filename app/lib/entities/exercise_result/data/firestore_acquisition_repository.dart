import 'package:billard_cfa/entities/exercise_result/data/acquisition_document.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/data_owner.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';
import 'package:billard_cfa/shared/persistence/student_data.dart';

/// Blocs acquis au positionnement du club actif dans
/// `clubs/{c}/acquisitions/{id}`. Choisi par `DataBackend.firestore`.
///
/// - groupe et saison dénormalisés : un groupe de la fiche (`OwnerResolver`) ;
///   rejouer un identifiant connu **remplace** le marqueur chez le même
///   propriétaire (idempotent) ;
/// - lecture par rôle (`StudentData`) : un parent ou un élève lit **les blocs
///   acquis de sa fiche liée** (`GetStudentShowcase`), jamais ceux d'une
///   autre ;
/// - `delete` est physique (décision 15) ; listes triées par jour puis
///   identifiant.
class FirestoreAcquisitionRepository implements AcquisitionRepository {
  FirestoreAcquisitionRepository(this._club)
    : _owners = OwnerResolver(_club),
      _data = StudentData(
        _club,
        (paths) => paths.acquisitions,
        familyMayRead: true,
      );

  final ClubStore _club;
  final OwnerResolver _owners;
  final StudentData _data;

  @override
  Future<void> add(BlockAcquisition acquisition) => guardStore(
    () => _data.upsert(
      _club.paths.acquisition(acquisition.id),
      (owner, {required exists}) =>
          AcquisitionDocument.encode(acquisition, owner),
      () => _owners.ofStudent(acquisition.studentId),
    ),
  );

  @override
  Future<List<BlockAcquisition>> forStudent(StudentId studentId) =>
      guardStore(() async => _sorted(await _data.forStudent(studentId)));

  @override
  Future<List<BlockAcquisition>> all() =>
      guardStore(() async => _sorted(await _data.all()));

  @override
  Stream<List<BlockAcquisition>> watchForStudent(StudentId studentId) =>
      guardStoreStream(() => _data.watchForStudent(studentId).map(_sorted));

  @override
  Stream<List<BlockAcquisition>> watchAll() =>
      guardStoreStream(() => _data.watchAll().map(_sorted));

  @override
  Future<void> delete(AcquisitionId id) =>
      guardStore(() => _club.commit([DeleteOp(_club.paths.acquisition(id))]));

  @override
  Future<void> eraseStudent(StudentId studentId) =>
      guardStore(() => _data.eraseStudent(studentId));

  List<BlockAcquisition> _sorted(List<StoredDocument> documents) =>
      decodeValid(documents, AcquisitionDocument.decode)
        ..sort(AcquisitionDocument.compare);
}
