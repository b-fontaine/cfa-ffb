import 'package:billard_cfa/shared/lib/invitation_code.dart';

/// D'où viennent les codes d'invitation : le hasard cryptographique en
/// production, une suite prévisible dans les tests.
abstract interface class InvitationCodeSource {
  InvitationCode next();
}
