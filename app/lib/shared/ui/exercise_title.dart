import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';

/// Titre localisé « bloc · exercice n ». Pour une proposition `[Prop]`, le
/// titre porte la mention « Proposition » : un exercice non fédéral n'est
/// jamais présenté comme tel.
String exerciseTitle(
  AppLocalizations l10n, {
  required String blockTitle,
  required int number,
  bool proposal = false,
}) {
  final title = l10n.sheetExerciseTitle(blockTitle, number);
  return proposal ? l10n.proposalTagged(title) : title;
}
