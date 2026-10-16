import 'dart:async';

import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/backup_bloc.dart';
import 'package:billard_cfa/features/close_season/domain/get_closable_season.dart';
import 'package:billard_cfa/features/close_season/presentation/bloc/closable_season_cubit.dart';
import 'package:billard_cfa/features/close_season/presentation/bloc/season_closure_bloc.dart';
import 'package:billard_cfa/features/close_season/presentation/ui/closable_season_card.dart';
import 'package:billard_cfa/features/close_season/presentation/ui/closable_season_section.dart';
import 'package:billard_cfa/features/close_season/presentation/ui/season_closure_view.dart';
import 'package:billard_cfa/features/manage_groups/presentation/bloc/manage_groups_cubit.dart';
import 'package:billard_cfa/features/manage_groups/presentation/bloc/move_student_cubit.dart';
import 'package:billard_cfa/features/manage_groups/presentation/ui/group_form_dialog.dart';
import 'package:billard_cfa/features/manage_groups/presentation/ui/group_menu_button.dart';
import 'package:billard_cfa/features/manage_groups/presentation/ui/move_student_dialog.dart';
import 'package:billard_cfa/features/track_seasons/domain/closed_season.dart';
import 'package:billard_cfa/features/track_seasons/domain/list_season_archives.dart';
import 'package:billard_cfa/features/track_seasons/presentation/bloc/season_archives_cubit.dart';
import 'package:billard_cfa/features/track_seasons/presentation/ui/season_archive_view.dart';
import 'package:billard_cfa/pages/season_archive/presentation/season_archive_page.dart';
import 'package:billard_cfa/pages/season_closure/presentation/season_closure_page.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/archive_figure_table.dart';
import 'package:billard_cfa/shared/ui/closure_choice_tile.dart';
import 'package:billard_cfa/shared/ui/group_choice_picker.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook_workspace/support/preview_world.dart';

const _components = '[Design system]/Composants';
const _features = '[Features]';
const _pages = '[Pages]';

/// Démarre [start] sur [cubit] sans attendre : le cubit publie ses états.
T _loaded<T>(T cubit, Future<void> Function(T cubit) start) {
  unawaited(start(cubit));
  return cubit;
}

Widget _pad(Widget child) =>
    Padding(padding: const EdgeInsets.all(AppSpacing.md), child: child);

Widget _scroll(Widget child) => SingleChildScrollView(
  padding: const EdgeInsets.all(AppSpacing.md),
  child: child,
);

/// Une saison close de démonstration : deux publics et un tableau d'exercices.
final _closedSeason = ClosedSeason(
  season: Season(
    id: const SeasonId('demo'),
    label: '2025-2026',
    startDate: DateTime(2025, 9),
    endDate: DateTime(2026, 6, 30),
    closedOn: DateTime(2026, 6, 30),
  ),
  audiences: [
    AudienceArchive(
      audience: Audience.children,
      sessionCount: 28,
      presenceCount: 196,
      possiblePresenceCount: 224,
      studentCount: 9,
      attemptCount: 410,
    ),
    AudienceArchive(
      audience: Audience.adults,
      sessionCount: 24,
      presenceCount: 118,
      possiblePresenceCount: 168,
      studentCount: 7,
      attemptCount: 235,
    ),
  ],
  exercises: const [
    ExerciseLine(
      audience: Audience.children,
      blockTitle: 'Posture, visée et coup de queue',
      exerciseNumber: 1,
      studentCount: 8,
      attemptCount: 41,
      potted: 102,
      total: 164,
    ),
    ExerciseLine(
      audience: Audience.children,
      blockTitle: 'La puissance',
      exerciseNumber: 2,
      studentCount: 5,
      attemptCount: 22,
      potted: 44,
      total: 110,
    ),
  ],
);

class _FakeList implements ListSeasonArchives {
  const _FakeList(this.seasons);

  final List<ClosedSeason> seasons;

  @override
  Future<Result<List<ClosedSeason>>> call() async => Ok(seasons);
}

class _FakeClosable implements GetClosableSeason {
  const _FakeClosable(this.season);

  final Season? season;

  @override
  Future<Season?> call({required DateTime today}) async => season;
}

@widgetbook.UseCase(
  name: 'Trois groupes',
  type: GroupChoicePicker,
  path: _components,
)
Widget buildGroupChoicePickerUseCase(BuildContext context) => _pad(
  GroupChoicePicker(
    choices: const [
      GroupChoice(GroupId('a'), 'Mercredi'),
      GroupChoice(GroupId('b'), 'Samedi matin'),
      GroupChoice(GroupId('c'), 'Samedi après-midi'),
    ],
    selected: const GroupId('b'),
    onChanged: (_) {},
  ),
);

@widgetbook.UseCase(
  name: 'Reconduire',
  type: ClosureChoiceTile,
  path: _components,
)
Widget buildClosureChoiceTileKeepUseCase(BuildContext context) => _pad(
  ClosureChoiceTile(
    name: context.knobs.string(label: 'prénom', initialValue: 'Léa'),
    reason: 'Actif cette saison, inscrit cette saison',
    erase: false,
    onChanged: (_) {},
  ),
);

@widgetbook.UseCase(name: 'Effacer', type: ClosureChoiceTile, path: _components)
Widget buildClosureChoiceTileEraseUseCase(BuildContext context) => _pad(
  ClosureChoiceTile(
    name: context.knobs.string(label: 'prénom', initialValue: 'Hugo'),
    reason: 'Absent de toutes les séances cette saison',
    erase: true,
    onChanged: (_) {},
  ),
);

@widgetbook.UseCase(
  name: 'Exercices d’une saison',
  type: ArchiveFigureTable,
  path: _components,
)
Widget buildArchiveFigureTableUseCase(BuildContext context) => _pad(
  ArchiveFigureTable(
    rows: [
      for (final line in _closedSeason.exercises)
        (
          title: line.blockTitle,
          number: line.exerciseNumber,
          students: line.studentCount,
          attempts: line.attemptCount,
          potted: line.potted,
          total: line.total,
        ),
    ],
  ),
);

@widgetbook.UseCase(name: 'Création', type: GroupFormDialog, path: _features)
Widget buildGroupFormDialogCreateUseCase(BuildContext context) =>
    const GroupFormDialog(
      creating: true,
      initialName: '',
      audience: Audience.children,
    );

@widgetbook.UseCase(name: 'Renommage', type: GroupFormDialog, path: _features)
Widget buildGroupFormDialogRenameUseCase(BuildContext context) =>
    const GroupFormDialog(
      creating: false,
      initialName: 'Mercredi',
      audience: Audience.children,
    );

@widgetbook.UseCase(
  name: 'Menu d’un groupe',
  type: GroupMenuButton,
  path: _features,
)
Widget buildGroupMenuButtonUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) => getIt<ManageGroupsCubit>(),
    child: _pad(
      GroupMenuButton(groupId: world.childrenGroup, groupName: 'Enfants'),
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Nouveau groupe',
  type: NewGroupButton,
  path: _features,
)
Widget buildNewGroupButtonUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) => getIt<ManageGroupsCubit>(),
    child: _pad(NewGroupButton(seasonId: world.seasonId)),
  ),
);

@widgetbook.UseCase(
  name: 'Changer de groupe',
  type: MoveStudentDialog,
  path: _features,
)
Widget buildMoveStudentDialogUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) => _loaded(
      getIt<MoveStudentCubit>(),
      (cubit) => cubit.load(world.children.id),
    ),
    child: MoveStudentDialog(studentId: world.children.id),
  ),
);

@widgetbook.UseCase(name: 'Assistant', type: SeasonClosureView, path: _features)
Widget buildSeasonClosureViewUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) =>
        getIt<SeasonClosureBloc>()
          ..add(SeasonClosureEvent.started(seasonId: world.seasonId)),
    child: _scroll(
      SeasonClosureView(
        backupSection: OutlinedButton(
          onPressed: () {},
          child: const Text('Exporter une sauvegarde'),
        ),
        backupAfterSection: const SizedBox.shrink(),
        onSeasons: () {},
        onHome: () {},
      ),
    ),
  ),
);

@widgetbook.UseCase(name: 'Carte', type: ClosableSeasonCard, path: _features)
Widget buildClosableSeasonCardUseCase(BuildContext context) =>
    _pad(ClosableSeasonCard(season: _closedSeason.season, onClose: () {}));

@widgetbook.UseCase(
  name: 'Saison à clore',
  type: ClosableSeasonSection,
  path: _features,
)
Widget buildClosableSeasonSectionUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) => _loaded(
      ClosableSeasonCubit(_FakeClosable(_closedSeason.season), getIt<Clock>()),
      (cubit) => cubit.load(),
    ),
    child: _pad(ClosableSeasonSection(onClose: (_) {})),
  ),
);

@widgetbook.UseCase(
  name: 'Saisons passées',
  type: SeasonArchiveView,
  path: _features,
)
Widget buildSeasonArchiveViewUseCase(BuildContext context) => BlocProvider(
  create: (_) => _loaded(
    SeasonArchivesCubit(_FakeList([_closedSeason])),
    (cubit) => cubit.load(),
  ),
  child: _scroll(const SeasonArchiveView()),
);

@widgetbook.UseCase(
  name: 'Assistant de clôture',
  type: SeasonClosurePage,
  path: _pages,
)
Widget buildSeasonClosurePageUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) =>
            getIt<SeasonClosureBloc>()
              ..add(SeasonClosureEvent.started(seasonId: world.seasonId)),
      ),
      BlocProvider(
        create: (_) => getIt<BackupBloc>()..add(const BackupEvent.started()),
      ),
    ],
    child: SeasonClosurePage(
      today: world.today,
      onCancel: () {},
      onSeasons: () {},
      onHome: () {},
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Saisons passées',
  type: SeasonArchivePage,
  path: _pages,
)
Widget buildSeasonArchivePageUseCase(BuildContext context) => BlocProvider(
  create: (_) => _loaded(
    SeasonArchivesCubit(_FakeList([_closedSeason])),
    (cubit) => cubit.load(),
  ),
  child: SeasonArchivePage(onBack: () {}),
);
