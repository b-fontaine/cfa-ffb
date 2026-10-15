import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/diagrammes/model.dart';
import '../../tool/fiches/catalogue.dart';
import '../../tool/fiches/cli.dart';
import '../../tool/fiches/context.dart';
import '../../tool/fiches/directory.dart';
import '../../tool/fiches/format_table.dart';
import '../../tool/fiches/session_rules.dart';

const _root = '..';
const _catalogueDir = '$_root/docs/knowledge/05-seances/catalogue';
const _pilotName = '08-demi-bille-1.yaml';
const _pilotPath = '$_catalogueDir/$_pilotName';

const _badName = '06-bille-pleine-1.yaml';

/// Copie temporaire de la racine utile à l'outil (`docs/knowledge`, noms des
/// PDF de `docs/sources`) : le dépôt réel n'est jamais modifié.
String _copyRoot() {
  final root = Directory.systemTemp.createTempSync('fiches_root_');
  addTearDown(() => root.deleteSync(recursive: true));
  final result = Process.runSync('cp', [
    '-r',
    '$_root/docs/knowledge',
    '${root.path}/docs_knowledge_tmp',
  ]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  Directory('${root.path}/docs').createSync();
  Directory('${root.path}/docs_knowledge_tmp')
      .renameSync('${root.path}/docs/knowledge');
  final sources = Directory('${root.path}/docs/sources')..createSync();
  for (final f in Directory('$_root/docs/sources').listSync()) {
    if (f is File) {
      File('${sources.path}/${f.uri.pathSegments.last}').createSync();
    }
  }
  return root.path;
}

/// Copie profonde modifiable du pilote (JSON : un JSON est du YAML).
Json _pilot() => jsonDecode(
  jsonEncode(toPlain(loadYaml(File(_pilotPath).readAsStringSync()))),
) as Json;

Json _obj(Object? v) => v! as Json;

List<Json> _exercises(Json d) => [
  for (final e in _obj(d['training'])['exercises']! as List) _obj(e),
];

List<Json> _illustrations(Json d) => [
  for (final e in d['illustrations']! as List) _obj(e),
];

Json _game(Json d) => _obj(d['game']);

/// Illustration d'identifiant [id] de [d].
Json _illustration(Json d, String id) =>
    _illustrations(d).firstWhere((i) => i['id'] == id);

void main() {
  late FichesContext context;

  setUpAll(() => context = FichesContext.load(_root));

  List<String> run(
    Json doc, {
    String fileName = _pilotName,
    Map<String, Json> siblings = const {},
  }) => validateSession(
    jsonEncode(doc),
    fileName: fileName,
    context: context,
    siblings: siblings,
  );

  /// Erreurs du pilote après modification par [mutate].
  List<String> broken(
    void Function(Json d) mutate, {
    String fileName = _pilotName,
    Map<String, Json> siblings = const {},
  }) {
    final d = _pilot();
    mutate(d);
    return run(d, fileName: fileName, siblings: siblings);
  }

  /// Rouge pour la règle [rule], et vert avant modification.
  void expectRule(List<String> errors, String rule, {String? mention}) {
    final hits = errors.where((e) => e.startsWith('$rule ')).toList();
    expect(hits, isNotEmpty, reason: 'règle $rule attendue dans $errors');
    if (mention != null) {
      expect(hits.join('\n'), contains(mention));
    }
  }

  group('structure calculée depuis le catalogue (FORMAT § 1)', () {
    late Structure structure;

    setUpAll(() => structure = context.structure);

    test('le catalogue réel donne 28 séances sans erreur', () {
      expect(structure.errors, isEmpty);
      expect(structure.slots, hasLength(28));
    });

    test('nombre de parties par technique (valeurs indépendantes)', () {
      expect(structure.partsByTechnique, {
        'posture': 2,
        'puissance': 2,
        'bille-fantome': 1,
        'bille-pleine': 2,
        'demi-bille': 2,
        'trois-quarts': 2,
        'quart': 1,
        'finesse': 1,
        'rebond-bande': 2,
        'rejet-naturel': 2,
        'coule': 3,
        'carreau': 2,
        'angle-droit': 2,
        'retro': 4,
      });
    });

    test("ordre d'enseignement : rebond sur bande avant rejet naturel", () {
      final ids = [for (final s in structure.slots) s.id];
      expect(
        ids.indexOf('rebond-bande-2'),
        lessThan(ids.indexOf('rejet-naturel-1')),
      );
      expect(ids.first, 'posture-1');
      expect(ids.last, 'retro-4');
    });

    test('tranches contiguës, premières parties plus chargées', () {
      List<int> of(String id) => structure.slotById(id)!.exercises;
      expect(of('coule-1'), [1, 2, 3]);
      expect(of('coule-2'), [4, 5, 6]);
      expect(of('coule-3'), [7, 8]);
      expect(of('retro-1'), [1, 2, 3]);
      expect(of('retro-4'), [9, 10]);
      expect(of('quart-1'), [1, 2]);
      expect(of('finesse-1'), [3, 4]);
      expect(of('demi-bille-2'), [3, 4]);
    });

    test('séance précédente : partie k-1, ou dernière partie précédente', () {
      expect(structure.slotById('posture-1')!.previous, isNull);
      expect(structure.slotById('demi-bille-2')!.previous, 'demi-bille-1');
      expect(structure.slotById('demi-bille-1')!.previous, 'bille-pleine-2');
      expect(structure.slotById('retro-1')!.previous, 'angle-droit-2');
      expect(structure.slotById('finesse-1')!.previous, 'quart-1');
    });

    test('nom de fichier : rang sur deux chiffres puis identifiant', () {
      expect(structure.slotById('demi-bille-1')!.fileName, _pilotName);
      expect(structure.slotById('retro-4')!.fileName, '28-retro-4.yaml');
    });

    test('bornage par les sessions du bloc', () {
      // 8 exercices : ceil(8/2) = 4, borné à 3 ; 2 exercices : 1 partie.
      final s = computeStructure(
        parseCatalogue(
          _catalogueWith({
            'coule': (min: 2, max: 3, n: 8),
            'posture': (min: 3, max: 4, n: 4),
          }),
        ),
      );
      expect(s.partsByTechnique['coule'], 3);
      // min 3 > N 4/2 = 2 : borné à 3 mais 3 <= 4 exercices, valide.
      expect(s.partsByTechnique['posture'], 3);
    });

    test('N impair : arrondi au supérieur, puis borné', () {
      // Valeurs écrites à la main : ceil(5/2) = 3 (et non floor = 2) ;
      // ceil(7/2) = 4 borné à max 2 ; ceil(1/2) = 1.
      final s = computeStructure(
        parseCatalogue(
          _catalogueWith({
            'posture': (min: 1, max: 4, n: 5),
            'puissance': (min: 1, max: 2, n: 7),
            'coule': (min: 1, max: 3, n: 1),
          }),
        ),
      );

      expect(s.partsByTechnique['posture'], 3);
      expect(s.partsByTechnique['puissance'], 2);
      expect(s.partsByTechnique['coule'], 1);
      expect(s.slotById('posture-1')!.exercises, [1, 2]);
      expect(s.slotById('posture-3')!.exercises, [5]);
    });

    test('parties > N : technique invalide (V2)', () {
      final s = computeStructure(
        parseCatalogue(_catalogueWith({'posture': (min: 5, max: 5, n: 4)})),
      );
      expect(s.errors.join('\n'), contains('V2'));
      expect(s.errors.join('\n'), contains('posture'));
    });

    test('un bloc de technique absent du catalogue est une erreur (V2)', () {
      final s = computeStructure(parseCatalogue('blocks: []\n'));
      expect(s.errors, isNotEmpty);
      expect(s.errors.first, startsWith('V2'));
    });
  });

  group('le pilote', () {
    test('est vert', () {
      final text = File(_pilotPath).readAsStringSync();
      final errors = validateSession(
        text,
        fileName: _pilotName,
        context: context,
      );
      expect(errors, isEmpty);
    });
  });

  group('V1 clés et version', () {
    test('version autre que 1', () {
      expectRule(broken((d) => d['version'] = 2), 'V1', mention: 'version');
    });
    test('clé obligatoire absente', () {
      expectRule(broken((d) => d.remove('notion')), 'V1', mention: 'notion');
    });
    test('clé inconnue à la racine', () {
      expectRule(broken((d) => d['bonus'] = 1), 'V1', mention: 'bonus');
    });
    test('clé inconnue dans un exercice', () {
      expectRule(
        broken((d) => _exercises(d).first['scoring'] = {'mode': 'counter'}),
        'V1',
        mention: 'scoring',
      );
    });
    test('YAML invalide', () {
      final errors = validateSession(
        'a: [',
        fileName: _pilotName,
        context: context,
      );
      expectRule(errors, 'V1');
    });
    test("racine qui n'est pas un objet", () {
      final errors = validateSession(
        '- 1',
        fileName: _pilotName,
        context: context,
      );
      expectRule(errors, 'V1');
    });
  });

  group('V2 identité et structure', () {
    test('id différent du nom de fichier', () {
      expectRule(broken((d) => d['id'] = 'demi-bille-2'), 'V2', mention: 'id');
    });
    test('nom de fichier sans le rang attendu', () {
      expectRule(
        broken((_) {}, fileName: '10-demi-bille-1.yaml'),
        'V2',
        mention: 'fichier',
      );
    });
    test('nom de fichier sans préfixe numérique', () {
      expectRule(broken((_) {}, fileName: 'demi-bille-1.yaml'), 'V2');
    });
    test('technique inconnue', () {
      expectRule(
        broken((d) {
          d['technique'] = 'inconnue';
          d['id'] = 'inconnue-1';
        }, fileName: '09-inconnue-1.yaml'),
        'V2',
        mention: 'technique',
      );
    });
    test('partie au-delà du nombre de parties', () {
      expectRule(
        broken((d) {
          d['part'] = 3;
          d['id'] = 'demi-bille-3';
        }, fileName: '09-demi-bille-3.yaml'),
        'V2',
        mention: 'part',
      );
    });
    test('rang incohérent avec la structure', () {
      expectRule(broken((d) => d['order'] = 10), 'V2', mention: 'order');
    });
    test("identifiant qui n'est pas un slug", () {
      expectRule(
        broken(
          (d) => d['id'] = 'Demi_Bille-1',
          fileName: '09-Demi_Bille-1.yaml',
        ),
        'V2',
        mention: 'slug',
      );
    });
  });

  group('V3 séance précédente', () {
    test('previous différent de la structure', () {
      expectRule(
        broken((d) => d['previous'] = 'puissance-2'),
        'V3',
        mention: 'bille-pleine-2',
      );
    });
    test('previous nul alors que le rang est > 1', () {
      expectRule(
        broken((d) => d['previous'] = null),
        'V3',
        mention: 'bille-pleine-2',
      );
    });
    test('previous non nul pour le rang 1', () {
      final errors = broken((d) {
        d['id'] = 'posture-1';
        d['order'] = 1;
        d['technique'] = 'posture';
        d['catalogue_block'] = 'posture';
        d['previous'] = 'puissance-1';
      }, fileName: '01-posture-1.yaml');
      expectRule(errors, 'V3', mention: 'null pour order 1');
    });
  });

  group('V4 bloc et ExerciseRef', () {
    test('catalogue_block nul', () {
      expectRule(broken((d) => d['catalogue_block'] = null), 'V4');
    });
    test("catalogue_block d'une autre technique", () {
      expectRule(
        broken((d) => d['catalogue_block'] = 'puissance'),
        'V4',
        mention: 'demi-bille',
      );
    });
    test('exercice sans ref', () {
      expectRule(
        broken((d) => _exercises(d).first.remove('ref')),
        'V4',
        mention: 'ref',
      );
    });
    test('ref.block différent du bloc de la séance', () {
      expectRule(
        broken((d) => _obj(_exercises(d).first['ref'])['block'] = 'puissance'),
        'V4',
      );
    });
    test('ref.n absent du bloc', () {
      expectRule(
        broken((d) => _obj(_exercises(d).first['ref'])['n'] = 9),
        'V4',
        mention: '9',
      );
    });
  });

  group("V5 tranche d'exercices", () {
    test('ref.n hors de la tranche de la partie', () {
      expectRule(
        broken((d) => _obj(_exercises(d).first['ref'])['n'] = 3),
        'V5',
        mention: 'hors de la tranche 1-2 de demi-bille-1',
      );
    });
    test('ref.n en double', () {
      expectRule(
        broken((d) => _obj(_exercises(d).last['ref'])['n'] = 1),
        'V5',
        mention: 'double',
      );
    });
  });

  group('V6 diagrammes', () {
    test('diagramme inconnu', () {
      expectRule(
        broken((d) => _exercises(d).first['diagram'] = 'entrainement-p99-e1'),
        'V6',
      );
    });
    test("diagramme d'un autre exercice du bloc", () {
      expectRule(
        broken((d) => _exercises(d).first['diagram'] = 'entrainement-p06-e3'),
        'V6',
        mention: 'exercise',
      );
    });
    test("diagramme d'un autre bloc", () {
      expectRule(
        broken((d) => _exercises(d).first['diagram'] = 'entrainement-p03-e1'),
        'V6',
        mention: 'sheet',
      );
    });
    test("diagramme d'un autre type (jeu)", () {
      expectRule(
        broken((d) => _exercises(d).first['diagram'] = 'jeux-p07-g1'),
        'V6',
        mention: 'kind',
      );
    });
    test('diagram_ref inconnu', () {
      expectRule(
        broken(
          (d) => _illustration(d, 'schema-jeu')['diagram'] = 'jeux-p99-g1',
        ),
        'V6',
        mention: 'jeux-p99-g1',
      );
    });
    test('bloc [Prop] : diagramme hors du dossier proposition', () {
      final errors = broken((d) {
        d['id'] = 'posture-1';
        d['order'] = 1;
        d['technique'] = 'posture';
        d['catalogue_block'] = 'posture';
        d['previous'] = null;
        _exercises(d).first['ref'] = {'block': 'posture', 'n': 1};
        _exercises(d).first['diagram'] = 'entrainement-p05-e1';
      }, fileName: '01-posture-1.yaml');
      expectRule(errors, 'V6', mention: 'proposition/');
    });
  });

  group('V7 illustrations', () {
    test('alt vide', () {
      expectRule(
        broken((d) => _illustration(d, 'contact-demi')['alt'] = ''),
        'V7',
        mention: 'alt',
      );
    });
    test('caption absente', () {
      expectRule(
        broken((d) => _illustration(d, 'contact-demi').remove('caption')),
        'V7',
        mention: 'caption',
      );
    });
    test('type hors de la liste fermée', () {
      expectRule(
        broken((d) => _illustration(d, 'contact-demi')['type'] = 'photo_pdf'),
        'V7',
        mention: 'type',
      );
    });
    test('illustration citée par la théorie mais absente', () {
      expectRule(
        broken((d) {
          final s = _obj((_obj(d['theory'])['sections']! as List).first);
          s['illustrations'] = ['absente'];
        }),
        'V7',
        mention: 'absente',
      );
    });
    test('setup_illustration absente', () {
      expectRule(
        broken((d) => _game(d)['setup_illustration'] = 'absente'),
        'V7',
      );
    });
    test("identifiant d'illustration en double", () {
      expectRule(
        broken((d) => _illustration(d, 'quantites')['id'] = 'contact-demi'),
        'V7',
        mention: 'double',
      );
    });
    test('table sans billes (forme du FORMAT des diagrammes)', () {
      final errors = broken((d) {
        (d['illustrations']! as List).add({
          'id': 'tbl',
          'type': 'table',
          'caption': 'c',
          'alt': 'a',
        });
      });
      expectRule(errors, 'V7', mention: 'tbl');
    });
    test('table valide', () {
      final errors = broken((d) {
        (d['illustrations']! as List).add({
          'id': 'tbl',
          'type': 'table',
          'caption': 'c',
          'alt': 'a',
          'balls': [
            {
              'id': 'r1',
              'color': 'red',
              'at': [4.0, 2.0],
            },
            {
              'id': 'w',
              'color': 'white',
              'at': [3.0, 3.0],
              'role': 'cue',
            },
          ],
        });
      });
      expect(errors, isEmpty);
    });
    test('recall.reuse : illustration absente de la séance précédente', () {
      final previous = _pilot()
        ..['id'] = 'bille-pleine-2'
        ..['illustrations'] = <Object?>[];
      expectRule(
        broken((_) {}, siblings: {'bille-pleine-2': previous}),
        'V7',
        mention: 'contact-plein',
      );
    });
    test('recall.reuse : illustration présente dans la séance précédente', () {
      final previous = _pilot()
        ..['id'] = 'bille-pleine-2'
        ..['illustrations'] = [
          {
            'id': 'contact-plein',
            'type': 'contact',
            'fraction': 'full',
            'tip_point': 'center',
            'caption': 'c',
            'alt': 'a',
          },
        ];
      expect(broken((_) {}, siblings: {'bille-pleine-2': previous}), isEmpty);
    });
  });

  group('V8 illustrations générées uniquement', () {
    for (final key in ['photo', 'image', 'path', 'url', 'asset']) {
      test("clé interdite « $key » au niveau de l'illustration", () {
        expectRule(
          broken((d) => _illustration(d, 'contact-demi')[key] = 'x'),
          'V8',
          mention: key,
        );
      });
    }
    test('chemin de fichier image dans un texte', () {
      expectRule(
        broken(
          (d) => _illustration(d, 'contact-demi')['caption'] = 'voir a.png',
        ),
        'V8',
      );
    });
    test("la clé path des flèches d'un tableau reste permise", () {
      final errors = broken((d) {
        (d['illustrations']! as List).add({
          'id': 'tbl',
          'type': 'table',
          'caption': 'c',
          'alt': 'a',
          'balls': [
            {
              'id': 'r1',
              'color': 'red',
              'at': [4.0, 2.0],
            },
          ],
          'arrows': [
            {
              'id': 'a1',
              'ball': 'r1',
              'kind': 'object',
              'path': [
                [4.0, 2.0],
                [8.0, 0.0],
              ],
              'to': 'tr',
            },
          ],
        });
      });
      expect(errors.where((e) => e.startsWith('V8')), isEmpty);
    });
  });

  group("V9 notation de l'initiation", () {
    Json initiation(Json d) => _obj((d['initiation']! as List).first);

    test('mode inconnu', () {
      expectRule(
        broken((d) => initiation(d)['scoring'] = {'mode': 'timer'}),
        'V9',
      );
    });
    test('compteur sans taille', () {
      expectRule(
        broken((d) => initiation(d)['scoring'] = {'mode': 'counter', 'of': 0}),
        'V9',
        mention: 'of',
      );
    });
    test('liste de critères vide', () {
      expectRule(
        broken(
          (d) => initiation(d)['scoring'] = {
            'mode': 'checklist',
            'criteria': <String>[],
          },
        ),
        'V9',
        mention: 'criteria',
      );
    });
    test('compteur valide', () {
      expect(
        broken((d) => initiation(d)['scoring'] = {'mode': 'counter', 'of': 5}),
        isEmpty,
      );
    });
    test('compteur de 1 : borne basse acceptée', () {
      expect(
        broken((d) => initiation(d)['scoring'] = {'mode': 'counter', 'of': 1}),
        isEmpty,
      );
    });
  });

  group('V28 créneau de rappel', () {
    Json slot(Json d) => _obj(_obj(d['training'])['recall_slot']);

    test('absent dès la deuxième séance : refusé', () {
      expectRule(
        broken((d) => _obj(d['training']).remove('recall_slot')),
        'V28',
        mention: 'obligatoire',
      );
    });
    test('présent sur la première séance : refusé', () {
      final errors = broken((d) {
        d['id'] = 'posture-1';
        d['technique'] = 'posture';
        d['order'] = 1;
        d['previous'] = null;
        d['catalogue_block'] = 'posture';
      }, fileName: '01-posture-1.yaml');
      expectRule(errors, 'V28', mention: 'interdit');
    });
    List<String> v28(List<String> errors) =>
        errors.where((e) => e.startsWith('V28 ')).toList();

    test('poids manquant pour un public : refusé', () {
      expectRule(
        broken((d) => slot(d)['weight'] = {'children': 1}),
        'V28',
        mention: 'adults',
      );
    });
    test('poids nul : refusé', () {
      final errors = broken(
        (d) => slot(d)['weight'] = {'children': 0, 'adults': 1},
      );
      expect(errors, isNotEmpty);
      expect(errors.join('\n'), contains('recall_slot'));
    });
    test('passes à 3 : refusé', () {
      expectRule(
        broken((d) => slot(d)['passes'] = 3),
        'V28',
        mention: 'passes',
      );
    });
    test('passes à 0 : refusé', () {
      expectRule(
        broken((d) => slot(d)['passes'] = 0),
        'V28',
        mention: 'passes',
      );
    });
    test('passes non entier : refusé', () {
      expectRule(
        broken((d) => slot(d)['passes'] = 1.5),
        'V28',
        mention: 'passes',
      );
      expectRule(
        broken((d) => slot(d)['passes'] = '1'),
        'V28',
        mention: 'passes',
      );
    });
    test('clé inconnue dans le créneau : refusée', () {
      final errors = broken((d) => slot(d)['inconnue'] = 1);
      expect(errors, isNotEmpty);
      expect(errors.join('\n'), contains('inconnue'));
    });
    test('order 2 avec créneau valide : accepté', () {
      final errors = broken((d) {
        d['order'] = 2;
        slot(d)['weight'] = {'children': 1, 'adults': 2};
        slot(d)['passes'] = 2;
      });
      expect(v28(errors), isEmpty, reason: '$errors');
    });
    test('order 1 sans créneau : accepté', () {
      final errors = broken((d) {
        d['id'] = 'posture-1';
        d['technique'] = 'posture';
        d['order'] = 1;
        d['previous'] = null;
        d['catalogue_block'] = 'posture';
        _obj(d['training']).remove('recall_slot');
      }, fileName: '01-posture-1.yaml');
      expect(v28(errors), isEmpty, reason: '$errors');
    });
  });

  group('V10 exercices : passages et textes', () {
    void expectBad(String field, String text, String mention) {
      expectRule(
        broken((d) => _exercises(d).first[field] = text),
        'V10',
        mention: mention,
      );
    }

    test('passes hors de 1 et 2', () {
      expectRule(
        broken((d) => _exercises(d).first['passes'] = 3),
        'V10',
        mention: 'passes',
      );
    });
    test('passes 0 refusé, 1 et 2 acceptés', () {
      expectRule(
        broken((d) => _exercises(d).first['passes'] = 0),
        'V10',
        mention: 'passes',
      );
      for (final passes in [1, 2]) {
        expect(
          broken((d) => _exercises(d).first['passes'] = passes),
          isEmpty,
          reason: 'passes $passes',
        );
      }
    });
    test('taux dans la mise en place', () {
      expectBad('setup', 'Réussir 6/8 tirs.', 'taux');
    });
    test('taux avec espaces', () {
      expectBad('instruction', 'Réussir 4 / 6 tirs.', 'taux');
    });
    test('type de chevalet', () {
      expectBad('expected', 'Chevalet sur cadre stable.', 'chevalet');
    });
    test('nombre de billes en chiffres', () {
      expectBad('setup', 'Poser 8 billes devant la poche.', 'billes');
    });
    test('nombre de billes en lettres', () {
      expectBad('instruction', 'Empocher six billes.', 'billes');
    });
    test('mention bronze', () {
      expectBad('expected', 'Mention Billard de bronze.', 'bronze');
    });
    test('« les billes du schéma » est permis', () {
      expect(
        broken(
          (d) => _exercises(d).first['setup'] =
              'Les billes du schéma, chacune devant sa poche.',
        ),
        isEmpty,
      );
    });
  });

  group('V11 contenu minimal par public', () {
    test('aucune théorie pour les enfants', () {
      expectRule(
        broken((d) {
          for (final s in _obj(d['theory'])['sections']! as List) {
            _obj(_obj(s)['weight']).remove('children');
          }
        }),
        'V11',
        mention: 'children',
      );
    });
    test('un seul exercice pour les adultes', () {
      expectRule(
        broken((d) => _obj(_exercises(d).last['weight']).remove('adults')),
        'V11',
        mention: 'adults',
      );
    });
    test('jeu non affiché pour un public', () {
      expectRule(
        broken((d) => _obj(_game(d)['weight']).remove('adults')),
        'V11',
        mention: 'game',
      );
    });
    test('poids nul', () {
      expectRule(
        broken((d) => _obj(_exercises(d).first['weight'])['children'] = 0),
        'V11',
      );
    });
    test('poids non entier', () {
      expectRule(
        broken((d) => _obj(_exercises(d).first['weight'])['adults'] = 1.5),
        'V11',
      );
    });
  });

  group('V13 provenance', () {
    test('exercice sans src', () {
      expectRule(broken((d) => _exercises(d).first.remove('src')), 'V13');
    });
    test('src hors de la liste', () {
      expectRule(
        broken((d) => _exercises(d).first['src'] = 'Wikipedia'),
        'V13',
      );
    });
    test('exercice Prop dans un bloc sourcé', () {
      expectRule(
        broken((d) => _exercises(d).first['src'] = 'Prop'),
        'V13',
        mention: 'bloc',
      );
    });
    test('jeu adapté déclaré [S]', () {
      expectRule(broken((d) => _game(d)['adapted'] = true), 'V13');
    });
    test('jeu source inexistant', () {
      expectRule(
        broken((d) => _game(d)['source_game'] = 99),
        'V13',
        mention: '99',
      );
    });
    test('jeu sans source déclaré [S]', () {
      expectRule(broken((d) => _game(d)['source_game'] = null), 'V13');
    });
    test('jeu adapté [Prop] avec source : accepté', () {
      expect(
        broken((d) {
          _game(d)['adapted'] = true;
          _game(d)['src'] = 'Prop';
        }),
        isEmpty,
      );
    });
    test('rappel sans src', () {
      expectRule(broken((d) => _obj(d['recall']).remove('src')), 'V13');
    });
  });

  group('V14 lien avec la séance précédente', () {
    test('link_previous absent', () {
      expectRule(broken((d) => _game(d).remove('link_previous')), 'V14');
    });
    test('notion_of différent de previous', () {
      expectRule(
        broken(
          (d) => _obj(_game(d)['link_previous'])['notion_of'] = 'puissance-2',
        ),
        'V14',
      );
    });
    test('règle vide', () {
      expectRule(
        broken((d) => _obj(_game(d)['link_previous'])['rule'] = ' '),
        'V14',
        mention: 'rule',
      );
    });
    test('note vide', () {
      expectRule(
        broken((d) => _obj(_game(d)['link_previous'])['note'] = ''),
        'V14',
        mention: 'note',
      );
    });
  });

  group('V15 notion et fiches techniques', () {
    test('notion en deux phrases', () {
      expectRule(
        broken((d) => d['notion'] = 'Viser la tangente. Puis empocher.'),
        'V15',
        mention: 'phrase',
      );
    });
    test('notion avec point-virgule', () {
      expectRule(broken((d) => d['notion'] = 'Viser ; empocher.'), 'V15');
    });
    test('notion de plus de 25 mots', () {
      expectRule(
        broken((d) => d['notion'] = List.filled(26, 'mot').join(' ')),
        'V15',
        mention: '25',
      );
    });
    test('notion de 25 mots : borne acceptée', () {
      expect(
        broken((d) => d['notion'] = '${List.filled(24, 'mot').join(' ')} fin.'),
        isEmpty,
      );
    });
    test('fiche technique incohérente', () {
      expectRule(broken((d) => d['technical_sheets'] = [4]), 'V15');
    });
  });

  group('V16 texte pour les enfants', () {
    Json section(Json d) =>
        _obj((_obj(d['theory'])['sections']! as List).first);

    test('élément de body de plus de 60 mots', () {
      expectRule(
        broken((d) => section(d)['body'] = [List.filled(61, 'mot').join(' ')]),
        'V16',
        mention: 'body',
      );
    });
    test('body de 60 mots et key_point de 20 mots : bornes acceptées', () {
      expect(
        broken((d) {
          section(d)['body'] = [List.filled(60, 'mot').join(' ')];
          section(d)['key_point'] = List.filled(20, 'mot').join(' ');
        }),
        isEmpty,
      );
    });
    test('key_point de plus de 20 mots', () {
      expectRule(
        broken(
          (d) => section(d)['key_point'] = List.filled(21, 'mot').join(' '),
        ),
        'V16',
        mention: 'key_point',
      );
    });
    test('section réservée aux adultes : limite non appliquée', () {
      expect(
        broken((d) {
          final s = _obj((_obj(d['theory'])['sections']! as List).last);
          s['body'] = [List.filled(61, 'mot').join(' ')];
        }),
        isEmpty,
      );
    });
  });

  group('V17 bornes de ghost_aim', () {
    test('blanche hors de la table', () {
      expectRule(
        broken((d) => _illustration(d, 'visee-demi')['cue'] = [9.0, 2.0]),
        'V17',
        mention: 'cue',
      );
    });
    test('bille cible hors de la table', () {
      expectRule(
        broken((d) => _illustration(d, 'visee-demi')['object'] = [4.0, 5.0]),
        'V17',
        mention: 'object',
      );
    });
    test('poche inconnue', () {
      expectRule(
        broken((d) => _illustration(d, 'visee-demi')['pocket'] = 'xx'),
        'V17',
        mention: 'pocket',
      );
    });
    test('fraction inconnue', () {
      expectRule(
        broken((d) => _illustration(d, 'visee-demi')['fraction'] = 'moitie'),
        'V17',
        mention: 'fraction',
      );
    });
  });

  group('V17 cohérence géométrique de ghost_aim', () {
    test("la séance telle qu'écrite est cohérente", () {
      expect(broken((d) {}), isEmpty);
    });
    test('demi-bille annoncée pleine : écart d = r_o = 0,1098 case', () {
      expectRule(
        broken((d) => _illustration(d, 'visee-demi')['fraction'] = 'full'),
        'V17',
        mention: 'incohérente avec la géométrie',
      );
    });
    test('demi-bille annoncée en quart : écart r_c / 2 = 0,05 case', () {
      // d nominal du quart = 0,1617 ; celui du demi = 0,1098 ; l'écart de
      // ≈ 0,05 dépasse la tolérance 0,07 s = 0,01495.
      expectRule(
        broken((d) => _illustration(d, 'visee-demi')['fraction'] = 'quarter'),
        'V17',
        mention: 'écart 0.05',
      );
    });
    test('demi-bille annoncée en trois-quarts (snake_case) : refusée', () {
      expectRule(
        broken(
          (d) => _illustration(d, 'visee-demi')['fraction'] = 'three_quarter',
        ),
        'V17',
        mention: 'three_quarter',
      );
    });
  });

  group('ball_size : comparaison de taille de la blanche', () {
    List<String> withIllustration(Json extra) => broken((d) {
      (d['illustrations']! as List).add({
        'id': 'nouvelle',
        'caption': 'c',
        'alt': 'a',
        ...extra,
      });
    });

    test('est acceptée sans paramètre', () {
      expect(withIllustration({'type': 'ball_size'}), isEmpty);
    });

    test('refuse tout paramètre', () {
      expect(
        withIllustration({'type': 'ball_size', 'diameter': 48}),
        isNotEmpty,
      );
    });
  });

  group('contact_height : contact de côté, écart exagéré', () {
    List<String> withIllustration(Json extra) => broken((d) {
      (d['illustrations']! as List).add({
        'id': 'nouvelle',
        'caption': 'c',
        'alt': 'a',
        ...extra,
      });
    });

    test('est acceptée sans paramètre', () {
      expect(withIllustration({'type': 'contact_height'}), isEmpty);
    });

    test("refuse tout paramètre (l'exagération est interne)", () {
      expect(
        withIllustration({'type': 'contact_height', 'exaggeration': 10}),
        isNotEmpty,
      );
    });
  });

  group('V25 à V27 : cue_ball_target, player_figure, power_ratio', () {
    /// Ajoute l'illustration [extra] au pilote et rend les erreurs.
    List<String> withIllustration(Json extra) => broken((d) {
      (d['illustrations']! as List).add({
        'id': 'nouvelle',
        'caption': 'c',
        'alt': 'a',
        ...extra,
      });
    });

    test('les trois nouveaux types valides sont acceptés', () {
      expect(
        withIllustration({
          'type': 'cue_ball_target',
          'tip_point': 'bottom',
          'cue_height': 'high',
          'compare': ['center', 'top'],
        }),
        isEmpty,
      );
      expect(
        withIllustration({
          'type': 'player_figure',
          'view': 'both',
          'focus': ['feet', 'head'],
          'lead_eye': 'left',
          'head_case': 'left_eye_over_cue',
          'bridge': 'surface',
        }),
        isEmpty,
      );
      expect(
        withIllustration({
          'type': 'power_ratio',
          'points': [
            {'amplitude': 'short', 'speed': 'slow', 'label': 'proche'},
            {'amplitude': 'long', 'speed': 'fast'},
          ],
          'highlight': 1,
          'distance_label': 'loin',
        }),
        isEmpty,
      );
    });

    test('les trois anciens types sont hors de la liste fermée', () {
      for (final extra in [
        {'type': 'cue_side', 'tip_point': 'top', 'cue_height': 'level'},
        {'type': 'stance_top', 'view': 'top'},
        {'type': 'power_scale', 'levels': 5},
      ]) {
        expectRule(withIllustration(extra), 'V7', mention: 'type');
      }
    });

    test('V25 : tip_point inconnu', () {
      expectRule(
        withIllustration({'type': 'cue_ball_target', 'tip_point': 'dessous'}),
        'V25',
        mention: 'tip_point',
      );
    });
    test('V25 : tip_point obligatoire', () {
      expectRule(
        withIllustration({'type': 'cue_ball_target'}),
        'V7',
        mention: 'tip_point',
      );
    });
    test('V25 : compare avec doublon ou avec le point lui-même', () {
      expectRule(
        withIllustration({
          'type': 'cue_ball_target',
          'tip_point': 'top',
          'compare': ['center', 'center'],
        }),
        'V25',
        mention: 'compare',
      );
      expectRule(
        withIllustration({
          'type': 'cue_ball_target',
          'tip_point': 'top',
          'compare': ['top'],
        }),
        'V25',
        mention: 'compare',
      );
    });
    test('V25 : cue_height hors de high | level | low', () {
      expectRule(
        withIllustration({
          'type': 'cue_ball_target',
          'tip_point': 'top',
          'cue_height': 'medium',
        }),
        'V25',
        mention: 'cue_height',
      );
    });

    test('V26 : view hors de side | top | both', () {
      expectRule(
        withIllustration({'type': 'player_figure', 'view': 'front'}),
        'V26',
        mention: 'view',
      );
    });
    test('V26 : focus vide, inconnu ou en double', () {
      for (final focus in [
        <String>[],
        ['nez'],
        ['feet', 'feet'],
      ]) {
        expectRule(
          withIllustration({
            'type': 'player_figure',
            'view': 'side',
            'focus': focus,
          }),
          'V26',
          mention: 'focus',
        );
      }
    });
    test('V26 : head_case seulement quand la vue contient le dessus', () {
      expectRule(
        withIllustration({
          'type': 'player_figure',
          'view': 'side',
          'head_case': 'cue_between_eyes',
        }),
        'V26',
        mention: 'head_case',
      );
    });
    test('V26 : lead_eye et bridge hors des listes', () {
      expectRule(
        withIllustration({
          'type': 'player_figure',
          'view': 'top',
          'lead_eye': 'both',
        }),
        'V26',
        mention: 'lead_eye',
      );
      expectRule(
        withIllustration({
          'type': 'player_figure',
          'view': 'side',
          'bridge': 'air',
        }),
        'V26',
        mention: 'bridge',
      );
    });
    test('V26 : annotations (ancienne clé de stance_top) refusée', () {
      expectRule(
        withIllustration({
          'type': 'player_figure',
          'view': 'top',
          'annotations': ['x'],
        }),
        'V1',
        mention: 'annotations',
      );
    });

    test('V27 : niveaux hors des listes fermées', () {
      expectRule(
        withIllustration({
          'type': 'power_ratio',
          'points': [
            {'amplitude': 'huge', 'speed': 'slow'},
          ],
        }),
        'V27',
        mention: 'amplitude',
      );
      expectRule(
        withIllustration({
          'type': 'power_ratio',
          'points': [
            {'amplitude': 'short', 'speed': 3},
          ],
        }),
        'V27',
        mention: 'speed',
      );
    });
    test('V27 : highlight hors des points', () {
      expectRule(
        withIllustration({'type': 'power_ratio', 'highlight': 0}),
        'V27',
        mention: 'highlight',
      );
    });
    test('V27 : au plus deux exemples par illustration', () {
      final point = {'amplitude': 'short', 'speed': 'slow'};
      expectRule(
        withIllustration({
          'type': 'power_ratio',
          'points': [point, point, point],
        }),
        'V27',
        mention: 'points',
      );
    });
    test('V27 : aucune clé levels ni cran', () {
      expectRule(
        withIllustration({'type': 'power_ratio', 'levels': 5}),
        'V1',
        mention: 'levels',
      );
    });
  });

  group('V18 sources', () {
    test('sources vides', () {
      expectRule(broken((d) => d['sources'] = <Object?>[]), 'V18');
    });
    test('fichier [S] absent de docs/sources', () {
      expectRule(
        broken(
          (d) => _obj((d['sources']! as List).first)['file'] = 'Inconnu.pdf',
        ),
        'V18',
        mention: 'Inconnu.pdf',
      );
    });
    test('rang de source inconnu', () {
      expectRule(
        broken((d) => _obj((d['sources']! as List).first)['rank'] = 'Prop'),
        'V18',
        mention: 'rank',
      );
    });
    test('exercice [Prop] sans source [S] dont il est adapté', () {
      final errors = broken((d) {
        for (final s in d['sources']! as List) {
          final m = _obj(s);
          m['rank'] = 'Web';
        }
        _exercises(d).first['src'] = 'Prop';
      });
      expectRule(errors, 'V18', mention: 'Prop');
    });
  });

  group("V19 aucune présentation « officielle » d'une proposition", () {
    test('mot officiel dans un défi ludique', () {
      expectRule(
        broken(
          (d) => _obj(_exercises(d).first['playful'])['hook'] =
              'Le défi officiel.',
        ),
        'V19',
      );
    });
    test('mot officiel dans le thème (casse ignorée)', () {
      expectRule(
        broken((d) => _obj(d['theme'])['pitch'] = 'Un gâteau OFFICIEL.'),
        'V19',
      );
    });
    test('mot officiel dans la variante ludique', () {
      expectRule(
        broken((d) => _game(d)['playful_variant'] = 'Règle officielle.'),
        'V19',
      );
    });
    test('mot officiel dans un jeu adapté', () {
      expectRule(
        broken((d) {
          _game(d)['adapted'] = true;
          _game(d)['src'] = 'Prop';
          _game(d)['rules'] = ['Règle officielle.'];
        }),
        'V19',
      );
    });
    test('chemin docs/sources hors de sources[].file', () {
      expectRule(
        broken(
          (d) => (d['uncertainties']! as List).add(
            'Voir docs/sources/Fiches Jeux CFA blackball.pdf.',
          ),
        ),
        'V19',
        mention: 'docs/sources',
      );
    });
    test('docs/sources reste permis dans sources[].file', () {
      expect(
        broken((d) => _obj((d['sources']! as List).first)['note'] = 'ok'),
        isEmpty,
      );
    });
  });

  group('V20 ludique', () {
    test('thème absent', () {
      expectRule(broken((d) => d.remove('theme')), 'V1');
      expectRule(broken((d) => d['theme'] = null), 'V20');
    });
    test('nom de thème de plus de 4 mots', () {
      expectRule(
        broken((d) => _obj(d['theme'])['name'] = 'un deux trois quatre cinq'),
        'V20',
      );
    });
    test('nom de thème de 4 mots : borne acceptée', () {
      expect(
        broken((d) => _obj(d['theme'])['name'] = 'un deux trois quatre'),
        isEmpty,
      );
    });
    test('nom de thème de 1 mot refusé, de 2 mots accepté', () {
      expectRule(broken((d) => _obj(d['theme'])['name'] = 'gâteau'), 'V20');
      expect(broken((d) => _obj(d['theme'])['name'] = 'un gâteau'), isEmpty);
    });
    test('accroche vide', () {
      expectRule(
        broken((d) => _obj(_exercises(d).first['playful'])['hook'] = ''),
        'V20',
        mention: 'hook',
      );
    });
    test('défi absent', () {
      expectRule(
        broken((d) => _obj(_exercises(d).last['playful']).remove('challenge')),
        'V20',
      );
    });
    test("playful absent d'un exercice", () {
      expectRule(broken((d) => _exercises(d).first.remove('playful')), 'V20');
    });
    test('variante ludique vide', () {
      expectRule(
        broken((d) => _game(d)['playful_variant'] = ''),
        'V20',
        mention: 'playful_variant',
      );
    });
  });

  group("V21 fiches d'initiation", () {
    Json initiation(Json d) => _obj((d['initiation']! as List).first);

    test("fiche d'initiation inexistante", () {
      expectRule(
        broken((d) => initiation(d)['initiation_sheet'] = 99),
        'V21',
        mention: '99',
      );
    });
    test("fiche d'une autre technique", () {
      expectRule(
        broken((d) => initiation(d)['initiation_sheet'] = 6),
        'V21',
        mention: 'technique',
      );
    });
  });

  group('V24 illustration jamais visible', () {
    const unused = {
      'id': 'orpheline',
      'type': 'pdf_ref',
      'file': 'Fiches techniques CFA BàP.pdf',
      'page': 5,
      'caption': 'Renvoi.',
      'alt': 'Renvoi à la page 5.',
    };

    /// Séance suivante (`demi-bille-2`) qui reprend [illustration] en rappel.
    Map<String, Json> next(String? illustration) => {
      'demi-bille-2': {
        'recall': {
          'reuse': {'sheet': 'demi-bille-1', 'illustration': ?illustration},
        },
      },
    };

    test('le pilote est vert quand la séance suivante est connue', () {
      expect(run(_pilot(), siblings: next('contact-demi')), isEmpty);
    });

    test('une illustration que rien ne cite est refusée', () {
      final errors = broken(
        (d) => (d['illustrations']! as List).add(unused),
        siblings: next(null),
      );

      expectRule(errors, 'V24', mention: 'orpheline');
    });

    test('une illustration reprise en rappel par la suivante est valide', () {
      final errors = broken(
        (d) => (d['illustrations']! as List).add(unused),
        siblings: next('orpheline'),
      );

      expect(errors.where((e) => e.startsWith('V24')), isEmpty);
    });

    test('une illustration citée par la théorie est valide', () {
      final errors = broken((d) {
        (d['illustrations']! as List).add(unused);
        final sections = _obj(d['theory'])['sections']! as List;
        _obj(sections.first)['illustrations'] = [
          ...(_obj(sections.first)['illustrations']! as List),
          'orpheline',
        ];
      }, siblings: next(null));

      expect(errors.where((e) => e.startsWith('V24')), isEmpty);
    });

    test('non contrôlée tant que la séance suivante est absente', () {
      final errors = broken((d) => (d['illustrations']! as List).add(unused));

      expect(errors.where((e) => e.startsWith('V24')), isEmpty);
    });
  });

  group('V22 rang 1 et partie > 1', () {
    Json asFirst(Json d) => d
      ..['id'] = 'posture-1'
      ..['order'] = 1
      ..['technique'] = 'posture'
      ..['catalogue_block'] = 'posture'
      ..['previous'] = null;

    test('rang 1 : recall.reuse interdit', () {
      final errors = broken((d) {
        asFirst(d);
        _game(d).remove('link_previous');
      }, fileName: '01-posture-1.yaml');
      expectRule(errors, 'V22', mention: 'reuse');
    });
    test('rang 1 : link_previous interdit', () {
      final errors = broken((d) {
        asFirst(d);
        _obj(d['recall']).remove('reuse');
      }, fileName: '01-posture-1.yaml');
      expectRule(errors, 'V14');
    });
    test('reuse.sheet différent de previous', () {
      expectRule(
        broken(
          (d) => _obj(_obj(d['recall'])['reuse'])['sheet'] = 'puissance-2',
        ),
        'V22',
        mention: 'previous',
      );
    });
    test("partie 2 dont previous n'est pas la partie 1", () {
      final errors = broken((d) {
        d['id'] = 'demi-bille-2';
        d['order'] = 9;
        d['part'] = 2;
        d['previous'] = 'bille-pleine-2';
      }, fileName: '09-demi-bille-2.yaml');
      expectRule(errors, 'V22', mention: 'suit demi-bille-1');
      expectRule(errors, 'V3', mention: 'attendu demi-bille-1');
    });
  });

  group('répertoire (V2 à V23 entre fichiers, --complete)', () {
    late Directory dir;

    Json part2() {
      final d = _pilot()
        ..['id'] = 'demi-bille-2'
        ..['order'] = 9
        ..['part'] = 2
        ..['previous'] = 'demi-bille-1';
      final ex = _exercises(d);
      ex[0]['ref'] = {'block': 'demi-bille', 'n': 3};
      ex[0]['diagram'] = 'entrainement-p06-e3';
      ex[1]['ref'] = {'block': 'demi-bille', 'n': 4};
      ex[1]['diagram'] = 'entrainement-p06-e4';
      _obj(_obj(d['recall'])['reuse'])
        ..['sheet'] = 'demi-bille-1'
        ..['illustration'] = 'contact-demi';
      _game(d)['playful_variant'] =
          'Chaque joueur nomme sa poche avant de tirer.';
      _obj(_game(d)['link_previous'])['notion_of'] = 'demi-bille-1';
      return d;
    }

    void write(String name, Json doc) =>
        File('${dir.path}/$name').writeAsStringSync(jsonEncode(doc));

    DirectoryReport check({bool complete = false}) =>
        validateDirectory(dir.path, context, complete: complete);

    setUp(() {
      dir = Directory.systemTemp.createTempSync('fiches_');
      write(_pilotName, _pilot());
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('un dossier avec le seul pilote est vert hors --complete', () {
      final report = check();
      expect(report.ok, isTrue, reason: '${report.allErrors}');
      expect(report.files, [_pilotName]);
    });

    test('--complete : les 27 autres séances manquent (V2)', () {
      final report = check(complete: true);
      expect(report.ok, isFalse);
      final missing = report.globalErrors.where((e) => e.startsWith('V2 '));
      expect(missing, hasLength(27));
      expect(missing.join('\n'), contains('01-posture-1.yaml'));
    });

    test('--complete : V5 couvre la plage de la technique', () {
      final report = check(complete: true);
      final v5 = report.globalErrors.where((e) => e.startsWith('V5'));

      expect(v5.single, contains('demi-bille'));
      expect(v5.single, contains('[3, 4]'));
    });

    test('deux parties cohérentes : vert', () {
      write('09-demi-bille-2.yaml', part2());
      final report = check();
      expect(report.ok, isTrue, reason: '${report.allErrors}');
    });

    test('V23 : notion différente entre deux parties', () {
      final d = part2()..['notion'] = 'Autre notion.';
      write('09-demi-bille-2.yaml', d);
      final report = check();
      expectRule(report.globalErrors, 'V23', mention: 'notion');
    });

    test('V23 : nom de thème différent', () {
      final d = part2();
      _obj(d['theme'])['name'] = 'Un autre thème';
      write('09-demi-bille-2.yaml', d);
      expectRule(check().globalErrors, 'V23', mention: 'theme.name');
    });

    test('V23 : variante ludique identique à la partie précédente', () {
      final d = part2();
      _game(d)['playful_variant'] = _game(_pilot())['playful_variant'];
      write('09-demi-bille-2.yaml', d);
      expectRule(check().globalErrors, 'V23', mention: 'playful_variant');
    });

    test('V2 : identifiant en double dans deux fichiers', () {
      write('10-demi-bille-1.yaml', _pilot());
      final report = check();
      expectRule(report.globalErrors, 'V2', mention: 'double');
    });

    test('V7 : reuse contrôlé dès que la séance précédente est présente', () {
      final d = part2();
      _obj(_obj(d['recall'])['reuse'])['illustration'] = 'absente';
      write('09-demi-bille-2.yaml', d);
      final report = check();
      expectRule(report.errorsByFile['09-demi-bille-2.yaml']!, 'V7');
    });

    test('un fichier non YAML du dossier est ignoré', () {
      File('${dir.path}/FORMAT.md').writeAsStringSync('# format');
      expect(check().ok, isTrue);
    });
  });

  group('tableaux du FORMAT.md (T1)', () {
    late String format;
    setUpAll(
      () => format = File('$_catalogueDir/FORMAT.md').readAsStringSync(),
    );

    test('le FORMAT.md réel est égal à la structure calculée', () {
      expect(checkFormatTables(format, context.structure), isEmpty);
    });

    test('un nombre de parties périmé est détecté', () {
      final stale = format.replaceFirst(
        RegExp(r'\| \*\*2\*\* \| 1-2 / 3-4 \|'),
        '| **3** | 1-2 / 3-4 |',
      );
      expect(stale, isNot(format));
      final errors = checkFormatTables(stale, context.structure);
      expect(errors.first, startsWith('T1'));
    });

    test('une ligne du tableau des séances modifiée est détectée', () {
      final stale = format.replaceFirst(
        '| 8 | `demi-bille-1` | 1-2 | `bille-pleine-2` |',
        '| 8 | `demi-bille-1` | 1-2 | `puissance-2` |',
      );
      expect(stale, isNot(format));
      expect(checkFormatTables(stale, context.structure), isNotEmpty);
    });

    test('un FORMAT sans tableau est une erreur', () {
      expect(checkFormatTables('# rien', context.structure), isNotEmpty);
    });
  });

  group('ligne de commande', () {
    String out0(StringBuffer b) => b.toString();

    test('sans argument : valide le dossier du catalogue, exit 0', () {
      final out = StringBuffer();
      final err = StringBuffer();
      final code = runCli(const [], out: out, err: err);
      expect(code, 0, reason: '$err');
      expect(out0(out), contains(_pilotName));
    });

    test('--complete : vert sur les 28 séances du catalogue', () {
      final out = StringBuffer();
      final err = StringBuffer();
      final code = runCli(const ['--complete'], out: out, err: err);
      expect(code, 0, reason: '$err');
      expect(out0(out), contains(_pilotName));
    });

    test('fichier isolé vert', () {
      final out = StringBuffer();
      final err = StringBuffer();
      final code = runCli([_pilotPath], out: out, err: err);
      expect(code, 0, reason: '$err');
    });

    test('fichier isolé fautif : exit 1 et règle citée avec le fichier', () {
      final dir = Directory.systemTemp.createTempSync('fiches_cli_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final bad = _pilot()..['version'] = 2;
      final path = '${dir.path}/$_pilotName';
      File(path).writeAsStringSync(jsonEncode(bad));
      final out = StringBuffer();
      final err = StringBuffer();

      final code = runCli([path], out: out, err: err);

      expect(code, 1);
      expect(err.toString(), contains(_pilotName));
      expect(err.toString(), contains('V1'));
    });

    test('--complete : une fiche corrompue du dossier donne exit 1 (V1)', () {
      final root = _copyRoot();
      final target = File(
        '$root/docs/knowledge/05-seances/catalogue/$_badName',
      );
      target.writeAsStringSync(
        target.readAsStringSync().replaceFirst('version: 1', 'version: 2'),
      );
      final out = StringBuffer();
      final err = StringBuffer();

      final code = runCli(const ['--complete'], out: out, err: err, root: root);

      expect(code, 1);
      expect(err.toString(), contains(_badName));
      expect(err.toString(), contains('V1'));
    });

    test('--complete : 27 fiches sur 28 donnent exit 1 (V2)', () {
      final root = _copyRoot();
      File('$root/docs/knowledge/05-seances/catalogue/$_badName').deleteSync();
      final out = StringBuffer();
      final err = StringBuffer();

      final code = runCli(const ['--complete'], out: out, err: err, root: root);

      expect(code, 1);
      expect(err.toString(), contains('V2'));
      expect(err.toString(), contains(_badName));
    });

    test('fichier introuvable : exit 2', () {
      final out = StringBuffer();
      final err = StringBuffer();
      final code = runCli(const ['/nulle/part.yaml'], out: out, err: err);
      expect(code, 2);
    });

    test('option inconnue : exit 2', () {
      final err = StringBuffer();
      expect(runCli(const ['--nope'], out: StringBuffer(), err: err), 2);
    });

    test('--structure affiche les 28 séances', () {
      final out = StringBuffer();
      final code = runCli(const ['--structure'], out: out, err: StringBuffer());
      expect(code, 0);
      final lines = out.toString().trim().split('\n');

      // 1 en-tête + 28 séances, une par ligne.
      expect(lines, hasLength(29));
      expect(lines.first, startsWith('rang'));
      expect(lines.last, startsWith('28  retro-4  9-10  retro-3'));
      expect(out.toString(), contains('9  demi-bille-2  3-4  demi-bille-1'));
    });

    test('--structure seul ne lit aucune séance', () {
      final out = StringBuffer();
      runCli(const ['--structure'], out: out, err: StringBuffer());
      expect(out.toString(), isNot(contains('OK ')));
    });

    test('racine inexistante : exit 2', () {
      final err = StringBuffer();
      expect(
        runCli(const [], out: StringBuffer(), err: err, root: '/nulle/part'),
        2,
      );
    });
  });
}

/// Catalogue minimal : [blocks] associe un bloc à ses sessions et à son
/// nombre d'exercices ; les autres blocs de technique sont ajoutés avec
/// 4 exercices et 1 à 2 séances.
String _catalogueWith(Map<String, ({int min, int max, int n})> blocks) {
  const ids = [
    'posture',
    'puissance',
    'bille-fantome',
    'bille-pleine',
    'demi-bille',
    'trois-quarts',
    'quart-finesses',
    'rebond-bande',
    'rejet-naturel',
    'coule',
    'carreau',
    'angle-droit',
    'retro',
  ];
  final b = StringBuffer('blocks:\n');
  for (final id in ids) {
    final spec = blocks[id] ?? (min: 1, max: 2, n: 4);
    b
      ..writeln('  - id: $id')
      ..writeln('    title: Bloc $id')
      ..writeln('    sessions: {min: ${spec.min}, max: ${spec.max}}')
      ..writeln('    exercises:');
    for (var n = 1; n <= spec.n; n++) {
      b.writeln('      - {n: $n, rate: [3, 5]}');
    }
  }
  return b.toString();
}
