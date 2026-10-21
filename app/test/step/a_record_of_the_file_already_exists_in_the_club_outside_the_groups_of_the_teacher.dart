import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';
import '../support/realistic_backup.dart';

/// Usage:
/// a record of the file already exists in the club outside the groups of
/// the teacher
///
/// Un enseignant ne voit que les fiches de ses groupes : celle-ci lui est
/// invisible (groupe d'un autre) ; les règles refuseront son lot.
Future<void> aRecordOfTheFileAlreadyExistsInTheClubOutsideTheGroupsOfTheTeacher(
  WidgetTester tester,
) async {
  final id = RealisticBackup(groups: 1).studentId(1, 1).value;
  ImportWorld.current.seed('clubs/c1/students/$id', {
    'firstName': 'Déjà là',
    'audience': 'children',
    'groupIds': ['g-autre'],
  });
}
