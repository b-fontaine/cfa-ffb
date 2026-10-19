import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';

/// Port d'accès aux séances données (implémenté dans la couche data).
///
/// Même contrat que `StudentRepository` : ordre de première sauvegarde pour
/// [all], remplacement par id, suppression logique.
abstract interface class SessionRecordRepository {
  /// Écrit la séance **telle quelle** : les présents et les blocs remplacent
  /// ceux d'une saisie existante (import d'une sauvegarde).
  Future<void> save(SessionRecord session);

  /// Ouvre la saisie [candidate] : la **crée** si son identifiant est libre,
  /// sinon la **reprend** sans rien perdre (ses blocs, sa séance du catalogue
  /// et ses étiquettes restent, les présents de [candidate] s'y **ajoutent**).
  /// Deux appareils qui ouvrent en même temps la même saisie (identifiant
  /// déterministe, ADR 0024 décision 18) réussissent tous deux et convergent :
  /// la création est atomique, la réunion des présents ne relit ni ne réécrit
  /// la liste. Rend la saisie telle qu'enregistrée.
  Future<SessionRecord> open(SessionRecord candidate);

  /// Reprend une saisie existante (l'animateur revient sur sa saisie) : blocs
  /// et séance du catalogue de [record] remplacent les siens, ses présents
  /// **remplacent** ceux enregistrés (un élève coché par erreur se décoche),
  /// les étiquettes ne changent pas. Crée la saisie si elle n'existe plus.
  /// Rend la
  /// saisie telle qu'enregistrée. Seule l'ouverture concurrente ([open]) réunit
  /// les présents.
  Future<SessionRecord> resume(SessionRecord record);

  Future<SessionRecord?> byId(SessionId id);

  /// Séances d'un groupe, de la plus ancienne à la plus récente.
  Future<List<SessionRecord>> forGroup(GroupId groupId);

  /// Séances où l'élève était présent, de la plus ancienne à la plus récente.
  Future<List<SessionRecord>> forStudent(StudentId studentId);

  /// Les identifiants des séances où l'élève était présent, supprimées
  /// logiquement comprises (droit à l'effacement).
  Future<Set<SessionId>> idsEverPresent(StudentId studentId);

  Future<List<SessionRecord>> all();

  /// Remplace les étiquettes de la séance [id] et rien d'autre (présences,
  /// blocs et date restent) ; sans effet si elle n'existe pas ou a été
  /// supprimée.
  Future<void> setTags(SessionId id, Set<SessionTag> tags);

  /// Supprime logiquement la séance ; sans effet si elle n'existe pas.
  Future<void> delete(SessionId id);

  /// Efface physiquement la présence de l'élève dans toutes les séances
  /// (droit à l'effacement) ; les séances elles-mêmes restent.
  Future<void> eraseStudent(StudentId studentId);

  /// Suit les séances données d'un groupe (voir [forGroup] ; contrat des
  /// `watch…` : `StudentRepository.watchById`).
  Stream<List<SessionRecord>> watchForGroup(GroupId groupId);

  /// Suit les séances données où l'élève est présent (voir [forStudent]).
  Stream<List<SessionRecord>> watchForStudent(StudentId studentId);

  /// Suit la liste que renvoie [all].
  Stream<List<SessionRecord>> watchAll();
}
