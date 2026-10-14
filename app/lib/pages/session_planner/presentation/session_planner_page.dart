import 'package:billard_cfa/features/plan_session/presentation/bloc/session_planner_bloc.dart';
import 'package:billard_cfa/features/plan_session/presentation/ui/plan_session_form.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/widgets/session_list/presentation/session_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Page de planification : le bloc est fourni par l'appelant (couche app).
///
/// [onOpenSheet] ouvre le détail de la séance du catalogue liée à une séance
/// planifiée ; [onChooseSheet] mène au catalogue pour en choisir une ;
/// [onLaunchSheet] lance la séance guidée d'une séance planifiée ;
/// [onRecord] ouvre la saisie des résultats d'une séance planifiée pour un
/// groupe (date et séance du catalogue reprises) ; [onOpenRecord] ouvre la
/// saisie déjà faite (ADR 0007).
class SessionPlannerPage extends StatelessWidget {
  const SessionPlannerPage({
    required this.onOpenSheet,
    required this.onChooseSheet,
    required this.onLaunchSheet,
    required this.onRecord,
    required this.onOpenRecord,
    super.key,
  });

  final void Function(SheetId id, Audience audience) onOpenSheet;
  final VoidCallback onChooseSheet;
  final void Function(SheetId id, Audience audience, String sessionId)
  onLaunchSheet;
  final void Function(GroupId group, DateTime date, SheetId? sheet) onRecord;
  final ValueChanged<SessionId> onOpenRecord;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // La page défile en entier : le formulaire (titre, séance, groupe, public,
    // date) laisse la place à la liste sur un téléphone.
    return ScrollPage(
      title: l10n.plannerTitle,
      children: [
        SectionCard(
          title: l10n.plannerFormTitle,
          child: const PlanSessionForm(),
        ),
        BlocBuilder<SessionPlannerBloc, SessionPlannerState>(
          builder: (context, state) => SessionList(
            sessions: state.sessions,
            sheetOptions: state.sheetOptions,
            onOpenSheet: onOpenSheet,
            onChooseSheet: onChooseSheet,
            onLaunchSheet: onLaunchSheet,
            onRecord: onRecord,
            onOpenRecord: onOpenRecord,
            onDelete: (session) => context.read<SessionPlannerBloc>().add(
              SessionPlannerEvent.sessionDeleted(sessionId: session.id),
            ),
          ),
        ),
      ],
    );
  }
}
