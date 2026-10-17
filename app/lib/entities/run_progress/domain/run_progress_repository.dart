import 'dart:async';

import 'package:billard_cfa/entities/run_progress/domain/run_progress.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_key.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_links.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Port d'accès aux séances guidées en cours (implémenté dans la couche data).
///
/// Une ligne par [RunProgressKey]. Donnée transitoire : **suppression
/// physique** uniquement (pas de suppression logique), jamais exportée.
abstract interface class RunProgressRepository {
  /// Enregistre [progress] ; remplace la ligne de même clé.
  Future<void> save(RunProgress progress);

  /// La progression de [key], `null` s'il n'y en a pas (ou si la ligne
  /// enregistrée est illisible : elle est alors supprimée).
  Future<RunProgress?> byKey(RunProgressKey key);

  /// Toutes les progressions lisibles, de la plus récemment modifiée à la
  /// plus ancienne ; les lignes illisibles sont supprimées au passage.
  Future<List<RunProgress>> all();

  /// Supprime la progression de [key] ; sans effet s'il n'y en a pas.
  Future<void> delete(RunProgressKey key);

  /// Les effacements par lien ([eraseLinked]), publiés **après** la
  /// suppression des lignes, pour que les séances gardées en mémoire soient
  /// libérées elles aussi. Flux de diffusion : rien n'est rejoué à qui
  /// s'abonne tard.
  Stream<RunProgressLinks> get erased;

  /// Efface les progressions liées à l'un des [groups], à l'une des [records]
  /// ou à l'une des séances planifiées [plannedSessions] (droit à l'effacement
  /// d'un élève, ADR 0020 § 7), puis publie ces liens sur [erased].
  Future<void> eraseLinked({
    Set<GroupId> groups = const {},
    Set<SessionId> records = const {},
    Set<String> plannedSessions = const {},
  });

  /// Efface les progressions modifiées **strictement avant** [limit] ;
  /// renvoie combien (péremption).
  Future<int> purgeOlderThan(DateTime limit);
}
