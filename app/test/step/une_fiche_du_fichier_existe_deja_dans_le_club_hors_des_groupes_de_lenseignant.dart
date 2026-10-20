import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';
import '../support/realistic_backup.dart';

Future<void> uneFicheDuFichierExisteDejaDansLeClubHorsDesGroupesDeLenseignant(
  WidgetTester tester,
) async {
  // Un enseignant ne voit que les fiches de ses groupes : celle-ci lui est
  // invisible (groupe d'un autre).
  ImportWorld.current.seed(
    'clubs/c1/students/${RealisticBackup(groups: 1).studentId(1, 1).value}',
    {
      'firstName': 'Déjà là',
      'audience': 'children',
      'groupIds': ['g-autre'],
    },
  );
}
