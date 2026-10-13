import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_library.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

class _EmptyDiagramRepository implements DiagramRepository {
  @override
  Future<DiagramLibrary> load() async => DiagramLibrary(const []);
}

/// Usage: the diagram library is empty
///
/// Aucun exercice du catalogue n'est sans schéma : on retire les schémas à la
/// frontière (le dépôt), le reste de l'application est réel.
Future<void> theDiagramLibraryIsEmpty(WidgetTester tester) async {
  await UiWorld.prepare(tester);
  await getIt.unregister<DiagramRepository>();
  getIt.registerSingleton<DiagramRepository>(_EmptyDiagramRepository());
}
