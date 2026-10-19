import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/student_showcase/domain/family_space.dart';
import 'package:billard_cfa/features/student_showcase/domain/get_student_showcase.dart';
import 'package:billard_cfa/features/student_showcase/domain/student_showcase.dart';
import 'package:billard_cfa/features/student_showcase/presentation/ui/family_space_view.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook_workspace/support/preview_world.dart';

const _path = '[Espace élève et parent]';

/// L'espace de démonstration : deux élèves liés (Léa et son camarade, parcours
/// réels du monde de démonstration) et deux séances à venir.
Future<Result<FamilySpace>> _space(PreviewWorld world) => runGuarded(() async {
  FamilyChild child(StudentId id, String name, StudentShowcase showcase) =>
      FamilyChild(id: id, firstName: name, showcase: showcase);
  final get = getIt<GetStudentShowcase>();
  Future<FamilyChild> load(StudentId id, String name) async =>
      child(id, name, switch (await get(id)) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      });
  return FamilySpace(
    children: [
      await load(world.children.id, world.children.firstName),
      await load(world.classmate.id, world.classmate.firstName),
    ],
    upcoming: [
      FamilySession(
        id: 'a',
        title: 'Rebond sur la bande',
        date: DateTime(2026, 10, 14),
        audience: Audience.children,
        groupName: 'Enfants du mardi',
      ),
      FamilySession(
        id: 'b',
        title: 'Séance libre',
        date: DateTime(2026, 10, 21),
        audience: Audience.children,
      ),
    ],
  );
});

Widget _page(Widget child) => SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: child,
    ),
  ),
);

@widgetbook.UseCase(name: 'Espace complet', type: FamilySpaceView, path: _path)
Widget buildFamilySpaceViewUseCase(BuildContext context) {
  final count = context.knobs.int.slider(
    label: 'Élèves liés',
    initialValue: 2,
    max: 2,
  );
  final withSessions = context.knobs.boolean(
    label: 'Séances prévues',
    initialValue: true,
  );
  final stale = context.knobs.boolean(label: 'Hors ligne (dernières données)');
  return LoadedScope<FamilySpace>(
    load: _space,
    builder: (context, world, space) => _Selectable(
      space: FamilySpace(
        children: space.children.take(count).toList(),
        upcoming: withSessions ? space.upcoming : const [],
      ),
      stale: stale,
    ),
  );
}

/// Garde l'élève choisi, comme le fait l'écran.
class _Selectable extends StatefulWidget {
  const _Selectable({required this.space, required this.stale});

  final FamilySpace space;
  final bool stale;

  @override
  State<_Selectable> createState() => _SelectableState();
}

class _SelectableState extends State<_Selectable> {
  StudentId? _selected;

  @override
  Widget build(BuildContext context) => _page(
    FamilySpaceView(
      space: widget.space,
      selected: _selected,
      stale: widget.stale,
      onSelect: (id) => setState(() => _selected = id),
    ),
  );
}

@widgetbook.UseCase(name: 'Choix de l’enfant', type: ChildSelector, path: _path)
Widget buildChildSelectorUseCase(BuildContext context) =>
    LoadedScope<FamilySpace>(
      load: _space,
      builder: (context, world, space) => _SelectorDemo(space.children),
    );

class _SelectorDemo extends StatefulWidget {
  const _SelectorDemo(this.children);

  final List<FamilyChild> children;

  @override
  State<_SelectorDemo> createState() => _SelectorDemoState();
}

class _SelectorDemoState extends State<_SelectorDemo> {
  late StudentId _selected = widget.children.first.id;

  @override
  Widget build(BuildContext context) => _page(
    ChildSelector(
      children: widget.children,
      selected: _selected,
      onSelect: (id) => setState(() => _selected = id),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Prochaines séances',
  type: UpcomingFamilySessions,
  path: _path,
)
Widget buildUpcomingFamilySessionsUseCase(BuildContext context) =>
    LoadedScope<FamilySpace>(
      load: _space,
      builder: (context, world, space) => _page(
        UpcomingFamilySessions(
          sessions: context.knobs.boolean(label: 'Aucune séance prévue')
              ? const []
              : space.upcoming,
        ),
      ),
    );

@widgetbook.UseCase(
  name: 'Accès refusé ou retiré',
  type: FamilyNotice,
  path: _path,
)
Widget buildFamilyNoticeUseCase(BuildContext context) {
  final removed = context.knobs.boolean(label: 'Accès retiré (sinon refusé)');
  return FamilyNotice(
    icon: removed ? Icons.link_off : Icons.lock_outline,
    title: removed ? 'Accès retiré' : 'Accès refusé',
    body: removed
        ? 'Votre accès à ces informations a été retiré par le club.'
        : 'Le service refuse de vous montrer ces informations.',
  );
}
