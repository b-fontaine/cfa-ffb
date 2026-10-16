import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/change_audience/domain/audience_change_outcome.dart';
import 'package:billard_cfa/features/change_audience/presentation/bloc/audience_change_bloc.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/audience_labels.dart';
import 'package:billard_cfa/shared/ui/confirm_dialog.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/group_choice_picker.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Public de l'élève : public actuel, historique conservé et changement
/// MANUEL (toujours confirmé) vers l'autre public.
class AudienceChangeCard extends StatefulWidget {
  const AudienceChangeCard({
    required this.student,
    required this.today,
    super.key,
  });

  final Student student;

  /// Date d'effet du changement (aujourd'hui).
  final DateTime today;

  @override
  State<AudienceChangeCard> createState() => _AudienceChangeCardState();
}

class _AudienceChangeCardState extends State<AudienceChangeCard> {
  GroupId? _groupId;

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    final today = widget.today;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dates = MaterialLocalizations.of(context);
    final current = student.currentAudience;
    final target = current == Audience.children
        ? Audience.adults
        : Audience.children;
    return SectionCard(
      title: l10n.audienceTitle,
      child: BlocBuilder<AudienceChangeBloc, AudienceChangeState>(
        builder: (context, state) {
          final failure = state.failure;
          final outcome = state.outcome;
          final choosing = state.choices.isNotEmpty;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.audienceCurrent(current.label(l10n)),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.audienceHistory, style: theme.textTheme.labelLarge),
              for (final change in student.audienceHistory)
                Text(
                  l10n.audienceHistoryRow(
                    change.audience.label(l10n),
                    dates.formatMediumDate(change.effectiveFrom),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.audienceManualNote, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.sm),
              if (choosing) ...[
                GroupChoicePicker(
                  choices: state.choices,
                  selected: _groupId,
                  onChanged: (id) => setState(() => _groupId = id),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              OutlinedButton(
                onPressed: state.status == AudienceChangeStatus.saving
                    ? null
                    : () async {
                        final bloc = context.read<AudienceChangeBloc>();
                        final confirmed = await showConfirmDialog(
                          context,
                          title: l10n.audienceConfirmTitle,
                          message: l10n.audienceConfirmBody(
                            student.firstName,
                            target.label(l10n),
                            dates.formatMediumDate(today),
                          ),
                        );
                        if (confirmed) {
                          bloc.add(
                            AudienceChangeEvent.requested(
                              studentId: student.id,
                              audience: target,
                              groupName: target.groupName(l10n),
                              destinationGroupId: _groupId,
                            ),
                          );
                        }
                      },
                child: Text(l10n.audienceMoveTo(target.label(l10n))),
              ),
              if (failure != null && !choosing) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  failureMessage(l10n, failure),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              if (outcome != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.audienceChanged(
                    outcome.student.currentAudience.label(l10n),
                    dates.formatMediumDate(
                      outcome.student.audienceHistory.last.effectiveFrom,
                    ),
                  ),
                ),
                for (final warning in outcome.warnings)
                  Text(switch (warning) {
                    AudienceChangeWarning.noAssessment =>
                      l10n.audienceWarnNoAssessment,
                    AudienceChangeWarning.readinessNotIndicated =>
                      l10n.audienceWarnNotReady,
                  }),
              ],
            ],
          );
        },
      ),
    );
  }
}
