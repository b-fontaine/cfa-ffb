// Matrice des droits de l'ADR 0024 : chaque collection × chaque action × chaque acteur, contre
// l'émulateur Firestore (lot FB3).
//
// Pour une collection et une action, la liste des acteurs AUTORISÉS est écrite à la main
// (colonne « qui » du tableau de l'ADR) ; tout autre acteur doit être REFUSÉ. Un test échoue donc
// aussi bien quand une règle s'affaiblit (un refusé passe) que quand elle se durcit trop (un
// autorisé est refusé). Les groupes g1 et g2 d'un même club séparent les enseignants ; s1 et s2
// séparent les parents ; le club c2 (qui a aussi un groupe « g1 ») sépare les clubs.
//
// Acteurs : anonymous, unverified (directeur sans e-mail vérifié), invited (compte vérifié sans
// member), student et guardian (fiche s1, groupe g1), guardian2 (fiche s2, groupe g2),
// teacherA (g1), teacherB (g2), teacherC2 (autre club), director, directorOther (autre club),
// admin. Voir support.mjs.
//
// Les cas particuliers (invitations, élévation de privilège, bornes) sont dans les fichiers
// voisins ; ce fichier-ci est la grille.
import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';

import {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

import {
  actorNames,
  allowed,
  createEnv,
  dbOf,
  member,
  now,
  put,
  remove,
  seed,
  seedDocs,
  student,
  ts,
  owned,
} from './support.mjs';

let env;
before(async () => {
  env = await createEnv();
  await seed(env);
});
after(async () => {
  await env?.cleanup();
});

test('les jeux de données utilisés existent (un refus vient bien des règles)', async () => {
  const present = new Set();
  await env.withSecurityRulesDisabled(async (ctx) => {
    for (const [path] of seedDocs()) {
      if ((await getDoc(doc(ctx.firestore(), path))).exists()) present.add(path);
    }
  });
  assert.equal(present.size, seedDocs().length);
});

/** Une suite par collection du modèle (model.json) ; `model_coverage.test.mjs` exige qu'aucune ne manque. */
const suite = (name, title, body) => describe(title, body);

const MGR = ['director', 'admin'];
const staffOf = (g) => [...MGR, g === 'g1' ? 'teacherA' : 'teacherB'];
const MEMBERS = ['student', 'guardian', 'guardian2', 'teacherA', 'teacherB', 'director', 'admin'];
const familyOfGroup = (g) => (g === 'g1' ? ['student', 'guardian'] : ['guardian2']);
const familyOfStudent = familyOfGroup;
const studentOf = (g) => (g === 'g1' ? 's1' : 's2');

/**
 * Pour chaque acteur : exécute l'opération et compare à la liste des autorisés. Un seul
 * `test` par (collection, action, cible) ; le message de l'échec nomme les acteurs fautifs.
 */
const check = async ({ expectAllowed, run, reset }) => {
  const wrong = [];
  // `reset` remet la cible dans son état de départ : une fois avant, puis après chaque écriture
  // acceptée (un refus ne change rien).
  if (reset) await reset();
  for (const actor of actorNames) {
    const ok = await allowed(() => run(dbOf(env, actor), actor));
    if (ok && reset) await reset();
    const expected = expectAllowed.includes(actor);
    if (ok !== expected) wrong.push(`${actor} : ${ok ? 'autorisé' : 'refusé'} (attendu ${expected ? 'autorisé' : 'refusé'})`);
  }
  assert.deepEqual(wrong, []);
};

const seededData = (path) => seedDocs().find(([p]) => p === path)?.[1];

// ───────────────────────── Administrateurs ─────────────────────────
suite('admins', 'admins/{uid}', () => {
  test('get de son propre document : l\'administrateur seulement', () =>
    check({ expectAllowed: ['admin'], run: (db) => getDoc(doc(db, 'admins/u-admin')) }));
  test('get du document d\'un autre administrateur : personne', () =>
    check({ expectAllowed: [], run: (db) => getDoc(doc(db, 'admins/u-admin2')) }));
  test('list : personne', () =>
    check({ expectAllowed: [], run: (db) => getDocs(collection(db, 'admins')) }));
  test('écriture : jamais, pas même l\'administrateur (création, mise à jour, suppression)', async () => {
    await check({ expectAllowed: [], run: (db) => setDoc(doc(db, 'admins/u-admin'), { x: 1 }) });
    await check({ expectAllowed: [], run: (db) => setDoc(doc(db, 'admins/nouveau'), {}) });
    await check({ expectAllowed: [], run: (db) => updateDoc(doc(db, 'admins/u-admin'), { x: 1 }) });
    await check({ expectAllowed: [], run: (db) => deleteDoc(doc(db, 'admins/u-admin')) });
  });
  test('un compte sans document admins ne devient pas administrateur en le créant', async () => {
    const db = dbOf(env, 'director');
    assert.equal(await allowed(() => setDoc(doc(db, 'admins/u-dir'), {})), false);
    assert.equal(await allowed(() => setDoc(doc(db, 'admins/u-dir'), { admin: true })), false);
  });
});

// ───────────────────────── Clubs ─────────────────────────
suite('clubs', 'clubs/{c}', () => {
  test('get du club c1 : ses membres et l\'administrateur', () =>
    check({ expectAllowed: MEMBERS, run: (db) => getDoc(doc(db, 'clubs/c1')) }));
  test('get du club c2 : son directeur et son enseignant, l\'administrateur', () =>
    check({
      expectAllowed: ['directorOther', 'teacherC2', 'admin'],
      run: (db) => getDoc(doc(db, 'clubs/c2')),
    }));
  test('list des clubs : l\'administrateur seulement', () =>
    check({ expectAllowed: ['admin'], run: (db) => getDocs(collection(db, 'clubs')) }));
  test('création d\'un club : l\'administrateur seulement', () =>
    check({
      expectAllowed: ['admin'],
      run: (db) => setDoc(doc(db, 'clubs/nouveau'), { name: 'Nouveau', createdAt: serverTimestamp() }),
      reset: () => remove(env, 'clubs/nouveau'),
    }));
  test('modification du nom : le directeur et l\'administrateur', () =>
    check({
      expectAllowed: MGR,
      run: (db) => updateDoc(doc(db, 'clubs/c1'), { name: 'Renommé' }),
      reset: () => put(env, 'clubs/c1', seededData('clubs/c1')),
    }));
  test('modification de la saison courante : l\'administrateur seulement', () =>
    check({
      expectAllowed: ['admin'],
      run: (db) => updateDoc(doc(db, 'clubs/c1'), { currentSeasonId: 'se1' }),
      reset: () => put(env, 'clubs/c1', seededData('clubs/c1')),
    }));
  test('suppression d\'un club : l\'administrateur seulement', () =>
    check({
      expectAllowed: ['admin'],
      run: (db) => deleteDoc(doc(db, 'clubs/c1')),
      reset: () => put(env, 'clubs/c1', seededData('clubs/c1')),
    }));
});

// ───────────────────────── Réglages ─────────────────────────
suite('settings', 'clubs/{c}/settings/main', () => {
  const path = 'clubs/c1/settings/main';
  test('get : tous les membres du club et l\'administrateur (aucune donnée nominative)', () =>
    check({ expectAllowed: MEMBERS, run: (db) => getDoc(doc(db, path)) }));
  test('list : personne', () =>
    check({ expectAllowed: [], run: (db) => getDocs(collection(db, 'clubs/c1/settings')) }));
  test('écriture (création, mise à jour) : le directeur et l\'administrateur', async () => {
    const reset = () => put(env, path, seededData(path));
    await check({
      expectAllowed: MGR,
      run: (db) => setDoc(doc(db, path), { ...seededData(path), passesRequired: 6 }),
      reset: reset,
    });
    await check({ expectAllowed: MGR, run: (db) => updateDoc(doc(db, path), { passesRequired: 7 }), reset: reset });
  });
  test('suppression : le directeur et l\'administrateur', () =>
    check({
      expectAllowed: MGR,
      run: (db) => deleteDoc(doc(db, path)),
      reset: () => put(env, path, seededData(path)),
    }));
  test('un autre identifiant que « main » est refusé à tous', () =>
    check({
      expectAllowed: [],
      run: (db) => setDoc(doc(db, 'clubs/c1/settings/autre'), seededData(path)),
    }));
});

// ───────────────────────── Membres ─────────────────────────
suite('members', 'clubs/{c}/members/{uid}', () => {
  const teacherPath = 'clubs/c1/members/u-teacher-a';
  const reset = () => put(env, teacherPath, seededData(teacherPath));
  test('get du member d\'un enseignant : lui-même, le directeur, l\'administrateur', () =>
    check({
      expectAllowed: ['teacherA', 'director', 'admin'],
      run: (db) => getDoc(doc(db, teacherPath)),
    }));
  test('get de son propre member, quel que soit le rôle (requête de groupe de collections)', async () => {
    const owners = {
      student: 'u-student',
      guardian: 'u-guardian',
      guardian2: 'u-guardian2',
      teacherA: 'u-teacher-a',
      teacherB: 'u-teacher-b',
      teacherC2: 'u-teacher-c2',
      director: 'u-dir',
      directorOther: 'u-dir2',
    };
    for (const [actor, uid] of Object.entries(owners)) {
      const db = dbOf(env, actor);
      const own = await getDocs(query(collectionGroup(db, 'members'), where('uid', '==', uid)));
      assert.equal(own.size, 1, `${actor} lit son member`);
      const others = Object.values(owners).filter((other) => other !== uid);
      assert.equal(
        await allowed(() => getDocs(query(collectionGroup(db, 'members'), where('uid', '==', others[0])))),
        false,
        `${actor} ne lit pas celui d'un autre`,
      );
    }
    // Sans filtre : refusé, même au directeur ; un compte sans member trouve zéro document.
    await check({ expectAllowed: [], run: (db) => getDocs(collectionGroup(db, 'members')) });
    const nobody = await getDocs(
      query(collectionGroup(dbOf(env, 'invited'), 'members'), where('uid', '==', 'u-invited')),
    );
    assert.equal(nobody.size, 0);
  });
  test('list des members du club : le directeur et l\'administrateur', () =>
    check({ expectAllowed: MGR, run: (db) => getDocs(collection(db, 'clubs/c1/members')) }));
  test('création directe (sans invitation) d\'un enseignant : le directeur et l\'administrateur', () =>
    check({
      expectAllowed: MGR,
      run: (db) =>
        setDoc(doc(db, 'clubs/c1/members/u-new'), {
          ...member('u-new', 'teacher'),
          createdAt: serverTimestamp(),
        }),
      reset: () => remove(env, 'clubs/c1/members/u-new'),
    }));
  test('création d\'un directeur : l\'administrateur seulement', () =>
    check({
      expectAllowed: ['admin'],
      run: (db) =>
        setDoc(doc(db, 'clubs/c1/members/u-new'), {
          ...member('u-new', 'director'),
          createdAt: serverTimestamp(),
        }),
      reset: () => remove(env, 'clubs/c1/members/u-new'),
    }));
  test('mise à jour des groupes d\'un enseignant : le directeur et l\'administrateur', () =>
    check({
      expectAllowed: MGR,
      run: (db) => updateDoc(doc(db, teacherPath), { groupIds: ['g1', 'g2'] }),
      reset: reset,
    }));
  test('mise à jour du nom affiché : le titulaire, le directeur, l\'administrateur', () =>
    check({
      expectAllowed: ['teacherA', 'director', 'admin'],
      run: (db) => updateDoc(doc(db, teacherPath), { displayName: 'Sophie' }),
      reset: reset,
    }));
  test('mise à jour d\'un directeur : l\'administrateur seulement (et lui-même pour son nom)', async () => {
    const path = 'clubs/c1/members/u-dir';
    const resetDirector = () => put(env, path, seededData(path));
    await check({
      expectAllowed: ['admin'],
      run: (db) => updateDoc(doc(db, path), { groupIds: ['g1'] }),
      reset: resetDirector,
    });
    await check({
      expectAllowed: ['director', 'admin'],
      run: (db) => updateDoc(doc(db, path), { displayName: 'Autre nom' }),
      reset: resetDirector,
    });
  });
  test('suppression d\'un enseignant : le directeur et l\'administrateur', () =>
    check({
      expectAllowed: MGR,
      run: (db) => deleteDoc(doc(db, teacherPath)),
      reset: reset,
    }));
  test('suppression d\'un directeur : l\'administrateur seulement', () =>
    check({
      expectAllowed: ['admin'],
      run: (db) => deleteDoc(doc(db, 'clubs/c1/members/u-dir')),
      reset: () => put(env, 'clubs/c1/members/u-dir', seededData('clubs/c1/members/u-dir')),
    }));
  test('un enseignant, un élève ou un parent ne crée ni ne supprime aucun member', async () => {
    for (const actor of ['teacherA', 'student', 'guardian', 'invited']) {
      const db = dbOf(env, actor);
      assert.equal(
        await allowed(() => setDoc(doc(db, 'clubs/c1/members/u-x'), { ...member('u-x', 'student'), createdAt: serverTimestamp() })),
        false,
        actor,
      );
      assert.equal(await allowed(() => deleteDoc(doc(db, 'clubs/c1/members/u-student'))), false, actor);
    }
  });
});

// ───────────────────────── Invitations (lecture ; le reste : invitations.test.mjs) ─────────────────────────
suite('invitations', 'invitations/{code}', () => {
  const verified = actorNames.filter((a) => !['anonymous', 'unverified'].includes(a));
  test('get par le code : tout compte connecté à e-mail vérifié', () =>
    check({ expectAllowed: verified, run: (db) => getDoc(doc(db, 'invitations/AAAAAAAAAA')) }));
  test('get d\'un code inexistant : même autorisation (le refus ne révèle rien)', () =>
    check({ expectAllowed: verified, run: (db) => getDoc(doc(db, 'invitations/BBBBBBBBBB')) }));
  test('list : personne, pas même l\'administrateur', () =>
    check({ expectAllowed: [], run: (db) => getDocs(collection(db, 'invitations')) }));
  test('list filtrée sur le club : personne', () =>
    check({
      expectAllowed: [],
      run: (db) => getDocs(query(collection(db, 'invitations'), where('clubId', '==', 'c1'))),
    }));
});

// ───────────────────────── Saisons ─────────────────────────
suite('seasons', 'clubs/{c}/seasons/{s}', () => {
  const path = 'clubs/c1/seasons/se1';
  test('get et list : les membres du club et l\'administrateur', async () => {
    await check({ expectAllowed: MEMBERS, run: (db) => getDoc(doc(db, path)) });
    await check({ expectAllowed: MEMBERS, run: (db) => getDocs(collection(db, 'clubs/c1/seasons')) });
  });
  test('création, mise à jour, suppression : le directeur et l\'administrateur', async () => {
    await check({
      expectAllowed: MGR,
      run: (db) => setDoc(doc(db, 'clubs/c1/seasons/se2'), { label: '2027-2028' }),
      reset: () => remove(env, 'clubs/c1/seasons/se2'),
    });
    await check({
      expectAllowed: MGR,
      run: (db) => updateDoc(doc(db, path), { label: 'clôturée' }),
      reset: () => put(env, path, seededData(path)),
    });
    await check({
      expectAllowed: MGR,
      run: (db) => deleteDoc(doc(db, path)),
      reset: () => put(env, path, seededData(path)),
    });
  });
});

// ───────────────────────── Groupes ─────────────────────────
suite('groups', 'clubs/{c}/groups/{g}', () => {
  test('get : directeur, administrateur, enseignant du groupe, élève et parent du groupe', async () => {
    await check({
      expectAllowed: [...staffOf('g1'), ...familyOfGroup('g1')],
      run: (db) => getDoc(doc(db, 'clubs/c1/groups/g1')),
    });
    await check({
      expectAllowed: [...staffOf('g2'), ...familyOfGroup('g2')],
      run: (db) => getDoc(doc(db, 'clubs/c1/groups/g2')),
    });
  });
  test('list : le directeur et l\'administrateur', () =>
    check({ expectAllowed: MGR, run: (db) => getDocs(collection(db, 'clubs/c1/groups')) }));
  test('écriture : le directeur et l\'administrateur seulement (l\'enseignant ne crée pas de groupe)', async () => {
    const group = { seasonId: 'se1', name: 'Vendredi', audience: 'children', teacherUids: [] };
    await check({
      expectAllowed: MGR,
      run: (db) => setDoc(doc(db, 'clubs/c1/groups/g3'), group),
      reset: () => remove(env, 'clubs/c1/groups/g3'),
    });
    await check({
      expectAllowed: MGR,
      run: (db) => updateDoc(doc(db, 'clubs/c1/groups/g1'), { name: 'Renommé' }),
      reset: () => put(env, 'clubs/c1/groups/g1', seededData('clubs/c1/groups/g1')),
    });
    await check({
      expectAllowed: MGR,
      run: (db) => deleteDoc(doc(db, 'clubs/c1/groups/g1')),
      reset: () => put(env, 'clubs/c1/groups/g1', seededData('clubs/c1/groups/g1')),
    });
  });
});

// ───────────────────────── Fiches élèves ─────────────────────────
suite('students', 'clubs/{c}/students/{id}', () => {
  for (const g of ['g1', 'g2']) {
    const s = studentOf(g);
    const path = `clubs/c1/students/${s}`;
    const reset = () => put(env, path, seededData(path));
    test(`get de la fiche ${s} (groupe ${g}) : gestionnaires, enseignant du groupe, élève et parent liés`, () =>
      check({
        expectAllowed: [...staffOf(g), ...familyOfStudent(g)],
        run: (db) => getDoc(doc(db, path)),
      }));
    test(`list des fiches du groupe ${g} (array-contains) : gestionnaires et enseignant du groupe`, () =>
      check({
        expectAllowed: staffOf(g),
        run: (db) =>
          getDocs(query(collection(db, 'clubs/c1/students'), where('groupIds', 'array-contains', g))),
      }));
    test(`création d'une fiche dans le groupe ${g} : gestionnaires et enseignant du groupe`, () =>
      check({
        expectAllowed: staffOf(g),
        run: (db) => setDoc(doc(db, 'clubs/c1/students/nouvelle'), student([g])),
        reset: () => remove(env, 'clubs/c1/students/nouvelle'),
      }));
    test(`mise à jour de la fiche ${s} : le directeur et l'administrateur (l'enseignant ne modifie pas)`, () =>
      check({
        expectAllowed: MGR,
        run: (db) => updateDoc(doc(db, path), { firstName: 'Autre' }),
        reset: reset,
      }));
    test(`effacement de la fiche ${s} : le directeur et l'administrateur`, () =>
      check({
        expectAllowed: MGR,
        run: (db) => deleteDoc(doc(db, path)),
        reset: reset,
      }));
  }
  test('list non filtrée : le directeur et l\'administrateur seulement ; élève et parent jamais', () =>
    check({ expectAllowed: MGR, run: (db) => getDocs(collection(db, 'clubs/c1/students')) }));
  test('list sur plusieurs groupes (array-contains-any) : refusée dès qu\'un groupe n\'est pas le sien', async () => {
    const run = (groups) => (db) =>
      getDocs(query(collection(db, 'clubs/c1/students'), where('groupIds', 'array-contains-any', groups)));
    await check({ expectAllowed: [...MGR, 'teacherA'], run: run(['g1']) });
    await check({ expectAllowed: MGR, run: run(['g1', 'g2']) });
  });
  test('un enseignant ne crée pas une fiche sans groupe ni dans un groupe qui n\'est pas le sien', async () => {
    const db = dbOf(env, 'teacherA');
    assert.equal(await allowed(() => setDoc(doc(db, 'clubs/c1/students/n1'), student([]))), false);
    assert.equal(await allowed(() => setDoc(doc(db, 'clubs/c1/students/n2'), student(['g1', 'g2']))), false);
  });
  test('club voisin : la fiche du club c2 est invisible depuis c1 et inversement', async () => {
    await check({
      expectAllowed: ['teacherC2', 'directorOther', 'admin'],
      run: (db) => getDoc(doc(db, 'clubs/c2/students/s-c2')),
    });
  });
});

// ───────────────────────── Données de groupe ─────────────────────────
const groupOwnedSuite = (name, options) => {
  const { hasStudent, familyRead, teacherWrites = true, readStudentLinked = false } = options;
  suite(name, `clubs/{c}/${name}/{id}`, () => {
    const idOf = options.idOf ?? ((g) => `${options.prefix}-${g}`);
    const pathOf = (g) => `clubs/c1/${name}/${idOf(g)}`;
    const bodyOf = (g, extra = {}) => owned(g, hasStudent ? studentOf(g) : undefined, extra);
    const reset = (g) => () => put(env, pathOf(g), seededData(pathOf(g)));
    const readers = (g) => {
      const base = staffOf(g);
      if (familyRead === 'group') return [...base, ...familyOfGroup(g)];
      if (familyRead === 'student') return [...base, ...familyOfStudent(g)];
      return base;
    };
    const writers = (g) => (teacherWrites ? staffOf(g) : MGR);

    for (const g of ['g1', 'g2']) {
      test(`get (groupe ${g}) : ${familyRead === 'none' ? 'animateurs du groupe' : 'animateurs du groupe et famille liée'}`, () =>
        check({ expectAllowed: readers(g), run: (db) => getDoc(doc(db, pathOf(g))) }));

      test(`list filtrée sur le groupe ${g}`, () =>
        check({
          expectAllowed: [...staffOf(g), ...(familyRead === 'group' ? familyOfGroup(g) : [])],
          run: (db) =>
            getDocs(query(collection(db, `clubs/c1/${name}`), where('groupId', '==', g))),
        }));

      if (readStudentLinked) {
        test(`list filtrée sur la fiche ${studentOf(g)} : animateurs du groupe et famille liée`, () =>
          check({
            // Une requête sur la seule fiche ne prouve pas le groupe : l'enseignant filtre par groupe.
            expectAllowed: [...MGR, ...familyOfStudent(g)],
            run: (db) =>
              getDocs(query(collection(db, `clubs/c1/${name}`), where('studentId', '==', studentOf(g)))),
          }));
      }

      test(`création dans le groupe ${g}`, () =>
        check({
          expectAllowed: writers(g),
          run: (db) => setDoc(doc(db, `clubs/c1/${name}/nouveau`), bodyOf(g)),
          reset: () => remove(env, `clubs/c1/${name}/nouveau`),
        }));

      test(`mise à jour (groupe ${g})`, () =>
        check({
          expectAllowed: writers(g),
          run: (db) => updateDoc(doc(db, pathOf(g)), { updatedAt: ts(now()) }),
          reset: reset(g),
        }));

      test(`suppression (groupe ${g})`, () =>
        check({
          expectAllowed: writers(g),
          run: (db) => deleteDoc(doc(db, pathOf(g))),
          reset: reset(g),
        }));
    }

    test('list non filtrée : le directeur et l\'administrateur seulement', () =>
      check({ expectAllowed: MGR, run: (db) => getDocs(collection(db, `clubs/c1/${name}`)) }));

    test('les champs d\'appartenance ne changent jamais (groupId, seasonId, studentId)', async () => {
      const patches = [{ groupId: 'g2' }, { seasonId: 'se2' }];
      if (hasStudent) patches.push({ studentId: 's2' });
      for (const patch of patches) {
        await check({
          expectAllowed: [],
          run: (db) => updateDoc(doc(db, pathOf('g1')), patch),
          reset: reset('g1'),
        });
      }
    });

    test('club voisin : un document du club c2 reste invisible aux acteurs de c1', async () => {
      const path = `clubs/c2/${name}/${options.prefix}-c2`;
      await put(env, path, owned('g1', hasStudent ? 's-c2' : undefined));
      await check({
        expectAllowed: ['directorOther', 'teacherC2', 'admin'],
        run: (db) => getDoc(doc(db, path)),
      });
      await remove(env, path);
    });
  });
};

groupOwnedSuite('memberships', {
  prefix: 'm',
  idOf: (g) => `${studentOf(g)}_2026-09-01`,
  hasStudent: true,
  familyRead: 'none',
  teacherWrites: false,
});
groupOwnedSuite('sessions', { prefix: 'ss', hasStudent: false, familyRead: 'group' });
groupOwnedSuite('records', { prefix: 'r', hasStudent: false, familyRead: 'none' });
groupOwnedSuite('attempts', { prefix: 'a', hasStudent: true, familyRead: 'student', readStudentLinked: true });
groupOwnedSuite('acquisitions', { prefix: 'q', hasStudent: true, familyRead: 'student', readStudentLinked: true });
groupOwnedSuite('assessments', { prefix: 'as', hasStudent: true, familyRead: 'none' });
groupOwnedSuite('acknowledgements', { prefix: 'k', hasStudent: true, familyRead: 'none' });

// ───────────────────────── Archives ─────────────────────────
suite('archives', 'clubs/{c}/archives/{id}', () => {
  const path = 'clubs/c1/archives/ar1';
  const animators = ['teacherA', 'teacherB', 'director', 'admin'];
  test('get et list : les animateurs du club ; ni élève ni parent', async () => {
    await check({ expectAllowed: animators, run: (db) => getDoc(doc(db, path)) });
    await check({ expectAllowed: animators, run: (db) => getDocs(collection(db, 'clubs/c1/archives')) });
  });
  test('écriture : le directeur et l\'administrateur (la clôture)', async () => {
    await check({
      expectAllowed: MGR,
      run: (db) => setDoc(doc(db, 'clubs/c1/archives/ar2'), { seasonId: 'se1', public: 'adults' }),
      reset: () => remove(env, 'clubs/c1/archives/ar2'),
    });
    await check({
      expectAllowed: MGR,
      run: (db) => deleteDoc(doc(db, path)),
      reset: () => put(env, path, seededData(path)),
    });
  });
});

// ───────────────────────── Sensibilité de la grille ─────────────────────────
test('preuve de sensibilité : l\'administrateur lit bien chaque club, la grille ne refuse pas tout', async () => {
  const db = dbOf(env, 'admin');
  assert.equal(await allowed(() => getDoc(doc(db, 'clubs/c1'))), true);
  assert.equal(await allowed(() => getDoc(doc(db, 'clubs/c2'))), true);
});

