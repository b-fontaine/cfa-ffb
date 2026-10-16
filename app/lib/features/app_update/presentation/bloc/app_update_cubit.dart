import 'dart:async';

import 'package:billard_cfa/shared/lib/app_update_source.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'app_update_cubit.freezed.dart';

@freezed
abstract class AppUpdateState with _$AppUpdateState {
  const factory AppUpdateState({
    required bool available,
    @Default(false) bool dismissed,
  }) = _AppUpdateState;

  const AppUpdateState._();

  /// Vrai quand la bannière doit s'afficher : une version attend et
  /// l'utilisateur n'a pas répondu « Plus tard ».
  bool get visible => available && !dismissed;
}

/// État de la bannière « nouvelle version disponible » (lot 15). La mise à
/// jour n'est jamais appliquée sans demande : elle recharge la page.
@injectable
class AppUpdateCubit extends Cubit<AppUpdateState> {
  AppUpdateCubit(this._source)
    : super(AppUpdateState(available: _source.isAvailable)) {
    _subscription = _source.changes.listen(
      (available) => emit(
        state.copyWith(
          available: available,
          // Une version retirée puis remplacée redemande l'attention.
          dismissed: available && state.dismissed,
        ),
      ),
    );
  }

  final AppUpdateSource _source;
  late final StreamSubscription<bool> _subscription;

  /// « Plus tard » : masque la bannière jusqu'au prochain rechargement.
  void dismiss() => emit(state.copyWith(dismissed: true));

  /// Active la nouvelle version (recharge la page).
  Future<void> apply() => _source.apply();

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
