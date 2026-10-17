import 'package:billard_cfa/entities/club/domain/club.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const id = ClubId('c1');

  test('a club has a name and no season by default', () {
    final club = Club(id: id, name: 'Club Nice');
    expect(club.name, 'Club Nice');
    expect(club.currentSeasonId, isNull);
  });

  test('refuses a blank name', () {
    expect(
      () => Club(id: id, name: '  '),
      throwsA(
        isA<InvariantViolation>().having(
          (e) => e.code,
          'code',
          InvariantCode.nameRequired,
        ),
      ),
    );
  });

  test('the name is limited to the length the server accepts', () {
    expect(
      Club(id: id, name: 'é' * maxClubNameLength).name,
      hasLength(maxClubNameLength),
    );
    expect(
      () => Club(id: id, name: 'é' * (maxClubNameLength + 1)),
      throwsA(
        isA<InvariantViolation>().having(
          (e) => e.code,
          'code',
          InvariantCode.nameTooLong,
        ),
      ),
    );
  });

  test('renaming trims and keeps the season', () {
    final club = Club(
      id: id,
      name: 'Club Nice',
      currentSeasonId: const SeasonId('s'),
    );
    final renamed = club.rename('  Club Lyon ');
    expect(renamed.name, 'Club Lyon');
    expect(renamed.currentSeasonId, const SeasonId('s'));
    expect(renamed.id, id);
  });
}
