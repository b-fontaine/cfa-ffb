// Contrôle que les tableaux du FORMAT.md (§ 1.2 techniques et parties,
// § 1.3 séances) sont égaux à la structure calculée depuis le catalogue.
import 'catalogue.dart';

String _range(List<int> n) =>
    n.length == 1 ? '${n.first}' : '${n.first}-${n.last}';

List<String> _cells(String line) {
  final parts = line.split('|');
  if (parts.length < 3) return const [];
  return [for (final c in parts.sublist(1, parts.length - 1)) c.trim()];
}

String _strip(String cell) =>
    cell.replaceAll('`', '').replaceAll('*', '').trim();

/// Erreurs `T1` : tableau périmé ou absent. [format] est le texte du
/// FORMAT.md.
List<String> checkFormatTables(String format, Structure structure) {
  final errors = <String>[];
  final lines = format.split('\n');

  // § 1.2 : lignes dont la 2e cellule est une technique.
  final slugs = {for (final s in techniqueSpecs) s.slug};
  final seen = <String>[];
  for (final line in lines) {
    final c = _cells(line);
    if (c.length < 9 || int.tryParse(c[0]) == null) continue;
    final slug = _strip(c[1]);
    if (!slugs.contains(slug)) continue;
    seen.add(slug);
    final slots = structure.slotsOf(slug);
    final spec = techniqueSpec(slug)!;
    final block = structure.blocks[spec.blockId];
    if (slots.isEmpty || block == null) continue;
    final numbers = [for (final s in slots) ...s.exercises];
    final expected = <String, String>{
      'Exercices': '${_range(numbers)} (${numbers.length})',
      'sessions': '${block.sessionsMin}-${block.sessionsMax}',
      'Parties': '${slots.length}',
      'Répartition': slots.map((s) => _range(s.exercises)).join(' / '),
    };
    final found = <String, String>{
      'Exercices': _strip(c[5]),
      'sessions': _strip(c[6]),
      'Parties': _strip(c[7]),
      'Répartition': _strip(c[8]),
    };
    for (final key in expected.keys) {
      if (expected[key] != found[key]) {
        errors.add(
          'T1 : § 1.2 $slug : colonne « $key » attendue '
          '« ${expected[key]} », trouvée « ${found[key]} »',
        );
      }
    }
  }
  if (seen.length != techniqueSpecs.length ||
      [for (final s in techniqueSpecs) s.slug].join(',') != seen.join(',')) {
    errors.add(
      'T1 : § 1.2 : tableau des techniques absent ou différent '
      '(${seen.length} lignes, ${techniqueSpecs.length} attendues)',
    );
  }

  // § 1.3 : lignes `| order | `id` | exercices | `previous` |`.
  final rows = <String, List<String>>{};
  for (final line in lines) {
    final c = _cells(line);
    if (c.length != 4) continue;
    final order = int.tryParse(c[0]);
    final id = _strip(c[1]);
    if (order == null || structure.slotById(id) == null) continue;
    rows[id] = [c[0], _strip(c[2]), _strip(c[3])];
  }
  for (final slot in structure.slots) {
    final row = rows[slot.id];
    if (row == null) {
      errors.add('T1 : § 1.3 ${slot.id} : ligne absente');
      continue;
    }
    final expected = [
      '${slot.order}',
      _range(slot.exercises),
      slot.previous ?? 'null',
    ];
    if (row.join('|') != expected.join('|')) {
      errors.add(
        'T1 : § 1.3 ${slot.id} : attendu ${expected.join(' / ')}, '
        'trouvé ${row.join(' / ')}',
      );
    }
  }
  return errors;
}
