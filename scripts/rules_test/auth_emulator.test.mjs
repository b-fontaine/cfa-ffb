// Authentification : ce que le code Dart de l'application suppose de Firebase Auth
// (lot FB2, ADR 0024 décisions 24 et 31), vérifié contre l'ÉMULATEUR Auth.
//
// Le code Dart (`FirebaseAuthRepository`, `FirebaseAuthSdk`) ne peut pas tourner
// sous `flutter test` : le plugin `firebase_auth` exige une plateforme native.
// Ses tests unitaires fournissent un SDK scripté qui renvoie les codes d'erreur
// ci-dessous ; ce fichier prouve que ce sont bien les codes qu'émet le service :
//
// - un compte créé n'a PAS son adresse vérifiée (l'application l'exige) ;
// - mauvais mot de passe et adresse inconnue sont des échecs que l'application
//   ramène à UN SEUL message : l'émulateur (comme un projet sans « protection contre
//   l'énumération d'adresses ») les distingue (`wrong-password`, `user-not-found`),
//   un projet protégé renvoie `invalid-credential` pour les deux. Le regroupement
//   est donc fait par l'application (`FirebaseAuthRepository`), pas par le service ;
// - une adresse déjà utilisée à l'inscription est refusée (l'application ne dit pas
//   pourquoi) ;
// - le serveur n'impose que 6 caractères : la règle des 10 caractères est donc
//   appliquée par l'application seule (décision 24), pas par le fournisseur ;
// - le courriel de vérification et celui de réinitialisation sont émis par le
//   service (l'application n'envoie rien), la réinitialisation d'une adresse
//   inconnue aboutit sans rien émettre, et chaque lien fait ce qu'il annonce.
//
// Aucune requête n'atteint le projet réel : projet « demo-… », émulateur local
// obligatoire (scripts/rules_test.sh). Les deux fournisseurs retirés de
// firebase.json (anonyme, Google) ne sont pas testables ici : l'émulateur n'applique
// pas la configuration des fournisseurs ; ce contrôle relève de la console
// (ADR 0024, décision 21).
import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';

import { deleteApp, initializeApp } from 'firebase/app';
import {
  applyActionCode,
  confirmPasswordReset,
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  getAuth,
  sendEmailVerification,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';

const host = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const projectId = process.env.GCLOUD_PROJECT ?? '';

// Garde de sécurité : jamais autre chose que l'émulateur local et un projet « demo- ».
assert.ok(
  host && /^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(host),
  'FIREBASE_AUTH_EMULATOR_HOST absent ou non local : lancer ces tests par scripts/rules_test.sh',
);
assert.match(projectId, /^demo-/, 'le projet des tests doit commencer par « demo- »');

const emulator = `http://${host}`;
const password = 'correct-horse-battery';

let app;
let auth;
let counter = 0;
const nextEmail = () => `user${++counter}-${process.pid}@example.org`;

const codes = async (email) => {
  const response = await fetch(`${emulator}/emulator/v1/projects/${projectId}/oobCodes`);
  const { oobCodes } = await response.json();
  return oobCodes.filter((code) => code.email === email);
};

// Les codes (sans le préfixe « auth/ ») que `FirebaseAuthRepository` ramène à l'unique
// échec « identifiants invalides » ; si le service en émet un autre, ce test échoue
// et le dépôt doit apprendre à le traduire.
const credentialCodes = ['auth/invalid-credential', 'auth/wrong-password', 'auth/user-not-found'];

const errorCode = async (body) => {
  try {
    await body();
  } catch (error) {
    return error.code;
  }
  assert.fail("une erreur d'authentification était attendue");
};

before(async () => {
  app = initializeApp({ projectId, apiKey: 'fake-api-key' }, 'auth-emulator-test');
  auth = getAuth(app);
  connectAuthEmulator(auth, emulator, { disableWarnings: true });
  await fetch(`${emulator}/emulator/v1/projects/${projectId}/accounts`, { method: 'DELETE' });
});

after(async () => {
  await signOut(auth);
  await deleteApp(app);
});

describe('inscription', () => {
  test("un compte créé n'a pas son adresse vérifiée", async () => {
    const email = nextEmail();

    const { user } = await createUserWithEmailAndPassword(auth, email, password);

    assert.equal(user.email, email);
    assert.equal(user.emailVerified, false);
    await signOut(auth);
  });

  test('une adresse déjà utilisée est refusée', async () => {
    const email = nextEmail();
    await createUserWithEmailAndPassword(auth, email, password);
    await signOut(auth);

    const code = await errorCode(() => createUserWithEmailAndPassword(auth, email, password));

    assert.equal(code, 'auth/email-already-in-use');
  });

  test("le serveur n'impose que 6 caractères : les 10 de l'ADR sont une règle de l'application", async () => {
    const tooShort = await errorCode(() => createUserWithEmailAndPassword(auth, nextEmail(), '12345'));
    assert.equal(tooShort, 'auth/weak-password');

    const { user } = await createUserWithEmailAndPassword(auth, nextEmail(), '123456');
    assert.ok(user.uid);
    await signOut(auth);
  });

  test('une adresse mal formée est refusée', async () => {
    const code = await errorCode(() => createUserWithEmailAndPassword(auth, 'pas-une-adresse', password));

    assert.equal(code, 'auth/invalid-email');
  });
});

describe('connexion', () => {
  test("mauvais mot de passe et adresse inconnue : deux codes, que l'application regroupe", async () => {
    const email = nextEmail();
    await createUserWithEmailAndPassword(auth, email, password);
    await signOut(auth);

    const wrongPassword = await errorCode(() => signInWithEmailAndPassword(auth, email, 'not-the-password'));
    const unknownAddress = await errorCode(() => signInWithEmailAndPassword(auth, nextEmail(), password));

    assert.ok(credentialCodes.includes(wrongPassword), wrongPassword);
    assert.ok(credentialCodes.includes(unknownAddress), unknownAddress);
  });

  test('des identifiants justes connectent un compte dont l’adresse n’est pas vérifiée', async () => {
    const email = nextEmail();
    await createUserWithEmailAndPassword(auth, email, password);
    await signOut(auth);

    const { user } = await signInWithEmailAndPassword(auth, email, password);

    // C'est l'application (cas d'usage SignIn) qui refuse puis déconnecte.
    assert.equal(user.emailVerified, false);
    await signOut(auth);
  });
});

describe('courriel de vérification', () => {
  test("le service l'émet pour le compte connecté ; son lien vérifie l'adresse", async () => {
    const email = nextEmail();
    const { user } = await createUserWithEmailAndPassword(auth, email, password);

    await sendEmailVerification(user);
    const [verification] = (await codes(email)).filter((c) => c.requestType === 'VERIFY_EMAIL');
    assert.ok(verification, 'un courriel de vérification doit avoir été émis');

    await applyActionCode(auth, verification.oobCode);
    await user.reload();
    assert.equal(user.emailVerified, true);
    await signOut(auth);

    const signedIn = await signInWithEmailAndPassword(auth, email, password);
    assert.equal(signedIn.user.emailVerified, true);
    await signOut(auth);
  });
});

describe('mot de passe oublié', () => {
  test("une adresse inconnue n'émet aucun courriel (le service aboutit ou refuse `user-not-found`, l'application l'ignore)", async () => {
    const unknown = nextEmail();

    const code = await sendPasswordResetEmail(auth, unknown).then(
      () => null,
      (error) => error.code,
    );

    assert.ok(code === null || code === 'auth/user-not-found', code);
    assert.deepEqual(await codes(unknown), []);
  });

  test("une adresse connue reçoit un courriel ; son lien change le mot de passe", async () => {
    const email = nextEmail();
    await createUserWithEmailAndPassword(auth, email, password);
    await signOut(auth);

    await sendPasswordResetEmail(auth, email);
    const [reset] = (await codes(email)).filter((c) => c.requestType === 'PASSWORD_RESET');
    assert.ok(reset, 'un courriel de réinitialisation doit avoir été émis');
    await confirmPasswordReset(auth, reset.oobCode, 'a-brand-new-password');

    const oldPassword = await errorCode(() => signInWithEmailAndPassword(auth, email, password));
    assert.ok(credentialCodes.includes(oldPassword), oldPassword);
    const { user } = await signInWithEmailAndPassword(auth, email, 'a-brand-new-password');
    assert.equal(user.email, email);
    await signOut(auth);
  });
});
