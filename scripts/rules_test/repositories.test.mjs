// Dépôts Firestore de FB4 (settings, élèves, groupes, appartenances) : les MÊMES opérations que
// ceux de l'application, avec les mêmes chemins, les mêmes champs et les mêmes requêtes, contre
// l'émulateur et les VRAIES règles (lot FB4, partie 1).
//
// Pourquoi ce fichier : la suite de contrat Dart (`app/test/contract/firestore_contract_test.dart`)
// tourne sur `fake_cloud_firestore`, qui n'applique ni règles ni index ni chemins réels. Un test
// Dart sur la VM ne peut pas charger le plugin natif `cloud_firestore`, et le même test dans Chrome
// (`flutter test --platform chrome`) n'a pas abouti de façon stable (voir testing.md). Ce fichier
// comble ce que le faux ne prouve pas : chaque dépôt, joué dans chaque rôle, est ACCEPTÉ ou REFUSÉ
// par les règles comme le dépôt Dart le suppose.
//
// Les formes de documents ci-dessous sont COPIÉES des tests Dart (`firestore_*_repository_test`,
// « writes exactly the fields firestore.rules allows ») : si un champ change d'un côté, l'autre
// échoue. Aucune opération n'est une requête mal formée : un refus attendu vient des règles.
import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  Timestamp,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
  arrayRemove,
  arrayUnion,
} from 'firebase/firestore';

import { allowed, createEnv, dbOf, put, seed } from './support.mjs';

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

const C = 'clubs/c1';
const membershipId = (group, student, from) => `${C}/memberships/${group}_${student}_${from}`;
const FROM = '2026-09-01T00:00:00.000';

// Formes écrites par les dépôts Dart.
const studentCreate = (extra = {}) => ({
  firstName: 'Léa',
  audience: 'adults',
  audienceHistory: [
    { audience: 'children', effectiveFrom: '2026-09-01T00:00:00.000' },
    { audience: 'adults', effectiveFrom: '2028-09-01T00:00:00.000Z' },
  ],
  groupIds: [],
  createdAt: serverTimestamp(),
  ...extra,
});
const studentUpdate = {
  firstName: 'Léa-Rose',
  audience: 'adults',
  audienceHistory: [{ audience: 'adults', effectiveFrom: '2026-09-01T00:00:00.000' }],
};
const groupCreate = { seasonId: 'se1', name: 'Jeunes', audience: 'children', teacherUids: [] };
const groupUpdate = { seasonId: 'se1', name: 'Nouveau', audience: 'children' };
const membershipDoc = (group, student, extra = {}) => ({
  groupId: group,
  seasonId: 'se1',
  studentId: student,
  from: FROM,
  to: null,
  ...extra,
});
const settingsDoc = {
  passesRequired: 3,
  alertThreshold: 4,
  recallStaleSessions: 6,
  groupFailureSharePercent: 30,
  backupReminderDays: 14,
};

describe('réglages : clubs/{c}/settings/main', () => {
  test('le directeur écrit les cinq champs, tout membre les lit, le directeur les supprime', async () => {
    const dir = dbOf(env, 'director');
    assert.equal(await allowed(() => setDoc(doc(dir, `${C}/settings/main`), settingsDoc)), true);
    for (const actor of ['teacherA', 'guardian', 'student', 'director']) {
      assert.equal(await allowed(() => getDoc(doc(dbOf(env, actor), `${C}/settings/main`))), true, actor);
    }
    assert.equal(await allowed(() => deleteDoc(doc(dir, `${C}/settings/main`))), true);
  });

  test('un enseignant, un parent et un autre club ne les écrivent pas', async () => {
    for (const actor of ['teacherA', 'guardian', 'student', 'directorOther', 'invited']) {
      assert.equal(await allowed(() => setDoc(doc(dbOf(env, actor), `${C}/settings/main`), settingsDoc)), false, actor);
    }
  });

  test('sans backupReminderDays le document passe aussi (champ facultatif)', async () => {
    const { backupReminderDays, ...rest } = settingsDoc;
    assert.equal(await allowed(() => setDoc(doc(dbOf(env, 'director'), `${C}/settings/main`), rest)), true);
  });
});

describe('élèves : clubs/{c}/students/{id}', () => {
  test('le directeur crée la fiche (groupes vides, date du serveur, historique) puis la met à jour', async () => {
    const dir = dbOf(env, 'director');
    assert.equal(await allowed(() => setDoc(doc(dir, `${C}/students/n1`), studentCreate())), true, 'création');
    assert.equal(await allowed(() => updateDoc(doc(dir, `${C}/students/n1`), studentUpdate)), true, 'mise à jour');
    const stored = (await getDoc(doc(dir, `${C}/students/n1`))).data();
    assert.deepEqual(stored.groupIds, [], 'les groupes courants ne sont pas touchés par la mise à jour');
  });

  test('la mise à jour d\'une fiche publiée par FB3 (même document) ajoute l\'historique', async () => {
    assert.equal(await allowed(() => updateDoc(doc(dbOf(env, 'director'), `${C}/students/s1`), studentUpdate)), true);
    const stored = (await getDoc(doc(dbOf(env, 'director'), `${C}/students/s1`))).data();
    assert.deepEqual(stored.groupIds, ['g1']);
  });

  test('enregistrement fusionné (le dépôt Dart) : crée sans groupe, puis ne remplace jamais groupIds', async () => {
    const dir = dbOf(env, 'director');
    const own = { ...studentUpdate, groupIds: arrayUnion() };
    assert.equal(
      await allowed(() => setDoc(doc(dir, `${C}/students/n1`), { ...own, createdAt: serverTimestamp() }, { merge: true })),
      true,
      'création',
    );
    assert.deepEqual((await getDoc(doc(dir, `${C}/students/n1`))).data().groupIds, []);

    assert.equal(await allowed(() => setDoc(doc(dbOf(env, 'director'), `${C}/students/s1`), own, { merge: true })), true, 'mise à jour');
    assert.deepEqual((await getDoc(doc(dir, `${C}/students/s1`))).data().groupIds, ['g1']);
  });

  test('groupIds par union et retrait atomiques (le dépôt de groupes), sans lecture préalable', async () => {
    const dir = dbOf(env, 'director');
    assert.equal(await allowed(() => updateDoc(doc(dir, `${C}/students/s1`), { groupIds: arrayUnion('g3') })), true);
    assert.deepEqual((await getDoc(doc(dir, `${C}/students/s1`))).data().groupIds.sort(), ['g1', 'g3']);
    assert.equal(await allowed(() => updateDoc(doc(dir, `${C}/students/s1`), { groupIds: arrayRemove('g1') })), true);
    assert.deepEqual((await getDoc(doc(dir, `${C}/students/s1`))).data().groupIds, ['g3']);
  });

  test('un enseignant ne crée pas de fiche sans groupe : le dépôt inscrit donc fiche et groupe dans UN lot', async () => {
    // Les règles exigent au moins un groupe de l'enseignant à la création (règle inchangée, la plus
    // stricte) : `groupIds: []` est refusé, c'est le cas d'usage qui écrit la fiche AVEC son groupe.
    const teacher = dbOf(env, 'teacherA');
    assert.equal(await allowed(() => setDoc(doc(teacher, `${C}/students/n1`), studentCreate())), false);
    assert.equal(
      await allowed(() => setDoc(doc(teacher, `${C}/students/n1`), studentCreate({ groupIds: ['g1'] }))),
      true,
      'avec un de ses groupes, oui',
    );
  });

  // Ce que le dépôt Dart envoie pour l'inscription d'un élève par un enseignant (UnitOfWork) : la
  // fiche fusionnée (`groupIds` par union) et l'appartenance, dans un seul lot, une écriture par document.
  const enroll = (db, { student = 'n1', group = 'g1', groups = ['g1'] } = {}) => {
    const batch = writeBatch(db);
    batch.set(
      doc(db, `${C}/students/${student}`),
      { ...studentUpdate, groupIds: arrayUnion(...groups), createdAt: serverTimestamp() },
      { merge: true },
    );
    batch.set(doc(db, membershipId(group, student, FROM)), membershipDoc(group, student));
    return allowed(() => batch.commit());
  };

  test('un enseignant inscrit un NOUVEL élève dans SON groupe : fiche et appartenance, un lot', async () => {
    assert.equal(await enroll(dbOf(env, 'teacherA')), true);
    const dir = dbOf(env, 'director');
    assert.deepEqual((await getDoc(doc(dir, `${C}/students/n1`))).data().groupIds, ['g1']);
    assert.equal((await getDoc(doc(dir, membershipId('g1', 'n1', FROM)))).exists(), true);
  });

  test('l\'appartenance d\'un enseignant n\'est acceptée que pour une fiche NEUVE de son groupe', async () => {
    const teacher = dbOf(env, 'teacherA');
    // Élève déjà inscrit (s1, g1) : l'enseignant n'y ajoute pas d'appartenance (ni ne rouvre une période).
    assert.equal(
      await allowed(() => setDoc(doc(teacher, membershipId('g1', 's1', '2026-10-01T00:00:00.000')), membershipDoc('g1', 's1'))),
      false,
      'fiche existante',
    );
    // Sans la fiche dans le même lot : pas d'appartenance orpheline.
    assert.equal(
      await allowed(() => setDoc(doc(teacher, membershipId('g1', 'n1', FROM)), membershipDoc('g1', 'n1'))),
      false,
      'fiche absente du lot',
    );
    // Groupe d'un autre enseignant : refusé même avec une fiche neuve.
    assert.equal(await enroll(teacher, { group: 'g2', groups: ['g1'] }), false, 'appartenance à g2');
    assert.equal(await enroll(teacher, { group: 'g2', groups: ['g2'] }), false, 'fiche et appartenance à g2');
    assert.equal(await enroll(dbOf(env, 'teacherB')), false, 'g1 pour l\'enseignant de g2');
    // Fiche neuve d'un groupe, appartenance d'une autre fiche (existante).
    const batch = writeBatch(teacher);
    batch.set(doc(teacher, `${C}/students/n1`), studentCreate({ groupIds: ['g1'] }));
    batch.set(doc(teacher, membershipId('g1', 's1', '2026-10-01T00:00:00.000')), membershipDoc('g1', 's1'));
    assert.equal(await allowed(() => batch.commit()), false, 'appartenance d\'une fiche existante dans un lot qui en crée une autre');
    // Aucun reste des essais refusés.
    const dir = dbOf(env, 'director');
    assert.equal((await getDoc(doc(dir, `${C}/students/n1`))).exists(), false);
  });

  // Resserrage (revue FB4b) : l'appartenance d'un enseignant est liée à son contenu. Identifiant
  // `groupId_studentId_from`, `from` égal au début de l'historique de la fiche (le jour d'entrée),
  // période ouverte, saison du groupe : UNE appartenance par (fiche, groupe), pas d'autre période.
  const enrollWith = (db, memberships, { student = 'n1', groups = ['g1'] } = {}) => {
    const batch = writeBatch(db);
    batch.set(
      doc(db, `${C}/students/${student}`),
      { ...studentUpdate, groupIds: arrayUnion(...groups), createdAt: serverTimestamp() },
      { merge: true },
    );
    for (const [id, data] of memberships) batch.set(doc(db, `${C}/memberships/${id}`), data);
    return allowed(() => batch.commit());
  };

  test('l\'appartenance d\'un enseignant est liée à son contenu : identifiant, jour d\'entrée, saison, période ouverte', async () => {
    const teacher = dbOf(env, 'teacherA');
    const id = `g1_n1_${FROM}`;
    const ok = membershipDoc('g1', 'n1');
    assert.equal(await enrollWith(teacher, [[id, ok]]), true, 'référence : la forme de l\'application');
    await seed(env);
    assert.equal(await enrollWith(teacher, [['n1_whatever', ok]]), false, 'identifiant sans rapport avec le contenu');
    assert.equal(await enrollWith(teacher, [[`g1_n1_${FROM}x`, ok]]), false, 'identifiant qui diffère du from');
    assert.equal(await enrollWith(teacher, [[id, membershipDoc('g1', 'n1', { seasonId: 'se-inventee' })]]), false, 'saison libre');
    assert.equal(await enrollWith(teacher, [[id, membershipDoc('g1', 'n1', { to: '2026-12-01T00:00:00.000' })]]), false, 'période fermée');
    assert.equal(await enrollWith(teacher, [[id, membershipDoc('g1', 'n1', { from: '2020-01-01T00:00:00.000' })]]), false, 'jour d\'entrée inventé');
    const early = '2020-01-01T00:00:00.000';
    assert.equal(
      await enrollWith(teacher, [[id, ok], [`g1_n1_${early}`, membershipDoc('g1', 'n1', { from: early })]]),
      false,
      'une seconde période arbitraire pour la même fiche neuve',
    );
    assert.equal(
      await enrollWith(teacher, [[id, { ...ok, from: Timestamp.fromMillis(0) }]]),
      false,
      'from horodatage : l\'identifiant ne peut pas le reproduire',
    );
    const dir = dbOf(env, 'director');
    assert.equal((await getDoc(doc(dir, `${C}/students/n1`))).exists(), false, 'aucun reste des essais refusés');
    assert.equal((await getDocs(query(collection(dir, `${C}/memberships`), where('studentId', '==', 'n1')))).size, 0);
  });

  test('ATTAQUE : une appartenance seule, pour une fiche DÉJÀ existante qui satisfait tout le reste, est refusée par la seule condition « fiche absente avant le lot »', async () => {
    // La fiche x1 existe (groupe g1, historique commençant à FROM) mais n'a aucune appartenance :
    // identifiant, période ouverte, saison, groupe de la fiche et jour d'entrée sont ceux d'une
    // inscription légitime. Seule `!exists(fiche)` distingue ce cas d'une fiche neuve du même lot.
    await put(env, `${C}/students/x1`, {
      firstName: 'Léa',
      audienceHistory: [{ audience: 'children', effectiveFrom: FROM }],
      groupIds: ['g1'],
      createdAt: Timestamp.fromMillis(1000),
    });
    const teacher = dbOf(env, 'teacherA');
    assert.equal(
      await allowed(() => setDoc(doc(teacher, membershipId('g1', 'x1', FROM)), membershipDoc('g1', 'x1'))),
      false,
      'fiche existante, tout le reste conforme',
    );
    assert.equal(
      await allowed(() => setDoc(doc(dbOf(env, 'director'), membershipId('g1', 'x1', FROM)), membershipDoc('g1', 'x1'))),
      true,
      'le directeur le peut (contrôle : la forme est valable)',
    );
  });

  test('les autres rôles et les modifications d\'appartenance restent refusés', async () => {
    for (const actor of ['guardian', 'student', 'directorOther', 'invited']) {
      assert.equal(await enroll(dbOf(env, actor)), false, actor);
    }
    assert.equal(await enroll(dbOf(env, 'director')), true, 'le directeur');
    const teacher = dbOf(env, 'teacherA');
    assert.equal(await allowed(() => updateDoc(doc(teacher, membershipId('g1', 'n1', FROM)), { to: '2026-12-01T00:00:00.000' })), false, 'mise à jour');
    assert.equal(await allowed(() => deleteDoc(doc(teacher, membershipId('g1', 'n1', FROM)))), false, 'suppression');
  });

  test('un lot dont une écriture est refusée n\'écrit rien (atomicité réelle du lot)', async () => {
    const teacher = dbOf(env, 'teacherA');
    const batch = writeBatch(teacher);
    batch.set(doc(teacher, `${C}/students/n1`), studentCreate({ groupIds: ['g1'] }));
    batch.set(doc(teacher, membershipId('g2', 'n1', FROM)), membershipDoc('g2', 'n1'));
    assert.equal(await allowed(() => batch.commit()), false);
    assert.equal((await getDoc(doc(dbOf(env, 'director'), `${C}/students/n1`))).exists(), false);
  });

  test('suppression physique : le directeur seulement', async () => {
    assert.equal(await allowed(() => deleteDoc(doc(dbOf(env, 'teacherA'), `${C}/students/s1`))), false);
    assert.equal(await allowed(() => deleteDoc(doc(dbOf(env, 'director'), `${C}/students/s1`))), true);
  });

  test('all() : le directeur liste, l\'enseignant interroge ses groupes, jamais ceux d\'un autre', async () => {
    assert.equal(await allowed(() => getDocs(collection(dbOf(env, 'director'), `${C}/students`))), true, 'directeur');
    const teacher = (groups) =>
      allowed(() => getDocs(query(collection(dbOf(env, 'teacherA'), `${C}/students`), where('groupIds', 'array-contains-any', groups))));
    assert.equal(await teacher(['g1']), true, 'ses groupes');
    assert.equal(await teacher(['g2']), false, 'le groupe d\'un autre');
    assert.equal(await teacher(['g1', 'g2']), false, 'un des siens et un autre');
    const found = await getDocs(
      query(collection(dbOf(env, 'teacherA'), `${C}/students`), where('groupIds', 'array-contains-any', ['g1'])),
    );
    assert.deepEqual(found.docs.map((d) => d.id), ['s1']);
  });

  test('all() : array-contains-any accepte 30 valeurs et refuse la 31e (borne du dépôt Dart)', async () => {
    // La borne `_maxContainsAny = 30` de FirestoreStudentRepository est celle du serveur : un
    // gestionnaire est autorisé à tout lire, seul le nombre de valeurs fait donc la différence.
    const ids = (n) => Array.from({ length: n }, (_, i) => `x${i}`);
    const run = (n) =>
      getDocs(query(collection(dbOf(env, 'director'), `${C}/students`), where('groupIds', 'array-contains-any', ids(n))));
    await assert.doesNotReject(() => run(30));
    await assert.rejects(() => run(31), (error) => error.code === 'invalid-argument');
  });

  test('all() : un parent lit sa fiche liée une à une, pas la liste ni la fiche d\'un autre', async () => {
    assert.equal(await allowed(() => getDoc(doc(dbOf(env, 'guardian'), `${C}/students/s1`))), true);
    assert.equal(await allowed(() => getDoc(doc(dbOf(env, 'guardian'), `${C}/students/s2`))), false);
    assert.equal(await allowed(() => getDocs(collection(dbOf(env, 'guardian'), `${C}/students`))), false);
  });
});

describe('groupes : clubs/{c}/groups/{g}', () => {
  test('création avec teacherUids vide, puis mise à jour SANS teacherUids : les enseignants restent', async () => {
    const dir = dbOf(env, 'director');
    assert.equal(await allowed(() => setDoc(doc(dir, `${C}/groups/g9`), groupCreate)), true, 'création');
    await updateDoc(doc(dir, `${C}/groups/g1`), groupUpdate);
    assert.deepEqual((await getDoc(doc(dir, `${C}/groups/g1`))).data().teacherUids, ['u-teacher-a']);
    assert.equal((await getDoc(doc(dir, `${C}/groups/g1`))).data().name, 'Nouveau');
  });

  test('all() : le directeur liste ; un enseignant et un parent lisent leurs groupes un à un', async () => {
    assert.equal(await allowed(() => getDocs(collection(dbOf(env, 'director'), `${C}/groups`))), true);
    assert.equal(await allowed(() => getDocs(collection(dbOf(env, 'teacherA'), `${C}/groups`))), false, 'pas de liste');
    assert.equal(await allowed(() => getDoc(doc(dbOf(env, 'teacherA'), `${C}/groups/g1`))), true);
    assert.equal(await allowed(() => getDoc(doc(dbOf(env, 'teacherA'), `${C}/groups/g2`))), false);
    assert.equal(await allowed(() => getDoc(doc(dbOf(env, 'guardian'), `${C}/groups/g1`))), true);
  });
});

describe('appartenances : clubs/{c}/memberships/{groupId_studentId_from}', () => {
  test('le directeur écrit l\'appartenance (to null), la ferme, la supprime', async () => {
    const dir = dbOf(env, 'director');
    const path = membershipId('g1', 's9', FROM);
    assert.equal(await allowed(() => setDoc(doc(dir, path), membershipDoc('g1', 's9'))), true, 'ouverte');
    assert.equal(
      await allowed(() => setDoc(doc(dir, path), membershipDoc('g1', 's9', { to: '2027-01-01T00:00:00.000Z' }))),
      true,
      'fermée',
    );
    assert.equal(await allowed(() => deleteDoc(doc(dir, path))), true, 'supprimée');
  });

  test('un élève dans deux groupes le même jour : deux documents distincts', async () => {
    const dir = dbOf(env, 'director');
    await setDoc(doc(dir, membershipId('g1', 's9', FROM)), membershipDoc('g1', 's9'));
    await setDoc(doc(dir, membershipId('g2', 's9', FROM)), membershipDoc('g2', 's9'));
    const found = await getDocs(query(collection(dir, `${C}/memberships`), where('studentId', '==', 's9')));
    assert.equal(found.size, 2);
  });

  test('par groupe : le directeur et l\'enseignant du groupe interrogent, pas un autre ni la famille', async () => {
    const byGroup = (actor, group) =>
      allowed(() => getDocs(query(collection(dbOf(env, actor), `${C}/memberships`), where('groupId', '==', group))));
    assert.equal(await byGroup('director', 'g1'), true);
    assert.equal(await byGroup('teacherA', 'g1'), true);
    assert.equal(await byGroup('teacherA', 'g2'), false);
    assert.equal(await byGroup('guardian', 'g1'), false);
  });

  test('par élève (idsEverContaining, eraseStudent) : gestionnaire seulement', async () => {
    const byStudent = (actor) =>
      allowed(() => getDocs(query(collection(dbOf(env, actor), `${C}/memberships`), where('studentId', '==', 's1'))));
    assert.equal(await byStudent('director'), true);
    assert.equal(await byStudent('admin'), true);
    assert.equal(await byStudent('teacherA'), false);
    assert.equal(await byStudent('guardian'), false);
  });

  test('list() du club entier (all() du directeur) : gestionnaire seulement', async () => {
    assert.equal(await allowed(() => getDocs(collection(dbOf(env, 'director'), `${C}/memberships`))), true);
    assert.equal(await allowed(() => getDocs(collection(dbOf(env, 'teacherA'), `${C}/memberships`))), false);
  });

  test('un champ hors liste ou un `from` qui n\'est pas un texte ISO court est refusé', async () => {
    const dir = dbOf(env, 'director');
    const path = membershipId('g1', 's9', FROM);
    assert.equal(await allowed(() => setDoc(doc(dir, path), membershipDoc('g1', 's9', { note: 'x' }))), false);
    assert.equal(await allowed(() => setDoc(doc(dir, path), membershipDoc('g1', 's9', { from: 'x'.repeat(41) }))), false);
  });
});

describe('save et delete d\'un groupe : un seul lot', () => {
  test('le lot de save (groupe, appartenances, groupIds de la fiche) passe pour le directeur', async () => {
    const dir = dbOf(env, 'director');
    const batch = writeBatch(dir);
    batch.set(doc(dir, `${C}/groups/g1`), groupCreate); // groupe existant : le dépôt fait un update ;
    batch.update(doc(dir, `${C}/groups/g1`), groupUpdate);
    batch.set(doc(dir, membershipId('g1', 's1', FROM)), membershipDoc('g1', 's1'));
    batch.update(doc(dir, `${C}/students/s1`), { groupIds: ['g1', 'g2'] });
    // `set` sur un groupe existant remplacerait `teacherUids` : le test ci-dessus ne s'en sert que
    // pour vérifier que la forme complète est acceptée ; l'application, elle, met à jour.
    assert.equal(await allowed(() => batch.commit()), true);
  });

  test('le lot de delete (appartenances, groupe, groupIds des fiches) passe pour le directeur', async () => {
    const dir = dbOf(env, 'director');
    const batch = writeBatch(dir);
    batch.delete(doc(dir, `${C}/memberships/s1_2026-09-01`));
    batch.delete(doc(dir, `${C}/groups/g1`));
    batch.update(doc(dir, `${C}/students/s1`), { groupIds: [] });
    assert.equal(await allowed(() => batch.commit()), true);
  });

  test('un enseignant ne peut pas écrire le groupe ni ses appartenances', async () => {
    const t = dbOf(env, 'teacherA');
    assert.equal(await allowed(() => updateDoc(doc(t, `${C}/groups/g1`), groupUpdate)), false);
    assert.equal(
      await allowed(() => setDoc(doc(t, membershipId('g1', 's9', FROM)), membershipDoc('g1', 's9'))),
      false,
    );
  });
});

describe('isolation entre clubs', () => {
  test('le directeur d\'un autre club n\'écrit rien dans c1', async () => {
    const other = dbOf(env, 'directorOther');
    assert.equal(await allowed(() => setDoc(doc(other, `${C}/students/n1`), studentCreate())), false);
    assert.equal(await allowed(() => setDoc(doc(other, `${C}/groups/g9`), groupCreate)), false);
    assert.equal(await allowed(() => setDoc(doc(other, `${C}/settings/main`), settingsDoc)), false);
    assert.equal(await allowed(() => setDoc(doc(other, membershipId('g1', 's9', FROM)), membershipDoc('g1', 's9'))), false);
  });
});

// Garde de la graine : les documents utilisés ci-dessus existent bien (sinon un refus pourrait
// venir d'un document absent et non des règles).
test('la graine contient les documents que ces tests supposent', async () => {
  for (const path of [`${C}/students/s1`, `${C}/groups/g1`, `${C}/memberships/s1_2026-09-01`]) {
    assert.equal((await getDoc(doc(dbOf(env, 'director'), path))).exists(), true, path);
  }
});
