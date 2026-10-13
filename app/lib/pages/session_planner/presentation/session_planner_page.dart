import 'package:billard_cfa/features/plan_session/presentation/bloc/session_planner_bloc.dart';
import 'package:billard_cfa/features/plan_session/presentation/ui/plan_session_form.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/ui/page_header.dart';
import 'package:billard_cfa/shared/ui/responsive_body.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/widgets/session_list/presentation/session_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Page de planification : le bloc est fourni par l'appelant (couche app).
///
/// [onOpenSheet] ouvre le détail de la séance du catalogue liée à une séance
/// planifiée ; [onChooseSheet] mène au catalogue pour en choisir une ;
/// [onLaunchSheet] lance la séance guidée d'une séance planifiée.
class SessionPlannerPage extends StatelessWidget {
  const SessionPlannerPage({
    required this.onOpenSheet,
    required this.onChooseSheet,
    required this.onLaunchSheet,
    super.key,
  });

  final void Function(SheetId id, Audience audience) onOpenSheet;
  final VoidCallback onChooseSheet;
  final void Function(SheetId id, Audience audience, String sessionId)
  onLaunchSheet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: ResponsiveBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(title: l10n.plannerTitle),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: l10n.plannerFormTitle,
                child: const PlanSessionForm(),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: BlocBuilder<SessionPlannerBloc, SessionPlannerState>(
                  builder: (context, state) => SessionList(
                    sessions: state.sessions,
                    sheetOptions: state.sheetOptions,
                    onOpenSheet: onOpenSheet,
                    onChooseSheet: onChooseSheet,
                    onLaunchSheet: onLaunchSheet,
                    onDelete: (session) =>
                        context.read<SessionPlannerBloc>().add(
                          SessionPlannerEvent.sessionDeleted(
                            sessionId: session.id,
                          ),
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
