import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/assessment_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/change_audience/domain/audience_change_outcome.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:injectable/injectable.dart';

/// R7 : changement de public, TOUJOURS manuel `[U]`. L'historique des
/// publics et les résultats sont conservés ; le bilan de maturité ne fait
/// qu'avertir.
///
/// Les groupes suivent le public : l'appartenance ouverte dans un groupe d'un
/// autre public est close la veille de la date d'effet et ouverte dans un
/// groupe du nouveau public (le même, de la même saison, ou un groupe créé).
@injectable
class ChangeAudience {
  ChangeAudience(
    this._students,
    this._assessments,
    this._groups,
    this._ids,
    this._config,
    this._unitOfWork,
  );

  final StudentRepository _students;
  final AssessmentRepository _assessments;
  final GroupRepository _groups;
  final IdGenerator _ids;
  final RulesConfig _config;
  final UnitOfWork _unitOfWork;

  /// [groupName] nomme le groupe créé si le nouveau public n'en a pas encore
  /// dans la saison (à défaut : le nom technique du public).
  Future<Result<AudienceChangeOutcome>> call({
    required StudentId studentId,
    required Audience audience,
    required DateTime effectiveFrom,
    String? groupName,
  }) => runGuarded(() async {
    final student = await _students.byId(studentId);
    if (student == null) throw NotFound('student', studentId.value);
    final updated = student.changeAudience(audience, effectiveFrom);
    final assessments = await _assessments.forStudent(studentId);
    final warnings = <AudienceChangeWarning>[
      if (audience == Audience.adults && assessments.isEmpty)
        AudienceChangeWarning.noAssessment,
      if (audience == Audience.adults &&
          assessments.isNotEmpty &&
          !assessments.last.readinessHint(_config))
        AudienceChangeWarning.readinessNotIndicated,
    ];
    final groups = await _groups.all();
    await _unitOfWork.run(() async {
      await _students.save(updated);
      for (final group in groups) {
        final open = group.memberships.where(
          (m) => m.studentId == studentId && m.to == null,
        );
        if (open.isEmpty || group.audience == audience) continue;
        final end = effectiveFrom.subtract(const Duration(days: 1));
        final from = open.first.from;
        await _groups.save(
          group.release(
            studentId: studentId,
            to: end.isBefore(from) ? from : end,
          ),
        );
        final destination = await _destination(
          groups,
          group,
          audience,
          groupName ?? audience.name,
        );
        await _groups.save(
          destination.admit(
            studentId: studentId,
            studentAudience: audience,
            from: effectiveFrom,
          ),
        );
      }
    });
    return AudienceChangeOutcome(student: updated, warnings: warnings);
  });

  /// Groupe de [audience] de la saison de [origin] ; créé s'il n'existe pas.
  Future<Group> _destination(
    List<Group> groups,
    Group origin,
    Audience audience,
    String name,
  ) async {
    final existing = groups.where(
      (g) => g.seasonId == origin.seasonId && g.audience == audience,
    );
    if (existing.isNotEmpty) {
      return (await _groups.byId(existing.first.id)) ?? existing.first;
    }
    return Group(
      id: GroupId(_ids.next()),
      seasonId: origin.seasonId,
      name: name,
      audience: audience,
    );
  }
}
