import 'package:billard_cfa/entities/invitation/domain/invitation.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_failure.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_repository.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';
import 'package:injectable/injectable.dart';

/// Invitations dans le stock de documents (`invitations/{code}`, à la racine :
/// l'invité ne connaît que le code, pas le club) et acceptation par lot.
///
/// L'acceptation écrit **dans un seul lot** le `member` du compte et la
/// consommation de l'invitation : les règles (`getAfter` / `existsAfter`)
/// refusent chaque écriture seule. Budget de lectures des règles par
/// écriture : au plus 4 accès (voir `docs/engineering/clubs-roles-plan.md`).
@LazySingleton(as: InvitationRepository)
class StoreInvitationRepository implements InvitationRepository {
  StoreInvitationRepository(this._store, this._clock);

  final DocumentStore _store;
  final Clock _clock;

  static String pathOf(InvitationCode code) => 'invitations/${code.value}';

  @override
  Future<void> create(Invitation invitation) => guardStore(
    () => _store.commit([
      SetOp(pathOf(invitation.code), {
        'clubId': invitation.clubId.value,
        'role': invitation.role.name,
        'groupIds': [for (final id in invitation.groupIds) id.value],
        'studentIds': [for (final id in invitation.studentIds) id.value],
        'createdBy': invitation.createdBy.value,
        'createdAt': serverTimestamp,
        'expiresAt': invitation.expiresAt,
        'used': false,
      }),
    ]),
  );

  @override
  Future<Invitation?> find(InvitationCode code) => guardStore(() async {
    final document = await _store.get(pathOf(code));
    return document == null ? null : _invitation(code, document.fields);
  });

  @override
  Future<void> revoke(InvitationCode code) =>
      guardStore(() => _store.commit([DeleteOp(pathOf(code))]));

  @override
  Future<void> accept({
    required InvitationCode code,
    required UserId user,
    required String displayName,
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) {
      throw const InvariantViolation(InvariantCode.nameRequired);
    }
    if (name.length > maxDisplayNameLength) {
      throw const InvariantViolation(InvariantCode.nameTooLong);
    }
    final invitation = await find(code);
    if (invitation == null) {
      throw const InvitationFailure(InvitationFailureCode.notFound);
    }
    switch (invitation.statusAt(_clock.now())) {
      case InvitationStatus.used:
        throw const InvitationFailure(InvitationFailureCode.used);
      case InvitationStatus.expired:
        throw const InvitationFailure(InvitationFailureCode.expired);
      case InvitationStatus.waiting:
        break;
    }
    try {
      await _store.commit([
        SetOp('clubs/${invitation.clubId.value}/members/${user.value}', {
          'uid': user.value,
          'role': invitation.role.name,
          'groupIds': [for (final id in invitation.groupIds) id.value],
          'studentIds': [for (final id in invitation.studentIds) id.value],
          'displayName': name,
          'invitationCode': code.value,
          'createdAt': serverTimestamp,
        }),
        UpdateOp(pathOf(code), {
          'used': true,
          'usedBy': user.value,
          'usedAt': serverTimestamp,
        }),
      ]);
    } on StoreFailure catch (failure) {
      throw switch (failure.code) {
        // Les règles refusent : invitation consommée entre-temps, expirée pour
        // l'horloge du serveur, ou compte déjà membre de ce club.
        StoreFailureCode.permissionDenied => const InvitationFailure(
          InvitationFailureCode.refused,
        ),
        StoreFailureCode.notFound => const InvitationFailure(
          InvitationFailureCode.notFound,
        ),
        StoreFailureCode.unavailable => ServiceFailure(
          ServiceFailureCode.unavailable,
          failure.detail,
        ),
        StoreFailureCode.unsupported => ServiceFailure(
          ServiceFailureCode.unsupported,
          failure.detail,
        ),
        StoreFailureCode.failedPrecondition ||
        StoreFailureCode.batchTooLarge ||
        StoreFailureCode.other => ServiceFailure(
          ServiceFailureCode.other,
          failure.detail,
        ),
      };
    }
  }

  /// Un document illisible est ignoré (`null`), jamais fatal.
  static Invitation? _invitation(InvitationCode code, Fields fields) {
    final role = Role.tryParse(fields['role'] as String?);
    final club = fields['clubId'];
    final by = fields['createdBy'];
    final created = fields['createdAt'];
    final expires = fields['expiresAt'];
    if (role == null ||
        club is! String ||
        by is! String ||
        created is! DateTime ||
        expires is! DateTime) {
      return null;
    }
    try {
      return Invitation(
        code: code,
        clubId: ClubId(club),
        role: role,
        createdBy: UserId(by),
        createdAt: created,
        expiresAt: expires,
        groupIds: _ids(fields['groupIds'], GroupId.new),
        studentIds: _ids(fields['studentIds'], StudentId.new),
        used: fields['used'] == true,
        usedBy: fields['usedBy'] is String
            ? UserId(fields['usedBy']! as String)
            : null,
      );
    } on InvariantViolation {
      return null;
    }
  }

  static List<T> _ids<T>(Object? raw, T Function(String) make) => [
    if (raw is List<Object?>)
      for (final item in raw)
        if (item is String && item.isNotEmpty) make(item),
  ];
}
