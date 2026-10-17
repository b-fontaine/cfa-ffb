import 'package:billard_cfa/entities/run_progress/domain/run_progress_key.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter/foundation.dart';

/// Clé d'une séance guidée : la séance du catalogue, le public demandé
/// (`null` : celui de la séance planifiée, sinon les enfants) et la séance
/// planifiée éventuelle, plus le groupe pour lequel le guide est lancé depuis
/// la séance suggérée (ADR 0009). Deux guidages de même clé partagent leur
/// état.
@immutable
final class RunKey {
  const RunKey({
    required this.sheetId,
    this.audience,
    this.sessionId,
    this.group,
  });

  /// La clé relue d'une progression enregistrée (reprise au démarrage).
  RunKey.fromProgress(RunProgressKey key)
    : sheetId = key.sheetId,
      audience = key.audience,
      sessionId = key.sessionId,
      group = key.groupId;

  final SheetId sheetId;
  final Audience? audience;
  final String? sessionId;
  final GroupId? group;

  /// La même identité sous sa forme persistable (ADR 0020).
  RunProgressKey get progressKey => RunProgressKey(
    sheetId: sheetId,
    audience: audience,
    sessionId: sessionId,
    groupId: group,
  );

  @override
  bool operator ==(Object other) =>
      other is RunKey &&
      other.sheetId == sheetId &&
      other.audience == audience &&
      other.sessionId == sessionId &&
      other.group == group;

  @override
  int get hashCode => Object.hash(sheetId, audience, sessionId, group);
}
