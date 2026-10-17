// Invitations (ADR 0024, décision 24) : création par rôle, validité, usage unique par lot
// (`getAfter`), révocation, contre l'émulateur Firestore (lot FB3).
//
// Une invitation est lue par `get` seulement (jamais `list`) ; elle porte le club, le rôle, les
// groupes ou les fiches ; elle se consomme dans le MÊME lot que la création du member, et les
// deux écritures se vérifient mutuellement (`existsAfter` d'un côté, `getAfter` de l'autre).
import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, test } from 'node:test';

import { deleteDoc, doc, getDoc, serverTimestamp, setDoc, updateDoc, writeBatch } from 'firebase/firestore';

import {
  allowed,
  createEnv,
  days,
  hours,
  invitation,
  now,
  put,
  seed,
  ts,
} from './support.mjs';

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

const context = (uid, claims = {}) =>
  env.authenticatedContext(uid, { email: `${uid}@example.org`, email_verified: true, ...claims });
const dbFor = (uid, claims) => context(uid, claims).firestore();

/** Corps d'une invitation créée par l'application (`createdAt` côté serveur). */
const body = (uid, extra = {}) => ({
  clubId: 'c1',
  role: 'student',
  groupIds: ['g1'],
  studentIds: ['s1'],
  createdBy: uid,
  createdAt: serverTimestamp(),
  expiresAt: ts(now() + days(6)),
  used: false,
  ...extra,
});

const createInvitation = (db, code, data) => setDoc(doc(db, `invitations/${code}`), data);

/**
 * Le lot du client : crée le member ET consomme l'invitation. `member` et `inv` remplacent
 * ou complètent les champs écrits.
 */
const join = (db, uid, code, { clubId = 'c1', memberData = {}, invData = {}, memberCode = code } = {}) => {
  const batch = writeBatch(db);
  batch.set(doc(db, `clubs/${clubId}/members/${uid}`), {
    uid,
    role: 'student',
    groupIds: ['g1'],
    studentIds: ['s1'],
    displayName: 'Nouvel élève',
    invitationCode: memberCode,
    createdAt: serverTimestamp(),
    ...memberData,
  });
  batch.update(doc(db, `invitations/${code}`), {
    used: true,
    usedBy: uid,
    usedAt: serverTimestamp(),
    ...invData,
  });
  return batch.commit();
};

const seedInvitation = (code, extra = {}) => put(env, `invitations/${code}`, invitation({ role: 'student', groupIds: ['g1'], studentIds: ['s1'], ...extra }));

// ───────────────────────── Création : qui invite qui ─────────────────────────
describe('création : rôles', () => {
  test('l\'administrateur invite un directeur dans un club existant', async () => {
    const db = dbFor('u-admin');
    const directorInvitation = body('u-admin', { role: 'director', groupIds: [], studentIds: [], expiresAt: ts(now() + hours(47)) });
    assert.equal(await allowed(() => createInvitation(db, 'DDDDDDDDDD', directorInvitation)), true);
    assert.equal(
      await allowed(() => createInvitation(db, 'DDDDDDDDDE', { ...directorInvitation, clubId: 'inexistant' })),
      false,
      'le club doit exister',
    );
  });

  test('le directeur invite enseignant, élève et parent de son club, jamais un directeur', async () => {
    const db = dbFor('u-dir');
    const base = (extra) => body('u-dir', extra);
    assert.equal(await allowed(() => createInvitation(db, 'TTTTTTTTTT', base({ role: 'teacher', groupIds: ['g1', 'g2'], studentIds: [], expiresAt: ts(now() + hours(47)) }))), true);
    assert.equal(await allowed(() => createInvitation(db, 'SSSSSSSSSS', base({ role: 'student' }))), true);
    assert.equal(await allowed(() => createInvitation(db, 'GGGGGGGGGG', base({ role: 'guardian', studentIds: ['s1', 's2'], groupIds: ['g1', 'g2'] }))), true);
    assert.equal(await allowed(() => createInvitation(db, 'DDDDDDDDDD', base({ role: 'director', groupIds: [], studentIds: [], expiresAt: ts(now() + hours(47)) }))), false, 'un directeur n\'invite pas de directeur');
  });

  test('le directeur n\'invite pas dans un autre club', async () => {
    const db = dbFor('u-dir');
    assert.equal(await allowed(() => createInvitation(db, 'XXXXXXXXXX', body('u-dir', { clubId: 'c2', role: 'teacher', groupIds: [], studentIds: [] }))), false);
    const other = dbFor('u-dir2');
    assert.equal(await allowed(() => createInvitation(other, 'XXXXXXXXXY', body('u-dir2', { clubId: 'c1', role: 'teacher', groupIds: [], studentIds: [] }))), false);
  });

  test('l\'enseignant invite un élève ou un parent dans SES groupes et pour SES élèves', async () => {
    const db = dbFor('u-teacher-a');
    const base = (extra) => body('u-teacher-a', extra);
    assert.equal(await allowed(() => createInvitation(db, 'SSSSSSSSSS', base({ role: 'student' }))), true);
    assert.equal(await allowed(() => createInvitation(db, 'GGGGGGGGGG', base({ role: 'guardian' }))), true);
    // Autre groupe du même club : refusé.
    assert.equal(await allowed(() => createInvitation(db, 'SSSSSSSSST', base({ role: 'student', groupIds: ['g2'], studentIds: ['s2'] }))), false, 'groupe d\'un autre enseignant');
    // Groupe à lui mais fiche d'un autre groupe : refusé.
    assert.equal(await allowed(() => createInvitation(db, 'SSSSSSSSSU', base({ role: 'student', groupIds: ['g1'], studentIds: ['s2'] }))), false, 'fiche d\'un autre groupe');
    // Un groupe à lui et un groupe qui ne l'est pas : refusé.
    assert.equal(await allowed(() => createInvitation(db, 'SSSSSSSSSV', base({ role: 'guardian', groupIds: ['g1', 'g2'], studentIds: ['s1'] }))), false);
  });

  test('l\'enseignant n\'invite ni enseignant ni directeur', async () => {
    const db = dbFor('u-teacher-a');
    for (const role of ['teacher', 'director']) {
      assert.equal(
        await allowed(() => createInvitation(db, `ROLEROLE${role === 'teacher' ? 'AA' : 'BB'}`, body('u-teacher-a', { role, groupIds: ['g1'], studentIds: [], expiresAt: ts(now() + hours(47)) }))),
        false,
        role,
      );
    }
  });

  test('élève, parent, compte sans member, anonyme et e-mail non vérifié n\'invitent pas', async () => {
    const attempts = {
      student: dbFor('u-student'),
      guardian: dbFor('u-guardian'),
      invited: dbFor('u-invited'),
      anonymous: env.unauthenticatedContext().firestore(),
      unverified: dbFor('u-dir', { email_verified: false }),
    };
    for (const [name, db] of Object.entries(attempts)) {
      const uid = name === 'unverified' ? 'u-dir' : `u-${name}`;
      assert.equal(await allowed(() => createInvitation(db, 'NOPENOPENO', body(uid, { role: 'student' }))), false, name);
    }
  });
});

// ───────────────────────── Création : forme et validité ─────────────────────────
describe('création : forme', () => {
  const dir = () => dbFor('u-dir');
  const make = (code, extra) => allowed(() => createInvitation(dir(), code, body('u-dir', extra)));

  test('la durée : 7 jours pour élève et parent, 48 heures pour enseignant et directeur', async () => {
    assert.equal(await make('AAAAAAAAAB', { expiresAt: ts(now() + days(7)) }), true, '7 jours');
    assert.equal(await make('AAAAAAAAAC', { expiresAt: ts(now() + days(8)) }), false, '8 jours');
    const teacher = { role: 'teacher', groupIds: [], studentIds: [] };
    assert.equal(await make('AAAAAAAAAD', { ...teacher, expiresAt: ts(now() + hours(48)) }), true, 'enseignant 48 h');
    assert.equal(await make('AAAAAAAAAE', { ...teacher, expiresAt: ts(now() + hours(72)) }), false, 'enseignant 72 h');
    const admin = dbFor('u-admin');
    const director = body('u-admin', { role: 'director', groupIds: [], studentIds: [] });
    assert.equal(await allowed(() => createInvitation(admin, 'AAAAAAAAAF', { ...director, expiresAt: ts(now() + hours(48)) })), true, 'directeur 48 h');
    assert.equal(await allowed(() => createInvitation(admin, 'AAAAAAAAAG', { ...director, expiresAt: ts(now() + days(7)) })), false, 'directeur 7 jours');
  });

  test('l\'expiration est dans le futur', async () => {
    assert.equal(await make('AAAAAAAAAH', { expiresAt: ts(now() - hours(1)) }), false);
    assert.equal(await make('AAAAAAAAAI', { expiresAt: 'demain' }), false);
  });

  test('la date de création est celle du serveur', async () => {
    assert.equal(await make('AAAAAAAAAJ', { createdAt: ts(now() - days(1)) }), false);
  });

  test('le code : Base32 de 10 à 32 caractères sans 0, 1, 8, 9, en majuscules', async () => {
    assert.equal(await make('AAAAAAAAA', {}), false, '9 caractères');
    assert.equal(await make('A'.repeat(33), {}), false, '33 caractères');
    assert.equal(await make('A'.repeat(32), {}), true, '32 caractères');
    assert.equal(await make('aaaaaaaaaaaa', {}), false, 'minuscules');
    assert.equal(await make('AAAAAAAAA0', {}), false, 'chiffre 0');
    assert.equal(await make('AAAAAAAAA1', {}), false, 'chiffre 1');
    assert.equal(await make('AAAAAAAA89', {}), false, 'chiffres 8 et 9');
    assert.equal(await make('AAAAAAAAAK', {}), true, '10 caractères valides');
  });

  test('le créateur est le compte connecté, l\'invitation naît non utilisée, sans champ en trop', async () => {
    assert.equal(await make('AAAAAAAAAL', { createdBy: 'u-admin' }), false, 'créateur usurpé');
    assert.equal(await make('AAAAAAAAAM', { used: true }), false, 'déjà utilisée');
    assert.equal(await make('AAAAAAAAAN', { usedBy: 'u-new' }), false, 'champ en trop');
    assert.equal(await make('AAAAAAAAAO', { note: 'texte libre' }), false, 'champ en trop');
  });

  test('fiches et groupes liés selon le rôle', async () => {
    assert.equal(await make('BBBBBBBBBB', { role: 'student', studentIds: ['s1', 's2'] }), false, 'élève : une seule fiche');
    assert.equal(await make('BBBBBBBBBC', { role: 'student', studentIds: [] }), false, 'élève : une fiche');
    assert.equal(await make('BBBBBBBBBD', { role: 'guardian', studentIds: [] }), false, 'parent : au moins une fiche');
    assert.equal(await make('BBBBBBBBBE', { role: 'guardian', studentIds: ['s1', 's2', 's1', 's2', 's1'] }), false, 'parent : au plus quatre');
    assert.equal(await make('BBBBBBBBBF', { role: 'guardian', studentIds: ['s1', 's2', 's1', 's2'], groupIds: ['g1', 'g2'] }), true, 'parent : quatre');
    assert.equal(await make('BBBBBBBBBG', { role: 'student', groupIds: [] }), false, 'élève : au moins un groupe');
    assert.equal(await make('BBBBBBBBBH', { role: 'teacher', studentIds: ['s1'], groupIds: [], expiresAt: ts(now() + hours(47)) }), false, 'enseignant : aucune fiche');
    assert.equal(await make('BBBBBBBBBI', { role: 'student', studentIds: ['inconnue'] }), false, 'la fiche doit exister');
    assert.equal(await make('BBBBBBBBBJ', { role: 'guardian', studentIds: ['s1', 'inconnue'], groupIds: ['g1'] }), false, 'toutes les fiches doivent exister');
    assert.equal(await make('BBBBBBBBBK', { role: 'student', studentIds: ['s-c2'] }), false, 'la fiche d\'un autre club n\'existe pas ici');
  });

  test('le club est un identifiant simple (aucun chemin glissé dans la valeur)', async () => {
    const admin = dbFor('u-admin');
    // « c1/members/u-dir » désigne un document qui existe : sans la forme exigée de l'identifiant,
    // le test d'existence du club passerait.
    assert.equal(await allowed(() => createInvitation(admin, 'CCCCCCCCCC', body('u-admin', { clubId: 'c1/members/u-dir', role: 'director', groupIds: [], studentIds: [], expiresAt: ts(now() + hours(47)) }))), false);
  });

  test('au plus 30 groupes par invitation', async () => {
    const groups = (n) => Array.from({ length: n }, (_, i) => `g${i}`);
    const teacher = { role: 'teacher', studentIds: [], expiresAt: ts(now() + hours(47)) };
    assert.equal(await make('DDDDDDDDDE', { ...teacher, groupIds: groups(30) }), true, '30 groupes');
    assert.equal(await make('DDDDDDDDDF', { ...teacher, groupIds: groups(31) }), false, '31 groupes');
  });

  test('l\'administrateur invite aussi un parent ou un élève, avec les mêmes contraintes de fiches', async () => {
    const admin = dbFor('u-admin');
    const make = (code, extra) => allowed(() => createInvitation(admin, code, body('u-admin', extra)));
    assert.equal(await make('EEEEEEEEEA', { role: 'guardian', studentIds: ['s1', 's2'], groupIds: ['g1', 'g2'] }), true);
    assert.equal(await make('EEEEEEEEEB', { role: 'guardian', studentIds: ['s1', 'inconnue'] }), false, '2e fiche inexistante');
    assert.equal(await make('EEEEEEEEEC', { role: 'guardian', studentIds: ['s1', 's2', 'inconnue'] }), false, '3e fiche inexistante');
    assert.equal(await make('EEEEEEEEED', { role: 'guardian', studentIds: ['s1', 's2', 's1', 'inconnue'] }), false, '4e fiche inexistante');
    assert.equal(await make('EEEEEEEEEF', { role: 'student', studentIds: ['inconnue'] }), false, 'fiche inexistante');
    assert.equal(await make('EEEEEEEEEG', { role: 'director', groupIds: ['g1'], studentIds: [], expiresAt: ts(now() + hours(47)) }), false, 'un directeur n\'a pas de groupe');
    assert.equal(await make('EEEEEEEEEH', { role: 'guardian', studentIds: ['s1'], groupIds: [] }), false, 'un parent a au moins un groupe');
  });

  test('un administrateur dont l\'adresse n\'est pas vérifiée n\'invite pas', async () => {
    const db = dbFor('u-admin', { email_verified: false });
    assert.equal(await allowed(() => createInvitation(db, 'FFFFFFFFFA', body('u-admin', { role: 'director', groupIds: [], studentIds: [], expiresAt: ts(now() + hours(47)) }))), false);
  });

  test('l\'enseignant lie jusqu\'à quatre fiches, toutes de ses groupes', async () => {
    await put(env, 'clubs/c1/students/s4', { firstName: 'Zoé', groupIds: ['g1'] });
    await put(env, 'clubs/c1/students/s5', { firstName: 'Ugo', groupIds: ['g1'] });
    const db = dbFor('u-teacher-a');
    const make = (code, studentIds) => allowed(() => createInvitation(db, code, body('u-teacher-a', { role: 'guardian', studentIds })));
    assert.equal(await make('GGGGGGGGGA', ['s1', 's4', 's5']), true, 'trois fiches de g1');
    assert.equal(await make('GGGGGGGGGB', ['s1', 's2']), false, '2e fiche d\'un autre groupe');
    assert.equal(await make('GGGGGGGGGC', ['s1', 's4', 's2']), false, '3e fiche d\'un autre groupe');
    assert.equal(await make('GGGGGGGGGD', ['s1', 's4', 's5', 's2']), false, '4e fiche d\'un autre groupe');
    assert.equal(await make('GGGGGGGGGE', ['s1', 's4', 's5', 's1', 's4']), false, 'plus de quatre fiches');
  });

  test('le code n\'est pas remplaçable par un autre compte (création sur un code existant = mise à jour)', async () => {
    assert.equal(await allowed(() => createInvitation(dir(), 'AAAAAAAAAA', body('u-dir', { role: 'teacher', groupIds: [], studentIds: [], expiresAt: ts(now() + hours(47)) }))), false);
  });
});

// ───────────────────────── Lecture ─────────────────────────
describe('lecture : par le code, jamais en liste', () => {
  test('un compte vérifié lit une invitation par son code', async () => {
    assert.equal(await allowed(() => getDoc(doc(dbFor('u-invited'), 'invitations/AAAAAAAAAA'))), true);
  });
  test('anonyme et e-mail non vérifié ne la lisent pas', async () => {
    assert.equal(await allowed(() => getDoc(doc(env.unauthenticatedContext().firestore(), 'invitations/AAAAAAAAAA'))), false);
    assert.equal(await allowed(() => getDoc(doc(dbFor('u-invited', { email_verified: false }), 'invitations/AAAAAAAAAA'))), false);
  });
});

// ───────────────────────── Usage unique par lot ─────────────────────────
describe('consommation : un lot crée le member et consomme l\'invitation', () => {
  beforeEach(async () => {
    await seedInvitation('JOINJOINJO');
  });

  test('un compte vérifié rejoint avec une invitation valide', async () => {
    const db = dbFor('u-new');
    assert.equal(await allowed(() => join(db, 'u-new', 'JOINJOINJO')), true);
    await env.withSecurityRulesDisabled(async (ctx) => {
      const created = await getDoc(doc(ctx.firestore(), 'clubs/c1/members/u-new'));
      assert.equal(created.data().role, 'student');
      const used = await getDoc(doc(ctx.firestore(), 'invitations/JOINJOINJO'));
      assert.equal(used.data().used, true);
      assert.equal(used.data().usedBy, 'u-new');
    });
  });

  test('un parent rejoint avec deux enfants', async () => {
    await seedInvitation('GUARDGUARD', { role: 'guardian', groupIds: ['g1', 'g2'], studentIds: ['s1', 's2'] });
    const db = dbFor('u-new');
    assert.equal(
      await allowed(() => join(db, 'u-new', 'GUARDGUARD', { memberData: { role: 'guardian', groupIds: ['g1', 'g2'], studentIds: ['s1', 's2'] } })),
      true,
    );
  });

  test('un enseignant rejoint avec ses groupes ; un directeur avec une invitation d\'administrateur', async () => {
    await seedInvitation('TEACHTEACH', { role: 'teacher', groupIds: ['g1'], studentIds: [] });
    assert.equal(
      await allowed(() => join(dbFor('u-new'), 'u-new', 'TEACHTEACH', { memberData: { role: 'teacher', groupIds: ['g1'], studentIds: [] } })),
      true,
    );
    await seedInvitation('DIRDIRDIRD', { role: 'director', groupIds: [], studentIds: [], createdBy: 'u-admin' });
    assert.equal(
      await allowed(() => join(dbFor('u-new2'), 'u-new2', 'DIRDIRDIRD', { memberData: { role: 'director', groupIds: [], studentIds: [] } })),
      true,
    );
  });

  test('réutilisation : une invitation déjà consommée est refusée', async () => {
    assert.equal(await allowed(() => join(dbFor('u-new'), 'u-new', 'JOINJOINJO')), true);
    assert.equal(await allowed(() => join(dbFor('u-new2'), 'u-new2', 'JOINJOINJO')), false);
  });

  test('une invitation marquée utilisée dès le départ est refusée', async () => {
    await seedInvitation('USEDUSEDUS', { used: true, usedBy: 'u-other', usedAt: ts(now()) });
    assert.equal(await allowed(() => join(dbFor('u-new'), 'u-new', 'USEDUSEDUS')), false);
  });

  test('expiration : une invitation expirée est refusée', async () => {
    await seedInvitation('EXPIREDEXP', { expiresAt: ts(now() - hours(1)) });
    assert.equal(await allowed(() => join(dbFor('u-new'), 'u-new', 'EXPIREDEXP')), false);
  });

  test('révoquée (supprimée) : une invitation absente est refusée', async () => {
    await deleteDoc(doc(dbFor('u-dir'), 'invitations/JOINJOINJO'));
    assert.equal(await allowed(() => join(dbFor('u-new'), 'u-new', 'JOINJOINJO')), false);
  });

  test('mauvais club : le member est créé dans un autre club que celui de l\'invitation', async () => {
    assert.equal(await allowed(() => join(dbFor('u-new'), 'u-new', 'JOINJOINJO', { clubId: 'c2' })), false);
  });

  test('mauvais rôle : un élève qui se déclare enseignant, directeur ou administrateur', async () => {
    for (const role of ['teacher', 'director', 'admin']) {
      assert.equal(
        await allowed(() => join(dbFor('u-new'), 'u-new', 'JOINJOINJO', { memberData: { role }, invData: {} })),
        false,
        role,
      );
    }
  });

  test('mauvais périmètre : groupes ou fiches autres que ceux de l\'invitation', async () => {
    const db = () => dbFor('u-new');
    assert.equal(await allowed(() => join(db(), 'u-new', 'JOINJOINJO', { memberData: { groupIds: ['g1', 'g2'] } })), false, 'groupe en plus');
    assert.equal(await allowed(() => join(db(), 'u-new', 'JOINJOINJO', { memberData: { studentIds: ['s2'] } })), false, 'autre fiche');
    assert.equal(await allowed(() => join(db(), 'u-new', 'JOINJOINJO', { memberData: { studentIds: ['s1', 's2'] } })), false, 'fiche en plus');
    assert.equal(await allowed(() => join(db(), 'u-new', 'JOINJOINJO', { memberData: { groupIds: [] } })), false, 'groupe en moins');
  });

  test('e-mail non vérifié ou anonyme : refusé', async () => {
    assert.equal(await allowed(() => join(dbFor('u-new', { email_verified: false }), 'u-new', 'JOINJOINJO')), false);
    assert.equal(await allowed(() => join(env.unauthenticatedContext().firestore(), 'u-new', 'JOINJOINJO')), false);
  });

  test('on ne crée pas le member d\'un autre compte', async () => {
    assert.equal(await allowed(() => join(dbFor('u-new'), 'u-other', 'JOINJOINJO', { invData: { usedBy: 'u-new' } })), false);
  });

  test('le champ uid du member est celui du compte', async () => {
    assert.equal(await allowed(() => join(dbFor('u-new'), 'u-new', 'JOINJOINJO', { memberData: { uid: 'u-dir' } })), false);
  });

  test('usedBy usurpé : refusé', async () => {
    assert.equal(await allowed(() => join(dbFor('u-new'), 'u-new', 'JOINJOINJO', { invData: { usedBy: 'u-dir' } })), false);
  });

  test('la date de création du member est celle du serveur', async () => {
    assert.equal(await allowed(() => join(dbFor('u-new'), 'u-new', 'JOINJOINJO', { memberData: { createdAt: ts(now() - days(1)) } })), false);
  });

  test('l\'invitation consommée ne change ni de rôle, ni de club, ni d\'expiration', async () => {
    assert.equal(await allowed(() => join(dbFor('u-new'), 'u-new', 'JOINJOINJO', { invData: { expiresAt: ts(now() + days(300)) } })), false, 'expiration');
    assert.equal(await allowed(() => join(dbFor('u-new'), 'u-new', 'JOINJOINJO', { invData: { role: 'director' } })), false, 'rôle');
    assert.equal(await allowed(() => join(dbFor('u-new'), 'u-new', 'JOINJOINJO', { invData: { clubId: 'c2' } })), false, 'club');
  });

  test('un member déjà dans le club ne brûle pas une invitation sans devenir membre par elle', async () => {
    // u-student est déjà élève de c1 : il consomme à vide une invitation d'élève de c1.
    const db = dbFor('u-student');
    assert.equal(
      await allowed(() => updateDoc(doc(db, 'invitations/JOINJOINJO'), { used: true, usedBy: 'u-student', usedAt: serverTimestamp() })),
      false,
    );
  });

  test('une invitation ne crée qu\'un seul member (pas de second compte dans le même lot)', async () => {
    const db = dbFor('u-new');
    const batch = writeBatch(db);
    for (const uid of ['u-new', 'u-complice']) {
      batch.set(doc(db, `clubs/c1/members/${uid}`), {
        uid, role: 'student', groupIds: ['g1'], studentIds: ['s1'], displayName: uid, invitationCode: 'JOINJOINJO', createdAt: serverTimestamp(),
      });
    }
    batch.update(doc(db, 'invitations/JOINJOINJO'), { used: true, usedBy: 'u-new', usedAt: serverTimestamp() });
    assert.equal(await allowed(() => batch.commit()), false);
  });

  test('la date de consommation est celle du serveur', async () => {
    assert.equal(await allowed(() => join(dbFor('u-new'), 'u-new', 'JOINJOINJO', { invData: { usedAt: ts(now() - days(1)) } })), false);
  });

  test('le member cite un autre code que celui consommé', async () => {
    await seedInvitation('OTHEROTHER');
    assert.equal(await allowed(() => join(dbFor('u-new'), 'u-new', 'JOINJOINJO', { memberCode: 'OTHEROTHER' })), false);
  });

  test('le member cite un code mal formé (aucun chemin glissé)', async () => {
    assert.equal(await allowed(() => join(dbFor('u-new'), 'u-new', 'JOINJOINJO', { memberCode: '../clubs/c1' })), false);
  });

  test('le member seul, sans consommer l\'invitation : refusé', async () => {
    const db = dbFor('u-new');
    assert.equal(
      await allowed(() =>
        setDoc(doc(db, 'clubs/c1/members/u-new'), {
          uid: 'u-new', role: 'student', groupIds: ['g1'], studentIds: ['s1'], displayName: 'X', invitationCode: 'JOINJOINJO', createdAt: serverTimestamp(),
        }),
      ),
      false,
    );
  });

  test('l\'invitation seule, sans member : refusée (on ne la brûle pas)', async () => {
    const db = dbFor('u-new');
    assert.equal(await allowed(() => updateDoc(doc(db, 'invitations/JOINJOINJO'), { used: true, usedBy: 'u-new', usedAt: serverTimestamp() })), false);
  });

  test('l\'invitation modifiée autrement que par la consommation : refusée', async () => {
    const db = dbFor('u-dir');
    assert.equal(await allowed(() => updateDoc(doc(db, 'invitations/JOINJOINJO'), { role: 'director' })), false, 'même par son créateur');
    const admin = dbFor('u-admin');
    assert.equal(await allowed(() => updateDoc(doc(admin, 'invitations/JOINJOINJO'), { expiresAt: ts(now() + days(30)) })), false, 'même par l\'administrateur');
  });

  test('un member existant ne se sert pas d\'une invitation pour changer de rôle', async () => {
    await seedInvitation('TEACHTEACH', { role: 'teacher', groupIds: ['g1'], studentIds: [] });
    // u-student est déjà élève de c1 : il tente de devenir enseignant.
    assert.equal(
      await allowed(() => join(dbFor('u-student'), 'u-student', 'TEACHTEACH', { memberData: { role: 'teacher', groupIds: ['g1'], studentIds: [] } })),
      false,
    );
  });

  test('un compte déjà member d\'un club peut rejoindre un autre club (un member par club)', async () => {
    await seedInvitation('OTHERCLUB2', { clubId: 'c2', role: 'student', groupIds: ['g1'], studentIds: ['s-c2'] });
    assert.equal(
      await allowed(() => join(dbFor('u-student'), 'u-student', 'OTHERCLUB2', { clubId: 'c2', memberData: { studentIds: ['s-c2'] } })),
      true,
    );
  });

  test('un nom affiché absent ou trop long est refusé', async () => {
    assert.equal(await allowed(() => join(dbFor('u-new'), 'u-new', 'JOINJOINJO', { memberData: { displayName: '' } })), false);
    assert.equal(await allowed(() => join(dbFor('u-new'), 'u-new', 'JOINJOINJO', { memberData: { displayName: 'x'.repeat(41) } })), false);
  });

  test('un champ en trop dans le member est refusé', async () => {
    assert.equal(await allowed(() => join(dbFor('u-new'), 'u-new', 'JOINJOINJO', { memberData: { isAdmin: true } })), false);
  });
});

// ───────────────────────── Révocation ─────────────────────────
describe('révocation', () => {
  const revoke = (uid, claims) => allowed(() => deleteDoc(doc(dbFor(uid, claims), 'invitations/AAAAAAAAAA')));

  test('le directeur du club, l\'administrateur et l\'enseignant qui l\'a créée révoquent', async () => {
    assert.equal(await revoke('u-dir'), true);
    await seed(env);
    assert.equal(await revoke('u-admin'), true);
    await seed(env);
    await put(env, 'invitations/AAAAAAAAAA', invitation({ role: 'student', groupIds: ['g1'], studentIds: ['s1'], createdBy: 'u-teacher-a' }));
    assert.equal(await revoke('u-teacher-a'), true);
  });

  test('un autre enseignant, un élève, un parent, le directeur d\'un autre club ne révoquent pas', async () => {
    await put(env, 'invitations/AAAAAAAAAA', invitation({ role: 'student', groupIds: ['g1'], studentIds: ['s1'], createdBy: 'u-teacher-a' }));
    for (const uid of ['u-teacher-b', 'u-student', 'u-guardian', 'u-dir2', 'u-invited', 'u-teacher-c2']) {
      assert.equal(await revoke(uid), false, uid);
    }
    assert.equal(await revoke('u-dir', { email_verified: false }), false, 'e-mail non vérifié');
    assert.equal(await allowed(() => deleteDoc(doc(env.unauthenticatedContext().firestore(), 'invitations/AAAAAAAAAA'))), false, 'anonyme');
  });
});
