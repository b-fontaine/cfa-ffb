import 'package:billard_cfa/entities/maturity_assessment/data/assessment_document.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/assessment_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/data_owner.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';
import 'package:billard_cfa/shared/persistence/student_data.dart';

/// Bilans de maturité du club actif dans `clubs/{c}/assessments/{id}`. Choisi
/// par `DataBackend.firestore`.
///
/// - **réservés aux animateurs** (B2 : bilans et alertes exclus) : un parent
///   ou un élève reçoit des listes vides, aucune requête refusée ;
/// - groupe et saison dénormalisés : un groupe de la fiche ; rejouer un
///   identifiant connu **remplace** le bilan chez le même propriétaire, la
///   remarque retirée est effacée ;
/// - `delete` est physique (décision 15) ; listes triées par jour puis
///   identifiant.
class FirestoreAssessmentRepository implements AssessmentRepository {
  FirestoreAssessmentRepository(this._club)
    : _owners = OwnerResolver(_club),
      _data = StudentData(
        _club,
        (paths) => paths.assessments,
        familyMayRead: false,
      );

  final ClubStore _club;
  final OwnerResolver _owners;
  final StudentData _data;

  @override
  Future<void> add(MaturityAssessment assessment) => guardStore(
    () => _data.upsert(
      _club.paths.assessment(assessment.id),
      (owner, {required exists}) =>
          AssessmentDocument.encode(assessment, owner),
      () => _owners.ofStudent(assessment.studentId),
    ),
  );

  @override
  Future<List<MaturityAssessment>> forStudent(StudentId studentId) =>
      guardStore(() async => _sorted(await _data.forStudent(studentId)));

  @override
  Future<List<MaturityAssessment>> all() =>
      guardStore(() async => _sorted(await _data.all()));

  @override
  Stream<List<MaturityAssessment>> watchForStudent(StudentId studentId) =>
      guardStoreStream(() => _data.watchForStudent(studentId).map(_sorted));

  @override
  Future<void> delete(AssessmentId id) =>
      guardStore(() => _club.commit([DeleteOp(_club.paths.assessment(id))]));

  @override
  Future<void> eraseStudent(StudentId studentId) =>
      guardStore(() => _data.eraseStudent(studentId));

  List<MaturityAssessment> _sorted(List<StoredDocument> documents) =>
      decodeValid(documents, AssessmentDocument.decode)
        ..sort(AssessmentDocument.compare);
}
