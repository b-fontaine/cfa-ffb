import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Contrôle de forme des workflows GitHub (le dépôt n'a pas d'actionlint) : ce
/// que la décision de déploiement des règles et des index (2026-10-18,
/// docs/engineering/deploiement-firestore.md) exige et qu'une relecture de
/// YAML laisserait passer : actions épinglées par empreinte, jamais depuis une
/// pull request, tests avant déploiement, index avant règles, règles et index
/// avant l'hébergement, authentification sans clé JSON.
const _dir = '../.github/workflows';

YamlMap _load(String name) =>
    loadYaml(File('$_dir/$name').readAsStringSync()) as YamlMap;

String _text(String name) => File('$_dir/$name').readAsStringSync();

List<String> _needs(YamlMap job) {
  final needs = job['needs'];
  return switch (needs) {
    null => const [],
    final String one => [one],
    final YamlList many => [for (final n in many) '$n'],
    _ => throw StateError('needs illisible : $needs'),
  };
}

YamlMap _jobs(String name) => _load(name)['jobs'] as YamlMap;

void main() {
  final workflows = [
    for (final entity in Directory(_dir).listSync())
      if (entity is File && entity.path.endsWith('.yml'))
        entity.uri.pathSegments.last,
  ]..sort();

  test('the workflows under test exist', () {
    expect(
      workflows,
      containsAll([
        'ci.yml',
        'firebase-firestore-deploy.yml',
        'firebase-hosting-merge.yml',
        'firebase-hosting-pull-request.yml',
      ]),
    );
  });

  group('every workflow', () {
    for (final name in workflows) {
      test('$name pins each external action by commit SHA', () {
        final uses = RegExp(
          r'^\s*(?:-\s*)?uses:\s*(\S+)',
          multiLine: true,
        ).allMatches(_text(name)).map((m) => m.group(1)!);

        for (final reference in uses) {
          if (reference.startsWith('./')) continue;
          expect(
            reference,
            matches(RegExp(r'^[\w.-]+/[\w./-]+@[0-9a-f]{40}$')),
            reason: '$name : $reference',
          );
        }
      });

      test('$name never uses a long-lived service account key', () {
        final text = _text(name);

        expect(text, isNot(contains('credentials_json')));
        expect(text, isNot(contains('GOOGLE_CREDENTIALS')));
        expect(text, isNot(contains('FIREBASE_TOKEN')));
      });
    }
  });

  group('firebase-firestore-deploy.yml', () {
    const name = 'firebase-firestore-deploy.yml';

    test('is never triggered by a pull request or by a bare push', () {
      final on = _load(name)['on'] as YamlMap;

      expect(on.keys.toSet(), {'workflow_call', 'workflow_dispatch'});
    });

    test('deploys on every run, never on the diff of one push', () {
      // Le workflow Hosting garde UNE exécution en attente par groupe : un
      // push remplacé par un suivant n'a jamais son propre diff déployé. Les
      // règles et les index partent donc à chaque exécution (la CLI ne publie
      // que ce qui diffère), sans comparaison avec le push précédent.
      final text = _text(name);
      final jobs = _jobs(name);

      expect(jobs.keys, isNot(contains('changes')));
      expect(text, isNot(contains('github.event.before')));
      expect(text, isNot(contains('git diff')));
      expect(text, isNot(contains("outputs.firestore == 'true'")));
      expect(
        (jobs['tests'] as YamlMap)['if'],
        isNull,
        reason: 'les tests ne sont jamais sautés',
      );
      expect((jobs['deploy'] as YamlMap)['if'], isNull);
    });

    test('tests come first and deployment depends on them', () {
      final jobs = _jobs(name);

      expect(_needs(jobs['deploy'] as YamlMap), contains('tests'));
      final tests = _text(name);
      expect(tests, contains('scripts/rules_test.sh'));
      expect(tests, contains('tool/check_indexes.dart'));
    });

    test('only the deployment job may ask for an identity token', () {
      final jobs = _jobs(name);

      for (final entry in jobs.entries) {
        final permissions = (entry.value as YamlMap)['permissions'] as YamlMap?;
        final idToken = permissions?['id-token'];
        if (entry.key == 'deploy') {
          expect(idToken, 'write');
        } else {
          expect(idToken, isNull, reason: '${entry.key}');
        }
      }
      expect((_load(name)['permissions'] as YamlMap)['id-token'], isNull);
    });

    test('a manual run joins the Hosting concurrency group, never cancelling '
        'a deployment in progress', () {
      final hosting =
          _load('firebase-hosting-merge.yml')['concurrency'] as YamlMap;
      final own = _load(name)['concurrency'] as YamlMap;

      expect(own['cancel-in-progress'], false);
      expect(
        '${own['group']}',
        allOf(
          contains("github.event_name == 'workflow_dispatch'"),
          contains("'${hosting['group']}'"),
        ),
      );
      // Appelé, le groupe ne doit pas être celui de l'appelant (il serait
      // annulé) : il est propre à l'exécution.
      expect('${own['group']}', contains('github.run_id'));
    });

    test('the job holding the identity token is hardened', () {
      final deploy = _jobs(name)['deploy'] as YamlMap;
      final steps = (deploy['steps'] as YamlList).cast<YamlMap>();

      expect(
        {
          for (final e in (deploy['permissions'] as YamlMap).entries)
            e.key: e.value,
        },
        {'contents': 'read', 'id-token': 'write'},
      );
      final checkout = steps.singleWhere(
        (s) => '${s['uses']}'.startsWith('actions/checkout@'),
      );
      expect((checkout['with'] as YamlMap)['persist-credentials'], false);
      final install = steps.singleWhere(
        (s) => '${s['run']}'.contains('npm ci'),
      );
      expect('${install['run']}', contains('npm ci --ignore-scripts'));
    });

    test('no checkout of this workflow keeps the repository token', () {
      for (final entry in _jobs(name).entries) {
        final steps = ((entry.value as YamlMap)['steps'] as YamlList)
            .cast<YamlMap>();
        for (final step in steps) {
          if (!'${step['uses']}'.startsWith('actions/checkout@')) continue;
          expect(
            (step['with'] as YamlMap?)?['persist-credentials'],
            false,
            reason: entry.key as String,
          );
        }
      }
    });

    test('authenticates by workload identity federation', () {
      final steps = ((_jobs(name)['deploy'] as YamlMap)['steps'] as YamlList)
          .cast<YamlMap>();
      final auth = steps.singleWhere(
        (s) => '${s['uses']}'.startsWith('google-github-actions/auth@'),
      );

      final inputs = auth['with'] as YamlMap;
      expect(
        inputs.keys,
        containsAll(['workload_identity_provider', 'service_account']),
      );
    });

    test('refuses any context but main, then names a missing variable '
        'before authenticating', () {
      final steps = ((_jobs(name)['deploy'] as YamlMap)['steps'] as YamlList)
          .cast<YamlMap>();
      final labels = [for (final s in steps) '${s['name'] ?? s['uses']}'];

      expect(labels.first, startsWith('Refuser tout contexte autre que main'));
      final refuse = '${steps.first['run']}';
      expect(refuse, contains('refs/heads/main'));
      expect(refuse, contains('pull_request'));
      final check = steps.singleWhere(
        (s) => '${s['name']}'.startsWith('Vérifier la configuration'),
      );
      expect('${check['run']}', contains('GCP_WORKLOAD_IDENTITY_PROVIDER'));
      expect(
        '${check['run']}',
        contains('GCP_FIRESTORE_DEPLOY_SERVICE_ACCOUNT'),
      );
      expect('${check['run']}', contains('::error'));
      expect(
        labels.indexWhere((l) => l.startsWith('Vérifier')),
        lessThan(
          labels.indexWhere((l) => l.startsWith('google-github-actions/auth')),
        ),
      );
    });

    test('deploys the indexes, then the rules, with no deletion forced', () {
      final steps = ((_jobs(name)['deploy'] as YamlMap)['steps'] as YamlList)
          .cast<YamlMap>();
      final commands = [
        for (final s in steps)
          if (s['run'] != null && '${s['run']}'.contains('firebase deploy'))
            '${s['run']}',
      ];

      expect(commands, hasLength(2));
      expect(commands[0], contains('--only firestore:indexes'));
      expect(commands[1], contains('--only firestore:rules'));
      for (final command in commands) {
        expect(command, contains('--non-interactive'));
        expect(command, isNot(contains('--force')));
        expect(command, isNot(contains('hosting')));
      }
    });
  });

  group('firebase-hosting-merge.yml', () {
    const name = 'firebase-hosting-merge.yml';

    test('deploys the hosting only after the rules and the indexes', () {
      final jobs = _jobs(name);

      expect(
        (jobs['firestore'] as YamlMap)['uses'],
        './.github/workflows/firebase-firestore-deploy.yml',
      );
      expect(
        _needs(jobs['build_and_deploy'] as YamlMap),
        contains('firestore'),
      );
    });

    test(
      'runs on pushes to main only, without the identity token by default',
      () {
        final workflow = _load(name);

        expect(((workflow['on'] as YamlMap)['push'] as YamlMap)['branches'], [
          'main',
        ]);
        expect(workflow['on'].toString(), isNot(contains('pull_request')));
        expect((workflow['permissions'] as YamlMap)['id-token'], isNull);
      },
    );
  });

  group('the data backend of each hosting build (ADR 0024, decision A1)', () {
    // L'étape « Build web » d'un workflow : sa commande `run`.
    String buildCommand(String name, String job) {
      final steps = (_jobs(name)[job] as YamlMap)['steps'] as YamlList;
      final builds = [
        for (final step in steps)
          if ((step as YamlMap)['name'] == 'Build web') '${step['run']}'.trim(),
      ];
      expect(builds, hasLength(1), reason: '$name : une seule étape de build');
      return builds.single;
    }

    test('the live deployment builds the default backend, Firestore', () {
      final command = buildCommand(
        'firebase-hosting-merge.yml',
        'build_and_deploy',
      );

      expect(command, 'scripts/build_web.sh');
      expect(command, isNot(contains('DATA_BACKEND')));
    });

    test('the pull request previews stay on drift, explicitly', () {
      final command = buildCommand(
        'firebase-hosting-pull-request.yml',
        'build_and_preview',
      );

      expect(command, contains('--dart-define=DATA_BACKEND=drift'));
    });

    test('the pull request preview says why it is not on Firestore', () {
      expect(
        _text('firebase-hosting-pull-request.yml'),
        contains('previews de PR non connectées à Firestore'),
      );
    });

    test('no workflow passes a redundant Firestore flag', () {
      // Le défaut est Firestore : aucun drapeau firestore redondant.
      for (final name in workflows) {
        expect(
          _text(name),
          isNot(contains('DATA_BACKEND=firestore')),
          reason: name,
        );
      }
    });
  });

  // Les previews de PR sont déployées avec le même compte de service et sur le
  // même projet que le live : leur seule protection est ce test (ADR 0024,
  // lot de bascule) : drift explicite, aucun secret de déploiement des règles,
  // aucune étape Firestore.
  group('the pull request workflow cannot touch Firestore', () {
    const name = 'firebase-hosting-pull-request.yml';

    test('it carries no rules deployment secret or variable', () {
      final text = _text(name);

      expect(text, isNot(contains('GCP_WORKLOAD_IDENTITY_PROVIDER')));
      expect(text, isNot(contains('GCP_FIRESTORE_DEPLOY_SERVICE_ACCOUNT')));
      expect(text, isNot(contains('firebase-firestore-deploy')));
      expect(text, isNot(contains('workflow_call')));
      expect(text, isNot(contains('id-token')));
    });

    test('none of its steps mentions Firestore', () {
      for (final job in _jobs(name).values) {
        for (final step in (job as YamlMap)['steps'] as YamlList) {
          expect(
            '$step'.toLowerCase(),
            isNot(contains('firestore')),
            reason: '$step',
          );
        }
      }
    });
  });

  test('no other workflow can deploy rules or indexes', () {
    for (final name in workflows) {
      if (name == 'firebase-firestore-deploy.yml') continue;
      final text = _text(name);

      expect(text, isNot(contains('firestore:rules')), reason: name);
      expect(text, isNot(contains('firestore:indexes')), reason: name);
      // Seul le job `firestore` du workflow Hosting, qui appelle le
      // déploiement, reçoit le jeton d'identité.
      if (name != 'firebase-hosting-merge.yml') {
        expect(text, isNot(contains('id-token: write')), reason: name);
      }
    }
  });
}
