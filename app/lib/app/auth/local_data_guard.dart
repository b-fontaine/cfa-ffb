import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:billard_cfa/shared/lib/send_status.dart';
import 'package:billard_cfa/shared/persistence/local_data_cache.dart';
import 'package:injectable/injectable.dart';

/// Garde du **cache local** des données du club (ADR 0024, décision 1 et C4) :
/// il contient des données d'élèves mineurs et reste sur l'appareil, donc :
///
/// - il appartient à **un compte** à la fois : le compte est consigné sur
///   l'appareil avant tout accès aux données ([claim]) ; si un **autre** compte
///   se connecte, le cache de l'ancien est vidé **avant** qu'il lise quoi que
///   ce soit (le SDK sert ses requêtes depuis le cache, sans distinguer les
///   comptes) ;
/// - il est vidé à la **déconnexion** voulue ([release]) ; si l'effacement
///   **échoue** (autre onglet qui tient la base, disque), un repère
///   « effacement en attente » reste consigné sur l'appareil (sans donnée
///   personnelle) : l'effacement est retenté au démarrage suivant
///   ([settleErasure]) et, de toute façon, avant que **n'importe quel**
///   compte (le même compris) lise quoi que ce soit ([claim]) ;
/// - il n'est **pas** vidé quand la session se perd autrement (jeton révoqué,
///   déconnexion dans un autre onglet) : des écritures hors ligne pourraient
///   s'y trouver ; le même compte les retrouve, un autre compte déclenche
///   l'effacement. Choix assumé et écrit (hors-ligne-plan.md).
///
/// Une déconnexion avec des **envois en attente** les perdrait :
/// [hasUnsentWrites] permet de le demander à l'utilisateur d'abord.
@LazySingleton()
class LocalDataGuard {
  LocalDataGuard(LocalDataCache cache, KeyValueStore store, SendStatus sends)
    : this.withTiming(cache, store, sends);

  /// Délais réglables (les tests les raccourcissent) : un constructeur à
  /// part, pour que l'injection n'ait que le constructeur principal à
  /// résoudre.
  LocalDataGuard.withTiming(
    this._cache,
    this._store,
    this._sends, {
    this.clearedElsewhereWithin = const Duration(seconds: 8),
    this.pollEvery = const Duration(milliseconds: 400),
  });

  /// Combien de temps attendre qu'un autre onglet finisse de vider le cache
  /// ([clearedElsewhere]) : sa session se ferme **avant** son effacement
  /// (borné à 5 s), qui consigne ensuite la disparition du propriétaire.
  final Duration clearedElsewhereWithin;

  /// Intervalle de la lecture du propriétaire pendant cette attente.
  final Duration pollEvery;

  /// Clé du compte propriétaire du cache (valeur : son identifiant, rien de
  /// plus ; retirée quand le cache est vidé).
  static const ownerKey = 'firestore_cache_owner';

  /// Repère « effacement en attente » : posé avant l'effacement d'une
  /// déconnexion, retiré quand il a réussi. Sa valeur est une constante : le
  /// repère ne nomme personne.
  static const erasurePendingKey = 'firestore_cache_erase_pending';

  final LocalDataCache _cache;
  final KeyValueStore _store;
  final SendStatus _sends;

  /// Des écritures validées localement attendent encore le serveur : la
  /// réponse vient du SDK (sa file survit au redémarrage), pas du seul
  /// compteur de la vie courante de la page.
  Future<bool> hasUnsentWrites() => _sends.hasUnsentWrites();

  /// Consigne [user] comme propriétaire du cache. Si le cache était celui
  /// d'un **autre** compte, ou si un effacement était **en attente**, il est
  /// d'abord vidé ; rend `true` dans ce cas (l'appelant remet alors le stock
  /// en service avec [reopen]). Un échec d'effacement **lève** : aucune donnée
  /// ne doit être servie au nouveau compte.
  Future<bool> claim(String user) async {
    final owner = await _store.read(ownerKey);
    final pending = await erasurePending();
    if (owner == user && !pending) return false;
    final clear = owner != null || pending;
    if (clear) await _clearAndForget();
    await _store.write(ownerKey, user);
    return clear;
  }

  /// Un effacement demandé par une déconnexion n'a pas abouti.
  Future<bool> erasurePending() async =>
      await _store.read(erasurePendingKey) != null;

  /// Vide le cache (déconnexion voulue) et oublie son propriétaire. Le repère
  /// « effacement en attente » est posé **avant** : un échec **lève** et le
  /// laisse, avec le propriétaire consigné, pour que le démarrage suivant (ou
  /// un autre compte) retente l'effacement.
  Future<void> release() async {
    if (await _store.read(ownerKey) == null && !await erasurePending()) return;
    await _store.write(erasurePendingKey, '1');
    await _clearAndForget();
  }

  /// Retente un effacement resté en attente (démarrage, « Réessayer
  /// l'effacement »). `true` si le cache a été vidé (l'appelant le remet en
  /// service avec [reopen]), `false` s'il n'y avait rien à faire ; un nouvel
  /// échec **lève**, le repère restant.
  Future<bool> settleErasure() async {
    if (!await erasurePending()) return false;
    await _clearAndForget();
    return true;
  }

  Future<void> _clearAndForget() async {
    await _cache.clear();
    await _store.remove(ownerKey);
    await _store.remove(erasurePendingKey);
  }

  /// Un **autre onglet** vide le cache (sa déconnexion) : la clé du
  /// propriétaire disparaît alors que cet onglet croyait encore le posséder.
  /// L'instance Firestore de cet onglet est terminée et ne se rouvre que par
  /// un rechargement ([reopen]). La session se ferme avant l'effacement : on
  /// attend jusqu'à [clearedElsewhereWithin] que la clé disparaisse ; [stop]
  /// interrompt l'attente (l'utilisateur s'est reconnecté entre-temps).
  /// `false` si la clé reste (jeton révoqué : le cache garde ses écritures).
  Future<bool> clearedElsewhere({bool Function()? stop}) async {
    final deadline = DateTime.now().add(clearedElsewhereWithin);
    while (true) {
      if (stop?.call() ?? false) return false;
      final forgotten = await _store.read(ownerKey) == null;
      // Revenu pendant la lecture : la disparition du propriétaire n'est plus
      // celle de la session que l'on attendait.
      if (stop?.call() ?? false) return false;
      if (forgotten) return true;
      if (DateTime.now().isAfter(deadline)) return false;
      await Future<void>.delayed(pollEvery);
    }
  }

  /// Remet le stock de documents en service après un effacement.
  Future<void> reopen() => _cache.reopen();
}
