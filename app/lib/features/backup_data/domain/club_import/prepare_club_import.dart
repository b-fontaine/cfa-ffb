import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_rules.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_planner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_integrity.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Prépare l'import d'une sauvegarde vers le club actif **sans rien écrire**
/// (FB7, ADR 0024 décision 19) : lit le fichier (formats 1 à 5), contrôle son
/// intégrité et ses références au catalogue, lit l'état du club dans le
/// périmètre du rôle, puis calcule le plan ([ClubImportPlanner]).
///
/// Un fichier refusé n'est pas une erreur du service : c'est un plan `blocked`
/// dont le rapport dit pourquoi, comme tout autre contrôle. Seule une lecture
/// du club qui échoue (réseau, droits) est un échec.
@Environment(Environment.prod)
@injectable
class PrepareClubImport {
  const PrepareClubImport(
    this._codec,
    this._rules,
    this._store,
    this._scope,
    this._clock,
  );

  final BackupCodec _codec;
  final BackupRules _rules;
  final ClubImportStore _store;
  final ActiveClubScope _scope;
  final Clock _clock;

  Future<Result<ClubImportPlan>> call(
    String content, {
    ImportDecisions decisions = ImportDecisions.none,
    Set<StudentId>? newerFileStudents,
    ImportLimits limits = const ImportLimits(),
  }) => runGuarded(() async {
    final role = _scope.role;
    if (role == null || _scope.clubId == null) {
      throw const ServiceFailure(ServiceFailureCode.denied, 'no-active-club');
    }
    final actor = ImportActor(role, {..._scope.groupIds});
    final now = _clock.now();
    const planner = ClubImportPlanner();
    final DecodedBackup decoded;
    try {
      decoded = _codec.decodeForImport(content, collect: true);
    } on InvariantViolation catch (violation) {
      return planner.plan(
        ClubImportInput(
          actor: actor,
          now: now,
          limits: limits,
          preProblems: [
            ImportProblem(switch (violation.code) {
              InvariantCode.backupUnreadable => ImportProblemCode.unreadable,
              InvariantCode.backupVersionUnsupported =>
                ImportProblemCode.versionUnsupported,
              _ => ImportProblemCode.invalid,
            }, null),
          ],
        ),
      );
    }
    final preProblems = <ImportProblem>[];
    // Les références du catalogue ne se vérifient que sur un fichier cohérent
    // (sinon la première erreur masquerait le rapport d'intégrité).
    if (const ImportIntegrity().check(decoded.snapshot).isEmpty) {
      try {
        await _rules.check(decoded.snapshot);
      } on InvariantViolation catch (violation) {
        preProblems.add(
          ImportProblem(switch (violation.code) {
            InvariantCode.backupUnknownSheet => ImportProblemCode.unknownSheet,
            InvariantCode.backupUnknownBlock => ImportProblemCode.unknownBlock,
            InvariantCode.backupInconsistent =>
              ImportProblemCode.inconsistentCatalogue,
            _ => ImportProblemCode.invalid,
          }, null),
        );
      }
    }
    final inventory = await _store.inventory(decoded.fingerprint);
    return planner.plan(
      ClubImportInput(
        snapshot: decoded.snapshot,
        fingerprint: decoded.fingerprint,
        version: decoded.version,
        exportedAt: decoded.exportedAt,
        actor: actor,
        inventory: inventory,
        decisions: decisions,
        now: now,
        limits: limits,
        preProblems: preProblems,
        newerFileStudents: newerFileStudents,
      ),
    );
  });
}
