import 'package:billard_cfa/entities/exercise_result/domain/acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/changes.dart';
import 'package:injectable/injectable.dart';

/// Les changements des données de la liste des groupes et de leurs élèves
/// (FB5b) : fiches, groupes et appartenances, passages, blocs acquis et « Vu »
/// (les compteurs et alertes de la liste en dérivent). La liste se recharge
/// par `GetClubOverview`. Les saisons ne se suivent pas : une saison change
/// rarement et par une action de cet appareil (voir `ADR 0024`, notes FB5b).
@injectable
class WatchClubOverview {
  WatchClubOverview(
    this._students,
    this._groups,
    this._attempts,
    this._acquisitions,
    this._acknowledgements,
  );

  final StudentRepository _students;
  final GroupRepository _groups;
  final AttemptRepository _attempts;
  final AcquisitionRepository _acquisitions;
  final AcknowledgementRepository _acknowledgements;

  Stream<void> call() => changesOf([
    _students.watchAll(),
    _groups.watchAll(),
    _attempts.watchAll(),
    _acquisitions.watchAll(),
    _acknowledgements.watchAll(),
  ]);
}
