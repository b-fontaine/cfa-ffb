import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/export_sheet/domain/exported_document.dart';
import 'package:billard_cfa/features/export_sheet/domain/layout_results_sheets.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_renderer.dart';
import 'package:billard_cfa/features/export_sheet/domain/results_sheets_input.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

export 'package:billard_cfa/features/export_sheet/domain/exported_document.dart';

/// Ce que l'animateur demande : les séries à imprimer (déjà mises en forme),
/// le nombre de colonnes et, **seulement s'il l'a choisi**, le groupe dont les
/// prénoms sont imprimés en tête des grilles.
@immutable
class ResultsSheetsRequest {
  const ResultsSheetsRequest({
    required this.title,
    required this.fileName,
    required this.series,
    required this.columns,
    required this.labels,
    this.groupId,
  });

  final String title;
  final String fileName;
  final List<ResultsSeries> series;
  final int columns;
  final ResultsLabels labels;

  /// Groupe dont les prénoms sont imprimés ; `null` : grilles sans nom, et
  /// aucun dépôt d'élèves n'est lu.
  final GroupId? groupId;
}

/// Cas d'usage : les fiches résultats en PDF (ADR 0021).
///
/// Sans groupe, aucune donnée d'élève n'est lue. Avec un groupe, seuls les
/// **prénoms** de ses membres du jour sont lus, dans l'ordre alphabétique
/// (sans tenir compte des accents), et jamais stockés. Groupe inconnu :
/// `NotFound('group', id)`.
@injectable
class ExportResultsSheets {
  ExportResultsSheets(
    this._renderer,
    this._groups,
    this._students,
    this._clock,
  );

  final PrintRenderer _renderer;
  final GroupRepository _groups;
  final StudentRepository _students;
  final Clock _clock;

  Future<Result<ExportedDocument>> call(ResultsSheetsRequest request) =>
      runGuarded(() async {
        final names = await _names(request.groupId);
        final session = await _renderer.open();
        final document = layoutResultsSheets(
          ResultsSheetsInput(
            title: request.title,
            series: request.series,
            names: names,
            columns: request.columns,
            labels: request.labels,
          ),
          session.measure,
        );
        return ExportedDocument(
          document: document,
          bytes: await session.render(document),
          fileName: request.fileName,
        );
      });

  Future<List<String>> _names(GroupId? groupId) async {
    if (groupId == null) return const [];
    final group = await _groups.byId(groupId);
    if (group == null) throw NotFound('group', groupId.value);
    final members = group.membersOn(_clock.today()).toSet();
    final names = [
      for (final student in await _students.all())
        if (members.contains(student.id)) student.firstName.trim(),
    ]..sort((a, b) => _key(a).compareTo(_key(b)));
    return names;
  }
}

const _accents = {
  'àâä': 'a',
  'ç': 'c',
  'èéêë': 'e',
  'îï': 'i',
  'ôö': 'o',
  'ùûü': 'u',
  'ÿ': 'y',
  'œ': 'oe',
};

/// Clé de tri d'un prénom : minuscules, accents ôtés.
String _key(String name) {
  final out = StringBuffer();
  for (final char in name.toLowerCase().split('')) {
    var mapped = char;
    for (final entry in _accents.entries) {
      if (entry.key.contains(char)) mapped = entry.value;
    }
    out.write(mapped);
  }
  return out.toString();
}
