import 'package:billard_cfa/features/track_group/presentation/bloc/group_overview_cubit.dart';
import 'package:billard_cfa/features/track_group/presentation/ui/group_alerts_list.dart';
import 'package:billard_cfa/features/track_group/presentation/ui/group_attendance_card.dart';
import 'package:billard_cfa/features/track_group/presentation/ui/group_heat_map.dart';
import 'package:billard_cfa/features/track_group/presentation/ui/group_text_summary.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// La vue d'un groupe : alertes de groupe, assiduité, carte de chaleur
/// technique × élève et son résumé en texte. Le cubit est fourni par la couche
/// `app` ; la page ne calcule rien.
class GroupOverviewPage extends StatelessWidget {
  const GroupOverviewPage({
    required this.onBack,
    required this.onOpenStudent,
    super.key,
  });

  final VoidCallback onBack;
  final ValueChanged<StudentId> onOpenStudent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<GroupOverviewCubit, GroupOverviewState>(
      builder: (context, state) {
        final grid = state.grid;
        return switch (state.status) {
          GroupOverviewStatus.loading => const Scaffold(body: LoadingView()),
          GroupOverviewStatus.failure => Scaffold(
            body: ErrorView(
              message: failureMessage(l10n, state.failure!),
              onRetry: () => context.read<GroupOverviewCubit>().reload(),
              onBack: onBack,
            ),
          ),
          GroupOverviewStatus.ready => ScrollPage(
            title: grid!.name,
            onBack: onBack,
            backLabel: l10n.navStudents,
            children: [
              GroupAlertsList(alerts: grid.alerts),
              GroupAttendanceCard(attendance: grid.attendance),
              SectionCard(
                title: l10n.groupSubtitle,
                child: GroupHeatMap(grid: grid, onOpenStudent: onOpenStudent),
              ),
              GroupTextSummary(grid: grid),
            ],
          ),
        };
      },
    );
  }
}
