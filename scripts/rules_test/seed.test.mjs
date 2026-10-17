// La graine des émulateurs (scripts/seed_emulator.mjs) et les règles, avec de VRAIS jetons de
// l'émulateur Auth (lot FB3).
//
// - la graine refuse tout hôte non local et tout projet qui n'est pas « demo-… » ;
// - posée deux fois, elle donne le même résultat (idempotente) ;
// - chaque compte de la graine se connecte à l'émulateur Auth et voit, dans Firestore, ce que
//   la matrice des droits lui accorde (jeton réel : la revendication `email_verified` vient du
//   service, pas d'un contexte simulé) ;
// - un compte neuf, créé et vérifié par l'émulateur Auth, rejoint le club « Démo » avec le code
//   de la graine (le parcours d'invitation de bout en bout, sans l'interface).
import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';

import { deleteApp, initializeApp } from 'firebase/app';
import {
  applyActionCode,
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  getAuth,
  sendEmailVerification,
  signInWithEmailAndPassword,
} from 'firebase/auth';
import {
  collection,
  collectionGroup,
  connectFirestoreEmulator,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  where,
  writeBatch,
} from 'firebase/firestore';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';

import { accounts, assertLocalEmulators, demoClubId, demoInvitationCode, demoPassword, environmentFrom, seedEmulators } from '../seed_emulator.mjs';
import { allowed, projectId, readRules } from './support.mjs';

const environment = environmentFrom();
const [firestoreHost, firestorePort] = environment.firestoreHost.split(':');

let uids;
const apps = [];

/** Connecte [email] à l'émulateur Auth et rend un Firestore qui porte son jeton réel. */
const signedIn = async (email, password = demoPassword) => {
  const app = initializeApp({ apiKey: 'seed', projectId }, `actor-${apps.length}-${Date.now()}`);
  apps.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${environment.authHost}`, { disableWarnings: true });
  const { user } = await signInWithEmailAndPassword(auth, email, password);
  const { getFirestore } = await import('firebase/firestore');
  const db = getFirestore(app);
  connectFirestoreEmulator(db, firestoreHost, Number(firestorePort));
  return { db, auth, user, app };
};

before(async () => {
  // Les règles de l'émulateur sont celles du dépôt (ou de la copie mutée) : on les charge ici
  // aussi, ce fichier pouvant tourner après un autre qui en aurait chargé d'autres.
  const env = await initializeTestEnvironment({
    projectId,
    firestore: { rules: readRules(), host: firestoreHost, port: Number(firestorePort) },
  });
  await env.clearFirestore();
  await env.cleanup();
  uids = await seedEmulators(environment);
});

after(async () => {
  await Promise.all(apps.map((app) => deleteApp(app).catch(() => undefined)));
});

describe('garde-fous de la graine', () => {
  const ok = { firestoreHost: '127.0.0.1:8080', authHost: 'localhost:9099', projectId: 'demo-cfa-ffb' };

  test('accepte des émulateurs locaux et un projet de démonstration', () => {
    assert.doesNotThrow(() => assertLocalEmulators(ok));
    assert.doesNotThrow(() => assertLocalEmulators({ ...ok, firestoreHost: '[::1]:8080' }));
  });

  test('refuse un hôte Firestore ou Auth qui n\'est pas local', () => {
    for (const host of ['firestore.googleapis.com:443', '10.0.0.5:8080', 'evil.example:8080', '127.0.0.1', '', undefined]) {
      assert.throws(() => assertLocalEmulators({ ...ok, firestoreHost: host }), /hôte Firestore refusé/, String(host));
      assert.throws(() => assertLocalEmulators({ ...ok, authHost: host }), /hôte Auth refusé/, String(host));
    }
  });

  test('refuse un projet qui n\'est pas « demo-… », dont le projet réel', () => {
    for (const project of ['animation-billard', 'prod', '', undefined, 'my-demo-project']) {
      assert.throws(() => assertLocalEmulators({ ...ok, projectId: project }), /projet refusé/, String(project));
    }
  });

  test('l\'environnement par défaut est celui de firebase.json', () => {
    assert.deepEqual(environmentFrom({}), {
      firestoreHost: '127.0.0.1:8080',
      authHost: '127.0.0.1:9099',
      projectId: '',
    });
    assert.equal(environmentFrom({ GCLOUD_PROJECT: 'demo-x' }).projectId, 'demo-x');
  });
});

describe('graine posée, vue par chaque rôle (jetons réels)', () => {
  test('est idempotente : une seconde pose donne les mêmes comptes', async () => {
    assert.deepEqual(await seedEmulators(environment), uids);
  });

  test('l\'administrateur lit les clubs, le directeur son club et son équipe', async () => {
    const admin = await signedIn(accounts.admin.email);
    assert.equal(admin.user.emailVerified, true);
    assert.equal((await getDocs(collection(admin.db, 'clubs'))).size, 1);

    const director = await signedIn(accounts.director.email);
    assert.equal((await getDoc(doc(director.db, `clubs/${demoClubId}`))).data().name, 'Démo');
    assert.equal((await getDocs(collection(director.db, `clubs/${demoClubId}/members`))).size, 5);
    assert.equal((await getDocs(collection(director.db, `clubs/${demoClubId}/students`))).size, 4);
  });

  test('chaque enseignant ne voit que ses élèves', async () => {
    const teacherA = await signedIn(accounts.teacherA.email);
    const students = (db) => collection(db, `clubs/${demoClubId}/students`);
    const mine = await getDocs(query(students(teacherA.db), where('groupIds', 'array-contains', 'g-enfants')));
    assert.deepEqual(mine.docs.map((d) => d.id).sort(), ['s-camille', 's-lea', 's-tom']);
    assert.equal(await allowed(() => getDoc(doc(teacherA.db, `clubs/${demoClubId}/students/s-marc`))), false);
    assert.equal(await allowed(() => getDocs(query(students(teacherA.db), where('groupIds', 'array-contains', 'g-adultes')))), false);

    const teacherB = await signedIn(accounts.teacherB.email);
    const adults = await getDocs(query(students(teacherB.db), where('groupIds', 'array-contains', 'g-adultes')));
    assert.deepEqual(adults.docs.map((d) => d.id), ['s-marc']);
    assert.equal(await allowed(() => getDoc(doc(teacherB.db, `clubs/${demoClubId}/students/s-lea`))), false);
  });

  test('le parent voit ses deux enfants et rien d\'autre', async () => {
    const parent = await signedIn(accounts.parent.email);
    for (const id of ['s-lea', 's-tom']) {
      assert.equal(await allowed(() => getDoc(doc(parent.db, `clubs/${demoClubId}/students/${id}`))), true, id);
    }
    for (const id of ['s-camille', 's-marc']) {
      assert.equal(await allowed(() => getDoc(doc(parent.db, `clubs/${demoClubId}/students/${id}`))), false, id);
    }
    assert.equal(await allowed(() => getDoc(doc(parent.db, `clubs/${demoClubId}/groups/g-enfants`))), true);
    assert.equal(await allowed(() => getDoc(doc(parent.db, `clubs/${demoClubId}/groups/g-adultes`))), false);
    assert.equal(await allowed(() => getDocs(collection(parent.db, `clubs/${demoClubId}/members`))), false);
  });

  test('l\'élève de 15 ans ne voit que sa fiche', async () => {
    const teen = await signedIn(accounts.teen.email);
    assert.equal(await allowed(() => getDoc(doc(teen.db, `clubs/${demoClubId}/students/s-camille`))), true);
    assert.equal(await allowed(() => getDoc(doc(teen.db, `clubs/${demoClubId}/students/s-lea`))), false);
  });

  test('chaque compte retrouve son club et son rôle par la requête « mes clubs »', async () => {
    for (const [key, account] of Object.entries(accounts)) {
      const actor = await signedIn(account.email);
      const mine = await getDocs(query(collectionGroup(actor.db, 'members'), where('uid', '==', uids[key])));
      assert.equal(mine.size, account.role === 'admin' ? 0 : 1, account.email);
      if (account.role !== 'admin') assert.equal(mine.docs[0].data().role, account.role);
    }
  });

  test('un compte neuf, vérifié par l\'émulateur, rejoint le club avec le code de la graine', async () => {
    const email = `nouveau-${process.pid}@demo.test`;
    const app = initializeApp({ apiKey: 'seed', projectId }, `join-${process.pid}`);
    apps.push(app);
    const auth = getAuth(app);
    connectAuthEmulator(auth, `http://${environment.authHost}`, { disableWarnings: true });
    const { user } = await createUserWithEmailAndPassword(auth, email, demoPassword);
    await sendEmailVerification(user);
    const { oobCodes } = await (await fetch(`http://${environment.authHost}/emulator/v1/projects/${projectId}/oobCodes`)).json();
    await applyActionCode(auth, oobCodes.find((c) => c.email === email && c.requestType === 'VERIFY_EMAIL').oobCode);
    await user.getIdToken(true);
    const { getFirestore } = await import('firebase/firestore');
    const db = getFirestore(app);
    connectFirestoreEmulator(db, firestoreHost, Number(firestorePort));

    assert.equal((await getDoc(doc(db, `invitations/${demoInvitationCode}`))).data().role, 'teacher');
    assert.equal(await allowed(() => getDocs(collection(db, 'invitations'))), false, 'jamais de liste');

    const batch = writeBatch(db);
    batch.set(doc(db, `clubs/${demoClubId}/members/${user.uid}`), {
      uid: user.uid,
      role: 'teacher',
      groupIds: ['g-enfants'],
      studentIds: [],
      displayName: 'Nouveau',
      invitationCode: demoInvitationCode,
      createdAt: serverTimestamp(),
    });
    batch.update(doc(db, `invitations/${demoInvitationCode}`), {
      used: true,
      usedBy: user.uid,
      usedAt: serverTimestamp(),
    });
    assert.equal(await allowed(() => batch.commit()), true);

    // Le code n'a servi qu'une fois, et le nouvel enseignant voit ses élèves.
    const again = writeBatch(db);
    again.update(doc(db, `invitations/${demoInvitationCode}`), { used: true, usedBy: user.uid, usedAt: serverTimestamp() });
    assert.equal(await allowed(() => again.commit()), false);
    const mine = await getDocs(query(collection(db, `clubs/${demoClubId}/students`), where('groupIds', 'array-contains', 'g-enfants')));
    assert.equal(mine.size, 3);
  });
});
