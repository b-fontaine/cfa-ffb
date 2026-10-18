import 'package:billard_cfa/app/data_backend.dart';
import 'package:billard_cfa/entities/group/data/drift_group_repository.dart';
import 'package:billard_cfa/entities/group/data/firestore_group_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/settings/data/drift_settings_repository.dart';
import 'package:billard_cfa/entities/settings/data/firestore_settings_repository.dart';
import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:billard_cfa/entities/student/data/drift_student_repository.dart';
import 'package:billard_cfa/entities/student/data/firestore_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:injectable/injectable.dart';

/// Aiguillage des dépôts de données entre drift (défaut) et Firestore (ADR
/// 0024, décision 28). Les dépôts migrés **un lot à la fois** y entrent ;
/// les autres restent drift. Le réglage est `DATA_BACKEND` (voir
/// [DataBackend]) ; les tests et les scénarios BDD (`Environment.test`)
/// gardent leurs dépôts en mémoire et n'en dépendent pas.
@module
abstract class DataBackendModule {
  @Environment(Environment.prod)
  @singleton
  DataBackendChoice dataBackend() => DataBackendChoice(DataBackend.fromBuild());

  @Environment(Environment.prod)
  @lazySingleton
  SettingsRepository settingsRepository(
    DataBackendChoice choice,
    DriftSettingsRepository drift,
    ClubStore club,
  ) => choice.backend.choose(
    drift: () => drift,
    firestore: () => FirestoreSettingsRepository(club),
  );

  @Environment(Environment.prod)
  @lazySingleton
  StudentRepository studentRepository(
    DataBackendChoice choice,
    DriftStudentRepository drift,
    ClubStore club,
  ) => choice.backend.choose(
    drift: () => drift,
    firestore: () => FirestoreStudentRepository(club),
  );

  @Environment(Environment.prod)
  @lazySingleton
  GroupRepository groupRepository(
    DataBackendChoice choice,
    DriftGroupRepository drift,
    ClubStore club,
  ) => choice.backend.choose(
    drift: () => drift,
    firestore: () => FirestoreGroupRepository(club),
  );
}
