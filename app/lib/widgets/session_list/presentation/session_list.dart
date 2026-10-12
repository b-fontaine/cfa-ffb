import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/ui/empty_state.dart';
import 'package:flutter/material.dart';

/// Liste des séances planifiées avec public et durée.
class SessionList extends StatelessWidget {
  const SessionList({required this.sessions, super.key});

  final List<Session> sessions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (sessions.isEmpty) {
      return EmptyState(message: l10n.plannerEmpty);
    }
    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final audience = switch (session.audience) {
          Audience.children => l10n.audienceChildren,
          Audience.adults => l10n.audienceAdults,
        };
        final minutes = l10n.sessionDurationMinutes(session.duration.inMinutes);
        return ListTile(
          title: Text(session.title),
          subtitle: Text('$audience · $minutes'),
        );
      },
    );
  }
}
