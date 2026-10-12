import 'package:billard_cfa/features/plan_session/presentation/bloc/session_planner_bloc.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Formulaire de planification (titre + public).
class PlanSessionForm extends StatefulWidget {
  const PlanSessionForm({super.key});

  @override
  State<PlanSessionForm> createState() => _PlanSessionFormState();
}

class _PlanSessionFormState extends State<PlanSessionForm> {
  final _titleController = TextEditingController();
  Audience _audience = Audience.children;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _label(AppLocalizations l10n, Audience audience) => switch (audience) {
    Audience.children => l10n.audienceChildren,
    Audience.adults => l10n.audienceAdults,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final invalid = context.select<SessionPlannerBloc, bool>(
      (bloc) => bloc.state.titleInvalid,
    );
    return BlocListener<SessionPlannerBloc, SessionPlannerState>(
      listenWhen: (previous, current) =>
          current.sessions.length > previous.sessions.length,
      listener: (context, state) => _titleController.clear(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: l10n.plannerTitleField,
              errorText: invalid ? l10n.plannerInvalidTitle : null,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<Audience>(
            segments: [
              for (final audience in Audience.values)
                ButtonSegment(
                  value: audience,
                  label: Text(_label(l10n, audience)),
                ),
            ],
            selected: {_audience},
            onSelectionChanged: (selection) =>
                setState(() => _audience = selection.first),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.read<SessionPlannerBloc>().add(
              SessionPlannerEvent.sessionSubmitted(
                title: _titleController.text,
                audience: _audience,
              ),
            ),
            child: Text(l10n.plannerAdd),
          ),
        ],
      ),
    );
  }
}
