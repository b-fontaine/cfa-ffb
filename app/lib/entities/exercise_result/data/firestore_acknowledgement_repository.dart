import 'package:billard_cfa/entities/exercise_result/data/acknowledgement_document.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/data_owner.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';
import 'package:billard_cfa/shared/persistence/student_data.dart';

/// Acquittements d'alertes du club actif dans
/// `clubs/{c}/acknowledgements/{id}`. Choisi par `DataBackend.firestore`.
///
/// - **« Vu » partagé par club** (ADR 0024, B5) : tous les animateurs du groupe
///   voient l'acquittement d'un collègue ; le compte qui l'a donné est
///   enregistré (`createdBy` = uid, donnée personnelle déclarée au registre) ;
///   le domaine ne le porte pas ;
/// - **réservés aux animateurs** (B2 : alertes exclues pour la famille) : un
///   parent ou un élève reçoit des listes vides ;
/// - groupe et saison dénormalisés : ceux du **dernier passage** acquitté s'il
///   existe (l'alerte est celle de ce groupe ; lu au cache, puis au serveur),
///   sinon un groupe de la fiche (aussi quand le serveur est injoignable :
///   l'acquittement s'écrit **hors ligne**) ;
///   rejouer un identifiant connu **remplace** l'acquittement chez le même
///   propriétaire, sans changer qui l'a donné ;
/// - `delete` est physique (décision 15) ; `eraseAll` supprime ceux du club
///   (gestionnaire : import d'un format qui ne les connaît pas, ADR 0013).
class FirestoreAcknowledgementRepository implements AcknowledgementRepository {
  FirestoreAcknowledgementRepository(this._club, this._user)
    : _owners = OwnerResolver(_club),
      _data = StudentData(
        _club,
        (paths) => paths.acknowledgements,
        familyMayRead: false,
      );

  final ClubStore _club;
  final CurrentUser _user;
  final OwnerResolver _owners;
  final StudentData _data;

  @override
  Future<void> add(AlertAcknowledgement acknowledgement) =>
      guardStore(() async {
        final user = _user.id;
        if (user == null) {
          throw const ServiceFailure(ServiceFailureCode.denied, 'no-user');
        }
        await _data.upsert(
          _club.paths.acknowledgement(acknowledgement.id),
          (owner, {required exists}) => AcknowledgementDocument.encode(
            acknowledgement,
            owner,
            createdBy: exists ? null : user,
          ),
          () => _ownerOf(acknowledgement),
        );
      });

  /// Le groupe du dernier passage acquitté (même élève), sinon un groupe de la
  /// fiche.
  Future<DataOwner> _ownerOf(AlertAcknowledgement acknowledgement) async {
    final path = _club.paths.attempt(acknowledgement.lastAttemptId);
    // Le cache d'abord ; à défaut, le serveur, et hors ligne le groupe de la
    // fiche : l'acquittement s'écrit sans réseau (FB5).
    StoredDocument? attempt;
    try {
      attempt = await _club.cachedOrGet(path);
    } on StoreFailure catch (failure) {
      if (failure.code != StoreFailureCode.unavailable) rethrow;
    }
    if (attempt != null) {
      final values = DocumentValues(attempt.path, attempt.fields);
      if (values.string('studentId') == acknowledgement.studentId.value) {
        return DataOwner(
          GroupId(values.string('groupId')),
          SeasonId(values.string('seasonId')),
        );
      }
    }
    return await _owners.ofStudent(acknowledgement.studentId);
  }

  @override
  Future<List<AlertAcknowledgement>> forStudent(StudentId studentId) =>
      guardStore(() async => _sorted(await _data.forStudent(studentId)));

  @override
  Future<List<AlertAcknowledgement>> all() =>
      guardStore(() async => _sorted(await _data.all()));

  @override
  Future<void> delete(AcknowledgementId id) => guardStore(
    () => _club.commit([DeleteOp(_club.paths.acknowledgement(id))]),
  );

  @override
  Future<void> eraseStudent(StudentId studentId) =>
      guardStore(() => _data.eraseStudent(studentId));

  @override
  Future<void> eraseAll() => guardStore(() async {
    final documents = await _club.documents.list(_club.paths.acknowledgements);
    await _club.commit([
      for (final document in documents) DeleteOp(document.path),
    ]);
  });

  List<AlertAcknowledgement> _sorted(List<StoredDocument> documents) =>
      decodeValid(documents, AcknowledgementDocument.decode)
        ..sort(AcknowledgementDocument.compare);
}
