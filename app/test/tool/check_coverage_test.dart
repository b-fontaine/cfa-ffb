import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Rejoue `scripts/check_coverage.dart` sur un faux dossier `app/` : le
/// script lit `coverage/lcov.info` et les fichiers de `lib/`.
void main() {
  late Directory app;

  setUp(() => app = Directory.systemTemp.createTempSync('check_coverage_'));

  tearDown(() => app.deleteSync(recursive: true));

  void write(String path, String content) {
    File('${app.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  /// lcov d'un fichier : [hit] lignes couvertes sur [lines].
  String record(String path, int lines, int hit) =>
      'SF:$path\nLF:$lines\nLH:$hit\nend_of_record\n';

  ProcessResult run(String threshold) => Process.runSync('dart', [
    '../scripts/check_coverage.dart',
    threshold,
    app.path,
  ]);

  group('threshold', () {
    test('fails just below the threshold', () {
      write('lib/a.dart', 'void a() {}');
      write('coverage/lcov.info', record('lib/a.dart', 1000, 899));

      final result = run('90');

      expect(result.exitCode, 1);
      expect(result.stderr, contains('Couverture insuffisante'));
    });

    test('passes exactly at the threshold', () {
      write('lib/a.dart', 'void a() {}');
      write('coverage/lcov.info', record('lib/a.dart', 1000, 900));

      final result = run('90');

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(result.stdout, contains('90.0 %'));
    });

    test('passes just above the threshold', () {
      write('lib/a.dart', 'void a() {}');
      write('coverage/lcov.info', record('lib/a.dart', 1000, 901));

      expect(run('90').exitCode, 0);
    });
  });

  group('files', () {
    test('fails when a library file is never loaded by the tests', () {
      write('lib/a.dart', 'void a() {}');
      write('lib/never.dart', 'void never() {}');
      write('coverage/lcov.info', record('lib/a.dart', 10, 10));

      final result = run('90');

      expect(result.exitCode, 1);
      expect(
        result.stderr,
        contains('NON CHARGÉ par les tests : lib/never.dart'),
      );
    });

    test('tolerates an untouched file imported by a loaded one', () {
      write('lib/a.dart', "import 'package:demo/port.dart';\nvoid a() {}");
      write('lib/port.dart', 'abstract class Port {}');
      write('coverage/lcov.info', record('lib/a.dart', 10, 10));

      expect(run('90').exitCode, 0);
    });

    test('ignores generated files, main and the injection wiring', () {
      write('lib/a.dart', 'void a() {}');
      write('lib/a.g.dart', '');
      write('lib/a.freezed.dart', '');
      write('lib/a.config.dart', '');
      write('lib/a.steps.dart', '');
      write('lib/shared/l10n/generated/app_localizations.dart', '');
      write('lib/main.dart', 'void main() {}');
      write('lib/app/di/injection.dart', '');
      write('coverage/lcov.info', record('lib/a.dart', 10, 10));

      expect(run('90').exitCode, 0);
    });

    test('lists the files that are not fully covered', () {
      write('lib/a.dart', 'void a() {}');
      write('coverage/lcov.info', record('lib/a.dart', 10, 9));

      final result = run('80');

      expect(result.exitCode, 0);
      expect(result.stdout, contains('9/10  lib/a.dart'));
    });
  });

  test('refuses to run without a coverage report', () {
    write('lib/a.dart', 'void a() {}');

    final result = run('90');

    expect(result.exitCode, 2);
    expect(result.stderr, contains('lcov.info introuvable'));
  });
}
