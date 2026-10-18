// Bornes de taille et forme des champs (ADR 0024 décisions 13 et 25, ADR 0025 décision 4) :
// prénom, initiale, nom affiché, nom de club, commentaire d'évaluation, champs inconnus,
// contre l'émulateur Firestore (lot FB3). Chaque borne a son cas juste en dessous (accepté) et
// juste au-dessus (refusé) : un seuil déplacé fait échouer le test.
import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, test } from 'node:test';

import { doc, serverTimestamp, setDoc, updateDoc, writeBatch } from 'firebase/firestore';

import { allowed, complete, createEnv, dbOf, invitation, member, now, owned, put, remove, seed, student, ts } from './support.mjs';

let env;
before(async () => {
  env = await createEnv();
});
after(async () => {
  await env?.cleanup();
});
beforeEach(async () => {
  await seed(env);
});

const text = (n) => 'é'.repeat(n);

describe('fiche élève : prénom et initiale (minimisation)', () => {
  const create = (data) => allowed(() => setDoc(doc(dbOf(env, 'director'), 'clubs/c1/students/n1'), data));

  test('le prénom compte de 1 à 40 caractères', async () => {
    assert.equal(await create(student(['g1'], { firstName: text(40) })), true, '40');
    assert.equal(await create(student(['g1'], { firstName: text(41) })), false, '41');
    assert.equal(await create(student(['g1'], { firstName: '' })), false, 'vide');
    assert.equal(await create(student(['g1'], { firstName: 42 })), false, 'pas un texte');
  });

  test('le prénom est obligatoire, les groupes aussi (liste)', async () => {
    assert.equal(await create({ groupIds: ['g1'] }), false, 'sans prénom');
    assert.equal(await create({ firstName: 'Léa' }), false, 'sans groupes');
    assert.equal(await create({ firstName: 'Léa', groupIds: 'g1' }), false, 'groupes pas une liste');
    assert.equal(await create(student(Array.from({ length: 31 }, (_, i) => `g${i}`))), false, '31 groupes');
  });

  test('l\'initiale est une seule lettre (accents compris)', async () => {
    assert.equal(await create(student(['g1'], { initial: 'D' })), true, 'une lettre');
    assert.equal(await create(student(['g1'], { initial: 'É' })), true, 'une lettre accentuée');
    assert.equal(await create(student(['g1'], { initial: 'Du' })), false, 'deux lettres');
    assert.equal(await create(student(['g1'], { initial: '' })), false, 'vide');
    assert.equal(await create(student(['g1'], { initial: '7' })), false, 'un chiffre');
    assert.equal(await create(student(['g1'], { initial: 'D.' })), false, 'avec un point');
  });

  test('aucun texte libre ni champ inconnu sur la fiche (pas de nom de famille, de note, de téléphone)', async () => {
    for (const key of ['lastName', 'notes', 'phone', 'birthYear', 'email']) {
      assert.equal(await create(student(['g1'], { [key]: 'x' })), false, key);
    }
  });

  test('le public est « children » ou « adults »', async () => {
    assert.equal(await create(student(['g1'], { audience: 'children' })), true);
    assert.equal(await create(student(['g1'], { audience: 'adults' })), true);
    assert.equal(await create(student(['g1'], { audience: 'seniors' })), false);
  });

  describe('historique du public (FB4)', () => {
    const change = (audience, effectiveFrom = '2026-09-01T00:00:00.000') => ({ audience, effectiveFrom });
    const history = (n) =>
      Array.from({ length: n }, (_, i) => change(i % 2 === 0 ? 'children' : 'adults', `2026-09-${String(i + 1).padStart(2, '0')}T00:00:00.000`));

    test('de 1 à 10 changements, chacun { audience, effectiveFrom }', async () => {
      assert.equal(await create(student(['g1'], { audienceHistory: history(1) })), true, '1');
      assert.equal(await create(student(['g1'], { audienceHistory: history(10) })), true, '10');
      assert.equal(await create(student(['g1'], { audienceHistory: history(11) })), false, '11');
      assert.equal(await create(student(['g1'], { audienceHistory: [] })), false, 'vide');
      assert.equal(await create(student(['g1'], { audienceHistory: 'children' })), false, 'pas une liste');
    });

    test('chaque élément est contrôlé, même le dixième', async () => {
      const at = (i, bad) => history(10).map((c, j) => (j === i ? bad : c));
      for (const i of [0, 4, 9]) {
        assert.equal(await create(student(['g1'], { audienceHistory: at(i, change('seniors')) })), false, `public ${i}`);
        assert.equal(await create(student(['g1'], { audienceHistory: at(i, { ...change('children'), note: 'x' }) })), false, `champ en trop ${i}`);
        assert.equal(await create(student(['g1'], { audienceHistory: at(i, { audience: 'children' }) })), false, `sans date ${i}`);
        assert.equal(await create(student(['g1'], { audienceHistory: at(i, 'x') })), false, `pas une table ${i}`);
        assert.equal(await create(student(['g1'], { audienceHistory: at(i, change('children', 'x'.repeat(41))) })), false, `date longue ${i}`);
      }
    });

    test('chaque date est un texte ISO exact (calendrier compris), même la dixième', async () => {
      const at = (i, bad) => history(10).map((c, j) => (j === i ? bad : c));
      const bads = ['pas une date', '2026-09-01', '2026-13-01T00:00:00', '2026-00-10T00:00:00', '2026-09-32T00:00:00',
        '2026-09-00T00:00:00', '2026-09-01T24:00:00', '2026-09-01T00:60:00', '2026-09-01T00:00:60', '2026-09-01T00:00:00+02:00'];
      for (const i of [0, 4, 9]) {
        for (const bad of bads) {
          assert.equal(await create(student(['g1'], { audienceHistory: at(i, change('children', bad)) })), false, `${bad} ${i}`);
        }
      }
    });

    test('la date est un texte ISO complet ou un horodatage', async () => {
      assert.equal(await create(student(['g1'], { audienceHistory: [change('children', ts(now()))] })), true);
      assert.equal(await create(student(['g1'], { audienceHistory: [change('children', 7)] })), false);
    });

    test('la mise à jour d\'une fiche publiée par FB3 ajoute l\'historique', async () => {
      const db = dbOf(env, 'director');
      assert.equal(await allowed(() => updateDoc(doc(db, 'clubs/c1/students/s1'), { audienceHistory: history(2) })), true);
      assert.equal(await allowed(() => updateDoc(doc(db, 'clubs/c1/students/s1'), { audienceHistory: history(11) })), false);
    });
  });

  test('la mise à jour est soumise aux mêmes bornes', async () => {
    const db = dbOf(env, 'director');
    assert.equal(await allowed(() => updateDoc(doc(db, 'clubs/c1/students/s1'), { firstName: text(41) })), false);
    assert.equal(await allowed(() => updateDoc(doc(db, 'clubs/c1/students/s1'), { firstName: text(40) })), true);
  });
});

describe('member : nom affiché', () => {
  const join = (displayName) => {
    const db = dbOf(env, 'invited');
    const batch = writeBatch(db);
    batch.set(doc(db, 'clubs/c1/members/u-invited'), {
      ...member('u-invited', 'teacher', { groupIds: ['g1'] }),
      displayName,
      invitationCode: 'JOINJOINJO',
      createdAt: serverTimestamp(),
    });
    batch.update(doc(db, 'invitations/JOINJOINJO'), { used: true, usedBy: 'u-invited', usedAt: serverTimestamp() });
    return allowed(() => batch.commit());
  };

  test('le nom affiché compte de 1 à 40 caractères, à la création et à la mise à jour', async () => {
    await put(env, 'invitations/JOINJOINJO', invitation({ role: 'teacher', groupIds: ['g1'], studentIds: [] }));
    assert.equal(await join(text(41)), false, '41 à la création');
    assert.equal(await join(''), false, 'vide à la création');
    assert.equal(await join(7), false, 'pas un texte');
    assert.equal(await join(text(40)), true, '40 à la création');
    const own = (name) => allowed(() => updateDoc(doc(dbOf(env, 'invited'), 'clubs/c1/members/u-invited'), { displayName: name }));
    assert.equal(await own(text(41)), false, '41 à la mise à jour');
    assert.equal(await own(''), false, 'vide à la mise à jour');
    assert.equal(await own(text(40)), true, '40 à la mise à jour');
  });

  test('au plus 30 groupes et 30 fiches liés par member', async () => {
    const db = dbOf(env, 'director');
    const create = (extra) => allowed(() => setDoc(doc(db, 'clubs/c1/members/u-x'), { ...member('u-x', 'teacher'), createdAt: serverTimestamp(), ...extra }));
    const ids = (n) => Array.from({ length: n }, (_, i) => `g${i}`);
    assert.equal(await create({ groupIds: ids(30) }), true, '30 groupes');
    await remove(env, 'clubs/c1/members/u-x');
    assert.equal(await create({ groupIds: ids(31) }), false, '31 groupes');
    assert.equal(await create({ studentIds: ids(31) }), false, '31 fiches');
    assert.equal(await create({ groupIds: 'g1' }), false, 'groupes pas une liste');
    assert.equal(await create({ groupIds: ['x'.repeat(900 * 1024)] }), false, 'groupe de 900 Ko');
  });
});

describe('club et réglages', () => {
  test('le nom du club compte de 1 à 80 caractères', async () => {
    const db = dbOf(env, 'admin');
    const create = (name) => allowed(() => setDoc(doc(db, 'clubs/c9'), { name, createdAt: serverTimestamp() }));
    assert.equal(await create(text(81)), false, '81');
    assert.equal(await create(''), false, 'vide');
    assert.equal(await create(text(80)), true, '80');
    const rename = (name) => allowed(() => updateDoc(doc(dbOf(env, 'director'), 'clubs/c1'), { name }));
    assert.equal(await rename(text(81)), false, '81 à la mise à jour');
    assert.equal(await rename(''), false, 'vide à la mise à jour');
    assert.equal(await rename(text(80)), true, '80 à la mise à jour');
  });

  test('l\'identifiant d\'un club est simple (lettres, chiffres, tiret, souligné)', async () => {
    const db = dbOf(env, 'admin');
    assert.equal(await allowed(() => setDoc(doc(db, 'clubs/mon club'), { name: 'X', createdAt: serverTimestamp() })), false);
    assert.equal(await allowed(() => setDoc(doc(db, `clubs/${'a'.repeat(65)}`), { name: 'X', createdAt: serverTimestamp() })), false);
    assert.equal(await allowed(() => setDoc(doc(db, `clubs/${'a'.repeat(64)}`), { name: 'X', createdAt: serverTimestamp() })), true);
  });

  test('un champ inconnu sur le club est refusé', async () => {
    const db = dbOf(env, 'admin');
    assert.equal(await allowed(() => setDoc(doc(db, 'clubs/c9'), { name: 'X', createdAt: serverTimestamp(), siret: '1' })), false);
  });

  test('les réglages sont des entiers dans leurs bornes ; aucun champ inconnu', async () => {
    const db = dbOf(env, 'director');
    const base = { passesRequired: 5, alertThreshold: 3, recallStaleSessions: 4, groupFailureSharePercent: 50 };
    const write = (patch) => allowed(() => setDoc(doc(db, 'clubs/c1/settings/main'), { ...base, ...patch }));
    assert.equal(await write({}), true);
    assert.equal(await write({ passesRequired: 0 }), false, 'seuil 0');
    assert.equal(await write({ passesRequired: 101 }), false, 'seuil 101');
    assert.equal(await write({ passesRequired: 100 }), true, 'seuil 100');
    assert.equal(await write({ passesRequired: 2.5 }), false, 'décimal');
    assert.equal(await write({ passesRequired: '5' }), false, 'texte');
    assert.equal(await write({ groupFailureSharePercent: 101 }), false, 'pourcentage 101');
    assert.equal(await write({ groupFailureSharePercent: 100 }), true, 'pourcentage 100');
    assert.equal(await write({ backupReminderDays: 366 }), false, 'rappel 366 jours');
    assert.equal(await write({ backupReminderDays: 365 }), true, 'rappel 365 jours');
    assert.equal(await write({ notes: 'x' }), false, 'champ inconnu');
  });
});

describe('données de groupe : identifiants dénormalisés et taille', () => {
  const director = () => dbOf(env, 'director');
  const create = (collectionName, data) =>
    allowed(() => setDoc(doc(director(), `clubs/c1/${collectionName}/n1`),
      // La création d'une saisie ou d'un passage exige `createdAt == request.time` (ouverture
      // concurrente, ordre d'enregistrement) ; celle d'un acquittement, `createdBy` = uid (B5).
      collectionName === 'records' || collectionName === 'attempts'
        ? { createdAt: serverTimestamp(), ...complete(collectionName, data) }
        : collectionName === 'acknowledgements'
          ? { createdBy: 'u-dir', ...complete(collectionName, data) }
          : complete(collectionName, data)));

  test('groupId et seasonId sont obligatoires, en texte non vide', async () => {
    for (const name of ['sessions', 'records']) {
      assert.equal(await create(name, { groupId: 'g1', seasonId: 'se1' }), true, `${name} complet`);
      await remove(env, `clubs/c1/${name}/n1`);
      assert.equal(await create(name, { seasonId: 'se1' }), false, `${name} sans groupId`);
      assert.equal(await create(name, { groupId: 'g1' }), false, `${name} sans seasonId`);
      assert.equal(await create(name, { groupId: '', seasonId: 'se1' }), false, `${name} groupId vide`);
      assert.equal(await create(name, { groupId: 7, seasonId: 'se1' }), false, `${name} groupId non texte`);
    }
  });

  test('studentId est obligatoire pour passages, acquis, bilans, acquittements et appartenances', async () => {
    for (const name of ['attempts', 'acquisitions', 'assessments', 'acknowledgements', 'memberships']) {
      assert.equal(await create(name, owned('g1', 's1')), true, `${name} complet`);
      await remove(env, `clubs/c1/${name}/n1`);
      assert.equal(await create(name, owned('g1')), false, `${name} sans studentId`);
    }
  });

  test('la fiche doit exister (une donnée d\'un élève effacé ne ressuscite pas)', async () => {
    for (const name of ['attempts', 'acquisitions', 'assessments', 'acknowledgements']) {
      assert.equal(await create(name, owned('g1', 'efface')), false, name);
    }
    await remove(env, 'clubs/c1/students/s1');
    assert.equal(await create('attempts', owned('g1', 's1')), false, 'fiche effacée entre-temps');
  });

  test('les champs d\'appartenance ne changent pas après la création', async () => {
    const db = director();
    for (const patch of [{ groupId: 'g2' }, { seasonId: 'se2' }]) {
      assert.equal(await allowed(() => updateDoc(doc(db, 'clubs/c1/attempts/a-g1'), patch)), false, JSON.stringify(patch));
    }
    assert.equal(await allowed(() => updateDoc(doc(db, 'clubs/c1/attempts/a-g1'), { studentId: 's2' })), false, 'studentId');
    assert.equal(await allowed(() => updateDoc(doc(db, 'clubs/c1/attempts/a-g1'), { potted: 3 })), true, 'un champ de la liste blanche passe');
    assert.equal(await allowed(() => updateDoc(doc(db, 'clubs/c1/attempts/a-g1'), { note: 'ok' })), false, 'un champ hors liste est refusé');
  });

  test('liste blanche de champs : un champ inconnu est refusé dans chaque collection de données', async () => {
    const withExtra = (name) => ({ ...owned('g1', name === 'records' || name === 'sessions' ? undefined : 's1'), nomPrenomSante: 'x' });
    for (const name of ['sessions', 'records', 'attempts', 'acquisitions', 'assessments', 'acknowledgements', 'memberships']) {
      assert.equal(await create(name, withExtra(name)), false, `${name} : champ libre`);
    }
  });

  test('un champ libre de 900 Ko est refusé, un champ connu trop long aussi', async () => {
    const big = 'x'.repeat(900 * 1024);
    assert.equal(await create('records', { ...owned('g1'), contenu: big }), false, 'champ inconnu de 900 Ko');
    assert.equal(await create('records', { ...owned('g1'), mainBlockId: big }), false, 'champ connu de 900 Ko');
    assert.equal(await create('records', { ...owned('g1'), mainBlockId: 'x'.repeat(64) }), true, '64 caractères');
    await remove(env, 'clubs/c1/records/n1');
    assert.equal(await create('records', { ...owned('g1'), mainBlockId: 'x'.repeat(65) }), false, '65 caractères');
  });

  test('étiquettes de séance : codes prédéfinis seulement, jamais de texte libre', async () => {
    const tags = (value) => create('records', { ...owned('g1'), tags: value });
    const codes = ['gameAppreciated', 'instructionsToRephrase', 'tooLong', 'tooShort', 'tooHard', 'tooEasy', 'toRedo', 'equipmentLacking'];
    assert.equal(await tags(codes), true, 'les huit codes de SessionTag');
    await remove(env, 'clubs/c1/records/n1');
    assert.equal(await tags(['x']), false, 'un code inconnu, même court');
    assert.equal(await tags(['Julie a pleuré']), false, 'texte libre');
    assert.equal(await tags([...codes.slice(0, 7), 'x']), false, 'un code inconnu parmi les codes connus');
    assert.equal(await tags('tooLong'), false, 'pas une liste');
    assert.equal(await tags(Array(9).fill('tooLong')), false, 'plus de 8');
  });

  test('passages et bilans : types et bornes des valeurs', async () => {
    const attempt = (extra) => create('attempts', { ...owned('g1', 's1'), ...extra });
    assert.equal(await attempt({ potted: 16, total: 16, exerciseNumber: 1000 }), true, 'bornes hautes');
    await remove(env, 'clubs/c1/attempts/n1');
    assert.equal(await attempt({ potted: 101 }), false, 'potted 101');
    assert.equal(await attempt({ potted: '3' }), false, 'potted texte');
    assert.equal(await attempt({ exerciseNumber: 1001 }), false, 'exercice 1001');
    const score = (value) => create('assessments', { ...owned('g1', 's1'), concentration: value });
    assert.equal(await score(4), true, 'note 4');
    await remove(env, 'clubs/c1/assessments/n1');
    assert.equal(await score(5), false, 'note 5');
    assert.equal(await score(0), false, 'note 0');
  });

  test('un enseignant ne crée de donnée que sur un élève de SON groupe (A1)', async () => {
    const db = dbOf(env, 'teacherA');
    const stamped = (name, data) =>
      name === 'attempts' ? { createdAt: serverTimestamp(), ...complete(name, data) }
        : name === 'acknowledgements' ? { createdBy: 'u-teacher-a', ...complete(name, data) } : complete(name, data);
    const write = (name, data) => allowed(() => setDoc(doc(db, `clubs/c1/${name}/inj`), stamped(name, data)));
    for (const name of ['attempts', 'acquisitions', 'assessments', 'acknowledgements']) {
      assert.equal(await write(name, owned('g1', 's2')), false, `${name} : s2 est du seul groupe g2`);
      assert.equal(await write(name, owned('g1', 's1')), true, `${name} : s1 est du groupe g1`);
      await remove(env, `clubs/c1/${name}/inj`);
    }
    // L'enseignant du groupe g2 ne peut pas non plus écrire pour s1 (hors de son groupe).
    assert.equal(await allowed(() => setDoc(doc(dbOf(env, 'teacherB'), 'clubs/c1/attempts/inj'), { createdAt: serverTimestamp(), ...complete('attempts', owned('g2', 's1')) })), false, 'teacherB sur s1');
  });

  test('le directeur crée une donnée sur une fiche existante (import d\'historique) mais pas sur une fiche absente', async () => {
    const db = dbOf(env, 'director');
    const stamped = (data) => ({ createdAt: serverTimestamp(), ...complete('attempts', data) });
    assert.equal(await allowed(() => setDoc(doc(db, 'clubs/c1/attempts/inj'), stamped(owned('g1', 's2')))), true, 'fiche existante');
    assert.equal(await allowed(() => setDoc(doc(db, 'clubs/c1/attempts/inj2'), stamped(owned('g1', 'absent')))), false, 'fiche absente');
  });

  test('le commentaire d\'évaluation est facultatif et borné à 500 caractères', async () => {
    const comment = (value) => create('assessments', { ...owned('g1', 's1'), comment: value });
    assert.equal(await comment('x'.repeat(500)), true, '500');
    await remove(env, 'clubs/c1/assessments/n1');
    assert.equal(await comment('x'.repeat(501)), false, '501');
    assert.equal(await comment(null), true, 'absent');
    await remove(env, 'clubs/c1/assessments/n1');
    assert.equal(await comment(12), false, 'pas un texte');
    assert.equal(await create('assessments', owned('g1', 's1')), true, 'sans commentaire');
    const edit = (value) => allowed(() => updateDoc(doc(director(), 'clubs/c1/assessments/as-g1'), { comment: value }));
    assert.equal(await edit('x'.repeat(501)), false, '501 à la mise à jour');
    assert.equal(await edit('x'.repeat(500)), true, '500 à la mise à jour');
  });

  test('nom d\'un groupe de 1 à 80 caractères, saison obligatoire, enseignants en liste', async () => {
    const group = (extra) => ({ seasonId: 'se1', name: 'Mardi', audience: 'children', teacherUids: [], ...extra });
    const write = (data) => allowed(() => setDoc(doc(director(), 'clubs/c1/groups/g9'), data));
    assert.equal(await write(group({ name: text(80) })), true, '80');
    assert.equal(await write(group({ name: text(81) })), false, '81');
    assert.equal(await write(group({ name: '' })), false, 'vide');
    assert.equal(await write(group({ teacherUids: 'u-teacher-a' })), false, 'enseignants pas une liste');
    assert.equal(await write({ name: 'x', teacherUids: [] }), false, 'sans saison');
  });

  test('libellé d\'une saison de 1 à 80 caractères', async () => {
    const write = (label) => allowed(() => setDoc(doc(director(), 'clubs/c1/seasons/se9'), { label }));
    assert.equal(await write(text(80)), true);
    assert.equal(await write(text(81)), false);
    assert.equal(await write(''), false);
  });
});

describe('bornes complémentaires : saisons, groupes, archives, réglages, club', () => {
  const director = () => dbOf(env, 'director');
  const many = (n) => Object.fromEntries(Array.from({ length: n }, (_, i) => [`f${i}`, i]));

  test('une saison n\'accepte que ses champs (liste blanche) et des dates courtes', async () => {
    const write = (extra) => allowed(() => setDoc(doc(director(), 'clubs/c1/seasons/se9'), { label: 'x', ...extra }));
    assert.equal(await write({ startDate: '2026-09-01T00:00:00.000', endDate: '2027-06-30T00:00:00.000', closedOn: null }), true, 'champs connus');
    assert.equal(await write({ startDate: 'zz' }), false, 'date illisible (écartée sans bruit par le décodeur)');
    assert.equal(await write({ closedOn: '2026-09-01' }), false, 'date sans heure : pas le texte des codecs');
    assert.equal(await write({ notes: 'x' }), false, 'champ inconnu');
    assert.equal(await write({ startDate: 'x'.repeat(900 * 1024) }), false, 'date de 900 Ko');
  });

  test('un groupe n\'accepte que ses champs, au plus 30 enseignants, identifiants en texte (A27)', async () => {
    const group = (extra) => ({ seasonId: 'se1', name: 'Mardi', audience: 'children', teacherUids: [], ...extra });
    const write = (data) => allowed(() => setDoc(doc(director(), 'clubs/c1/groups/g9'), data));
    assert.equal(await write(group({ createdAt: ts(now()) })), true, 'champ connu');
    assert.equal(await write(group({ notes: 'x' })), false, 'champ inconnu');
    assert.equal(await write(group({ name: 'x', teacherUids: [1] })), false, 'enseignant pas un texte');
    assert.equal(await write(group({ teacherUids: ['x'.repeat(900 * 1024)] })), false, 'identifiant de 900 Ko');
    assert.equal(await write(group({ name: 'x'.repeat(900 * 1024) })), false, 'nom de 900 Ko');
    const teachers = (n) => Array.from({ length: n }, (_, i) => `u${i}`);
    assert.equal(await write(group({ teacherUids: teachers(30) })), true, '30 enseignants');
    assert.equal(await write(group({ teacherUids: teachers(31) })), false, '31 enseignants');
  });

  test('une archive porte sa saison et que des compteurs bornés (liste blanche)', async () => {
    const write = (data) => allowed(() => setDoc(doc(director(), 'clubs/c1/archives/ar9'), data));
    assert.equal(await write({ seasonId: 'se1' }), true);
    assert.equal(await write({ public: 'children' }), false, 'sans saison');
    assert.equal(await write({ seasonId: 'se1', public: 'children', sessionCount: 30, studentCount: 12, blockId: 'b1', exerciseNumber: 2, potted: 40, total: 50 }), true, 'champs connus');
    assert.equal(await write({ seasonId: 'se1', studentId: 's1' }), false, 'aucun identifiant d\'élève');
    assert.equal(await write({ seasonId: 'se1', sessionCount: -1 }), false, 'compteur négatif');
    assert.equal(await write({ seasonId: 'se1', blockId: 'x'.repeat(900 * 1024) }), false, 'texte de 900 Ko');
  });

  test('chaque réglage est un entier dans sa borne (alerte, rappel d\'exercice)', async () => {
    const base = { passesRequired: 5, alertThreshold: 3, recallStaleSessions: 4, groupFailureSharePercent: 50 };
    const write = (patch) => allowed(() => setDoc(doc(director(), 'clubs/c1/settings/main'), { ...base, ...patch }));
    for (const key of ['alertThreshold', 'recallStaleSessions', 'groupFailureSharePercent']) {
      assert.equal(await write({ [key]: 0 }), false, `${key} 0`);
      assert.equal(await write({ [key]: 101 }), false, `${key} 101`);
      assert.equal(await write({ [key]: 100 }), true, `${key} 100`);
      assert.equal(await write({ [key]: 1 }), true, `${key} 1`);
    }
  });

  test('la date de création d\'un club est celle du serveur, et ne change plus', async () => {
    const admin = dbOf(env, 'admin');
    assert.equal(await allowed(() => setDoc(doc(admin, 'clubs/c9'), { name: 'X', createdAt: ts(now()) })), false, 'création avec une date du client');
    assert.equal(await allowed(() => updateDoc(doc(admin, 'clubs/c1'), { createdAt: ts(now()) })), false, 'mise à jour par l\'administrateur');
    assert.equal(await allowed(() => updateDoc(doc(dbOf(env, 'director'), 'clubs/c1'), { createdAt: ts(now()) })), false, 'mise à jour par le directeur');
    assert.equal(await allowed(() => updateDoc(doc(admin, 'clubs/c1'), { name: 'Renommé', currentSeasonId: 'se1' })), true, 'le nom et la saison passent');
  });
});
