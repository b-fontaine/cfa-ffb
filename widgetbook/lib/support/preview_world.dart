import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_catalog/data/asset_catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_diagram/data/asset_diagram_repository.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_repository.dart';
import 'package:billard_cfa/entities/session_sheet/data/asset_session_sheet_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/export_sheet/data/pdf_print_renderer.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_renderer.dart';
import 'package:billard_cfa/features/manage_students/domain/enroll_student.dart';
import 'package:billard_cfa/features/place_student/domain/mark_block_acquired.dart';
import 'package:billard_cfa/features/record_results/domain/open_session.dart';
import 'package:billard_cfa/features/record_results/domain/record_attempt.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Préfixe sous lequel Flutter expose, dans une application tierce, les assets
/// déclarés par le package `billard_cfa`.
const _packageAssets = 'packages/billard_cfa/';

/// Les assets de `billard_cfa` ne sont pas des assets de Widgetbook : ils sont
/// servis sous `packages/billard_cfa/`. Les dépôts d'assets sont donc recâblés
/// avec ce préfixe (le chemin logique reste celui de l'application).
Future<void> _useBundledPackageAssets() async {
  Future<String> load(String path) =>
      rootBundle.loadString('$_packageAssets$path');
  await getIt.unregister<CatalogueRepository>();
  getIt.registerLazySingleton<CatalogueRepository>(
    () => AssetCatalogueRepository(load),
  );
  Future<List<String>> listPackageAssets() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return [
      for (final key in manifest.listAssets())
        if (key.startsWith(_packageAssets))
          key.substring(_packageAssets.length),
    ];
  }

  await getIt.unregister<DiagramRepository>();
  getIt.registerLazySingleton<DiagramRepository>(
    () => AssetDiagramRepository(load, listPackageAssets),
  );
  await getIt.unregister<SessionSheetRepository>();
  getIt.registerLazySingleton<SessionSheetRepository>(
    () => AssetSessionSheetRepository(load, listPackageAssets),
  );
  // Les fontes du PDF (Exo 2) sont lues sous le même préfixe.
  await getIt.unregister<PrintRenderer>();
  getIt.registerLazySingleton<PrintRenderer>(
    () => PdfPrintRenderer.configured(bundle: _PackageBundle()),
  );
}

/// Lit les assets de `billard_cfa` sous leur préfixe de package.
class _PackageBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) => rootBundle.load('$_packageAssets$key');

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) => rootBundle.loadStructuredData('$_packageAssets$key', parser);
}

/// Horloge figée du catalogue de démonstration.
class _PreviewClock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 12, 9, 30);
}

/// Données de démonstration : un club avec un groupe d'enfants (une élève
/// avec des passages réussis puis manqués) et un groupe d'adultes.
class PreviewWorld {
  const PreviewWorld({
    required this.children,
    required this.adults,
    required this.classmate,
    required this.childrenGroup,
    required this.seasonId,
    required this.sessionId,
    required this.today,
    required this.catalogue,
  });

  final Student children;
  final Student adults;

  /// Un camarade de Léa dans le même groupe (grille et alertes de groupe).
  final Student classmate;
  final GroupId childrenGroup;

  /// La saison en cours du club de démonstration.
  final SeasonId seasonId;
  final SessionId sessionId;
  final DateTime today;
  final ExerciseCatalogue catalogue;

  static final validated = ExerciseRef(blockId: 'puissance', number: 1);
  static final struggling = ExerciseRef(blockId: 'puissance', number: 2);

  static Future<PreviewWorld>? _world;

  /// Compose (une seule fois) le graphe réel en mémoire et amorce le club.
  static Future<PreviewWorld> ensure() => _world ??= _build();

  static T _value<T>(Result<T> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw StateError('amorçage impossible : $failure'),
  };

  static Future<PreviewWorld> _build() async {
    await configureDependencies(environment: 'test');
    await _useBundledPackageAssets();
    await getIt.unregister<Clock>();
    getIt.registerSingleton<Clock>(_PreviewClock());
    final today = getIt<Clock>().today();
    final enroll = getIt<EnrollStudent>();
    final lea = _value(
      await enroll(
        firstName: 'Léa',
        audience: Audience.children,
        today: today,
        groupName: 'Enfants',
      ),
    );
    final marc = _value(
      await enroll(
        firstName: 'Marc',
        audience: Audience.adults,
        today: today,
        groupName: 'Adultes',
      ),
    );
    final hugo = _value(
      await enroll(
        firstName: 'Hugo',
        audience: Audience.children,
        today: today,
        groupName: 'Enfants',
      ),
    );
    final catalogue = await getIt<CatalogueRepository>().load();
    final open = getIt<OpenSession>();
    final record = getIt<RecordAttempt>();
    var day = 0;
    Future<SessionId> seed(
      ExerciseRef exercise,
      int count, {
      required bool passed,
    }) async {
      final rate = catalogue.exercise(exercise)!.rate;
      var remaining = count;
      late SessionId last;
      while (remaining > 0) {
        final session = _value(
          await open(
            groupId: lea.group.id,
            date: DateTime(2026, 9, 12).add(Duration(days: 7 * day++)),
            present: {lea.student.id},
          ),
        );
        last = session.id;
        for (var pass = 0; pass < 2 && remaining > 0; pass++, remaining--) {
          _value(
            await record(
              sessionId: session.id,
              studentId: lea.student.id,
              exercise: exercise,
              potted: passed ? rate.successes : rate.successes - 1,
              total: rate.attempts,
            ),
          );
        }
      }
      return last;
    }

    await seed(validated, 5, passed: true);
    final sessionId = await seed(struggling, 3, passed: false);
    // Hugo a lui aussi manqué la notion à son dernier passage : la grille
    // montre une alerte de groupe (2 élèves sur 2).
    final hugoSession = _value(
      await open(
        groupId: lea.group.id,
        date: DateTime(2026, 10, 5),
        present: {hugo.student.id},
      ),
    );
    final hugoRate = catalogue.exercise(validated)!.rate;
    _value(
      await record(
        sessionId: hugoSession.id,
        studentId: hugo.student.id,
        exercise: validated,
        potted: hugoRate.successes - 1,
        total: hugoRate.attempts,
      ),
    );
    // Positionnement : « Posture » acquis, « La puissance » acquis puis repris
    // par les passages ci-dessus (statuts et lignes distincts de la fiche).
    final mark = getIt<MarkBlockAcquired>();
    for (final block in const ['posture', 'puissance']) {
      _value(
        await mark(
          studentId: lea.student.id,
          blockId: block,
          date: DateTime(2026, 9),
          today: today,
        ),
      );
    }
    return PreviewWorld(
      children: lea.student,
      adults: marc.student,
      classmate: hugo.student,
      childrenGroup: lea.group.id,
      seasonId: lea.group.seasonId,
      sessionId: sessionId,
      today: today,
      catalogue: catalogue,
    );
  }
}

/// Fournit le monde de démonstration à [builder] une fois prêt.
class WorldScope extends StatelessWidget {
  const WorldScope({required this.builder, super.key});

  final Widget Function(BuildContext context, PreviewWorld world) builder;

  @override
  Widget build(BuildContext context) => FutureBuilder<PreviewWorld>(
    future: PreviewWorld.ensure(),
    builder: (context, snapshot) {
      final world = snapshot.data;
      if (world == null) return const LoadingView();
      return builder(context, world);
    },
  );
}

/// Charge une valeur par un cas d'usage (une seule fois) puis la remet à
/// [builder]. Un échec d'amorçage remonte comme erreur de la maquette.
class LoadedScope<T> extends StatefulWidget {
  const LoadedScope({required this.load, required this.builder, super.key});

  final Future<Result<T>> Function(PreviewWorld world) load;
  final Widget Function(BuildContext context, PreviewWorld world, T value)
  builder;

  @override
  State<LoadedScope<T>> createState() => _LoadedScopeState<T>();
}

class _LoadedScopeState<T> extends State<LoadedScope<T>> {
  late final Future<(PreviewWorld, T)> _future = PreviewWorld.ensure().then((
    world,
  ) async {
    final result = await widget.load(world);
    return (world, PreviewWorld._value(result));
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<(PreviewWorld, T)>(
    future: _future,
    builder: (context, snapshot) {
      final data = snapshot.data;
      if (data == null) return const LoadingView();
      return widget.builder(context, data.$1, data.$2);
    },
  );
}
