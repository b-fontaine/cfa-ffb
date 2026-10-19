// L'espace d'un parent ou d'un élève (lot FB6, ADR 0024 décision 26, ADR 0025) contre les VRAIES
// règles de l'émulateur : ce qu'il lit est exactement ce que l'application demande
// (`family_reads.json`, relu aussi par le test Dart de l'espace), tout le reste lui est refusé,
// il n'écrit rien, et un lien retiré lui retire l'accès EN DIRECT.
//
// Jeu de données (support.mjs) : club c1, groupes g1 et g2, fiches s1 (Léa, g1) et s2 (Tom, g2) ;
// u-guardian est parent de s1 (g1), u-student est l'élève s1 (g1), u-guardian2 est parent de s2.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { after, before, beforeEach, describe, test } from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  Timestamp,
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  onSnapshot,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

import { allowed, createEnv, dbOf, member, put, remove, seed, uids } from './support.mjs';

const reads = JSON.parse(
  readFileSync(resolve(dirname(fileURLToPath(import.meta.url)), 'family_reads.json'), 'utf8'),
);

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

/** Le jeu de données vu par `actor` : sa fiche, son groupe, l'autre fiche et l'autre groupe. */
const world = (actor) => ({
  club: 'c1',
  student: 's1',
  group: 'g1',
  uid: uids[actor],
  otherStudent: 's2',
  otherGroup: 'g2',
  otherUid: 'u-guardian2',
  otherClub: 'c2',
  otherClubStudent: 's-c2',
});

const fill = (template, values) =>
  template.replace(/\{(\w+)\}/g, (_, key) => {
    assert.ok(key in values, `variable ${key} inconnue`);
    return values[key];
  });

/** Joue une demande du format de `family_reads.json` ; refus des règles = `false`. */
const play = async (actor, request) => {
  const db = dbOf(env, actor);
  const [verb, ...rest] = request.split(' ');
  if (verb === 'get') return allowed(() => getDoc(doc(db, rest[0])));
  if (verb === 'list') return allowed(() => getDocs(collection(db, rest[0])));
  if (verb === 'group') {
    const [field, value] = rest[1].split('=');
    return allowed(() => getDocs(query(collectionGroup(db, rest[0]), where(field, '==', value))));
  }
  if (verb === 'query') {
    const [field, value] = rest[1].split('=');
    // `groupIds` est une liste : la fiche d'un élève se cherche par `array-contains`.
    const clause = field === 'groupIds' ? where(field, 'array-contains', value) : where(field, '==', value);
    return allowed(() => getDocs(query(collection(db, rest[0]), clause)));
  }
  assert.equal(verb, 'watch', `demande inconnue : ${request}`);
  const [kind, ...target] = rest;
  const reference =
    kind === 'document'
      ? doc(db, target[0])
      : query(collection(db, target[0]), where(target[1].split('=')[0], '==', target[1].split('=')[1]));
  return new Promise((resolveWatch, rejectWatch) => {
    const stop = onSnapshot(
      reference,
      () => {
        stop();
        resolveWatch(true);
      },
      (error) => {
        if (error.code === 'permission-denied') resolveWatch(false);
        else rejectWatch(error);
      },
    );
  });
};

describe('ce que l\'application demande est permis', () => {
  for (const actor of ['guardian', 'student']) {
    for (const template of [...reads.famille, ...reads.connexion]) {
      test(`${actor} : ${template}`, async () => {
        const request = fill(template, world(actor));
        assert.equal(await play(actor, request), true, request);
      });
    }
  }
});

describe('tout le reste est refusé', () => {
  for (const actor of ['guardian', 'student']) {
    for (const template of reads.interdit) {
      test(`${actor} : ${template}`, async () => {
        const request = fill(template, world(actor));
        assert.equal(await play(actor, request), false, request);
      });
    }
  }

  test('un parent ne lit que ses fiches : celle d\'un autre parent lui est refusée, et réciproquement', async () => {
    assert.equal(await play('guardian2', 'get clubs/c1/students/s1'), false);
    assert.equal(await play('guardian2', 'get clubs/c1/students/s2'), true);
    assert.equal(await play('guardian', 'get clubs/c1/students/s2'), false);
  });

  test('un parent de deux enfants lit les deux fiches, et seulement elles', async () => {
    await put(env, `${C}/members/u-guardian`, member('u-guardian', 'guardian', { groupIds: ['g1', 'g2'], studentIds: ['s1', 's2'] }));
    await put(env, `${C}/students/s3`, { firstName: 'Marc', groupIds: ['g1'] });
    assert.equal(await play('guardian', 'get clubs/c1/students/s1'), true);
    assert.equal(await play('guardian', 'get clubs/c1/students/s2'), true);
    assert.equal(await play('guardian', 'query clubs/c1/attempts studentId=s2'), true);
    assert.equal(await play('guardian', 'get clubs/c1/students/s3'), false, 'un camarade du même groupe');
    assert.equal(await play('guardian', 'query clubs/c1/attempts studentId=s3'), false);
  });
});

describe('aucune écriture', () => {
  const attempt = () => ({
    groupId: 'g1',
    seasonId: 'se1',
    studentId: 's1',
    sessionId: 'x1',
    blockId: 'puissance',
    exerciseNumber: 1,
    date: '2026-10-03T00:00:00.000',
    potted: 4,
    total: 5,
    createdAt: serverTimestamp(),
    recordedAt: Timestamp.fromMillis(Date.now()),
  });

  for (const actor of ['guardian', 'student']) {
    test(`${actor} : ni création, ni modification, ni suppression, nulle part`, async () => {
      const db = dbOf(env, actor);
      const attempts = [
        ['créer un passage', () => setDoc(doc(db, `${C}/attempts/new`), attempt())],
        ['modifier un passage', () => updateDoc(doc(db, `${C}/attempts/a-g1`), { potted: 5 })],
        ['supprimer un passage', () => deleteDoc(doc(db, `${C}/attempts/a-g1`))],
        ['modifier sa fiche', () => updateDoc(doc(db, `${C}/students/s1`), { firstName: 'X' })],
        ['créer une fiche', () => setDoc(doc(db, `${C}/students/s9`), { firstName: 'X', groupIds: ['g1'] })],
        ['supprimer sa fiche', () => deleteDoc(doc(db, `${C}/students/s1`))],
        ['planifier une séance', () => setDoc(doc(db, `${C}/sessions/new`), { groupId: 'g1', seasonId: 'se1' })],
        ['supprimer une séance', () => deleteDoc(doc(db, `${C}/sessions/ss-g1`))],
        ['modifier le groupe', () => updateDoc(doc(db, `${C}/groups/g1`), { name: 'X' })],
        ['modifier les réglages', () => updateDoc(doc(db, `${C}/settings/main`), { passesRequired: 1 })],
        ['créer une saisie', () => setDoc(doc(db, `${C}/records/new`), { groupId: 'g1', seasonId: 'se1' })],
        ['ajouter une fiche à son propre lien', () => updateDoc(doc(db, `${C}/members/${uids[actor]}`), { studentIds: ['s1', 's2'] })],
        ['changer son rôle', () => updateDoc(doc(db, `${C}/members/${uids[actor]}`), { role: 'director' })],
        ['inviter', () => setDoc(doc(db, 'invitations/ZZZZZZZZZZ'), { clubId: 'c1', role: 'teacher' })],
      ];
      for (const [label, operation] of attempts) {
        assert.equal(await allowed(operation), false, label);
      }
    });
  }
});

describe('un lien retiré retire l\'accès, en direct', () => {
  /** Écoute `reference` : états, erreurs, et de quoi attendre une condition. */
  const listen = (reference) => {
    const log = { events: [], errors: [] };
    const waiters = [];
    const poke = () => waiters.slice().forEach((waiter) => waiter());
    log.stop = onSnapshot(
      reference,
      (snapshot) => {
        log.events.push(snapshot);
        poke();
      },
      (error) => {
        log.errors.push(error);
        poke();
      },
    );
    log.until = (predicate, label, timeoutMs = 15000) =>
      new Promise((resolveUntil, rejectUntil) => {
        const check = () => {
          if (predicate(log)) {
            waiters.splice(waiters.indexOf(check), 1);
            clearTimeout(timer);
            resolveUntil(log);
          }
        };
        const timer = setTimeout(() => {
          waiters.splice(waiters.indexOf(check), 1);
          rejectUntil(new Error(`délai dépassé : ${label}`));
        }, timeoutMs);
        waiters.push(check);
        check();
      });
    return log;
  };

  const attemptsOf = (actor, student) =>
    query(collection(dbOf(env, actor), `${C}/attempts`), where('studentId', '==', student));

  test('le parent suit les passages de sa fiche : un passage saisi par l\'animateur lui arrive', async () => {
    const reader = listen(attemptsOf('guardian', 's1'));
    await reader.until((l) => l.events.length >= 1, 'état de départ');
    assert.deepEqual(reader.events.at(-1).docs.map((d) => d.id), ['a-g1']);

    await setDoc(doc(dbOf(env, 'teacherA'), `${C}/attempts/a-live`), {
      groupId: 'g1',
      seasonId: 'se1',
      studentId: 's1',
      sessionId: 'x1',
      blockId: 'puissance',
      exerciseNumber: 1,
      date: '2026-10-03T00:00:00.000',
      potted: 4,
      total: 5,
      createdAt: serverTimestamp(),
      recordedAt: Timestamp.fromMillis(Date.now()),
    });

    await reader.until(
      (l) => l.events.at(-1).docs.some((d) => d.id === 'a-live'),
      'le passage de l\'animateur',
    );
    reader.stop();
  });

  test('le lien du parent est supprimé : les nouvelles lectures sont refusées ; une écoute déjà ouverte n\'est refusée qu\'à la modification suivante du document écouté', async () => {
    const reader = listen(attemptsOf('guardian', 's1'));
    const link = listen(doc(dbOf(env, 'guardian'), `${C}/members/u-guardian`));
    await reader.until((l) => l.events.length >= 1, 'état de départ');
    await link.until((l) => l.events.length >= 1, 'son lien');

    await remove(env, `${C}/members/u-guardian`);
    await put(env, `${C}/attempts/a-after`, {
      groupId: 'g1', seasonId: 'se1', studentId: 's1', sessionId: 'x1', blockId: 'puissance',
      exerciseNumber: 1, date: '2026-10-03T00:00:00.000', potted: 4, total: 5,
      createdAt: Timestamp.now(), recordedAt: Timestamp.now(),
    });

    await reader.until((l) => l.errors.length >= 1, 'le refus du flux des passages');
    assert.equal(reader.errors[0].code, 'permission-denied');
    // Son propre lien : le document n'existe plus, la règle le refuse ou le flux le dit absent.
    await link.until(
      (l) => l.errors.length >= 1 || l.events.at(-1)?.exists() === false,
      'son lien disparu',
    );
    assert.equal(await play('guardian', 'get clubs/c1/students/s1'), false);
    assert.equal(await play('guardian', 'query clubs/c1/attempts studentId=s1'), false);
    assert.equal(await play('guardian', 'get clubs/c1/members/u-guardian'), false);
    reader.stop();
    link.stop();
  });


  test('known limit: un groupe retiré du lien reste servi à l\'écoute ouverte jusqu\'à FB7, et la lecture neuve est refusée', async () => {
    // Mesuré à l'émulateur (SDK navigateur, vraies règles), jamais deviné : c'est le comportement
    // SERVEUR que l'ADR 0024 (notes FB6) décrit. Il est durable : FB7 (relire la portée de session
    // côté client) ne le fait pas casser, c'est celui des règles. Ce qui casse avec FB7 est la
    // limite CLIENT, fixée par deux tests unitaires à doubles (`check_family_access_test.dart` et
    // `family_space_cubit_test.dart`, « known limit »), qui ne mesurent rien à l'émulateur.
    const db = dbOf(env, 'guardian');
    const sessionsOfG1 = () => query(collection(db, `${C}/sessions`), where('groupId', '==', 'g1'));
    const sessions = listen(sessionsOfG1());
    const group = listen(doc(db, `${C}/groups/g1`));
    await sessions.until((l) => l.events.length >= 1, 'séances du groupe');
    await group.until((l) => l.events.length >= 1, 'document du groupe');

    // Le club retire le groupe du lien ; la fiche reste liée.
    await put(env, `${C}/members/u-guardian`, member('u-guardian', 'guardian', { groupIds: [], studentIds: ['s1'] }));
    await new Promise((resolveWait) => setTimeout(resolveWait, 1500));

    // 1. Les écoutes déjà ouvertes ne reçoivent aucun refus ; 2. une lecture faite SUR LA MÊME
    // instance du client, pendant qu'une écoute identique y est ouverte, est servie par la cible de
    // cette écoute (le serveur n'est pas réinterrogé : `fromCache` vaut false parce que la cible
    // est synchronisée avec lui, pas parce que la lecture serait revalidée), comme celle de
    // l'écran qui se recharge au changement du lien.
    assert.deepEqual(sessions.errors, []);
    assert.deepEqual(group.errors, []);
    const served = await getDocs(sessionsOfG1());
    assert.equal(served.size, 1);
    assert.equal(served.metadata.fromCache, false);

    // Témoin : la même lecture depuis une AUTRE instance du client (aucune écoute ouverte) est
    // refusée. Ce qui est servi ne l'est donc que par l'écoute déjà ouverte de la première instance.
    assert.equal(await play('guardian', 'query clubs/c1/sessions groupId=g1'), false);
    assert.equal(await play('guardian', 'get clubs/c1/groups/g1'), false);

    // 3. Au prochain changement d'une séance de ce groupe, l'écoute est refusée.
    await put(env, `${C}/sessions/ss-g1`, {
      groupId: 'g1', seasonId: 'se1', title: 'Modifiée', date: '2026-10-20T00:00:00.000',
      audience: 'children', createdAt: Timestamp.now(),
    });
    await sessions.until((l) => l.errors.length >= 1, 'le refus de l\'écoute des séances');
    assert.equal(sessions.errors[0].code, 'permission-denied');
    sessions.stop();
    group.stop();

    // 4. Toute lecture neuve du groupe retiré est refusée.
    assert.equal(await play('guardian', 'query clubs/c1/sessions groupId=g1'), false);
    assert.equal(await play('guardian', 'get clubs/c1/groups/g1'), false);
    assert.equal(await play('guardian', 'get clubs/c1/students/s1'), true);
  });

  test('une fiche retirée du lien : celle-ci est refusée, l\'autre reste lisible', async () => {
    await put(env, `${C}/members/u-guardian`, member('u-guardian', 'guardian', { groupIds: ['g1', 'g2'], studentIds: ['s1', 's2'] }));
    assert.equal(await play('guardian', 'get clubs/c1/students/s2'), true);

    await put(env, `${C}/members/u-guardian`, member('u-guardian', 'guardian', { groupIds: ['g1'], studentIds: ['s1'] }));

    assert.equal(await play('guardian', 'get clubs/c1/students/s2'), false);
    assert.equal(await play('guardian', 'query clubs/c1/attempts studentId=s2'), false);
    assert.equal(await play('guardian', 'query clubs/c1/sessions groupId=g2'), false);
    assert.equal(await play('guardian', 'get clubs/c1/students/s1'), true);
  });
});
