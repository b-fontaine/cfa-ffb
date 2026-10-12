import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/ui/audience_badge.dart';
import 'package:billard_cfa/shared/ui/page_header.dart';
import 'package:billard_cfa/shared/ui/responsive_body.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({required this.onOpenPlanner, super.key});

  final VoidCallback onOpenPlanner;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: ResponsiveBody(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(title: l10n.homeTitle, subtitle: l10n.homeSubtitle),
                const SizedBox(height: AppSpacing.lg),
                SectionCard(
                  title: l10n.homeAudiencesTitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final audience in Audience.values)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            children: [
                              AudienceBadge(
                                kind: switch (audience) {
                                  Audience.children => AudienceKind.children,
                                  Audience.adults => AudienceKind.adults,
                                },
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                l10n.sessionDurationMinutes(
                                  audience.sessionDuration.inMinutes,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: onOpenPlanner,
                  child: Text(l10n.homeOpenPlanner),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
