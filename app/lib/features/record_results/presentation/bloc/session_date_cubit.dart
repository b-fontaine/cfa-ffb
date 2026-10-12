import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Date choisie pour la séance à ouvrir (par défaut : le jour courant).
@injectable
class SessionDateCubit extends Cubit<DateTime> {
  SessionDateCubit(@factoryParam super.initialState);

  void changed(DateTime date) => emit(date);
}
