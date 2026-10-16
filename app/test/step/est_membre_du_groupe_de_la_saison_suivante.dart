import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/group_ops.dart';
import '../support/tracking_world.dart';

/// Usage: {'Zoé'} est membre du groupe {'Jeunes'} de la saison suivante
Future<void> estMembreDuGroupeDeLaSaisonSuivante(
  WidgetTester tester,
  String student,
  String group,
) async {
  final found = await GroupOps.studentNamed(student);
  expect(found, isNotNull, reason: 'élève introuvable : $student');
  final groups = await getIt<GroupRepository>().all();
  final next = groups.where(
    (g) => g.name.startsWith(group) && g.seasonId != TrackingWorld.seasonId,
  );
  expect(
    next,
    isNotEmpty,
    reason: 'aucun groupe $group dans la saison suivante',
  );
  expect(
    next.any(
      (g) => g.memberships.any((m) => m.studentId == found!.id && m.to == null),
    ),
    isTrue,
  );
}
