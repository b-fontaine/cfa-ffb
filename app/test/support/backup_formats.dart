/// Retire les étiquettes de la note de jeu (`sessionRecords[].tags`, format 5,
/// ADR 0023) du bloc `data` d'une sauvegarde : ce qu'un fichier des formats 1
/// à 4 contient.
void dropSessionTags(Map<String, Object?> data) {
  for (final record in data['sessionRecords']! as List<Object?>) {
    (record! as Map<String, Object?>).remove('tags');
  }
}
