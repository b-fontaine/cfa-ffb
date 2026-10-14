import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/session_planner_bloc.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/ui/audience_labels.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Formulaire de planification : titre, séance du catalogue (facultative,
/// groupée par technique), groupe (facultatif), public et date.
///
/// Tout l'état vit dans le `SessionPlannerBloc` (titre, public, séance,
/// groupe et date choisis) ; le widget ne garde que le contrôleur du champ,
/// synchronisé par un écouteur. Choisir une séance du catalogue propose son
/// titre (règle du bloc : il remplace le titre tant que l'animateur n'y a pas
/// touché) ; choisir un groupe fixe le public (ADR 0007).
class PlanSessionForm extends StatefulWidget {
  const PlanSessionForm({super.key});

  @override
  State<PlanSessionForm> createState() => _PlanSessionFormState();
}

class _PlanSessionFormState extends State<PlanSessionForm> {
  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController.text = context.read<SessionPlannerBloc>().state.title;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _syncTitle(String title) {
    if (_titleController.text == title) return;
    _titleController.value = TextEditingValue(
      text: title,
      selection: TextSelection.collapsed(offset: title.length),
    );
  }

  void _suggestTitle(AppLocalizations l10n, SessionPlannerState state) {
    final option = state.sheetOptions
        .where((o) => o.id == state.selectedSheet)
        .firstOrNull;
    if (option == null) return;
    context.read<SessionPlannerBloc>().add(
      SessionPlannerEvent.titleSuggested(
        title: l10n.sheetFullTitle(option.title, option.part, option.partCount),
      ),
    );
  }

  Future<void> _pickSheet(
    BuildContext context,
    SessionPlannerState state,
  ) async {
    final bloc = context.read<SessionPlannerBloc>();
    final choice = await showModalBottomSheet<_SheetChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SheetPicker(
        options: state.sheetOptions,
        selected: state.selectedSheet,
      ),
    );
    if (choice == null) return;
    bloc.add(SessionPlannerEvent.sheetSelected(sheetId: choice.id));
  }

  Future<void> _pickGroup(
    BuildContext context,
    SessionPlannerState state,
  ) async {
    final bloc = context.read<SessionPlannerBloc>();
    final choice = await showModalBottomSheet<_GroupChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _GroupPicker(groups: state.groups, selected: state.selectedGroup),
    );
    if (choice == null) return;
    bloc.add(SessionPlannerEvent.groupSelected(groupId: choice.id));
  }

  Future<void> _pickDate(BuildContext context, DateTime date) async {
    final bloc = context.read<SessionPlannerBloc>();
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: date.add(const Duration(days: 366)),
    );
    if (picked != null) {
      bloc.add(SessionPlannerEvent.dateChanged(date: picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.select<SessionPlannerBloc, SessionPlannerState>(
      (bloc) => bloc.state,
    );
    final date = state.date;
    final failure = state.failure;
    final groupChosen = state.selectedGroupValue != null;
    return MultiBlocListener(
      listeners: [
        BlocListener<SessionPlannerBloc, SessionPlannerState>(
          listenWhen: (previous, current) => current.title != previous.title,
          listener: (context, state) => _syncTitle(state.title),
        ),
        BlocListener<SessionPlannerBloc, SessionPlannerState>(
          listenWhen: (previous, current) =>
              current.selectedSheet != previous.selectedSheet &&
              current.selectedSheet != null,
          listener: (context, state) => _suggestTitle(l10n, state),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            onChanged: (title) => context.read<SessionPlannerBloc>().add(
              SessionPlannerEvent.titleEdited(title: title),
            ),
            decoration: InputDecoration(
              labelText: l10n.plannerTitleField,
              errorText: state.titleInvalid ? l10n.plannerInvalidTitle : null,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SheetField(state: state, onTap: () => _pickSheet(context, state)),
          const SizedBox(height: AppSpacing.sm),
          _GroupField(state: state, onTap: () => _pickGroup(context, state)),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<Audience>(
            segments: [
              for (final audience in Audience.values)
                ButtonSegment(
                  value: audience,
                  label: Text(audience.label(l10n)),
                ),
            ],
            selected: {state.audience},
            // Le public d'une séance avec groupe est celui du groupe.
            onSelectionChanged: groupChosen
                ? null
                : (selection) => context.read<SessionPlannerBloc>().add(
                    SessionPlannerEvent.audienceChanged(
                      audience: selection.first,
                    ),
                  ),
          ),
          if (date != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.plannerDate, style: theme.textTheme.titleMedium),
            Row(
              children: [
                Expanded(
                  child: Text(
                    MaterialLocalizations.of(context).formatMediumDate(date),
                  ),
                ),
                TextButton(
                  key: const ValueKey('planner-change-date'),
                  onPressed: () => _pickDate(context, date),
                  child: Text(l10n.plannerChangeDate),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: () => context.read<SessionPlannerBloc>().add(
              const SessionPlannerEvent.sessionSubmitted(),
            ),
            child: Text(l10n.plannerAdd),
          ),
          if (failure != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              failureMessage(l10n, failure),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

/// Valeur du sélecteur : une séance du catalogue ou `null` (séance libre).
typedef _SheetChoice = ({SheetId? id});

/// Valeur du sélecteur de groupe : un groupe ou `null` (sans groupe).
typedef _GroupChoice = ({GroupId? id});

/// Champ « Séance du catalogue » : affiche le choix et ouvre le sélecteur.
class _SheetField extends StatelessWidget {
  const _SheetField({required this.state, required this.onTap});

  final SessionPlannerState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = state.sheetOptions
        .where((option) => option.id == state.selectedSheet)
        .firstOrNull;
    final value = selected == null
        ? l10n.plannerSheetNone
        : l10n.sheetFullTitle(
            selected.title,
            selected.part,
            selected.partCount,
          );
    final enabled = !state.sheetsUnavailable && state.sheetOptions.isNotEmpty;
    return _PickerField(
      fieldKey: const ValueKey('planner-sheet-field'),
      label: l10n.plannerSheetField,
      value: value,
      enabled: enabled,
      errorText: state.sheetsUnavailable ? l10n.plannerSheetsUnavailable : null,
      onTap: onTap,
    );
  }
}

/// Champ « Groupe » : affiche le groupe choisi et ouvre le sélecteur ;
/// désactivé quand le club n'a aucun groupe.
class _GroupField extends StatelessWidget {
  const _GroupField({required this.state, required this.onTap});

  final SessionPlannerState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = state.selectedGroupValue;
    final value = selected == null
        ? l10n.plannerGroupNone
        : l10n.plannerGroupOption(selected.name, selected.audience.label(l10n));
    return _PickerField(
      fieldKey: const ValueKey('planner-group-field'),
      label: l10n.plannerGroupField,
      value: value,
      enabled: state.groups.isNotEmpty,
      onTap: onTap,
    );
  }
}

/// Champ en lecture seule qui ouvre une feuille de choix (bouton sémantique
/// portant le libellé et la valeur).
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
    this.errorText,
  });

  final Key fieldKey;
  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    label: label,
    value: value,
    excludeSemantics: true,
    onTap: enabled ? onTap : null,
    child: InkWell(
      key: fieldKey,
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppSpacing.xs),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            enabled: enabled,
            errorText: errorText,
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          child: Text(value),
        ),
      ),
    ),
  );
}

/// Feuille de choix : « séance libre » puis une section par technique.
class _SheetPicker extends StatelessWidget {
  const _SheetPicker({required this.options, required this.selected});

  final List<SheetOption> options;
  final SheetId? selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rows = <Widget>[];
    String? lastTechnique;
    for (final option in options) {
      if (option.technique != lastTechnique) {
        lastTechnique = option.technique;
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Semantics(
              header: true,
              child: Text(
                l10n.catalogueTechniqueHeading(
                  option.techniqueRank,
                  option.title,
                ),
                style: theme.textTheme.titleSmall,
              ),
            ),
          ),
        );
      }
      rows.add(
        ListTile(
          key: ValueKey('sheet-option:${option.id.value}'),
          selected: option.id == selected,
          title: Text(
            l10n.sheetPartLabel(option.part, option.partCount),
            semanticsLabel: l10n.sheetFullTitle(
              option.title,
              option.part,
              option.partCount,
            ),
          ),
          onTap: () => Navigator.of(context).pop<_SheetChoice>((id: option.id)),
        ),
      );
    }
    return _PickerSheet(
      title: l10n.plannerSheetPickerTitle,
      children: [
        ListTile(
          key: const ValueKey('sheet-option:none'),
          selected: selected == null,
          title: Text(l10n.plannerSheetNone),
          onTap: () => Navigator.of(context).pop<_SheetChoice>((id: null)),
        ),
        ...rows,
      ],
    );
  }
}

/// Feuille de choix du groupe : « aucun groupe » puis les groupes de la
/// saison (« Jeunes · Enfants »).
class _GroupPicker extends StatelessWidget {
  const _GroupPicker({required this.groups, required this.selected});

  final List<Group> groups;
  final GroupId? selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _PickerSheet(
      title: l10n.plannerGroupPickerTitle,
      children: [
        ListTile(
          key: const ValueKey('group-option:none'),
          selected: selected == null,
          title: Text(l10n.plannerGroupNone),
          onTap: () => Navigator.of(context).pop<_GroupChoice>((id: null)),
        ),
        for (final group in groups)
          ListTile(
            key: ValueKey('group-option:${group.id.value}'),
            selected: group.id == selected,
            title: Text(
              l10n.plannerGroupOption(group.name, group.audience.label(l10n)),
            ),
            onTap: () =>
                Navigator.of(context).pop<_GroupChoice>((id: group.id)),
          ),
      ],
    );
  }
}

/// Cadre commun des feuilles de choix : titre puis lignes, bornées à 80 % de
/// la hauteur.
class _PickerSheet extends StatelessWidget {
  const _PickerSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    ),
  );
}
