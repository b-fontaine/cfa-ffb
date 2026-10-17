import 'dart:async';

import 'package:billard_cfa/app/auth/auth_cubit.dart';
import 'package:flutter/foundation.dart';

/// Fait réévaluer la redirection du routeur à chaque changement d'état de la
/// session.
class AuthRefresh extends ChangeNotifier {
  AuthRefresh(AuthCubit cubit) {
    _subscription = cubit.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
