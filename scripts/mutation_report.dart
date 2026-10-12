// Fusionne les rapports `mutation_test` des workers parallèles et applique le
// seuil global.
//
// Usage : dart run scripts/mutation_report.dart <seuil %> <dossier-rapport> [total attendu]
//
// Lit `<dossier>/part-*/mutation-test-report.{md,xml}` (format `-f all`),
// écrit `<dossier>/summary.md` et affiche le score global ainsi que chaque
// mutant non détecté (fichier, ligne, mutation). Code de sortie 1 sous le
// seuil, 2 si aucun rapport n'est lisible ou si le total diffère du total
// attendu (mutants énumérés avant la répartition : aucun ne doit être perdu).
import 'dart:io';

/// Un mutant que la suite de tests n'a pas détecté.
class UndetectedMutant {
  const UndetectedMutant(this.file, this.line, this.original, this.mutated);

  final String file;
  final int line;
  final String original;
  final String mutated;

  @override
  String toString() => '$file:$line  - ${original.trim()}  + ${mutated.trim()}';
}

/// Résultat agrégé d'un ou plusieurs workers.
class MutationSummary {
  const MutationSummary(this.total, this.mutants);

  final int total;
  final List<UndetectedMutant> mutants;

  int get undetected => mutants.length;
  int get detected => total - undetected;

  /// Score de détection en pourcentage (100 si aucune mutation).
  double get score => total == 0 ? 100 : detected * 100 / total;
}

String _unescapeXml(String value) => value
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

/// Analyse un rapport markdown (totaux) et son pendant XML (mutants non
/// détectés) produits par `mutation_test -f all`.
MutationSummary parsePart({required String markdown, required String xml}) {
  final totalMatch = RegExp(
    r'^\|\s*Mutations\s*\|\s*(\d+)',
    multiLine: true,
  ).firstMatch(markdown);
  if (totalMatch == null) {
    throw const FormatException('Rapport markdown sans ligne « Mutations ».');
  }
  final mutants = <UndetectedMutant>[];
  final files = RegExp(r'<file name="([^"]+)">(.*?)</file>', dotAll: true);
  final mutations = RegExp(
    r'<mutation line="(\d+)">\s*<original>(.*?)</original>\s*'
    r'<modified>(.*?)</modified>',
    dotAll: true,
  );
  for (final file in files.allMatches(xml)) {
    for (final m in mutations.allMatches(file.group(2)!)) {
      mutants.add(
        UndetectedMutant(
          file.group(1)!,
          int.parse(m.group(1)!),
          _unescapeXml(m.group(2)!),
          _unescapeXml(m.group(3)!),
        ),
      );
    }
  }
  return MutationSummary(int.parse(totalMatch.group(1)!), mutants);
}

/// Additionne plusieurs parties.
MutationSummary merge(Iterable<MutationSummary> parts) => MutationSummary(
  parts.fold(0, (sum, p) => sum + p.total),
  [for (final p in parts) ...p.mutants]..sort(
    (a, b) =>
        a.file != b.file ? a.file.compareTo(b.file) : a.line.compareTo(b.line),
  ),
);

/// Message d'erreur si les workers n'ont pas testé exactement les mutants
/// attendus (null si tout est cohérent).
String? totalMismatch(MutationSummary summary, int expected) =>
    summary.total == expected
    ? null
    : 'Mutants testés (${summary.total}) != mutants attendus ($expected).';

/// Rendu markdown du résumé global.
String render(MutationSummary summary, {required num threshold}) {
  final buffer = StringBuffer()
    ..writeln('# Mutation testing')
    ..writeln()
    ..writeln('- Mutations : ${summary.total}')
    ..writeln('- Détectées : ${summary.detected}')
    ..writeln('- Non détectées : ${summary.undetected}')
    ..writeln('- Score : ${summary.score.toStringAsFixed(1)} %')
    ..writeln('- Seuil : $threshold %');
  if (summary.mutants.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('## Mutants non détectés')
      ..writeln();
    for (final mutant in summary.mutants) {
      buffer.writeln(
        '- `${mutant.file}:${mutant.line}` — '
        '`${mutant.original.trim()}` -> `${mutant.mutated.trim()}`',
      );
    }
  }
  return buffer.toString();
}

void main(List<String> args) {
  if (args.length < 2 || args.length > 3) {
    stderr.writeln(
      'Usage : dart run scripts/mutation_report.dart <seuil %> <dossier> [total]',
    );
    exit(2);
  }
  final threshold = num.parse(args[0]);
  final dir = Directory(args[1]);
  final parts = <MutationSummary>[];
  final partDirs =
      dir
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.split('/').last.startsWith('part-'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final part in partDirs) {
    final md = File('${part.path}/mutation-test-report.md');
    final xml = File('${part.path}/mutation-test-report.xml');
    if (!md.existsSync() || !xml.existsSync()) {
      stderr.writeln('Rapport absent ou incomplet : ${part.path}');
      exit(2);
    }
    parts.add(
      parsePart(markdown: md.readAsStringSync(), xml: xml.readAsStringSync()),
    );
  }
  if (parts.isEmpty) {
    stderr.writeln('Aucun rapport part-* dans ${dir.path}.');
    exit(2);
  }
  final summary = merge(parts);
  if (args.length == 3) {
    final mismatch = totalMismatch(summary, int.parse(args[2]));
    if (mismatch != null) {
      stderr.writeln(mismatch);
      exit(2);
    }
  }
  final text = render(summary, threshold: threshold);
  File('${dir.path}/summary.md').writeAsStringSync(text);
  stdout.write(text);
  if (summary.score < threshold) {
    stderr.writeln(
      'Mutation : score ${summary.score.toStringAsFixed(1)} % < $threshold %.',
    );
    exit(1);
  }
}
