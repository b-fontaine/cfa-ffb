// Vérifie que le registre des traitements nomme chaque chemin lu par un parent
// ou un élève (lot FB6, ADR 0024 décision 26).
//
// `scripts/rules_test/family_reads.json` fait foi : ses listes `famille` et
// `connexion` donnent les lectures EXACTES de l'espace famille. Chacune doit
// apparaître, entre apostrophes inverses, dans le traitement 1 bis du registre
// (`## Traitement 1 bis` jusqu'au titre suivant). Un chemin ajouté à la liste
// sans être porté au registre fait échouer le garde-fou.
//
// Nom attendu d'une lecture : le chemin sans `clubs/{club}/` et sans segment
// variable (`clubs/{club}/students/{student}` → `students`,
// `clubs/{club}/settings/main` → `settings/main`) ; `clubs/{club}` et
// `admins/{uid}` restent tels quels ; `group members uid=…` → `members`.
//
// Usage : dart run scripts/check_family_register.dart [family_reads.json] [registre.md]
import 'dart:convert';
import 'dart:io';

const _sectionTitle = '## Traitement 1 bis';

/// Le nom, dans le registre, de ce que lit [read] (`get`, `query`, `watch
/// document`, `watch query` ou `group`).
String? nameOf(String read) {
  final words = read.trim().split(RegExp(r'\s+'));
  if (words.length < 2) return null;
  final String target;
  switch (words.first) {
    case 'group':
      return words[1];
    case 'get':
      target = words[1];
    case 'query':
      target = words[1];
    case 'watch':
      target = words.length > 2 ? words[2] : words[1];
    default:
      return null;
  }
  if (target.startsWith('clubs/{club}/')) {
    final segments = target
        .substring('clubs/{club}/'.length)
        .split('/')
        .where((s) => !(s.startsWith('{') && s.endsWith('}')));
    return segments.join('/');
  }
  return target;
}

void main(List<String> args) {
  final reads = File(
    args.isNotEmpty ? args[0] : 'scripts/rules_test/family_reads.json',
  );
  final register = File(
    args.length > 1
        ? args[1]
        : 'docs/engineering/conformite/registre-des-traitements.md',
  );
  final json = jsonDecode(reads.readAsStringSync()) as Map<String, dynamic>;
  final lines = <String>[
    for (final key in ['famille', 'connexion'])
      ...(json[key] as List<dynamic>? ?? const []).cast<String>(),
  ];

  final text = register.readAsStringSync();
  final start = text.indexOf(_sectionTitle);
  if (start < 0) {
    stderr.writeln('${register.path} : section "$_sectionTitle" introuvable.');
    exit(1);
  }
  final next = text.indexOf('\n## ', start + _sectionTitle.length);
  final section = text.substring(start, next < 0 ? text.length : next);

  var failed = false;
  final names = <String>{};
  for (final line in lines) {
    final name = nameOf(line);
    if (name == null || name.isEmpty) {
      stderr.writeln('${reads.path} : lecture incomprise "$line"');
      failed = true;
      continue;
    }
    if (names.add(name) && !section.contains('`$name`')) {
      stderr.writeln(
        '${register.path} : `$name` (lecture "$line") n\'est pas nommé '
        'entre apostrophes inverses dans le traitement 1 bis.',
      );
      failed = true;
    }
  }
  if (failed) exit(1);
  stdout.writeln(
    'registre OK : ${names.length} chemins de family_reads.json nommés '
    'dans le traitement 1 bis.',
  );
}
