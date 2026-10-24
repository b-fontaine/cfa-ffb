import 'package:billard_cfa/features/close_season/domain/close_season.dart';
import 'package:billard_cfa/features/close_season/domain/local_season_closing.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockClose extends Mock implements CloseSeason;

void main() {
  test('on the device there is no invitation: the closure deletes none, '
      'without reading anything', () async {
    final close = _MockClose();

    final result = await LocalSeasonClosing(close).invitationsToPurge();

    expect((result as Ok<int>).value, 0);
    verifyZeroInteractions(close);
  });
}
