import 'package:billard_cfa/entities/membership/domain/own_link.dart';
import 'package:billard_cfa/entities/membership/domain/own_link_source.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';
import 'package:injectable/injectable.dart';

/// Le `member` du compte lu dans `clubs/{club}/members/{uid}` (une lecture).
/// Les règles ne laissent à un compte que **ce** document ; pour un parent ou
/// un élève, le supprimer retire aussi toute lecture des données de la fiche.
@LazySingleton(as: OwnLinkSource)
class StoreOwnLinkSource implements OwnLinkSource {
  StoreOwnLinkSource(this._club, this._user);

  final ClubStore _club;
  final CurrentUser _user;

  @override
  Future<OwnLink?> read() async {
    final path = _path();
    try {
      return _decode((await _club.get(path))?.fields);
    } on StoreFailure catch (failure) {
      // Une règle refuse de lire un document qui n'existe plus : accès retiré.
      if (failure.code == StoreFailureCode.permissionDenied) return null;
      throw serviceFailureOf(failure);
    }
  }

  @override
  Stream<OwnLink?> watch() => guardStoreStream(
    () => _club.watchDocument(_path()).map((u) => _decode(u.document?.fields)),
  );

  String _path() {
    final user = _user.id;
    if (user == null) {
      throw const ServiceFailure(ServiceFailureCode.denied, 'no-user');
    }
    return _club.paths.member(user);
  }

  static OwnLink? _decode(Fields? fields) {
    if (fields == null) return null;
    final role = Role.tryParse(fields['role'] as String?);
    if (role == null) return null;
    return OwnLink(
      role: role,
      studentIds: _ids(fields['studentIds'], StudentId.new),
      groupIds: _ids(fields['groupIds'], GroupId.new),
    );
  }

  static Set<T> _ids<T>(Object? raw, T Function(String) make) => {
    if (raw is List<Object?>)
      for (final item in raw)
        if (item is String && item.isNotEmpty) make(item),
  };
}
