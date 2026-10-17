// Vérifie la complétude du catalogue Widgetbook :
//
// - chaque widget public de app/lib/shared/ui, widgets, pages et
//   features/*/presentation/ui a au moins un use case (`type: Widget`) ;
// - chaque use case annoté est référencé par le fichier généré
//   `main.directories.g.dart` (il est donc à jour).
//
// Usage : dart run scripts/check_widgetbook.dart [app] [widgetbook]
import 'dart:io';

final _widgetClass = RegExp(
  r'^class\s+([A-Z]\w*)\s+extends\s+(?:StatelessWidget|StatefulWidget)\b',
  multiLine: true,
);
final _useCaseType = RegExp(r'type:\s*([A-Z]\w*)');
final _useCaseFunction = RegExp(
  r'@widgetbook\.UseCase\([^)]*\)\s*Widget\s+(\w+)\(',
  dotAll: true,
);

Iterable<File> _dartFiles(String path) {
  final dir = Directory(path);
  if (!dir.existsSync()) return const [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where(
        (f) =>
            !f.path.endsWith('.g.dart') &&
            !f.path.endsWith('.freezed.dart') &&
            !f.path.endsWith('.config.dart') &&
            !f.path.endsWith('.steps.dart'),
      );
}

bool _isUiFile(String path) {
  final p = path.replaceAll(r'\', '/');
  return p.contains('/lib/shared/ui/') ||
      p.contains('/lib/widgets/') ||
      p.contains('/lib/pages/') ||
      RegExp('/lib/features/[^/]+/presentation/ui/').hasMatch(p);
}

void main(List<String> args) {
  final app = args.isNotEmpty ? args[0] : 'app';
  final book = args.length > 1 ? args[1] : 'widgetbook';

  final widgets = <String, String>{};
  for (final file in _dartFiles('$app/lib').where((f) => _isUiFile(f.path))) {
    for (final match in _widgetClass.allMatches(file.readAsStringSync())) {
      widgets[match.group(1)!] = file.path;
    }
  }

  final covered = <String>{};
  final functions = <String>{};
  for (final file in _dartFiles('$book/lib/use_cases')) {
    final text = file.readAsStringSync();
    covered.addAll(_useCaseType.allMatches(text).map((m) => m.group(1)!));
    functions.addAll(_useCaseFunction.allMatches(text).map((m) => m.group(1)!));
  }

  var failed = false;
  for (final entry in widgets.entries) {
    if (!covered.contains(entry.key)) {
      stderr.writeln(
        'Aucun use case Widgetbook pour ${entry.key} (${entry.value})',
      );
      failed = true;
    }
  }

  final generated = File('$book/lib/main.directories.g.dart');
  if (!generated.existsSync()) {
    stderr.writeln('main.directories.g.dart absent : lancer build_runner.');
    exit(1);
  }
  final generatedText = generated.readAsStringSync();
  for (final name in functions) {
    if (!generatedText.contains(name)) {
      stderr.writeln(
        'Code généré obsolète : $name absent de main.directories.g.dart',
      );
      failed = true;
    }
  }

  stdout.writeln(
    'Widgetbook : ${widgets.length} widget(s), '
    '${functions.length} use case(s).',
  );
  if (failed) exit(1);
}
