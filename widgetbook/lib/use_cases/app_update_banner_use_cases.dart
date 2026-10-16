import 'package:billard_cfa/shared/ui/app_update_banner.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Nouvelle version',
  type: AppUpdateBanner,
  path: '[Design system]/Composants',
)
Widget buildAppUpdateBannerUseCase(BuildContext context) =>
    AppUpdateBanner(onUpdate: () {}, onLater: () {});
