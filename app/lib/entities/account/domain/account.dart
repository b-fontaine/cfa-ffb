import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'account.freezed.dart';

/// Un compte connecté : ce que l'application sait de lui, et rien d'autre
/// (ni nom, ni jeton, ni rôle : le rôle dépend du club, voir `membership`).
@freezed
abstract class Account with _$Account {
  const factory Account({
    required UserId id,
    required String email,

    /// L'adresse a été confirmée par le lien envoyé par le fournisseur
    /// d'authentification : exigé pour entrer (ADR 0024, décision 24).
    required bool emailVerified,
  }) = _Account;
}
