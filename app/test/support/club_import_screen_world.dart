import 'package:billard_cfa/entities/group/data/firestore_group_repository.dart';
import 'package:billard_cfa/entities/season/data/firestore_season_repository.dart';
import 'package:billard_cfa/features/backup_data/data/in_memory_backup_files.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/list_import_targets.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/club_import_cubit.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/club_import_actions.dart';
import 'package:billard_cfa/pages/club_import/presentation/club_import_page.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/connectivity_status.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'import_world.dart';

/// L'écran « Importer dans le club » posé sur le moteur d'import du
/// [ImportWorld] (faux Firestore qui applique les garde-fous des règles) : le
/// parcours se joue **dans l'interface**, comme le fait l'animateur.
class ImportScreenWorld {
  ImportScreenWorld._();

  static InMemoryBackupFiles files = InMemoryBackupFiles();
  static InMemoryConnectivityStatus network = InMemoryConnectivityStatus();
  static ClubImportCubit? cubit;

  /// Le compte qui importe (identifiant de session, jamais affiché).
  static const account = 'u-import';

  static ImportWorld get world => ImportWorld.current;

  /// Un monde neuf : les doubles de fichiers et de réseau sont remis à zéro.
  static void reset() {
    files = InMemoryBackupFiles();
    network = InMemoryConnectivityStatus();
    cubit = null;
  }

  /// Ouvre l'écran pour [role] et [user] (l'enseignant a les groupes que le
  /// monde lui a confiés).
  static Future<void> open(
    WidgetTester tester,
    Role role, {
    String user = account,
  }) async {
    final w = world
      ..scope.signIn(UserId(user))
      ..store.authUid = user;
    w.act(role, groups: role == Role.teacher ? w.teacherGroups.toList() : []);
    await close(tester);
    final built = ClubImportCubit(
      files,
      w.prepareUseCase,
      w.runner,
      ListImportTargets(
        FirestoreGroupRepository(w.club),
        FirestoreSeasonRepository(w.club),
        w.scope,
      ),
      w.scope,
      network,
    )..limits = w.limits;
    cubit = built;
    await tester.pumpWidget(_app(built));
    await built.started();
    await tester.pumpAndSettle();
  }

  static Widget _app(ClubImportCubit built) => MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocBuilder<ClubImportCubit, ClubImportState>(
      bloc: built,
      builder: (context, state) => ClubImportPage(
        state: state,
        actions: ClubImportActions.of(built, onFinish: () {}),
        onBack: () {},
      ),
    ),
  );

  /// Ferme l'écran (le cubit se ferme avec lui).
  static Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    final old = cubit;
    cubit = null;
    if (old != null) await tester.runAsync(old.close);
  }

  /// Choisit le fichier courant du monde dans le sélecteur de fichiers.
  static Future<void> pick(WidgetTester tester) async {
    files.nextPick = world.content;
    final button = find.text('Choose a backup file');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  /// Ouvre le menu [menu] et en choisit l'option [option].
  static Future<void> choose(
    WidgetTester tester,
    Finder menu,
    String option,
  ) async {
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  static Finder groupMenu(String name) {
    final group = world.backup!.snapshot.groups.firstWhere(
      (g) => g.name == name,
    );
    return find.byKey(ValueKey('import-group-${group.id.value}'));
  }

  /// L'état courant de l'écran (assertions).
  static ClubImportState get state => cubit!.state;
}
