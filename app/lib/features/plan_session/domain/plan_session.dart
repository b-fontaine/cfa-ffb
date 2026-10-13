import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/features/plan_session/domain/invalid_session_title.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : planifier une nouvelle séance, libre ou suivant une séance
/// du catalogue (`sheetId`).
@injectable
class PlanSession {
  PlanSession(this._repository, this._ids);

  final SessionRepository _repository;
  final IdGenerator _ids;

  Future<Session> call({
    required String title,
    required Audience audience,
    SheetId? sheetId,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw const InvalidSessionTitle();
    }
    final session = Session(
      id: _ids.next(),
      title: cleanTitle,
      audience: audience,
      sheetId: sheetId,
    );
    await _repository.add(session);
    return session;
  }
}
