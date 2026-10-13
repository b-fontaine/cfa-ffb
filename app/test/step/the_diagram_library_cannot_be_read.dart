import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_library.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_repository.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

class _UnreadableDiagramRepository implements DiagramRepository {
  @override
  Future<DiagramLibrary> load() async =>
      throw const InvariantViolation(InvariantCode.invalidDiagram);
}

/// Usage: the diagram library cannot be read
Future<void> theDiagramLibraryCannotBeRead(WidgetTester tester) async {
  await UiWorld.prepare(tester);
  await getIt.unregister<DiagramRepository>();
  getIt.registerSingleton<DiagramRepository>(_UnreadableDiagramRepository());
}
