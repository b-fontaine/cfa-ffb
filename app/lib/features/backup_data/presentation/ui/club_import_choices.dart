import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_outline.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/list_import_targets.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/club_import_cubit.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/club_import_actions.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/club_import_parts.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/audience_labels.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Une option d'un menu de choix : la valeur typée (`null` : rien choisi) et
/// son libellé.
typedef _Option<T> = ({T? value, String label});

/// Un menu de choix : une question (son nom accessible), une valeur et des
/// options **typées** (aucune valeur codée en texte). Cible de 48 dp, au
/// clavier comme au toucher. La première option est « à choisir » (`null`).
class _ChoiceMenu<T> extends StatelessWidget {
  const _ChoiceMenu({
    required this.menuKey,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.enabled,
  });

  final Key menuKey;
  final String label;
  final T? value;
  final List<_Option<T>> options;
  final ValueChanged<T?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final found = options.indexWhere((o) => o.value == value);
    // Pas de `Semantics(label)` autour : le `labelText` de l'InputDecorator
    // nomme déjà le menu, l'ajouter ferait lire la question deux fois.
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          key: menuKey,
          value: found < 0 ? 0 : found,
          isExpanded: true,
          items: [
            for (var i = 0; i < options.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(options[i].label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: enabled
              ? (i) => i == null ? null : onChanged(options[i].value)
              : null,
        ),
      ),
    );
  }
}

/// Étape 3 : pour chaque groupe du fichier, « créer dans le club » (réservé au
/// directeur et à l'administrateur) ou « associer à ce groupe existant »
/// (la liste suit les droits : un enseignant ne voit que ses groupes). Aucune
/// fusion implicite : deux groupes du fichier sur un même groupe du club
/// exigent une confirmation.
class ClubImportGroupsStep extends StatelessWidget {
  const ClubImportGroupsStep({
    required this.state,
    required this.actions,
    super.key,
  });

  final ClubImportState state;
  final ClubImportActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = state.plan;
    if (plan == null) return const SizedBox.shrink();
    final choices = state.choices;
    final manages = state.canCreateGroups;
    return ImportStepFrame(
      state: state,
      title: l10n.clubImportGroupsTitle,
      children: [
        Text(l10n.clubImportGroupsIntro),
        if (plan.outline.marker != null) Text(l10n.clubImportSameChoices),
        if (!manages) Text(l10n.clubImportTeacherNote),
        for (final group in choices.groups)
          _GroupChoice(
            group: group,
            state: state,
            actions: actions,
            targets: choices.targetsFor(group),
          ),
        for (final merge in choices.merges)
          CheckboxListTile(
            key: ValueKey('import-merge-${merge.target.value}'),
            contentPadding: EdgeInsets.zero,
            value: state.decisions.confirmedMerges.contains(merge.target),
            onChanged: state.busy
                ? null
                : (v) => actions.onConfirmMerge(
                    merge.target,
                    confirmed: v ?? false,
                  ),
            title: Text(l10n.clubImportMergeConfirm(merge.name)),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ImportProblemsList(plan: plan),
        ImportNav(state: state, actions: actions),
      ],
    );
  }
}

class _GroupChoice extends StatelessWidget {
  const _GroupChoice({
    required this.group,
    required this.state,
    required this.actions,
    required this.targets,
  });

  final OutlineGroup group;
  final ClubImportState state;
  final ClubImportActions actions;
  final List<ImportTarget> targets;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final manages = state.canCreateGroups;
    final season = group.seasonLabel;
    final summary = season == null
        ? l10n.clubImportGroupSummaryNoSeason(
            group.audience.label(l10n),
            group.students,
          )
        : l10n.clubImportGroupSummary(
            group.audience.label(l10n),
            season,
            group.students,
          );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.name, style: Theme.of(context).textTheme.titleMedium),
            Text(summary),
            const SizedBox(height: AppSpacing.sm),
            _ChoiceMenu<GroupChoice>(
              menuKey: ValueKey('import-group-${group.id.value}'),
              label: l10n.clubImportGroupChoice(group.name),
              value: state.decisions.groups[group.id],
              enabled: !state.busy,
              options: [
                (value: null, label: l10n.clubImportChoiceUnset),
                if (manages)
                  (
                    value: const CreateGroup(),
                    label: l10n.clubImportGroupCreate,
                  ),
                for (final t in targets)
                  (
                    value: UseExistingGroup(t.id),
                    label: l10n.clubImportGroupAssociate(t.name),
                  ),
              ],
              onChanged: (choice) => actions.onChooseGroup(group.id, choice),
            ),
            if (targets.isEmpty && !manages) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.clubImportNoTarget),
            ],
          ],
        ),
      ),
    );
  }
}

/// Étape 4 : séances planifiées et élèves **sans groupe** : un choix explicite
/// par élément (rattacher à un groupe du club, ou ignorer), jamais deviné.
class ClubImportLooseStep extends StatelessWidget {
  const ClubImportLooseStep({
    required this.state,
    required this.actions,
    super.key,
  });

  final ClubImportState state;
  final ClubImportActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = state.plan;
    if (plan == null) return const SizedBox.shrink();
    final choices = state.choices;
    final options = <_Option<OwnerChoice>>[
      (value: null, label: l10n.clubImportChoiceUnset),
      for (final d in choices.destinations)
        (value: AttachTo(d.id), label: l10n.clubImportLooseAttach(d.name)),
      (value: const SkipIt(), label: l10n.clubImportLooseSkip),
    ];
    final material = MaterialLocalizations.of(context);
    return ImportStepFrame(
      state: state,
      title: l10n.clubImportLooseTitle,
      children: [
        Text(l10n.clubImportLooseIntro),
        if (choices.destinations.isEmpty) Text(l10n.clubImportNoGroupYet),
        if (choices.sessions.isNotEmpty) ...[
          Text(
            l10n.clubImportLooseSessions,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final session in choices.sessions)
            _ChoiceMenu<OwnerChoice>(
              menuKey: ValueKey('import-session-${session.id}'),
              label: l10n.clubImportLooseChoice(
                l10n.clubImportLooseSession(
                  session.title,
                  material.formatShortDate(session.date),
                ),
              ),
              value: state.decisions.plannedSessions[session.id],
              options: options,
              enabled: !state.busy,
              onChanged: (choice) =>
                  actions.onChooseSession(session.id, choice),
            ),
        ],
        if (choices.students.isNotEmpty) ...[
          Text(
            l10n.clubImportLooseStudents,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final student in choices.students)
            _ChoiceMenu<OwnerChoice>(
              menuKey: ValueKey('import-student-${student.id.value}'),
              label: l10n.clubImportLooseChoice(student.firstName),
              value: state.decisions.students[student.id],
              options: options,
              enabled: !state.busy,
              onChanged: (choice) =>
                  actions.onChooseStudent(student.id, choice),
            ),
        ],
        ImportProblemsList(plan: plan),
        ImportNav(state: state, actions: actions),
      ],
    );
  }
}

/// Étape 5 : le **nombre exact** d'élèves effacés que l'import rétablirait
/// (ADR 0019) et, pour un enseignant, le nombre de fiches qu'il ne peut pas
/// vérifier : une case à cocher qui nomme le nombre et dit la conséquence.
class ClubImportConfirmStep extends StatelessWidget {
  const ClubImportConfirmStep({
    required this.state,
    required this.actions,
    super.key,
  });

  final ClubImportState state;
  final ClubImportActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = state.plan;
    if (plan == null) return const SizedBox.shrink();
    final restored = plan.report.restoredStudents;
    final unverified = plan.report.unverifiableStudents;
    final decisions = state.decisions;
    return ImportStepFrame(
      state: state,
      title: l10n.clubImportConfirmTitle,
      children: [
        if (restored > 0)
          _Confirmation(
            boxKey: const ValueKey('import-confirm-restore'),
            notice: l10n.importRestoreNotice(restored),
            consequence: l10n.clubImportRestoreConsequence,
            label: l10n.clubImportRestoreCheck(restored),
            checked: decisions.restoreConfirmed == restored,
            enabled: !state.busy,
            onChanged: (v) => actions.onConfirmRestore(confirmed: v),
          ),
        if (unverified > 0)
          _Confirmation(
            boxKey: const ValueKey('import-confirm-unverified'),
            notice: l10n.importUnverifiableNotice(unverified),
            consequence: l10n.clubImportUnverifiedConsequence,
            label: l10n.clubImportUnverifiedCheck(unverified),
            checked: decisions.unverifiedConfirmed == unverified,
            enabled: !state.busy,
            onChanged: (v) => actions.onConfirmUnverified(confirmed: v),
          ),
        ImportProblemsList(plan: plan),
        ImportNav(state: state, actions: actions),
      ],
    );
  }
}

class _Confirmation extends StatelessWidget {
  const _Confirmation({
    required this.boxKey,
    required this.notice,
    required this.consequence,
    required this.label,
    required this.checked,
    required this.enabled,
    required this.onChanged,
  });

  final Key boxKey;
  final String notice;
  final String consequence;
  final String label;
  final bool checked;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notice),
          const SizedBox(height: AppSpacing.xs),
          Text(consequence, style: Theme.of(context).textTheme.bodyMedium),
          CheckboxListTile(
            key: boxKey,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: checked,
            onChanged: enabled ? (v) => onChanged(v ?? false) : null,
            title: Text(label),
          ),
        ],
      ),
    ),
  );
}
