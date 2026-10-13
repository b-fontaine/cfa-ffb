import 'model.dart';

/// Une ligne de synthèse par diagramme.
String summaryLine(Json d) {
  final counts = <String, int>{};
  for (final b in mapsOf(d, 'balls')) {
    counts.update('${b['color']}', (n) => n + 1, ifAbsent: () => 1);
  }
  final balls = counts.isEmpty
      ? '-'
      : counts.entries.map((e) => '${e.key}=${e.value}').join(',');
  final rate = d['success_rate'];
  final uncertainties = d['uncertainties'];
  return [
    '${d['id']}',
    '${d['kind']}',
    'billes: $balls',
    'fleches=${mapsOf(d, 'arrows').length}',
    'reussite=${rate is List ? rate.join('/') : '-'}',
    'chevalet=${d['bridge'] ?? '-'}',
    'incertitudes=${uncertainties is List ? uncertainties.length : 0}',
  ].join(' | ');
}
