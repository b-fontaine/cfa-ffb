import 'package:billard_cfa/app/data_backend.dart';
import 'package:billard_cfa/app/di/data_backend_module.dart';
import 'package:billard_cfa/entities/group/data/drift_group_repository.dart';
import 'package:billard_cfa/entities/group/data/firestore_group_repository.dart';
import 'package:billard_cfa/entities/settings/data/drift_settings_repository.dart';
import 'package:billard_cfa/entities/settings/data/firestore_settings_repository.dart';
import 'package:billard_cfa/entities/student/data/drift_student_repository.dart';
import 'package:billard_cfa/entities/student/data/firestore_student_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/firestore_world.dart';

class _Module extends DataBackendModule;

class _DriftSettings extends Mock implements DriftSettingsRepository;

class _DriftStudents extends Mock implements DriftStudentRepository;

class _DriftGroups extends Mock implements DriftGroupRepository;

void main() {
  final module = _Module();
  final club = FirestoreWorld().club;
  final settings = _DriftSettings();
  final students = _DriftStudents();
  final groups = _DriftGroups();

  group('with DATA_BACKEND=firestore', () {
    const choice = DataBackendChoice(DataBackend.firestore);

    test('settings, students and groups are the Firestore repositories', () {
      expect(
        module.settingsRepository(choice, settings, club),
        isA<FirestoreSettingsRepository>(),
      );
      expect(
        module.studentRepository(choice, students, club),
        isA<FirestoreStudentRepository>(),
      );
      expect(
        module.groupRepository(choice, groups, club),
        isA<FirestoreGroupRepository>(),
      );
    });
  });

  group('with DATA_BACKEND=drift', () {
    const choice = DataBackendChoice(DataBackend.drift);

    test('the very drift instances are returned', () {
      expect(module.settingsRepository(choice, settings, club), same(settings));
      expect(module.studentRepository(choice, students, club), same(students));
      expect(module.groupRepository(choice, groups, club), same(groups));
    });
  });
}
