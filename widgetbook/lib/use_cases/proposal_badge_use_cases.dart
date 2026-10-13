import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Proposition [Prop]',
  type: ProposalBadge,
  path: '[Design system]/Composants',
)
Widget buildProposalBadgeUseCase(BuildContext context) =>
    const Padding(padding: EdgeInsets.all(16), child: ProposalBadge());
