import 'dart:convert';

import 'package:billard_cfa/features/backup_data/domain/backup_decoder.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_encoder.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:injectable/injectable.dart';

/// Format de sauvegarde JSON versionné, indépendant du schéma SQL (ADR 0001).
///
/// Racine : `{ "format", "schemaVersion", "exportedAt", "data": { … } }`.
/// Toute lecture est stricte : la moindre incohérence lève une
/// `InvariantViolation` (`backupUnreadable`, `backupVersionUnsupported`,
/// `backupInvalid`, `backupInconsistent`) avant la moindre écriture.
@lazySingleton
class BackupCodec {
  /// Identifie un fichier de sauvegarde de l'application.
  static const format = 'billard-cfa-backup';

  /// Version du format écrite par [encode] ; propre au format JSON.
  static const currentVersion = 3;

  /// Taille maximale (en caractères) d'un fichier lu : au-delà, ce n'est pas
  /// une sauvegarde d'un club (plusieurs saisons tiennent en quelques Mo).
  static const int maxContentLength = 10 * 1024 * 1024;

  /// Profondeur maximale d'imbrication JSON (le format réel en compte 6).
  static const maxDepth = 12;

  /// Versions que [decode] sait lire.
  static const supportedVersions = {1, 2, 3};

  String encode(BackupSnapshot snapshot, {required DateTime exportedAt}) {
    final document = <String, Object?>{
      'format': format,
      'schemaVersion': currentVersion,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'data': const BackupEncoder().encode(snapshot),
    };
    return const JsonEncoder.withIndent('  ').convert(document);
  }

  /// Lit et valide une sauvegarde ; aucune écriture n'a lieu ici.
  BackupSnapshot decode(String content) {
    if (content.length > maxContentLength || _tooDeep(content)) {
      throw const InvariantViolation(InvariantCode.backupUnreadable);
    }
    final Object? parsed;
    try {
      parsed = jsonDecode(content);
    } on FormatException {
      throw const InvariantViolation(InvariantCode.backupUnreadable);
    }
    if (parsed is! Map<String, Object?> || parsed['format'] != format) {
      throw const InvariantViolation(InvariantCode.backupUnreadable);
    }
    final version = parsed['schemaVersion'];
    if (version is! int || !supportedVersions.contains(version)) {
      throw const InvariantViolation(InvariantCode.backupVersionUnsupported);
    }
    // Le format 2 ajoute les réglages du club (`data.settings`, ADR 0012), le
    // format 3 les acquittements d'alertes (`data.alertAcknowledgements`,
    // ADR 0013).
    return const BackupDecoder().decode(
      parsed['data'],
      withSettings: version >= 2,
      withAcknowledgements: version >= 3,
    );
  }

  /// Vrai si l'imbrication dépasse [maxDepth] ; les crochets et accolades des
  /// chaînes ne comptent pas. Évite de laisser `jsonDecode` descendre une
  /// pile récursive sur un fichier hostile.
  static bool _tooDeep(String content) {
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (final unit in content.codeUnits) {
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (unit == 0x5C) {
          escaped = true;
        } else if (unit == 0x22) {
          inString = false;
        }
      } else if (unit == 0x22) {
        inString = true;
      } else if (unit == 0x5B || unit == 0x7B) {
        if (++depth > maxDepth) return true;
      } else if (unit == 0x5D || unit == 0x7D) {
        depth--;
      }
    }
    return false;
  }
}
