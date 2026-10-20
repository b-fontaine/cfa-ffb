import 'package:billard_cfa/shared/lib/sha256.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> unAutreCompteAPoseUnMarqueurTerminePourCeFichier(
  WidgetTester tester,
) async {
  final world = ImportWorld.current;
  final fingerprint = sha256Hex(world.content!);
  // Un enseignant pose, sous SON identifiant, un marqueur « terminé » d'un
  // autre plan : il ne touche pas celui du directeur.
  world.seed('clubs/c1/imports/${fingerprint}_u-teacher', {
    'fileId': fingerprint,
    'planId': 'd' * 64,
    'lots': 1,
    'done': 1,
    'writes': 0,
    'restored': 0,
    'role': 'teacher',
    'createdBy': 'u-teacher',
    'state': 'done',
  });
}
