import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter/foundation.dart';

/// Clé d'une séance guidée : la séance du catalogue, le public demandé
/// (`null` : celui de la séance planifiée, sinon les enfants) et la séance
/// planifiée éventuelle. Deux guidages de même clé partagent leur état.
@immutable
final class RunKey {
  const RunKey({required this.sheetId, this.audience, this.sessionId});

  final SheetId sheetId;
  final Audience? audience;
  final String? sessionId;

  @override
  bool operator ==(Object other) =>
      other is RunKey &&
      other.sheetId == sheetId &&
      other.audience == audience &&
      other.sessionId == sessionId;

  @override
  int get hashCode => Object.hash(sheetId, audience, sessionId);
}
