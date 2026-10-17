import 'package:billard_cfa/entities/run_progress/data/run_progress_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('counts', () {
    test('round-trips and is written in a stable order', () {
      final text = RunProgressJson.encodeCounts({'b': 2, 'a': 1});

      expect(text, '{"a":1,"b":2}');
      expect(RunProgressJson.decodeCounts(text), {'a': 1, 'b': 2});
    });

    test('an empty map is an empty object', () {
      expect(RunProgressJson.encodeCounts({}), '{}');
      expect(RunProgressJson.decodeCounts('{}'), isEmpty);
    });

    test('rejects what is not an object of integers', () {
      for (final bad in [
        '',
        'not json',
        '[1]',
        '{"a":"1"}',
        '{"a":1.5}',
        '{"a":null}',
        'null',
      ]) {
        expect(
          () => RunProgressJson.decodeCounts(bad),
          throwsFormatException,
          reason: bad,
        );
      }
    });
  });

  group('checked', () {
    test('round-trips with sorted keys and indices', () {
      final text = RunProgressJson.encodeChecked({
        'b': {2, 0},
        'a': {1},
      });

      expect(text, '{"a":[1],"b":[0,2]}');
      expect(RunProgressJson.decodeChecked(text), {
        'a': {1},
        'b': {0, 2},
      });
    });

    test('keeps an initiation with no criterion checked', () {
      final text = RunProgressJson.encodeChecked({'a': <int>{}});

      expect(RunProgressJson.decodeChecked(text), {'a': <int>{}});
    });

    test('rejects what is not an object of integer lists', () {
      for (final bad in [
        '',
        '{"a":1}',
        '{"a":["x"]}',
        '{"a":[1.5]}',
        '[[1]]',
        '{"a":{"b":1}}',
      ]) {
        expect(
          () => RunProgressJson.decodeChecked(bad),
          throwsFormatException,
          reason: bad,
        );
      }
    });
  });
}
