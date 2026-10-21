// Vérifie que chaque lien relatif de la documentation vers une ancre (`#titre`)
// d'un fichier Markdown de `docs/` existant, ou du même fichier, pointe vers un
// titre qui existe. Il ne vérifie PAS l'existence des fichiers : un lien vers
// un fichier absent, ou sans ancre, est ignoré.
//
// Un titre renommé casse silencieusement les liens `fichier.md#ancre` : la
// roadmap, les ADR et les plans se renvoient des ancres (« Procédure de mise
// en service sur Firestore »). Les ancres suivent la règle de GitHub :
// minuscules, ponctuation retirée, espaces en tirets, suffixe `-1`, `-2`… pour
// un titre répété ; les titres dans un bloc de code ne comptent pas.
//
// Usage : dart run scripts/check_doc_links.dart [dossier-docs]   (défaut : docs)
import 'dart:convert';
import 'dart:io';

final _heading = RegExp(r'^ {0,3}#{1,6}\s+(.*?)\s*#*\s*$');
final _link = RegExp(r'\]\(([^)\s]+)(?:\s+"[^"]*")?\)');

/// L'ancre GitHub du texte d'un titre.
String slug(String title) {
  final plain = title
      .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!)
      .replaceAll(RegExp('[`*~]'), '')
      .toLowerCase();
  final kept = plain.replaceAll(
    RegExp(r'[^\p{L}\p{N}\p{M} _-]', unicode: true),
    '',
  );
  return kept.replaceAll(' ', '-');
}

/// Les lignes hors blocs de code d'un fichier Markdown.
Iterable<MapEntry<int, String>> proseLines(String text) sync* {
  var fenced = false;
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (RegExp(r'^\s*(```|~~~)').hasMatch(lines[i])) {
      fenced = !fenced;
      continue;
    }
    if (!fenced) yield MapEntry(i + 1, lines[i]);
  }
}

Set<String> anchorsOf(String text) {
  final seen = <String, int>{};
  final anchors = <String>{};
  for (final line in proseLines(text)) {
    final match = _heading.firstMatch(line.value);
    if (match != null) {
      final base = slug(match[1]!);
      final count = seen[base] ?? 0;
      seen[base] = count + 1;
      anchors.add(count == 0 ? base : '$base-$count');
    }
    for (final a in RegExp(
      r'<a\s+(?:name|id)="([^"]+)"',
    ).allMatches(line.value)) {
      anchors.add(a[1]!);
    }
  }
  return anchors;
}

String _decode(String raw) => raw.replaceAllMapped(
  RegExp('(%[0-9A-Fa-f]{2})+'),
  (m) => utf8.decode([
    for (var i = 1; i < m[0]!.length; i += 3)
      int.parse(m[0]!.substring(i, i + 2), radix: 16),
  ], allowMalformed: true),
);

void main(List<String> args) {
  final root = Directory(args.isNotEmpty ? args[0] : 'docs');
  final files = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.md'))
      .toList();
  final anchors = <String, Set<String>>{};
  Set<String> anchorsFor(File f) => anchors.putIfAbsent(
    f.absolute.path,
    () => anchorsOf(f.readAsStringSync()),
  );

  var broken = 0;
  var checked = 0;
  for (final file in files) {
    for (final line in proseLines(file.readAsStringSync())) {
      for (final m in _link.allMatches(line.value)) {
        final target = m[1]!;
        if (RegExp('^[a-z][a-z0-9+.-]*:').hasMatch(target)) continue;
        final hash = target.indexOf('#');
        final path = hash < 0 ? target : target.substring(0, hash);
        final fragment = hash < 0 ? '' : _decode(target.substring(hash + 1));
        if (fragment.isEmpty) continue;
        final dest = path.isEmpty
            ? file
            : File.fromUri(file.absolute.uri.resolve(path));
        if (!dest.path.endsWith('.md') || !dest.existsSync()) continue;
        checked++;
        if (!anchorsFor(dest).contains(fragment.toLowerCase())) {
          stderr.writeln(
            '${file.path}:${line.key} : ancre « #$fragment » introuvable '
            'dans ${dest.path}.',
          );
          broken++;
        }
      }
    }
  }
  if (broken > 0) exit(1);
  stdout.writeln(
    'liens OK : $checked ancres vérifiées dans ${files.length} fichiers.',
  );
}
