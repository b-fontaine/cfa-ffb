import 'package:billard_cfa/entities/group/domain/choose_group.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_calendar.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'enroll_student.freezed.dart';

/// Élève inscrit et groupe qui l'accueille.
@freezed
abstract class EnrolledStudent with _$EnrolledStudent {
  const factory EnrolledStudent({
    required Student student,
    required Group group,
  }) = _EnrolledStudent;
}

/// Cas d'usage : inscrire un élève (prénom et public seulement, données
/// minimales) dans le groupe de son public pour la saison de `today`.
///
/// La saison (année scolaire du 1er septembre au 31 août, à partir de
/// juillet) et le groupe sont
/// créés au besoin, pour que l'animateur n'ait aucune configuration à faire.
/// L'élève est inscrit dès le début de la saison pour pouvoir saisir des
/// séances déjà données.
@injectable
class EnrollStudent {
  EnrollStudent(
    this._students,
    this._groups,
    this._seasons,
    this._ids,
    this._unitOfWork,
  );

  final StudentRepository _students;
  final GroupRepository _groups;
  final SeasonRepository _seasons;
  final IdGenerator _ids;
  final UnitOfWork _unitOfWork;

  /// [groupName] nomme le groupe s'il faut le créer (à défaut : le nom
  /// technique du public).
  Future<Result<EnrolledStudent>> call({
    required String firstName,
    required Audience audience,
    required DateTime today,
    String? groupName,
    GroupId? groupId,
  }) => runGuarded(() async {
    if (firstName.trim().length > maxFirstNameLength) {
      throw const InvariantViolation(InvariantCode.nameTooLong);
    }
    final season = await _seasonOf(today);
    final since = season.startDate.isAfter(today) ? today : season.startDate;
    final student = Student.enroll(
      id: StudentId(_ids.next()),
      firstName: firstName.trim(),
      audience: audience,
      since: since,
    );
    final chosen = chooseGroup(
      groups: await _groups.all(),
      seasonId: season.id,
      audience: audience,
      requested: groupId,
    );
    final base =
        chosen ??
        Group(
          id: GroupId(_ids.next()),
          seasonId: season.id,
          name: groupName ?? audience.name,
          audience: audience,
        );
    final group = base.admit(
      studentId: student.id,
      studentAudience: audience,
      from: since,
    );
    await _unitOfWork.run(() async {
      await _seasons.save(season);
      await _students.save(student);
      await _groups.save(group);
    });
    return EnrolledStudent(student: student, group: group);
  });

  /// Saison ouverte contenant [today] ; sinon la saison existante qui recouvre
  /// l'année scolaire ; sinon une nouvelle année scolaire. Une saison close
  /// n'accueille plus personne : l'inscription ouvre la saison qui la suit.
  Future<Season> _seasonOf(DateTime today) async {
    final seasons = await _seasons.all();
    for (final season in seasons) {
      if (season.isOpenOn(today)) return season;
    }
    var created = schoolYearSeason(today, SeasonId(_ids.next()));
    for (var round = 0; round <= seasons.length; round++) {
      final overlapping = seasons.where((s) => s.overlaps(created));
      if (overlapping.isEmpty) return created;
      final season = overlapping.first;
      if (!season.isClosed) return season;
      created = nextSeasonAfter(season, created.id);
    }
    return created;
  }
}
