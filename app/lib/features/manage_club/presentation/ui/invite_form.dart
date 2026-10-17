import 'package:billard_cfa/entities/invitation/domain/invitation.dart';
import 'package:billard_cfa/features/manage_club/presentation/bloc/invite_state.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/role_labels.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Le formulaire « Inviter quelqu'un » : le rôle, puis les groupes d'un
/// enseignant ou l'élève (les enfants) lié, et la case « a 15 ans ou plus »
/// pour un élève. Les cases sont des lignes de 48 dp au moins ; l'échec
/// s'annonce en région vive.
class InviteForm extends StatelessWidget {
  const InviteForm({
    required this.state,
    required this.onRole,
    required this.onGroup,
    required this.onStudent,
    required this.onAge,
    required this.onSubmit,
    super.key,
  });

  final InviteState state;
  final ValueChanged<Role> onRole;
  final ValueChanged<GroupId> onGroup;
  final ValueChanged<StudentId> onStudent;
  final ValueChanged<bool> onAge;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final role = state.role;
    final isFamily = role == Role.student || role == Role.guardian;
    final failure = state.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: l10n.inviteRoleTitle,
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final option in state.roles)
                ChoiceChip(
                  label: Text(option.label(l10n)),
                  selected: option == role,
                  onSelected: state.submitting ? null : (_) => onRole(option),
                ),
            ],
          ),
        ),
        if (role == Role.teacher) ...[
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: l10n.inviteGroupsTitle,
            child: state.groups.isEmpty
                ? Text(l10n.inviteGroupsEmpty)
                : Column(
                    children: [
                      for (final group in state.groups)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(group.name),
                          value: state.selectedGroups.contains(group.id),
                          onChanged: (_) => onGroup(group.id),
                        ),
                    ],
                  ),
          ),
        ],
        if (isFamily) ...[
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: role == Role.student
                ? l10n.inviteStudentTitle
                : l10n.inviteChildrenTitle(InvitationPolicy.maxChildren),
            child: state.students.isEmpty
                ? Text(l10n.inviteStudentsEmpty)
                : Column(
                    children: [
                      for (final option in state.students)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            l10n.inviteStudentOption(
                              option.student.firstName,
                              option.groups.first.name,
                            ),
                          ),
                          value: state.selectedStudents.contains(
                            option.student.id,
                          ),
                          onChanged: (_) => onStudent(option.student.id),
                        ),
                    ],
                  ),
          ),
          if (role == Role.student) ...[
            const SizedBox(height: AppSpacing.md),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l10n.inviteAgeConfirm),
              subtitle: Text(l10n.inviteAgeHelp),
              value: state.ageConfirmed,
              onChanged: (value) => onAge(value ?? false),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(l10n.inviteNoticeReminder),
        ],
        if (failure != null) ...[
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: AppAlert(
              level: AlertLevel.persistent,
              message: failureMessage(l10n, failure),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: role == null || state.submitting ? null : onSubmit,
          child: Text(l10n.inviteSubmit),
        ),
      ],
    );
  }
}
