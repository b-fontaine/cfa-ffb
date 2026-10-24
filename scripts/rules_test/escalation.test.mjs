// Élévation de privilège (ADR 0024, décisions 14, 16 et 24) : aucun compte ne peut s'accorder
// plus de droits que ceux de son member, par mise à jour, création ou détour par l'invitation,
// contre l'émulateur Firestore (lot FB3).
import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

import { allowed, createEnv, dbOf, invitation, member, now, put, remove, seed, ts, days } from './support.mjs';

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

const memberPath = (uid) => `clubs/c1/members/${uid}`;
const update = (actor, uid, patch) => allowed(() => updateDoc(doc(dbOf(env, actor), memberPath(uid)), patch));

describe('mise à jour de son propre member', () => {
  const own = {
    student: 'u-student',
    guardian: 'u-guardian',
    teacherA: 'u-teacher-a',
    director: 'u-dir',
  };

  test('le rôle ne change jamais (vers un rôle plus puissant, y compris admin)', async () => {
    for (const [actor, uid] of Object.entries(own)) {
      for (const role of ['teacher', 'director', 'admin', 'student', 'guardian']) {
        const current = { student: 'student', guardian: 'guardian', teacherA: 'teacher', director: 'director' }[actor];
        if (role === current) continue;
        assert.equal(await update(actor, uid, { role }), false, `${actor} -> ${role}`);
      }
    }
  });

  test('les groupes et les fiches liés ne s\'étendent pas', async () => {
    assert.equal(await update('teacherA', 'u-teacher-a', { groupIds: ['g1', 'g2'] }), false, 'enseignant : groupe en plus');
    assert.equal(await update('teacherA', 'u-teacher-a', { groupIds: [] }), false, 'enseignant : groupe en moins aussi');
    assert.equal(await update('student', 'u-student', { studentIds: ['s1', 's2'] }), false, 'élève : fiche en plus');
    assert.equal(await update('guardian', 'u-guardian', { studentIds: ['s1', 's2'] }), false, 'parent : fiche en plus');
    assert.equal(await update('guardian', 'u-guardian', { groupIds: ['g1', 'g2'] }), false, 'parent : groupe en plus');
    assert.equal(await update('director', 'u-dir', { groupIds: ['g1'] }), false, 'directeur : pas de groupe');
  });

  test('l\'identité du member ne change pas (uid, date de création, code d\'invitation)', async () => {
    assert.equal(await update('teacherA', 'u-teacher-a', { uid: 'u-dir' }), false);
    assert.equal(await update('teacherA', 'u-teacher-a', { createdAt: ts(now()) }), false);
    assert.equal(await update('teacherA', 'u-teacher-a', { invitationCode: 'AAAAAAAAAA' }), false);
    assert.equal(await update('teacherA', 'u-teacher-a', { isAdmin: true }), false, 'champ inconnu');
  });

  test('le nom affiché, lui, peut changer (preuve que le refus vient du champ, pas du document)', async () => {
    for (const [actor, uid] of Object.entries(own)) {
      assert.equal(await update(actor, uid, { displayName: 'Nouveau nom' }), true, actor);
    }
  });

  test('un compte ne modifie pas le member d\'un autre compte', async () => {
    assert.equal(await update('teacherA', 'u-teacher-b', { displayName: 'Pirate' }), false);
    assert.equal(await update('student', 'u-guardian', { displayName: 'Pirate' }), false);
    assert.equal(await update('directorOther', 'u-teacher-a', { displayName: 'Pirate' }), false, 'directeur d\'un autre club');
    assert.equal(await update('teacherC2', 'u-teacher-a', { displayName: 'Pirate' }), false, 'enseignant d\'un autre club');
  });

});

// Suppression de son compte (FB8 partie B, B2 ; ADR 0025 décision 7(e)) : le titulaire supprime
// son member (voir la grille de matrix.test.mjs), mais s'effacer n'ouvre AUCUN retour : recréer
// un member exige toujours une invitation valide, un directeur ou l'administrateur.
describe('suppression de son propre member', () => {
  const del = (actor, path) => allowed(() => deleteDoc(doc(dbOf(env, actor), path)));
  const recreate = (actor, uid, role, extra = {}) =>
    allowed(() =>
      setDoc(doc(dbOf(env, actor), memberPath(uid)), { ...member(uid, role, extra), createdAt: serverTimestamp() }),
    );

  test('s\'effacer est permis, revenir sans invitation ne l\'est pas (même rôle, plus de droits)', async () => {
    const cases = [
      ['teacherA', 'u-teacher-a', 'teacher', { groupIds: ['g1'] }],
      ['student', 'u-student', 'student', { groupIds: ['g1'], studentIds: ['s1'] }],
      ['guardian', 'u-guardian', 'guardian', { groupIds: ['g1'], studentIds: ['s1'] }],
      ['director', 'u-dir', 'director', {}],
    ];
    for (const [actor, uid, role, extra] of cases) {
      assert.equal(await del(actor, memberPath(uid)), true, `${actor} supprime son member`);
      assert.equal(await recreate(actor, uid, role, extra), false, `${actor} ne se recrée pas ${role}`);
      assert.equal(await recreate(actor, uid, 'director'), false, `${actor} ne se recrée pas directeur`);
      assert.equal(await recreate(actor, uid, 'teacher', { groupIds: ['g1', 'g2'] }), false, `${actor} ne se recrée pas enseignant`);
    }
  });

  test('revenir avec une invitation déjà consommée est refusé', async () => {
    await put(env, 'invitations/USEDCODE22', invitation({ role: 'teacher', used: true, usedBy: 'u-teacher-a', usedAt: ts(now()) }));
    assert.equal(await del('teacherA', memberPath('u-teacher-a')), true);
    const batch = writeBatch(dbOf(env, 'teacherA'));
    batch.set(doc(dbOf(env, 'teacherA'), memberPath('u-teacher-a')), {
      ...member('u-teacher-a', 'teacher'),
      invitationCode: 'USEDCODE22',
      createdAt: serverTimestamp(),
    });
    assert.equal(await allowed(() => batch.commit()), false);
  });

  test('un compte ne supprime pas le member d\'un collègue, d\'un autre club, ni avec une adresse non vérifiée', async () => {
    assert.equal(await del('teacherA', memberPath('u-teacher-b')), false, 'collègue enseignant');
    assert.equal(await del('guardian', memberPath('u-guardian2')), false, 'autre parent');
    assert.equal(await del('student', memberPath('u-guardian')), false, 'son propre parent');
    assert.equal(await del('teacherC2', 'clubs/c1/members/u-teacher-c2'), true, 'chemin absent de c1 : aucun document, rien à protéger');
    assert.equal(await del('teacherC2', memberPath('u-teacher-a')), false, 'enseignant d\'un autre club');
    assert.equal(await del('directorOther', memberPath('u-dir')), false, 'directeur d\'un autre club');
    assert.equal(await del('unverified', memberPath('u-dir')), false, 'adresse non vérifiée');
    assert.equal(await del('anonymous', memberPath('u-student')), false, 'sans compte');
  });

  test('dans un club supprimé par l\'administrateur (sous-collections restées), le compte retrouve et efface encore SES traces', async () => {
    // Suppression de son compte (FB8 partie B) : `membershipsOf` ne liste plus ce club (sans nom),
    // mais ses `members` se lisent au serveur par la requête de groupe, et les règles ne demandent
    // pas que le document du club existe : invitations, marqueurs, puis le member.
    const marker = `${'ab'.repeat(32)}_u-teacher-a`;
    await put(env, `clubs/c1/imports/${marker}`, { createdBy: 'u-teacher-a', updatedAt: ts(now()) });
    await put(env, 'invitations/ORPHANINV2', invitation({ role: 'student', groupIds: ['g1'], studentIds: ['s1'], createdBy: 'u-teacher-a' }));
    await remove(env, 'clubs/c1');
    const db = dbOf(env, 'teacherA');

    const mine = await getDocs(query(collectionGroup(db, 'members'), where('uid', '==', 'u-teacher-a')));
    assert.deepEqual(mine.docs.map((d) => d.ref.path), ['clubs/c1/members/u-teacher-a']);
    const invitations = await getDocs(
      query(collection(db, 'invitations'), where('clubId', '==', 'c1'), where('createdBy', '==', 'u-teacher-a')),
    );
    assert.deepEqual(invitations.docs.map((d) => d.id), ['ORPHANINV2']);
    assert.equal(await del('teacherA', 'invitations/ORPHANINV2'), true, 'révoque son invitation');
    const markers = await getDocs(query(collection(db, 'clubs/c1/imports'), where('createdBy', '==', 'u-teacher-a')));
    assert.deepEqual(markers.docs.map((d) => d.id), [marker]);
    assert.equal(await del('teacherA', `clubs/c1/imports/${marker}`), true, 'supprime son marqueur');
    assert.equal(await del('teacherA', memberPath('u-teacher-a')), true, 'supprime son member');
  });

  test('l\'administrateur ne s\'efface pas de admins (console seule)', async () => {
    assert.equal(await del('admin', 'admins/u-admin'), false);
  });
});

describe('le directeur', () => {
  test('ne promeut personne directeur et ne crée pas de directeur', async () => {
    assert.equal(await update('director', 'u-teacher-a', { role: 'director' }), false);
    assert.equal(
      await allowed(() => setDoc(doc(dbOf(env, 'director'), memberPath('u-new')), { ...member('u-new', 'director'), createdAt: serverTimestamp() })),
      false,
    );
  });

  test('ne rétrograde ni ne modifie un autre directeur', async () => {
    await put(env, memberPath('u-dir-b'), member('u-dir-b', 'director'));
    assert.equal(await update('director', 'u-dir-b', { role: 'teacher' }), false);
    assert.equal(await update('director', 'u-dir-b', { displayName: 'Autre' }), false);
    assert.equal(await allowed(() => deleteDoc(doc(dbOf(env, 'director'), memberPath('u-dir-b')))), false);
  });

  test('ne s\'invente pas administrateur', async () => {
    assert.equal(await allowed(() => setDoc(doc(dbOf(env, 'director'), 'admins/u-dir'), {})), false);
    assert.equal(await update('director', 'u-teacher-a', { role: 'admin' }), false);
  });

  test('ne crée ni ne supprime de club et ne change pas la saison courante', async () => {
    const db = dbOf(env, 'director');
    assert.equal(await allowed(() => setDoc(doc(db, 'clubs/c3'), { name: 'Pirate', createdAt: serverTimestamp() })), false);
    assert.equal(await allowed(() => deleteDoc(doc(db, 'clubs/c1'))), false);
    assert.equal(await allowed(() => updateDoc(doc(db, 'clubs/c1'), { currentSeasonId: 'se1' })), false);
    assert.equal(await allowed(() => updateDoc(doc(db, 'clubs/c1'), { name: 'Renommé', currentSeasonId: 'se1' })), false);
    assert.equal(await allowed(() => updateDoc(doc(db, 'clubs/c1'), { name: 'Renommé' })), true, 'le nom reste permis');
  });

  test('ne déplace pas un member d\'un club à l\'autre (le club est le chemin)', async () => {
    const db = dbOf(env, 'director');
    assert.equal(await allowed(() => setDoc(doc(db, 'clubs/c2/members/u-teacher-a'), { ...member('u-teacher-a', 'teacher'), createdAt: serverTimestamp() })), false);
  });
});

describe('enseignant, élève et parent', () => {
  test('un enseignant n\'écrit ni réglages, ni saisons, ni groupes, ni appartenances, ni archives', async () => {
    const db = dbOf(env, 'teacherA');
    const attempts = [
      ['clubs/c1/settings/main', { passesRequired: 1, alertThreshold: 1, recallStaleSessions: 1, groupFailureSharePercent: 1 }],
      ['clubs/c1/seasons/se9', { label: 'x' }],
      ['clubs/c1/groups/g9', { seasonId: 'se1', name: 'x', teacherUids: [] }],
      ['clubs/c1/memberships/s1_x', { groupId: 'g1', seasonId: 'se1', studentId: 's1' }],
      ['clubs/c1/archives/ar9', { seasonId: 'se1' }],
    ];
    for (const [path, data] of attempts) {
      assert.equal(await allowed(() => setDoc(doc(db, path), data)), false, path);
    }
  });

  test('élève et parent n\'écrivent nulle part (aucune collection du modèle)', async () => {
    const paths = [
      ['clubs/c1/students/n', { firstName: 'X', groupIds: ['g1'] }],
      ['clubs/c1/sessions/n', { groupId: 'g1', seasonId: 'se1' }],
      ['clubs/c1/records/n', { groupId: 'g1', seasonId: 'se1' }],
      ['clubs/c1/attempts/n', { groupId: 'g1', seasonId: 'se1', studentId: 's1' }],
      ['clubs/c1/acquisitions/n', { groupId: 'g1', seasonId: 'se1', studentId: 's1' }],
      ['clubs/c1/assessments/n', { groupId: 'g1', seasonId: 'se1', studentId: 's1' }],
      ['clubs/c1/acknowledgements/n', { groupId: 'g1', seasonId: 'se1', studentId: 's1' }],
      ['clubs/c1/memberships/n', { groupId: 'g1', seasonId: 'se1', studentId: 's1' }],
    ];
    for (const actor of ['student', 'guardian']) {
      for (const [path, data] of paths) {
        assert.equal(await allowed(() => setDoc(doc(dbOf(env, actor), path), data)), false, `${actor} ${path}`);
      }
    }
  });

  test('un parent ne lit pas ce que l\'élève de 15 ans ne lit pas : saisies, bilans, acquittements', async () => {
    const { getDoc } = await import('firebase/firestore');
    for (const path of ['clubs/c1/records/r-g1', 'clubs/c1/assessments/as-g1', 'clubs/c1/acknowledgements/k-g1', 'clubs/c1/memberships/s1_2026-09-01']) {
      assert.equal(await allowed(() => getDoc(doc(dbOf(env, 'guardian'), path))), false, path);
    }
  });
});

describe('invitation et administration', () => {
  test('personne ne s\'invente administrateur par une invitation ou un member', async () => {
    const db = dbOf(env, 'admin');
    const admin = { clubId: 'c1', role: 'admin', groupIds: [], studentIds: [], createdBy: 'u-admin', createdAt: serverTimestamp(), expiresAt: ts(now() + days(1)), used: false };
    assert.equal(await allowed(() => setDoc(doc(db, 'invitations/ADMINADMIN'), admin)), false, 'invitation de rôle admin');
    assert.equal(
      await allowed(() => setDoc(doc(db, memberPath('u-new')), { ...member('u-new', 'admin'), createdAt: serverTimestamp() })),
      false,
      'member de rôle admin',
    );
  });

  test('l\'invité qui consomme le code d\'un enseignant ne devient pas directeur du même lot', async () => {
    await put(env, 'invitations/TEACHTEACH', invitation({ role: 'teacher', groupIds: ['g1'], studentIds: [] }));
    const db = dbOf(env, 'invited');
    const batch = writeBatch(db);
    batch.set(doc(db, memberPath('u-invited')), { ...member('u-invited', 'director'), invitationCode: 'TEACHTEACH', createdAt: serverTimestamp() });
    batch.update(doc(db, 'invitations/TEACHTEACH'), { used: true, usedBy: 'u-invited', usedAt: serverTimestamp() });
    assert.equal(await allowed(() => batch.commit()), false);
  });

  test('un enseignant ne rejoint pas des groupes en plus de ceux qui sont invités, même en deux lots', async () => {
    await put(env, 'invitations/TEACHTEACH', invitation({ role: 'teacher', groupIds: ['g1'], studentIds: [] }));
    const db = dbOf(env, 'invited');
    const batch = writeBatch(db);
    batch.set(doc(db, memberPath('u-invited')), { ...member('u-invited', 'teacher', { groupIds: ['g1', 'g2'] }), invitationCode: 'TEACHTEACH', createdAt: serverTimestamp() });
    batch.update(doc(db, 'invitations/TEACHTEACH'), { used: true, usedBy: 'u-invited', usedAt: serverTimestamp() });
    assert.equal(await allowed(() => batch.commit()), false);
  });
});

describe('création et mise à jour directes d\'un member', () => {
  const create = (actor, uid, extra = {}) =>
    allowed(() => setDoc(doc(dbOf(env, actor), memberPath(uid)), { ...member(uid, 'teacher'), createdAt: serverTimestamp(), ...extra }));

  test('le champ uid du document est celui de son identifiant, pour le directeur comme pour l\'administrateur', async () => {
    for (const actor of ['director', 'admin']) {
      assert.equal(await create(actor, 'u-new', { uid: 'u-victime' }), false, actor);
    }
    assert.equal(await create('director', 'u-new'), true);
  });

  test('la date de création est celle du serveur', async () => {
    for (const actor of ['director', 'admin']) {
      assert.equal(await create(actor, 'u-new', { createdAt: ts(now() - days(400)) }), false, actor);
    }
  });

  test('ni l\'identité ni la date d\'un member ne se modifient, même par le directeur ou l\'administrateur', async () => {
    for (const actor of ['director', 'admin']) {
      assert.equal(await update(actor, 'u-teacher-a', { uid: 'u-teacher-b' }), false, `${actor} uid`);
      assert.equal(await update(actor, 'u-teacher-a', { createdAt: ts(now()) }), false, `${actor} createdAt`);
      assert.equal(await update(actor, 'u-teacher-a', { invitationCode: 'AAAAAAAAAA' }), false, `${actor} invitationCode`);
    }
  });

  test('un enseignant dont le member porterait des fiches par erreur n\'a pas les droits d\'un parent', async () => {
    await put(env, memberPath('u-teacher-a'), member('u-teacher-a', 'teacher', { groupIds: ['g1'], studentIds: ['s2'] }));
    const { getDoc } = await import('firebase/firestore');
    // s2 est dans g2 : ni par son groupe, ni par une « fiche liée » un enseignant de g1 ne la lit.
    assert.equal(await allowed(() => getDoc(doc(dbOf(env, 'teacherA'), 'clubs/c1/students/s2'))), false);
    assert.equal(await allowed(() => getDoc(doc(dbOf(env, 'teacherA'), 'clubs/c1/attempts/a-g2'))), false);
  });
});
