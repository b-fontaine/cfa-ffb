import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/architecture/architecture_rules.dart';

void main() {
  late Directory lib;

  setUp(() {
    lib = Directory.systemTemp.createTempSync('arch_test_');
  });

  tearDown(() => lib.deleteSync(recursive: true));

  void write(String path, String content) {
    File('${lib.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  List<String> messages() =>
      checkArchitecture(lib, packageName: 'demo').map((v) => '$v').toList();

  test('real project respects the architecture', () {
    expect(checkArchitecture(Directory('lib')), isEmpty);
  });

  group('single ball radius', () {
    test('rejects a ballRadius identifier', () {
      write('shared/lib/g.dart', 'const double ballRadius = 0.1;');

      expect(messages().join('\n'), contains('rayon de bille unique'));
    });

    test('rejects a 0.1 literal next to a radius', () {
      write('shared/ui/g.dart', 'final r = unit * 0.1; final radius = 0.1;');

      expect(messages().join('\n'), contains('rayon de bille unique'));
    });

    test('rejects two radii used as the contact distance', () {
      write('shared/lib/g.dart', 'final s = 2 * objectRadius;');

      expect(messages().join('\n'), contains('rayon de bille unique'));
    });

    test('accepts a radius that is not a ball radius literal', () {
      write(
        'shared/ui/g.dart',
        'final w = math.max(0.75, radius * 0.08); // radius 0.1 rule',
      );

      expect(messages(), isEmpty);
    });

    test('allows the dimensions module to declare the radii', () {
      write(
        'shared/lib/blackball_dimensions.dart',
        'const double objectBallRadius = 25.4;\n'
            'const double ballRadius = 0.1;',
      );

      expect(messages(), isEmpty);
    });
  });

  group('pdf package', () {
    test('rejects the pdf widgets API (ADR 0021)', () {
      write('features/f/data/r.dart', "import 'package:pdf/widgets.dart';");

      expect(messages().join('\n'), contains('pdf/widgets'));
    });

    test('rejects the printing package (ADR 0021)', () {
      write(
        'features/f/data/r.dart',
        "import 'package:printing/printing.dart';",
      );

      expect(messages().join('\n'), contains('printing'));
    });

    test('rejects private files of the pdf package', () {
      write(
        'features/f/data/r.dart',
        "import 'package:pdf/src/pdf/document.dart';",
      );

      expect(messages().join('\n'), contains('pdf/src'));
    });

    test('accepts the low level API in the export data layer', () {
      write(
        'features/export_sheet/data/r.dart',
        "import 'package:pdf/pdf.dart';",
      );

      expect(messages(), isEmpty);
    });

    test('rejects the low level API outside the export data layer', () {
      write(
        'features/export_sheet/presentation/r.dart',
        "import 'package:pdf/pdf.dart';",
      );

      expect(messages().join('\n'), contains('export_sheet/data'));
    });
  });

  group('platform SDKs (rule 9)', () {
    for (final package in [
      'firebase_auth',
      'firebase_core',
      'cloud_firestore',
    ]) {
      test('rejects $package outside app/platform', () {
        write(
          'features/f/data/r.dart',
          "import 'package:$package/$package.dart';",
        );

        expect(messages().join('\n'), contains('SDK Firebase'));
      });

      test('rejects $package in the app layer outside app/platform', () {
        write('app/x.dart', "import 'package:$package/$package.dart';");

        expect(messages().join('\n'), contains('app/platform'));
      });

      test('accepts $package under app/platform', () {
        write(
          'app/platform/x.dart',
          "import 'package:$package/$package.dart';",
        );

        expect(messages(), isEmpty);
      });
    }

    test('accepts firebase_core in the generated options file only', () {
      write(
        'app/firebase_options.dart',
        "import 'package:firebase_core/firebase_core.dart';",
      );
      write(
        'app/firebase_other.dart',
        "import 'package:firebase_core/firebase_core.dart';",
      );

      expect(messages(), hasLength(1));
      expect(messages().single, contains('firebase_other.dart'));
    });

    test('options file may not import firebase_auth', () {
      write(
        'app/firebase_options.dart',
        "import 'package:firebase_auth/firebase_auth.dart';",
      );

      expect(messages().join('\n'), contains('SDK Firebase'));
    });

    test('shared_preferences has a single importer', () {
      write(
        'app/platform/shared_preferences_key_value_store.dart',
        "import 'package:shared_preferences/shared_preferences.dart';",
      );
      write(
        'app/platform/other.dart',
        "import 'package:shared_preferences/shared_preferences.dart';",
      );

      expect(messages(), hasLength(1));
      expect(messages().single, contains('other.dart'));
    });
  });

  test('accepts a clean layered layout', () {
    write('entities/a/domain/a.dart', 'class A {}');
    write(
      'features/f/presentation/ui/x.dart',
      "import 'package:demo/entities/a/domain/a.dart';",
    );
    write(
      'app/router.dart',
      "import 'package:demo/features/f/presentation/ui/x.dart';",
    );

    expect(messages(), isEmpty);
  });

  test('rejects an upward import between layers', () {
    write('pages/p/presentation/p.dart', 'class P {}');
    write(
      'entities/a/domain/a.dart',
      "import 'package:demo/pages/p/presentation/p.dart';",
    );

    expect(messages().single, contains('ne peut pas importer la couche'));
  });

  test('rejects imports between two slices of the same layer', () {
    write('features/f1/domain/a.dart', 'class A {}');
    write(
      'features/f2/domain/b.dart',
      "import 'package:demo/features/f1/domain/a.dart';",
    );

    expect(messages().single, contains('entre slices de la même couche'));
  });

  test('rejects Flutter in domain', () {
    write(
      'entities/a/domain/a.dart',
      "import 'package:flutter/material.dart';",
    );

    expect(messages().single, contains('non pur'));
  });

  test('rejects the yaml parser in domain', () {
    write('entities/a/domain/a.dart', "import 'package:yaml/yaml.dart';");

    expect(messages().single, contains('non pur'));
  });

  test('accepts the yaml parser in data', () {
    write('entities/a/domain/port.dart', 'class Port {}');
    write(
      'entities/a/data/parser.dart',
      "import 'package:yaml/yaml.dart';\n"
          "import 'package:demo/entities/a/domain/port.dart';",
    );

    expect(messages(), isEmpty);
  });

  test('rejects an entity importing a sibling entity', () {
    write('entities/a/domain/a.dart', 'class A {}');
    write(
      'entities/b/domain/b.dart',
      "import 'package:demo/entities/a/domain/a.dart';",
    );

    expect(messages().single, contains('entre slices de la même couche'));
  });

  test('lets entities share the pure kernel in shared/lib', () {
    write('shared/lib/audience.dart', 'enum Audience { a }');
    write(
      'entities/a/domain/a.dart',
      "import 'package:demo/shared/lib/audience.dart';",
    );
    write(
      'entities/b/domain/b.dart',
      "import 'package:demo/shared/lib/audience.dart';",
    );

    expect(messages(), isEmpty);
  });

  test('rejects presentation importing data', () {
    write('entities/a/data/repo.dart', 'class Repo {}');
    write(
      'features/f/presentation/ui/x.dart',
      "import 'package:demo/entities/a/data/repo.dart';",
    );

    expect(messages().single, contains('presentation ne doit jamais'));
  });

  test('rejects data importing another slice presentation', () {
    write('entities/a/presentation/w.dart', 'class W {}');
    write(
      'entities/a/data/repo.dart',
      "import 'package:demo/entities/a/presentation/w.dart';",
    );

    expect(messages().single, contains('data ne peut importer'));
  });

  test('rejects domain importing another domain-external segment', () {
    write('entities/a/data/repo.dart', 'class Repo {}');
    write(
      'entities/a/domain/a.dart',
      "import 'package:demo/entities/a/data/repo.dart';",
    );

    expect(messages().single, contains('domain ne peut importer'));
  });

  test('rejects relative imports', () {
    write('entities/a/domain/b.dart', 'class B {}');
    write('entities/a/domain/a.dart', "import 'b.dart';");

    expect(messages().single, contains('import relatif interdit'));
  });

  test('rejects unknown segments and stray files', () {
    write('entities/a/utils/u.dart', 'class U {}');
    write('stray.dart', 'class S {}');

    expect(messages(), hasLength(2));
  });

  test('rejects importing main.dart and ignores generated files', () {
    write('app/a.dart', "import 'package:demo/main.dart';");
    write('entities/a/domain/a.freezed.dart', "import 'dart:io';");
    write('shared/lib/db.steps.dart', "import 'dart:io';");

    expect(messages().single, contains('main.dart'));
  });

  test('forbids shared/ui and shared/l10n from domain', () {
    write('shared/ui/w.dart', 'class W {}');
    write('shared/lib/l.dart', 'class L {}');
    write(
      'entities/a/domain/a.dart',
      "import 'package:demo/shared/ui/w.dart';\n"
          "import 'package:demo/shared/lib/l.dart';",
    );

    expect(messages().single, contains('shared/lib'));
  });
  test('forbids shared/lib from importing other shared segments', () {
    write('shared/ui/w.dart', 'class W {}');
    write('shared/persistence/db.dart', 'class Db {}');
    write(
      'shared/lib/a.dart',
      "import 'package:demo/shared/ui/w.dart';\n"
          "import 'package:demo/shared/persistence/db.dart';",
    );

    expect(messages(), hasLength(2));
    expect(messages().first, contains('shared/lib ne peut importer'));
  });

  test('accepts shared/lib importing shared/lib', () {
    write('shared/lib/a.dart', 'class A {}');
    write('shared/lib/b.dart', "import 'package:demo/shared/lib/a.dart';");

    expect(messages(), isEmpty);
  });

  test('forbids presentation from importing shared/persistence', () {
    write('shared/persistence/db.dart', 'class Db {}');
    write(
      'features/f/presentation/ui/x.dart',
      "import 'package:demo/shared/persistence/db.dart';",
    );
    write(
      'pages/p/presentation/p.dart',
      "import 'package:demo/shared/persistence/db.dart';",
    );

    expect(messages(), hasLength(2));
    expect(messages().first, contains('shared/persistence'));
  });

  test('forbids shared/ui from importing shared/persistence', () {
    write('shared/persistence/db.dart', 'class Db {}');
    write(
      'shared/ui/w.dart',
      "import 'package:demo/shared/persistence/db.dart';",
    );

    expect(messages().single, contains('shared/persistence'));
  });

  test('allows data and app to import shared/persistence', () {
    write('shared/persistence/db.dart', 'class Db {}');
    write('entities/a/domain/port.dart', 'class Port {}');
    write(
      'entities/a/data/repo.dart',
      "import 'package:demo/shared/persistence/db.dart';\n"
          "import 'package:demo/entities/a/domain/port.dart';",
    );
    write('app/di.dart', "import 'package:demo/shared/persistence/db.dart';");

    expect(messages(), isEmpty);
  });

  test('forbids shared/persistence from importing shared/ui', () {
    write('shared/ui/w.dart', 'class W {}');
    write('shared/lib/a.dart', 'class A {}');
    write(
      'shared/persistence/db.dart',
      "import 'package:demo/shared/ui/w.dart';\n"
          "import 'package:demo/shared/lib/a.dart';",
    );

    expect(messages().single, contains('shared/persistence ne peut importer'));
  });
}
