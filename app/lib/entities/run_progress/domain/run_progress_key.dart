import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'run_progress_key.freezed.dart';

/// Identité d'une séance guidée en cours, sous une forme persistable
/// (équivalent de `RunKey`, qui vit dans la présentation du guide) : la
/// séance du catalogue, le public demandé, la séance planifiée éventuelle et
/// le groupe pour lequel le guide est lancé.
@freezed
abstract class RunProgressKey with _$RunProgressKey {
  const factory RunProgressKey({
    required SheetId sheetId,
    Audience? audience,
    String? sessionId,
    GroupId? groupId,
  }) = _RunProgressKey;

  const RunProgressKey._();

  /// Forme texte stable et injective : `séance|public|séance planifiée|groupe`.
  ///
  /// La séance du catalogue (un slug) et le public (un nom d'énumération) ne
  /// contiennent jamais `|`. Les deux identifiants libres sont vides quand ils
  /// sont absents, sinon préfixés `v:` et échappés (le séparateur ne peut donc
  /// jamais en faire partie, et une chaîne vide se distingue d'une absence) :
  /// deux clés différentes n'ont jamais le même texte.
  String get encoded => [
    sheetId.value,
    audience?.name ?? '',
    _part(sessionId),
    _part(groupId?.value),
  ].join('|');

  static String _part(String? value) =>
      value == null ? '' : 'v:${Uri.encodeComponent(value)}';
}
