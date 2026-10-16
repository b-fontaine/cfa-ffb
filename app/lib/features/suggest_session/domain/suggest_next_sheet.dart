import 'package:billard_cfa/features/suggest_session/domain/next_sheet.dart';
import 'package:billard_cfa/features/suggest_session/domain/session_plan.dart';
import 'package:billard_cfa/features/suggest_session/domain/suggest_session.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : la séance du catalogue à donner ensuite à un groupe, avec la
/// règle de la séance suggérée (ADR 0009) telle quelle : elle délègue à
/// [SuggestSession] (qui lit groupe, passages, acquis et catalogue pour
/// construire le plan complet) et n'en garde que le public, la notion
/// principale et la séance proposée, sans les exercices ni les phases.
@injectable
class SuggestNextSheet {
  SuggestNextSheet(this._suggest);

  final SuggestSession _suggest;

  Future<Result<NextSheet>> call({
    required GroupId groupId,
    required Set<StudentId> present,
  }) => runGuarded(() async {
    final plan = _unwrap(
      await _suggest(groupId: groupId, expectedStudents: present),
    );
    return NextSheet(
      audience: plan.audience,
      mainBlockId: plan.mainBlockId,
      sheet: plan.sheet,
    );
  });

  /// Rend la valeur d'un succès ou relève l'échec : [runGuarded] le convertit
  /// de nouveau en résultat.
  static SessionPlan _unwrap(Result<SessionPlan> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
}
