import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/features/select_club/presentation/ui/club_choice_list.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/auth_form_state.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/forgot_password_cubit.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/register_cubit.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/sign_in_cubit.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/account_section.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/auth_fields.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/forgot_password_form.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/register_form.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/sign_in_form.dart';
import 'package:billard_cfa/pages/forgot_password/presentation/forgot_password_page.dart';
import 'package:billard_cfa/pages/register/presentation/register_page.dart';
import 'package:billard_cfa/pages/select_club/presentation/select_club_page.dart';
import 'package:billard_cfa/pages/sign_in/presentation/sign_in_page.dart';
import 'package:billard_cfa/pages/splash/presentation/splash_page.dart';
import 'package:billard_cfa/pages/unavailable/presentation/unavailable_page.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook_workspace/support/preview_world.dart';

const _path = '[Compte]';

const _nice = ClubMembership(
  clubId: ClubId('club-nice'),
  clubName: 'Billard Club de Nice',
  role: Role.director,
);
const _lyon = ClubMembership(
  clubId: ClubId('club-lyon'),
  clubName: 'Académie de Lyon',
  role: Role.teacher,
);

AuthFormState _state(BuildContext context) {
  final status = context.knobs.object.dropdown<AuthFormStatus>(
    label: 'Avancement',
    options: AuthFormStatus.values,
    labelBuilder: (value) => value.name,
  );
  final failure = context.knobs.object.dropdown<AuthFailureCode?>(
    label: 'Échec (si « failed »)',
    options: [null, ...AuthFailureCode.values],
    labelBuilder: (value) => value?.name ?? 'aucun',
  );
  return AuthFormState(
    status: status,
    failure: failure,
    verificationSent: context.knobs.boolean(
      label: 'E-mail de vérification parti',
    ),
  );
}

Widget _padded(Widget child) => SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: child,
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Formulaire de connexion',
  type: SignInForm,
  path: _path,
)
Widget buildSignInFormUseCase(BuildContext context) => _padded(
  SignInForm(
    state: _state(context),
    onSubmit: (_, _) {},
    onResendVerification: (_, _) {},
    onForgotPassword: () {},
    onRegister: () {},
  ),
);

@widgetbook.UseCase(
  name: 'Formulaire « mot de passe oublié »',
  type: ForgotPasswordForm,
  path: _path,
)
Widget buildForgotPasswordFormUseCase(BuildContext context) =>
    _padded(ForgotPasswordForm(state: _state(context), onSubmit: (_) {}));

@widgetbook.UseCase(
  name: 'Formulaire d’inscription sur invitation',
  type: RegisterForm,
  path: _path,
)
Widget buildRegisterFormUseCase(BuildContext context) =>
    _padded(RegisterForm(state: _state(context), onSubmit: (_, _, _) {}));

@widgetbook.UseCase(
  name: 'Retour d’un formulaire (erreur, succès)',
  type: AuthFormFeedback,
  path: _path,
)
Widget buildAuthFormFeedbackUseCase(BuildContext context) => _padded(
  AuthFormFeedback(state: _state(context), success: 'Opération réussie.'),
);

@widgetbook.UseCase(name: 'Compte connecté', type: AccountSection, path: _path)
Widget buildAccountSectionUseCase(BuildContext context) => _padded(
  AccountSection(
    email: 'animateur@example.org',
    clubName: 'Billard Club de Nice',
    roleLabel: 'Directeur',
    onSignOut: () {},
  ),
);

@widgetbook.UseCase(name: 'Choix du club', type: ClubChoiceList, path: _path)
Widget buildClubChoiceListUseCase(BuildContext context) => _padded(
  ClubChoiceList(
    choices: const [_nice, _lyon],
    current: context.knobs.boolean(label: 'Un club est actif')
        ? _nice.clubId
        : null,
    enabled: context.knobs.boolean(label: 'Actif', initialValue: true),
    onChoose: (_) {},
  ),
);

@widgetbook.UseCase(name: 'Démarrage', type: SplashPage, path: _path)
Widget buildSplashPageUseCase(BuildContext context) => const SplashPage();

@widgetbook.UseCase(name: 'Connexion', type: SignInPage, path: _path)
Widget buildSignInPageUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) => getIt<SignInCubit>(),
    child: SignInPage(onForgotPassword: () {}, onRegister: () {}),
  ),
);

@widgetbook.UseCase(
  name: 'Mot de passe oublié',
  type: ForgotPasswordPage,
  path: _path,
)
Widget buildForgotPasswordPageUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) => getIt<ForgotPasswordCubit>(),
    child: ForgotPasswordPage(onBack: () {}),
  ),
);

@widgetbook.UseCase(
  name: 'Inscription sur invitation',
  type: RegisterPage,
  path: _path,
)
Widget buildRegisterPageUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) => getIt<RegisterCubit>(),
    child: RegisterPage(onBack: () {}),
  ),
);

@widgetbook.UseCase(
  name: 'Choix du club (page)',
  type: SelectClubPage,
  path: _path,
)
Widget buildSelectClubPageUseCase(BuildContext context) => SelectClubPage(
  choices: context.knobs.boolean(label: 'Aucun club')
      ? const []
      : const [_nice, _lyon],
  current: context.knobs.boolean(label: 'Bascule depuis « Plus »')
      ? _nice.clubId
      : null,
  blocked: context.knobs.boolean(label: 'Séance en cours (bascule interdite)'),
  onChoose: (_) {},
  onSignOut: () {},
  onRefresh: () {},
  onBack: context.knobs.boolean(label: 'Retour à « Plus »') ? () {} : null,
);

@widgetbook.UseCase(
  name: 'Service indisponible',
  type: UnavailablePage,
  path: _path,
)
Widget buildUnavailablePageUseCase(BuildContext context) =>
    UnavailablePage(onRetry: () {});
