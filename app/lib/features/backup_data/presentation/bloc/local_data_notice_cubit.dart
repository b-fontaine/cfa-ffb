import 'package:billard_cfa/features/backup_data/domain/local_data_probe.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:billard_cfa/shared/lib/local_data_inventory.dart';
import 'package:billard_cfa/shared/lib/send_status.dart';
import 'package:billard_cfa/shared/lib/sha256.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'local_data_notice_cubit.freezed.dart';
part 'local_data_notice_state.dart';

/// Le bandeau « Des données de cet appareil n'ont pas encore été exportées »
/// et l'entrée d'export (FB7c). Un seul exemplaire pour toute l'application :
/// le bandeau, « Plus » et les écrans sans compte lisent le même état.
///
/// Le repère « J'ai importé mes données » est **propre à un compte sur
/// l'appareil** : sur un appareil partagé, l'enseignant A n'importe que ses
/// groupes (il n'écrit que dans les siens), et son repère ne masque pas le
/// bandeau pour l'enseignant B. Il est aussi **lié au contenu** relevé quand
/// il a été posé : des données ajoutées depuis (ancien onglet resté ouvert,
/// autre usage) font revenir le rappel. Clé et valeur sans donnée
/// personnelle : un hachage de l'identifiant du compte, des compteurs. Aucune
/// donnée locale n'est supprimée, ni ici ni ailleurs dans ce lot.
@lazySingleton
class LocalDataNoticeCubit extends Cubit<LocalDataNoticeState> {
  LocalDataNoticeCubit(this._probe, this._store, this._sends)
    : super(const LocalDataNoticeState());

  /// Empreinte du relevé : l'état, la version, tous les compteurs et la date
  /// de dernière modification des données.
  static String _fingerprint(LocalDataInventory i) {
    final c = i.counts;
    return [
      i.state.name,
      i.schemaVersion,
      c.students,
      c.groups,
      c.seasons,
      c.sessionRecords,
      c.attempts,
      c.plannedSessions,
      c.assessments,
      c.blockAcquisitions,
      c.seasonArchives,
      i.lastModified?.millisecondsSinceEpoch ?? 0,
    ].join(':');
  }

  /// Début de la clé du repère « importé dans le club » ; la clé complète est
  /// celle d'un compte ([acknowledgedKeyFor]).
  static const acknowledgedKeyPrefix = 'local_data_imported_in_club';

  /// Clé du repère d'un compte : un hachage de son identifiant (jamais
  /// l'identifiant lui-même ni une adresse). La valeur est l'empreinte du
  /// relevé.
  static String acknowledgedKeyFor(String account) =>
      '$acknowledgedKeyPrefix.${sha256Hex(account).substring(0, 16)}';

  final LocalDataProbe _probe;
  final KeyValueStore _store;
  final SendStatus _sends;
  bool _loading = false;
  String? _account;

  /// Lit le relevé (une fois) et le repère de [account], le compte connecté
  /// (`null` sans session : le bandeau est alors toujours visible s'il y a
  /// des données). Rappelé quand le compte change : le repère de l'autre
  /// compte est relu. Une lecture qui échoue laisse le bandeau visible si des
  /// données existent (jamais masqué par erreur).
  Future<void> load({String? account}) async {
    _account = account;
    if (_loading) return;
    if (state.loaded) {
      await _readAcknowledgement(state.inventory);
      return;
    }
    _loading = true;
    var inventory = const LocalDataInventory(state: LocalStoreState.unreadable);
    try {
      inventory = await _probe.inspect();
    } on Object {
      // Un relevé qui échoue reste « illisible » : jamais « rien à protéger ».
    } finally {
      _loading = false;
    }
    await _readAcknowledgement(inventory);
  }

  Future<void> _readAcknowledgement(LocalDataInventory inventory) async {
    final account = _account;
    var acknowledged = false;
    if (account != null) {
      try {
        acknowledged =
            await _store.read(acknowledgedKeyFor(account)) ==
            _fingerprint(inventory);
      } on Object {
        // Un repère illisible n'est pas un repère.
      }
    }
    if (isClosed) return;
    // Le compte a pu changer pendant la lecture : la dernière demande gagne.
    if (account != _account) {
      await _readAcknowledgement(inventory);
      return;
    }
    emit(
      LocalDataNoticeState(
        loaded: true,
        inventory: inventory,
        acknowledged: acknowledged,
      ),
    );
  }

  /// « J'ai importé mes données dans le club » : masque le bandeau pour le
  /// compte connecté, sur cet appareil. L'export reste disponible. Rend
  /// `false`, sans rien consigner, si le SDK garde des écritures **non
  /// envoyées** : un import fait hors ligne n'est pas encore au club, et une
  /// déconnexion qui vide le cache le perdrait. Sans compte, rien n'est
  /// consigné non plus. Refusé aussi quand la base n'est **pas lisible**
  /// (illisible, ou écrite par une version plus récente) : son empreinte est
  /// constante, un repère posé sur elle masquerait le bandeau à chaque
  /// démarrage illisible suivant, alors qu'aucun compteur n'a jamais été
  /// connu.
  Future<bool> acknowledge() async {
    final account = _account;
    if (account == null) return false;
    if (!state.inventory.isReadable) return false;
    if (await _sends.hasUnsentWrites()) return false;
    await _store.write(
      acknowledgedKeyFor(account),
      _fingerprint(state.inventory),
    );
    if (isClosed || account != _account) return true;
    emit(state.copyWith(acknowledged: true));
    return true;
  }
}
