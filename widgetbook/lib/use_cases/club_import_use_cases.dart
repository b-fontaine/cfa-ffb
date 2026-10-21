import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_outline.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/list_import_targets.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/club_import_cubit.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/club_import_actions.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/club_import_choices.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/club_import_parts.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/club_import_view.dart';
import 'package:billard_cfa/pages/club_import/presentation/club_import_page.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

const _path = '[Import dans le club]';

const _mardi = GroupId('g-mardi');
const _jeudi = GroupId('g-jeudi');

/// Un fichier fictif : deux groupes, une séance et un élève sans groupe.
final _outline = ImportOutline(
  groups: const [
    OutlineGroup(
      id: _mardi,
      name: 'Enfants du mardi',
      audience: Audience.children,
      seasonLabel: '2025-2026',
      students: 8,
    ),
    OutlineGroup(
      id: _jeudi,
      name: 'Adultes du jeudi',
      audience: Audience.adults,
      seasonLabel: '2025-2026',
      students: 5,
    ),
  ],
  looseSessions: [
    OutlineSession(
      id: 'p1',
      title: 'Séance libre',
      date: DateTime(2026, 10, 14),
    ),
  ],
  looseStudents: const [
    OutlineStudent(id: StudentId('s1'), firstName: 'Camille'),
  ],
);

const _targets = [
  ImportTarget(
    id: GroupId('c-mardi'),
    name: 'Mardi 17 h',
    audience: Audience.children,
  ),
  ImportTarget(
    id: GroupId('c-jeudi'),
    name: 'Jeudi 19 h',
    audience: Audience.adults,
  ),
];

const Map<ImportCategory, ImportCount> _counts = {
  ImportCategory.groups: ImportCount(inFile: 2, writes: 2),
  ImportCategory.students: ImportCount(inFile: 13, writes: 13),
  ImportCategory.attempts: ImportCount(inFile: 480, writes: 480),
};

ClubImportPlan _plan(
  ImportStatus status, {
  ImportReport? report,
  int startLot = 0,
  ImportOutline? outline,
}) => ClubImportPlan(
  status: status,
  report: report ?? const ImportReport(counts: _counts),
  outline: outline ?? _outline,
  startLot: startLot,
  lots: [for (var i = 0; i < 4; i++) ImportLot(i, const [])],
);

Widget _page(Widget child) => SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: child,
    ),
  ),
);

Role _role(BuildContext context) => context.knobs.object.dropdown(
  label: 'Rôle',
  options: const [Role.director, Role.teacher, Role.admin],
  initialOption: Role.director,
  labelBuilder: (role) => role.name,
);

@widgetbook.UseCase(name: 'Guide', type: ClubImportGuide, path: _path)
Widget buildClubImportGuideUseCase(BuildContext context) =>
    _page(const ClubImportGuide());

@widgetbook.UseCase(
  name: '1. Choix du fichier',
  type: ClubImportFileStep,
  path: _path,
)
Widget buildClubImportFileStepUseCase(BuildContext context) => _page(
  ClubImportFileStep(
    state: ClubImportState(
      role: _role(context),
      busy: context.knobs.boolean(label: 'Lecture en cours'),
      online: context.knobs.boolean(label: 'En ligne', initialValue: true),
    ),
    actions: ClubImportActions.none,
  ),
);

@widgetbook.UseCase(name: '2. Rapport', type: ClubImportReportStep, path: _path)
Widget buildClubImportReportStepUseCase(BuildContext context) {
  final kind = context.knobs.object.dropdown(
    label: 'Cas',
    options: const ['À décider', 'Bloqué', 'Déjà importé', 'Commencé'],
    initialOption: 'À décider',
  );
  final plan = switch (kind) {
    'Bloqué' => _plan(
      ImportStatus.blocked,
      report: const ImportReport(
        counts: _counts,
        problems: [
          ImportProblem(
            ImportProblemCode.duplicateId,
            ImportCategory.students,
            count: 2,
          ),
          ImportProblem(
            ImportProblemCode.orphanAttempt,
            ImportCategory.attempts,
            count: 5,
          ),
        ],
      ),
    ),
    'Déjà importé' => _plan(ImportStatus.alreadyImported),
    'Commencé' => _plan(
      ImportStatus.needsDecisions,
      outline: ImportOutline(
        groups: _outline.groups,
        marker: const ImportMarker(
          fileId: 'f',
          planId: 'p',
          lots: 4,
          done: 2,
          writes: 400,
          restored: 0,
          role: Role.director,
        ),
      ),
    ),
    _ => _plan(
      ImportStatus.needsDecisions,
      report: const ImportReport(
        counts: _counts,
        warnings: {ImportWarning.settingsIgnored},
        undecidedGroups: [_mardi, _jeudi],
      ),
    ),
  };
  return _page(
    ClubImportReportStep(
      state: ClubImportState(step: ClubImportStep.report, plan: plan),
      actions: ClubImportActions.none,
    ),
  );
}

@widgetbook.UseCase(
  name: '3. Correspondance des groupes',
  type: ClubImportGroupsStep,
  path: _path,
)
Widget buildClubImportGroupsStepUseCase(BuildContext context) => _page(
  ClubImportGroupsStep(
    state: ClubImportState(
      step: ClubImportStep.groups,
      role: _role(context),
      targets: _targets,
      plan: _plan(
        ImportStatus.needsDecisions,
        report: const ImportReport(
          counts: _counts,
          undecidedGroups: [_mardi, _jeudi],
        ),
      ),
    ),
    actions: ClubImportActions.none,
  ),
);

@widgetbook.UseCase(
  name: '4. Sans groupe',
  type: ClubImportLooseStep,
  path: _path,
)
Widget buildClubImportLooseStepUseCase(BuildContext context) => _page(
  ClubImportLooseStep(
    state: ClubImportState(
      step: ClubImportStep.loose,
      role: Role.director,
      targets: _targets,
      decisions: const ImportDecisions(
        groups: {_mardi: CreateGroup(), _jeudi: CreateGroup()},
      ),
      plan: _plan(
        ImportStatus.needsDecisions,
        report: const ImportReport(
          counts: _counts,
          undecidedSessions: ['p1'],
          undecidedStudents: [StudentId('s1')],
        ),
      ),
    ),
    actions: ClubImportActions.none,
  ),
);

@widgetbook.UseCase(
  name: '5. Confirmations',
  type: ClubImportConfirmStep,
  path: _path,
)
Widget buildClubImportConfirmStepUseCase(BuildContext context) {
  final confirmed = context.knobs.boolean(label: 'Confirmé');
  return _page(
    ClubImportConfirmStep(
      state: ClubImportState(
        step: ClubImportStep.confirmations,
        role: Role.teacher,
        decisions: ImportDecisions(
          restoreConfirmed: confirmed ? 3 : null,
          unverifiedConfirmed: confirmed ? 12 : null,
        ),
        plan: _plan(
          ImportStatus.needsConfirmation,
          report: const ImportReport(
            counts: _counts,
            restoredStudents: 3,
            unverifiableStudents: 12,
          ),
        ),
      ),
      actions: ClubImportActions.none,
    ),
  );
}

@widgetbook.UseCase(
  name: '6. Récapitulatif',
  type: ClubImportRecapStep,
  path: _path,
)
Widget buildClubImportRecapStepUseCase(BuildContext context) {
  final resume = context.knobs.boolean(label: 'Reprise');
  return _page(
    ClubImportRecapStep(
      state: ClubImportState(
        step: ClubImportStep.recap,
        role: _role(context),
        plan: _plan(
          resume ? ImportStatus.resumable : ImportStatus.ready,
          startLot: resume ? 2 : 0,
        ),
      ),
      actions: ClubImportActions.none,
    ),
  );
}

@widgetbook.UseCase(name: '7. Exécution', type: ClubImportRunStep, path: _path)
Widget buildClubImportRunStepUseCase(BuildContext context) {
  final run = context.knobs.object.dropdown(
    label: 'État',
    options: ClubImportRun.values,
    initialOption: ClubImportRun.running,
    labelBuilder: (run) => run.name,
  );
  return _page(
    ClubImportRunStep(
      state: ClubImportState(
        step: ClubImportStep.running,
        run: run,
        doneLots: 2,
        totalLots: 4,
        plan: _plan(ImportStatus.ready),
        runFailure: run == ClubImportRun.failed
            ? const ServiceFailure(ServiceFailureCode.denied)
            : null,
      ),
      actions: ClubImportActions.none,
    ),
  );
}

@widgetbook.UseCase(name: '8. Fin', type: ClubImportDoneStep, path: _path)
Widget buildClubImportDoneStepUseCase(BuildContext context) => _page(
  ClubImportDoneStep(
    state: ClubImportState(
      step: ClubImportStep.finished,
      plan: _plan(ImportStatus.ready),
    ),
    actions: ClubImportActions.none,
  ),
);

@widgetbook.UseCase(name: 'Écran complet', type: ClubImportView, path: _path)
Widget buildClubImportViewUseCase(BuildContext context) => _page(
  ClubImportView(
    state: ClubImportState(
      step: context.knobs.object.dropdown(
        label: 'Étape',
        options: [
          ClubImportStep.file,
          ClubImportStep.report,
          ClubImportStep.recap,
          ClubImportStep.finished,
        ],
        initialOption: ClubImportStep.report,
        labelBuilder: (step) => step.name,
      ),
      role: Role.director,
      online: context.knobs.boolean(label: 'En ligne', initialValue: true),
      plan: _plan(ImportStatus.ready),
    ),
    actions: ClubImportActions.none,
  ),
);

@widgetbook.UseCase(name: 'Page', type: ClubImportPage, path: _path)
Widget buildClubImportPageUseCase(BuildContext context) => ClubImportPage(
  state: ClubImportState(role: Role.director, plan: _plan(ImportStatus.ready)),
  actions: ClubImportActions.none,
  onBack: () {},
);

@widgetbook.UseCase(name: 'Cadre d’étape', type: ImportStepFrame, path: _path)
Widget buildImportStepFrameUseCase(BuildContext context) => _page(
  const ImportStepFrame(
    state: ClubImportState(),
    title: 'Titre d’étape',
    children: [Text('Contenu de l’étape')],
  ),
);

@widgetbook.UseCase(name: 'Problèmes', type: ImportProblemsList, path: _path)
Widget buildImportProblemsListUseCase(BuildContext context) => _page(
  ImportProblemsList(
    plan: _plan(
      ImportStatus.blocked,
      report: const ImportReport(
        counts: _counts,
        problems: [
          ImportProblem(
            ImportProblemCode.duplicateId,
            ImportCategory.students,
            count: 2,
          ),
          ImportProblem(ImportProblemCode.roleDenied, ImportCategory.groups),
        ],
      ),
    ),
  ),
);

@widgetbook.UseCase(name: 'Navigation d’étape', type: ImportNav, path: _path)
Widget buildImportNavUseCase(BuildContext context) => _page(
  ImportNav(
    state: ClubImportState(
      step: ClubImportStep.groups,
      busy: context.knobs.boolean(label: 'Occupé'),
      plan: _plan(ImportStatus.ready),
    ),
    actions: ClubImportActions.none,
  ),
);
