import 'package:billard_cfa/entities/season/data/in_memory_season_repository.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

void main() {
  test('stores and finds a season', () async {
    final repository = InMemorySeasonRepository();
    final season = Season(
      id: const SeasonId('s1'),
      label: '2026-2027',
      startDate: day(1),
      endDate: day(30),
    );

    expect(await repository.byId(const SeasonId('s1')), isNull);
    await repository.save(season);

    expect(await repository.byId(const SeasonId('s1')), season);
  });
}
