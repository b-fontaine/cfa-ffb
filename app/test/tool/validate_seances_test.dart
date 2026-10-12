import 'package:flutter_test/flutter_test.dart';

import '../../../scripts/validate_seances.dart';

/// Séance minimale : front matter et déroulé donnés par [rows].
String seance({
  String public = 'enfants',
  Object? minutes = 90,
  List<String>? rows,
  bool frontMatter = true,
}) {
  final table = [
    '| Min | Phase | Contenu | Source |',
    '|-----|-------|---------|--------|',
    ...rows ?? defaultRows,
  ].join('\n');
  final front = frontMatter
      ? '---\npublic: $public\nduree_minutes: $minutes\n---\n'
      : '';
  return '$front\n# Titre\n\n$table';
}

const defaultRows = <String>[
  '| 0–10 | Accueil | Rappel | [Prop] |',
  '| 10–35 | Notion + initiation | Bille fantôme | [S] fiche 3 |',
  '| 35–70 | Entraînement | E1 à E3 | [S] fiche 5 |',
  '| 70–90 | Jeu | Partie | [FFB] jeu 7 |',
];

void main() {
  List<String> errors(String content) => validate('seance.md', content);

  test('accepts a valid children session of 90 minutes', () {
    expect(errors(seance()), isEmpty);
  });

  test('accepts a valid adults session of 120 minutes', () {
    final content = seance(
      public: 'adultes',
      minutes: 120,
      rows: [
        '| 0–10 | Accueil | Rappel | [Prop] |',
        '| 10–40 | Notion | Bille fantôme | [S] fiche 3 |',
        '| 40–100 | Entraînement | E1 à E3 | [S] fiche 5 |',
        '| 100–120 | Jeu | Partie | [Web] jeu |',
      ],
    );

    expect(errors(content), isEmpty);
  });

  group('duration bounds', () {
    for (final minutes in [89, 91]) {
      test('rejects $minutes minutes for children', () {
        final content = seance(
          minutes: minutes,
          rows: [
            '| 0–10 | Accueil | a | [Prop] |',
            '| 10–$minutes | Notion | b | [S] f |',
          ],
        );

        const tail = 'public=enfants (attendu 90)';
        expect(errors(content), [
          'duree_minutes=$minutes incompatible avec $tail',
        ]);
      });
    }

    for (final minutes in [119, 121]) {
      test('rejects $minutes minutes for adults', () {
        final content = seance(
          public: 'adultes',
          minutes: minutes,
          rows: [
            '| 0–10 | Accueil | a | [Prop] |',
            '| 10–$minutes | Notion | b | [S] f |',
          ],
        );

        const tail = 'public=adultes (attendu 120)';
        expect(errors(content), [
          'duree_minutes=$minutes incompatible avec $tail',
        ]);
      });
    }

    test('rejects 90 minutes for adults', () {
      final content = seance(public: 'adultes');

      expect(errors(content), [
        'duree_minutes=90 incompatible avec public=adultes (attendu 120)',
      ]);
    });
  });

  test('rejects an unknown audience', () {
    expect(errors(seance(public: 'seniors')), [
      'public invalide : seniors (enfants|adultes)',
    ]);
  });

  test('rejects a missing front matter', () {
    final found = errors(seance(frontMatter: false));

    expect(found, contains('front matter manquant'));
    expect(found, contains('duree_minutes manquant ou invalide'));
  });

  test('rejects a non numeric duration', () {
    expect(errors(seance(minutes: 'longue')), [
      'duree_minutes manquant ou invalide',
    ]);
  });

  test('rejects a gap in the timeline', () {
    final content = seance(
      rows: [
        '| 0–10 | Accueil | a | [Prop] |',
        '| 15–90 | Notion | b | [S] f |',
      ],
    );

    expect(errors(content), [
      'déroulé non contigu : ligne attendue à 10, trouvée à 15',
    ]);
  });

  test('rejects an overlap in the timeline', () {
    final content = seance(
      rows: [
        '| 0–20 | Accueil | a | [Prop] |',
        '| 10–90 | Notion | b | [S] f |',
      ],
    );

    expect(errors(content), [
      'déroulé non contigu : ligne attendue à 20, trouvée à 10',
    ]);
  });

  test('rejects a timeline that stops before the duration', () {
    final content = seance(
      rows: [
        '| 0–10 | Accueil | a | [Prop] |',
        '| 10–80 | Notion | b | [S] f |',
      ],
    );

    expect(errors(content), [
      'le déroulé se termine à 80 min au lieu de 90 min',
    ]);
  });

  test('rejects a timeline that runs past the duration', () {
    final content = seance(
      rows: [
        '| 0–10 | Accueil | a | [Prop] |',
        '| 10–95 | Notion | b | [S] f |',
      ],
    );

    expect(errors(content), [
      'le déroulé se termine à 95 min au lieu de 90 min',
    ]);
  });

  test('rejects an empty range', () {
    final content = seance(
      rows: ['| 0–0 | Accueil | a | [Prop] |', '| 0–90 | Notion | b | [S] f |'],
    );

    expect(errors(content), ['plage invalide 0–0']);
  });

  test('rejects a row without a source label', () {
    final content = seance(
      rows: [
        '| 0–10 | Accueil | a | [Prop] |',
        '| 10–90 | Notion | b | rien |',
      ],
    );

    expect(errors(content), [
      'ligne 10–90 sans étiquette de source [S]/[FFB]/[Web]/[Prop]',
    ]);
  });

  test('rejects the game before the notion', () {
    final content = seance(
      rows: ['| 0–30 | Jeu | a | [S] f |', '| 30–90 | Notion | b | [S] f |'],
    );

    expect(errors(content), ['ordre des phases non respecté près de 30–90']);
  });

  test('rejects the training before the notion', () {
    final content = seance(
      rows: [
        '| 0–30 | Entraînement | a | [S] f |',
        '| 30–90 | Notion | b | [S] f |',
      ],
    );

    expect(errors(content), ['ordre des phases non respecté près de 30–90']);
  });

  test('accepts a plain hyphen between the bounds', () {
    final content = seance(
      rows: [
        '| 0-10 | Accueil | a | [Prop] |',
        '| 10-90 | Notion | b | [S] f |',
      ],
    );

    expect(errors(content), isEmpty);
  });

  test('rejects a session without a timeline', () {
    const content = '---\npublic: enfants\nduree_minutes: 90\n---\n# Titre\n';

    expect(errors(content), ['déroulé minuté introuvable']);
  });
}
