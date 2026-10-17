import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/empty_state.dart';
import 'package:flutter/material.dart';

/// Les élèves liés au compte : le prénom et « Voir la progression » (cible de
/// 48 dp). Aucune autre information : ni alerte, ni assiduité, ni camarade.
class LinkedStudentsList extends StatelessWidget {
  const LinkedStudentsList({
    required this.students,
    required this.onShow,
    super.key,
  });

  final List<Student> students;
  final ValueChanged<StudentId> onShow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (students.isEmpty) return EmptyState(message: l10n.childrenEmpty);
    return Column(
      children: [
        for (final student in students)
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(student.firstName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onShow(student.id),
              subtitle: Text(l10n.childrenShow),
            ),
          ),
      ],
    );
  }
}
