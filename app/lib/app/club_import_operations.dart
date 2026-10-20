import 'package:billard_cfa/entities/exercise_result/data/acknowledgement_document.dart';
import 'package:billard_cfa/entities/exercise_result/data/acquisition_document.dart';
import 'package:billard_cfa/entities/exercise_result/data/attempt_document.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/group/data/group_document.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/assessment_document.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/entities/season/data/season_archive_document.dart';
import 'package:billard_cfa/entities/season/data/season_document.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session/data/session_document.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_record/data/session_record_document.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/student/data/student_document.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_planner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_paths.dart';
import 'package:billard_cfa/shared/persistence/data_owner.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';

/// Les écritures Firestore d'**une** écriture du plan d'import : le même
/// document que les dépôts écrivent (mêmes codecs, mêmes champs), seulement
/// créé s'il n'existe pas déjà. Partagé par `FirestoreClubImportStore` et par
/// l'outil qui produit les écritures jouées contre les vraies règles
/// (`tool/import_plan_fixture.dart`).
abstract final class ClubImportOperations {
  /// La marque d'import (`importedAt`, date du serveur) : posée **à la création
  /// seulement**, avec la date du serveur ; elle ne prouve PAS l'origine
  /// d'import (tout animateur peut la poser sur une création ordinaire). Les
  /// règles refusent toute mise à jour qui la pose ou la change : une écriture
  /// d'import sur un document déjà présent (créé entre la lecture de
  /// l'inventaire et le lot) est donc refusée en bloc, quelle que soit la
  /// fraîcheur de l'inventaire. Ni les passages ni les saisies (déjà protégés
  /// par `createdAt`) ne la portent.
  static const Fields _stamp = {'importedAt': serverTimestamp};

  static List<WriteOp> of(
    ClubPaths paths,
    ImportWrite write,
    ClubInventory inventory,
    UserId? user,
  ) {
    final id = write.id;
    final exists = inventory.has(write.category, id);
    if (exists && write.category != ImportCategory.students) return const [];
    final owner = write.group == null || write.season == null
        ? null
        : DataOwner(write.group!, write.season!);
    switch (write.category) {
      case ImportCategory.seasons:
        return [
          SetOp(paths.season(SeasonId(id)), {
            ...SeasonDocument.encode(write.payload as Season),
            ...SeasonDocument.creationOnly(),
            ..._stamp,
          }),
        ];
      case ImportCategory.groups:
        return [
          SetOp(paths.group(GroupId(id)), {
            ...GroupDocument.encode(write.payload as Group),
            ...GroupDocument.creationOnly(),
            ..._stamp,
          }),
        ];
      case ImportCategory.students:
        final student = write.payload as ImportStudent;
        final path = paths.student(student.student.id);
        if (!exists) {
          return [
            SetOp(path, {
              ...StudentDocument.encode(student.student),
              'groupIds': [for (final g in student.groupIds) g.value]..sort(),
              ...StudentDocument.creationOnly(),
              ..._stamp,
            }),
          ];
        }
        final known = inventory.students[student.student.id] ?? const {};
        final missing = [
          for (final g in student.groupIds)
            if (!known.contains(g)) g.value,
        ]..sort();
        return missing.isEmpty
            ? const []
            : [
                SetOp(path, {'groupIds': ArrayUnion(missing)}, merge: true),
              ];
      case ImportCategory.memberships:
        final membership = write.payload as ImportMembership;
        return [
          SetOp('${paths.memberships}/$id', {
            ...GroupDocument.encodeMembershipOf(
              membership.group,
              membership.season,
              membership.membership,
            ),
            ..._stamp,
          }),
        ];
      case ImportCategory.seasonArchives:
        final archive = write.payload as ImportArchiveDoc;
        final block = archive.block;
        final line = archive.line;
        return [
          SetOp(paths.archive(id), {
            ...(block != null
                ? SeasonArchiveDocument.encodeAudience(archive.season, block)
                : SeasonArchiveDocument.encodeExercise(archive.season, line!)),
            ..._stamp,
          }),
        ];
      case ImportCategory.plannedSessions:
        return [
          SetOp(paths.session(id), {
            ...SessionDocument.encode(write.payload as Session, write.season!),
            ...SessionDocument.creationOnly(),
            ..._stamp,
          }),
        ];
      case ImportCategory.sessionRecords:
        return [
          SetOp(paths.record(SessionId(id)), {
            ...SessionRecordDocument.encode(write.payload as SessionRecord),
            ...SessionRecordDocument.creationOnly(),
          }),
        ];
      case ImportCategory.attempts:
        return [
          SetOp(
            paths.attempt(AttemptId(id)),
            AttemptDocument.encode(
              write.payload as ExerciseAttempt,
              owner!,
              recordedAt: write.recordedAt!,
            ),
          ),
        ];
      case ImportCategory.acquisitions:
        return [
          SetOp(paths.acquisition(AcquisitionId(id)), {
            ...AcquisitionDocument.encode(
              write.payload as BlockAcquisition,
              owner!,
            ),
            ..._stamp,
          }),
        ];
      case ImportCategory.assessments:
        return [
          SetOp(paths.assessment(AssessmentId(id)), {
            ...AssessmentDocument.encode(
              write.payload as MaturityAssessment,
              owner!,
            ),
            ..._stamp,
          }),
        ];
      case ImportCategory.acknowledgements:
        if (user == null) {
          throw const StoreFailure(StoreFailureCode.permissionDenied, 'user');
        }
        return [
          SetOp(paths.acknowledgement(AcknowledgementId(id)), {
            ...AcknowledgementDocument.encode(
              write.payload as AlertAcknowledgement,
              owner!,
              createdBy: user,
            ),
            ..._stamp,
          }),
        ];
    }
  }
}
