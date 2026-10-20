import 'package:billard_cfa/entities/season/data/season_archive_document.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/document_ids.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_paths.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les identifiants que le plan d'import compose sont ceux des dépôts : un
/// import et l'application écrivent le même document.
void main() {
  const paths = ClubPaths(ClubId('c1'));
  final from = DateTime(2026, 9, 1, 8, 30);

  test('a membership id is the last segment of the membership path', () {
    const group = GroupId('g1');
    const student = StudentId('s1');
    expect(
      paths.membership(group, student, from),
      'clubs/c1/memberships/${DocumentIds.membership(group, student, from)}',
    );
    expect(
      DocumentIds.membership(group, student, from),
      'g1_s1_2026-09-01T08:30:00.000',
    );
  });

  test('archive ids are the ones of the archive repository', () {
    const season = SeasonId('se');
    final exercise = ExerciseRef(blockId: 'puissance', number: 2);
    expect(
      DocumentIds.archiveSummary(season, Audience.children),
      SeasonArchiveDocument.summaryId(season, Audience.children),
    );
    expect(
      DocumentIds.archiveExercise(season, Audience.adults, exercise),
      SeasonArchiveDocument.exerciseId(season, Audience.adults, exercise),
    );
    expect(
      DocumentIds.archiveExercise(season, Audience.adults, exercise),
      'se_adults_puissance_2',
    );
  });

  test('the import marker belongs to its author: digest and uid in its id', () {
    expect(
      paths.importMarker('a' * 64, const UserId('u1')),
      'clubs/c1/imports/${'a' * 64}_u1',
    );
    expect(
      paths.importMarker('a' * 64, const UserId('u1')),
      isNot(paths.importMarker('a' * 64, const UserId('u2'))),
    );
  });
}
