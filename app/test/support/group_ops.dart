import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/change_audience/domain/change_audience.dart';
import 'package:billard_cfa/features/manage_groups/domain/create_group.dart';
import 'package:billard_cfa/features/manage_groups/domain/delete_group.dart';
import 'package:billard_cfa/features/manage_groups/domain/move_student.dart';
import 'package:billard_cfa/features/manage_groups/domain/rename_group.dart';
import 'package:billard_cfa/features/manage_students/domain/enroll_student.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tracking_world.dart';

/// Opérations de groupes des scénarios du lot 11 : le dernier résultat (accepté
/// ou refusé) et la recherche d'un groupe ou d'un élève par son nom courant
/// (les groupes créés par un cas d'usage n'ont pas d'identifiant dérivé du
/// nom).
class GroupOps {
  static Result<Object?>? last;

  /// Le groupe dont le nom courant est [name] (casse et espaces ignorés).
  static Future<Group> groupNamed(String name) async {
    final wanted = name.trim().toLowerCase();
    final groups = await getIt<GroupRepository>().all();
    return groups.firstWhere(
      (group) => group.name.trim().toLowerCase() == wanted,
      orElse: () => fail('groupe introuvable : $name'),
    );
  }

  static Future<Student?> studentNamed(String name) async {
    final students = await getIt<StudentRepository>().all();
    for (final student in students) {
      if (student.firstName == name) return student;
    }
    return null;
  }

  static Future<void> create(String name, String audience) async {
    last = await getIt<CreateGroup>()(
      seasonId: TrackingWorld.seasonId,
      name: name,
      audience: TrackingWorld.audience(audience),
    );
    if (last case Ok<Object?>(value: final Group group)) {
      TrackingWorld.createdGroups[name] = group.id;
    }
  }

  static Future<void> rename(String name, String newName) async {
    last = await getIt<RenameGroup>()(
      groupId: (await groupNamed(name)).id,
      name: newName,
    );
  }

  static Future<void> delete(String name) async {
    last = await getIt<DeleteGroup>()(
      groupId: (await groupNamed(name)).id,
      today: TrackingWorld.today,
    );
  }

  static Future<void> enroll(
    String student,
    String audience, {
    String? group,
  }) async {
    last = await getIt<EnrollStudent>()(
      firstName: student,
      audience: TrackingWorld.audience(audience),
      today: TrackingWorld.today,
      groupId: group == null ? null : (await groupNamed(group)).id,
    );
  }

  static Future<void> changeAudience(
    String student,
    String audience,
    String date, {
    String? group,
  }) async {
    last = await getIt<ChangeAudience>()(
      studentId: TrackingWorld.studentId(student),
      audience: TrackingWorld.audience(audience),
      effectiveFrom: TrackingWorld.date(date),
      destinationGroupId: group == null ? null : (await groupNamed(group)).id,
    );
  }

  static Future<void> move(String student, String group, String date) async {
    last = await getIt<MoveStudent>()(
      studentId: TrackingWorld.studentId(student),
      toGroupId: (await groupNamed(group)).id,
      on: TrackingWorld.date(date),
    );
  }

  /// Exige que la dernière opération ait réussi.
  static void expectOk() {
    final result = last;
    expect(result, isA<Ok<Object?>>(), reason: 'résultat : $result');
  }

  /// Exige que la dernière opération ait été refusée avec le code [code].
  static void expectRefused(String code) {
    final result = last;
    expect(result, isA<Err<Object?>>(), reason: 'résultat : $result');
    final failure = (result! as Err<Object?>).failure;
    expect(failure, isA<InvariantViolation>());
    expect((failure as InvariantViolation).code.name, code);
  }
}
