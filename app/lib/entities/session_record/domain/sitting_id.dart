import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';

/// Identifiant **déterministe** d'une saisie liée à une séance du catalogue
/// (ADR 0016 amendé par l'ADR 0024, décision 18) : le groupe, le jour (l'heure
/// est ignorée) et la séance du catalogue, `groupe_AAAAMMJJ_séance`. Deux
/// appareils qui ouvrent la même séance le même jour écrivent le même
/// document au lieu d'en créer deux. Une saisie libre (sans séance du
/// catalogue) garde un identifiant généré (UUID).
///
/// L'identifiant est cité par les passages (`sessionId`) : les règles le
/// bornent à `maxSessionReferenceLength` ; au-delà, `sessionReferenceTooLong`.
SessionId sittingId(GroupId group, DateTime date, SheetId sheet) {
  String two(int n) => n.toString().padLeft(2, '0');
  final day =
      '${date.year.toString().padLeft(4, '0')}${two(date.month)}'
      '${two(date.day)}';
  final id = '${group.value}_${day}_${sheet.value}';
  if (id.length > maxSessionReferenceLength) {
    throw const InvariantViolation(InvariantCode.sessionReferenceTooLong);
  }
  return SessionId(id);
}
