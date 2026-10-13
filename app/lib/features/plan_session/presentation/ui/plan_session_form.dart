import 'package:billard_cfa/features/plan_session/domain/sheet_option.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/session_planner_bloc.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Formulaire de planification : titre, séance du catalogue (facultative,
/// groupée par technique) et public.
///
/// Tout l'état vit dans le `SessionPlannerBloc` (titre, public, séance
/// choisie) ; le widget ne garde que le contrôleur du champ, synchronisé par
/// un écouteur. Choisir une séance du catalogue propose son titre (règle du
/// bloc : il remplace le titre tant que l'animateur n'y a pas touché).
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

  String _label(AppLocalizations l10n, Audience audience) => switch (audience) {
    Audience.children => l10n.audienceChildren,
    Audience.adults => l10n.audienceAdults,
  };

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.select<SessionPlannerBloc, SessionPlannerState>(
      (bloc) => bloc.state,
    );
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
          SegmentedButton<Audience>(
            segments: [
              for (final audience in Audience.values)
                ButtonSegment(
                  value: audience,
                  label: Text(_label(l10n, audience)),
                ),
            ],
            selected: {state.audience},
            onSelectionChanged: (selection) =>
                context.read<SessionPlannerBloc>().add(
                  SessionPlannerEvent.audienceChanged(
                    audience: selection.first,
                  ),
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: () => context.read<SessionPlannerBloc>().add(
              const SessionPlannerEvent.sessionSubmitted(),
            ),
            child: Text(l10n.plannerAdd),
          ),
        ],
      ),
    );
  }
}

/// Valeur du sélecteur : une séance du catalogue ou `null` (séance libre).
typedef _SheetChoice = ({SheetId? id});

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
    return Semantics(
      button: true,
      enabled: enabled,
      label: l10n.plannerSheetField,
      value: value,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: InkWell(
        key: const ValueKey('planner-sheet-field'),
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.plannerSheetField,
              enabled: enabled,
              errorText: state.sheetsUnavailable
                  ? l10n.plannerSheetsUnavailable
                  : null,
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            child: Text(value),
          ),
        ),
      ),
    );
  }
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
    return SafeArea(
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
                    l10n.plannerSheetPickerTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
              ListTile(
                key: const ValueKey('sheet-option:none'),
                selected: selected == null,
                title: Text(l10n.plannerSheetNone),
                onTap: () =>
                    Navigator.of(context).pop<_SheetChoice>((id: null)),
              ),
              ...rows,
            ],
          ),
        ),
      ),
    );
  }
}
