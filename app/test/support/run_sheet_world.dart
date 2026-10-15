import 'dart:async';

import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_library.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_repository.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_table.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/entities/session/data/in_memory_session_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/features/run_sheet/domain/load_validated_exercises.dart';
import 'package:billard_cfa/features/run_sheet/domain/resolve_run_plan.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_ticker.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/rules_store.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';

import 'domain_world.dart';
import 'fixtures.dart';
import 'session_sheet_fixtures.dart';

class _Diagrams implements DiagramRepository {
  _Diagrams(this.library);

  final DiagramLibrary library;

  @override
  Future<DiagramLibrary> load() async => library;
}

/// Minuteur factice : les secondes s'écoulent quand le test le décide.
class ManualTicker implements RunTicker {
  final _controller = StreamController<void>.broadcast(sync: true);

  @override
  Stream<void> ticks() => _controller.stream;

  /// Laisse passer [seconds] secondes.
  void tick([int seconds = 1]) {
    for (var i = 0; i < seconds; i++) {
      _controller.add(null);
    }
  }
}

/// Schéma minimal pour un identifiant donné.
ExerciseDiagram diagramFixture(String id) => ExerciseDiagram(
  id: id,
  kind: DiagramKind.exercise,
  sheet: 'Fiche',
  caption: 'Légende du schéma $id',
  description: 'Description',
  sourceFile: 'Test.pdf',
  sourcePage: 1,
  table: const DiagramTable(balls: []),
);

/// Déroulé réel (cas d'usage de production) sur des séances de test.
class RunSheetWorld {
  RunSheetWorld({
    List<SessionSheet>? sheets,
    ExerciseCatalogue? catalogue,
    List<ExerciseDiagram> diagrams = const [],
    RulesConfig? rules,
  }) : sessions = InMemorySessionRepository() {
    final config = rules ?? RulesConfig();
    domain = DomainWorld(
      catalogue:
          catalogue ??
          buildCatalogue([
            block('posture', 1),
            block('demi-bille', 2, exercises: 4),
            block('quart-finesses', 3),
          ]),
      config: config,
    );
    resolve = ResolveRunPlan(
      FixtureSessionSheetRepository(sheets ?? catalogueFixture()),
      sessions,
      domain.catalogueRepository,
      _Diagrams(DiagramLibrary(diagrams)),
      RulesStore(config),
      LoadValidatedExercises(
        domain.students,
        domain.groups,
        domain.attempts,
        domain.acquisitions,
        RulesStore(config),
      ),
    );
  }

  /// Dépôts en mémoire du suivi (élèves, groupes, passages).
  late final DomainWorld domain;

  final InMemorySessionRepository sessions;
  final ticker = ManualTicker();
  late final ResolveRunPlan resolve;

  /// Cubit chargé de la séance [sheet] pour [audience].
  Future<RunSheetCubit> cubit(
    String sheet, {
    Audience? audience = Audience.children,
    String? sessionId,
    int? step,
  }) async {
    final cubit = RunSheetCubit(
      resolve,
      ticker,
      RunKey(sheetId: SheetId(sheet), audience: audience, sessionId: sessionId),
    );
    if (step != null) cubit.showStep(step);
    await cubit.load();
    return cubit;
  }
}
