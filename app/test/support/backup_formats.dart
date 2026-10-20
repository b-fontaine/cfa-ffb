import 'dart:convert';

/// Retire les étiquettes de la note de jeu (`sessionRecords[].tags`, format 5,
/// ADR 0023) du bloc `data` d'une sauvegarde : ce qu'un fichier des formats 1
/// à 4 contient.
void dropSessionTags(Map<String, Object?> data) {
  for (final record in data['sessionRecords']! as List<Object?>) {
    (record! as Map<String, Object?>).remove('tags');
  }
}

/// Le fichier [content] (format 5) tel qu'une version plus ancienne de
/// l'application l'aurait écrit : les clés qu'un format ne connaît pas sont
/// retirées et `schemaVersion` est celui du format (1 à 5).
///
/// - 5 : étiquettes de la note de jeu (`sessionRecords[].tags`, ADR 0023) ;
/// - 4 : archives de saison (`seasonArchives`, ADR 0019) ;
/// - 3 : acquittements (`alertAcknowledgements`, ADR 0013) ;
/// - 2 : réglages (`settings`, ADR 0012).
String backupAtVersion(String content, int version) {
  final document = jsonDecode(content) as Map<String, Object?>;
  final data = document['data']! as Map<String, Object?>;
  if (version < 5) dropSessionTags(data);
  if (version < 4) data.remove('seasonArchives');
  if (version < 3) data.remove('alertAcknowledgements');
  if (version < 2) data.remove('settings');
  document['schemaVersion'] = version;
  return const JsonEncoder.withIndent('  ').convert(document);
}
