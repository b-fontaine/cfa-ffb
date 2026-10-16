import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/student_form_bloc.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/audience_labels.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/group_choice_picker.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Formulaire d'un élève : prénom et public (données minimales). En édition,
/// seul le prénom change ; le public se change depuis le bilan de maturité.
class StudentForm extends StatefulWidget {
  const StudentForm({super.key});

  @override
  State<StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<StudentForm> {
  final _name = TextEditingController();
  Audience _audience = Audience.children;
  GroupId? _groupId;
  Student? _filledFrom;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _fill(Student? student) {
    if (student == null || student == _filledFrom) return;
    _filledFrom = student;
    _name.text = student.firstName;
    _audience = student.currentAudience;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return BlocConsumer<StudentFormBloc, StudentFormState>(
      listenWhen: (previous, current) => previous.student != current.student,
      listener: (context, state) => setState(() => _fill(state.student)),
      builder: (context, state) {
        final editing = state.student != null;
        final failure = state.failure;
        final choosing = state.choices.isNotEmpty;
        final saving = state.status == StudentFormStatus.saving;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.studentFormFirstName,
                // Le choix du groupe porte son propre message.
                errorText: failure == null || choosing
                    ? null
                    : failureMessage(l10n, failure),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              header: true,
              child: Text(
                l10n.studentFormAudience,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<Audience>(
              segments: [
                for (final audience in Audience.values)
                  ButtonSegment(
                    value: audience,
                    label: Text(audience.label(l10n)),
                  ),
              ],
              selected: {_audience},
              onSelectionChanged: editing
                  ? null
                  : (selection) => setState(() => _audience = selection.first),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              editing
                  ? l10n.studentFormAudienceLocked
                  : l10n.studentFormMinimalData,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (choosing) ...[
              const SizedBox(height: AppSpacing.md),
              GroupChoicePicker(
                choices: state.choices,
                selected: _groupId,
                onChanged: (id) => setState(() => _groupId = id),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: saving
                  ? null
                  : () => context.read<StudentFormBloc>().add(
                      StudentFormEvent.submitted(
                        firstName: _name.text,
                        audience: _audience,
                        groupName: _audience.groupName(l10n),
                        groupId: _groupId,
                      ),
                    ),
              child: Text(l10n.commonSave),
            ),
          ],
        );
      },
    );
  }
}
