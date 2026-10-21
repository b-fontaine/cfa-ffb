// Détection des données locales (drift) par le BUILD WEB `firestore`, dans un VRAI Chrome
// (lot FB7c, ADR 0024 notes FB7c, T1).
//
// Pourquoi : la détection ouvre la base du navigateur (WebAssembly, IndexedDB) AVANT que
// l'application n'ouvre la sienne ; ce mécanisme n'est éprouvé ni par `flutter test` ni par
// un faux navigateur. Deux builds web partagent la MÊME origine (donc la même base) :
//
// - le build `drift` (explicite) remplit la base par son écran « Sauvegarde » (import d'un
//   fichier FICTIF des tests) ;
// - le build `firestore` relève ensuite cette base au démarrage et affiche le bandeau.
//
// Trois parcours :
// 1. base REMPLIE : le bandeau annonce les bons compteurs ; l'écran d'export, qui ouvre la
//    base par l'application APRÈS la détection, relit le même contenu ;
// 2. base ABSENTE : ni bandeau, ni base créée par la détection ;
// 3. base remplie, relevée par le build firestore, puis rouverte par le build drift : elle
//    s'ouvre ET s'écrit normalement (la détection n'a laissé ni verrou, ni lecture seule,
//    ni version de schéma modifiée), les données du premier build sont toujours là.
//
// Le build `drift` demande lui aussi une connexion : un compte fictif de l'ÉMULATEUR Auth (comme
// scripts/web_smoke/) ; les appels du SDK vers Google sont renvoyés à l'émulateur. Aucune requête
// n'atteint un projet Firebase : tout autre hôte que localhost est refusé.
// Les service workers sont bloqués (deux builds sur une origine : le cache d'un build ne doit
// pas servir l'autre).
//
// Prérequis (échec explicite, jamais de saut) : Google Chrome, et les deux builds produits par
// scripts/local_data_web.sh (LOCAL_DATA_WEB_DRIFT et LOCAL_DATA_WEB_FIRESTORE).
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize, resolve } from 'node:path';
import { after, afterEach, before, describe, test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { deleteApp, initializeApp } from 'firebase/app';
import {
  applyActionCode,
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  getAuth,
  sendEmailVerification,
  signOut,
} from 'firebase/auth';
import { chromium } from 'playwright-core';

const emulatorHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const projectId = process.env.GCLOUD_PROJECT ?? '';
assert.ok(
  emulatorHost && /^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(emulatorHost),
  'FIREBASE_AUTH_EMULATOR_HOST absent ou non local : lancer ce test par scripts/local_data_web.sh',
);
assert.match(projectId, /^demo-/, 'le projet du test doit commencer par « demo- »');
const emulator = `http://${emulatorHost}`;
const password = 'correct-horse-battery';
const email = `local-data-${process.pid}@example.org`;
const proxied = new Set(['identitytoolkit.googleapis.com', 'securetoken.googleapis.com']);
let accountUid;

const seedVerifiedAccount = async () => {
  const app = initializeApp({ apiKey: 'smoke', projectId }, `seed-${process.pid}`);
  const auth = getAuth(app);
  connectAuthEmulator(auth, emulator, { disableWarnings: true });
  const { user } = await createUserWithEmailAndPassword(auth, email, password);
  await sendEmailVerification(user);
  const { oobCodes } = await (
    await fetch(`${emulator}/emulator/v1/projects/${projectId}/oobCodes`)
  ).json();
  const verification = oobCodes.find((c) => c.email === email && c.requestType === 'VERIFY_EMAIL');
  assert.ok(verification, 'un courriel de vérification doit avoir été émis par l’émulateur');
  await applyActionCode(auth, verification.oobCode);
  await signOut(auth);
  await deleteApp(app);
  return user.uid;
};

const driftRoot = process.env.LOCAL_DATA_WEB_DRIFT ?? '';
const firestoreRoot = process.env.LOCAL_DATA_WEB_FIRESTORE ?? '';
for (const [name, dir] of [
  ['LOCAL_DATA_WEB_DRIFT', driftRoot],
  ['LOCAL_DATA_WEB_FIRESTORE', firestoreRoot],
]) {
  assert.ok(
    dir && existsSync(join(dir, 'index.html')),
    `${name} doit désigner un build web : lancer ce test par scripts/local_data_web.sh`,
  );
}
const backupPath = resolve(
  fileURLToPath(new URL('.', import.meta.url)),
  '..',
  '..',
  'app',
  'test',
  'fixtures',
  'backup',
  'club-small-v5.json',
);
// Ce que le fichier fictif contient (relu de la fixture : jamais recopié en dur).
const fixture = JSON.parse(await readFile(backupPath, 'utf8')).data;
const studentCount = fixture.students.length;
const attemptCount = fixture.attempts.length;
const students = (n) => (n === 1 ? '1 élève' : `${n} élèves`);
const attempts = (n) => (n === 1 ? '1 passage' : `${n} passages`);
const bannerText = `Des données de cet appareil n’ont pas encore été exportées ou importées dans le club (${students(studentCount)}, ${attempts(attemptCount)}).`;

const mimeTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.css': 'text/css',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.yaml': 'text/yaml; charset=utf-8',
  '.md': 'text/markdown; charset=utf-8',
};

let servedRoot = firestoreRoot;
let server;
let origin;
let browser;
const blocked = new Set();
const pageErrors = [];

const startServer = () =>
  new Promise((done) => {
    server = createServer(async (request, response) => {
      const path = normalize(decodeURIComponent(new URL(request.url, 'http://x').pathname));
      const file = join(servedRoot, path.endsWith('/') ? `${path}index.html` : path);
      if (!file.startsWith(servedRoot)) {
        response.writeHead(403).end();
        return;
      }
      try {
        const body = await readFile(file);
        response.writeHead(200, {
          'content-type': mimeTypes[extname(file)] ?? 'application/octet-stream',
        });
        response.end(body);
      } catch {
        response.writeHead(404).end();
      }
    });
    server.listen(0, '127.0.0.1', () => {
      origin = `http://127.0.0.1:${server.address().port}`;
      done();
    });
  });

const contexts = [];
const newContext = async () => {
  const context = await browser.newContext({ serviceWorkers: 'block', locale: 'fr-FR' });
  contexts.push(context);
  await context.route('**/*', async (r) => {
    const request = r.request();
    const url = new URL(request.url());
    if (url.hostname === '127.0.0.1' || url.hostname === 'localhost') return r.continue();
    if (proxied.has(url.hostname)) {
      const upstream = await fetch(`${emulator}/${url.hostname}${url.pathname}${url.search}`, {
        method: request.method(),
        headers: { 'content-type': request.headers()['content-type'] ?? 'application/json' },
        body: ['GET', 'HEAD'].includes(request.method()) ? undefined : request.postDataBuffer(),
      });
      return r.fulfill({
        status: upstream.status,
        headers: {
          'content-type': upstream.headers.get('content-type') ?? 'application/json',
          'access-control-allow-origin': '*',
        },
        body: Buffer.from(await upstream.arrayBuffer()),
      });
    }
    // Firestore n'est pas émulé ici (flux longs) : refusé explicitement, sans être une erreur.
    if (
      url.hostname === 'firestore.googleapis.com' ||
      (url.hostname === 'www.google.com' && url.pathname === '/images/cleardot.gif')
    ) {
      return r.abort('connectionrefused');
    }
    blocked.add(`${url.hostname}${url.pathname}`);
    return r.abort();
  });
  return context;
};

// Espion des ouvertures IndexedDB faites DEPUIS LA PAGE (le thread principal, où la détection lit
// la base) : l'application, elle, ouvre sa base dans un worker, que l'espion ne voit pas.
const spyIndexedDb = (page) =>
  page.addInitScript(() => {
    window.__idbOpens = [];
    const open = IDBFactory.prototype.open;
    IDBFactory.prototype.open = function (name, ...rest) {
      window.__idbOpens.push(name);
      return open.call(this, name, ...rest);
    };
  });

const openPage = async (context, root, hash) => {
  servedRoot = root;
  const page = await context.newPage();
  await spyIndexedDb(page);
  page.on('pageerror', (error) => pageErrors.push(String(error)));
  await page.goto(`${origin}/`);
  await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 60_000 });
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  if (hash) {
    await page.evaluate((h) => { window.location.hash = h; }, hash);
  }
  return page;
};

const see = (page, text, timeout = 45_000) =>
  page.getByText(text).first().waitFor({ state: 'visible', timeout });

const hasText = async (page, text) => (await page.getByText(text).count()) > 0;

// Flutter crée l'élément de saisie quand le champ prend le focus, de façon asynchrone : on
// attend l'élément, on frappe, puis on contrôle ce que le champ contient (voir web_smoke).
const typeInto = async (page, label, value) => {
  const field = page.getByLabel(label, { exact: true });
  let typed = '';
  for (let attempt = 0; attempt < 4 && typed !== value; attempt++) {
    await field.click();
    await page.waitForFunction(() =>
      ['INPUT', 'TEXTAREA'].includes(document.activeElement?.tagName),
    );
    await page.waitForTimeout(300);
    await page.keyboard.press('ControlOrMeta+A');
    await page.keyboard.press('Backspace');
    await page.keyboard.type(value, { delay: 15 });
    typed = await page.evaluate(() => document.activeElement.value);
  }
  assert.equal(typed, value, `saisie incomplète dans « ${label} »`);
};

// Remplit la base par le build `drift` : connexion (compte de l'émulateur, club retenu sur
// l'appareil), puis import du fichier fictif par l'écran « Sauvegarde ».
const fillWithDriftBuild = async (context) => {
  servedRoot = driftRoot;
  const page = await context.newPage();
  page.on('pageerror', (error) => pageErrors.push(String(error)));
  await page.goto(`${origin}/`);
  await page.evaluate(
    ([key, club]) => localStorage.setItem(key, JSON.stringify(JSON.stringify(club))),
    [
      `active_club.${accountUid}`,
      { club: 'demo', name: 'Démo', role: 'director', groups: [], students: [] },
    ],
  );
  await page.reload();
  await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 60_000 });
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  // Une session déjà ouverte (second passage) arrive directement à l'accueil.
  await page
    .getByText('Connexion à l’application')
    .or(page.getByText('Aujourd\'hui'))
    .first()
    .waitFor({ state: 'visible', timeout: 45_000 });
  if ((await page.getByText('Connexion à l’application').count()) > 0) {
    await typeInto(page, 'Adresse e-mail', email);
    await typeInto(page, 'Mot de passe', password);
    await page.getByRole('button', { name: 'Se connecter', exact: true }).click();
  }
  await see(page, 'Aujourd\'hui');
  await page.evaluate(() => { window.location.hash = '#/backup'; });
  await page.getByRole('button', { name: 'Importer une sauvegarde' }).waitFor({ timeout: 45_000 });
  const [chooser] = await Promise.all([
    page.waitForEvent('filechooser'),
    page.getByRole('button', { name: 'Importer une sauvegarde' }).click(),
  ]);
  await chooser.setFiles(backupPath);
  await page.getByRole('button', { name: 'Importer ces données' }).click({ timeout: 30_000 });
  await see(page, 'Import terminé.');
  return page;
};

before(async () => {
  await startServer();
  await fetch(`${emulator}/emulator/v1/projects/${projectId}/accounts`, { method: 'DELETE' });
  accountUid = await seedVerifiedAccount();
  try {
    browser = await chromium.launch({ channel: 'chrome', headless: true });
  } catch (error) {
    assert.fail(`Google Chrome est requis et n’a pas pu être lancé : ${error.message}`);
  }
});

// Un parcours qui échoue ne laisse aucune page ouverte au suivant (une page ouverte garde sa base).
afterEach(async () => {
  while (contexts.length > 0) await contexts.pop().close().catch(() => {});
});

after(async () => {
  await browser?.close();
  await new Promise((done) => server.close(done));
});

describe('détection des données locales par le build web firestore (Chrome réel)', () => {
  test('une base remplie par le build drift est relevée : bandeau et compteurs exacts', async () => {
    const context = await newContext();
    const filler = await fillWithDriftBuild(context);
    await filler.close();

    const page = await openPage(context, firestoreRoot);
    await see(page, 'Des données de cet appareil n’ont pas encore été exportées');
    await see(page, bannerText);
    assert.ok(!(await hasText(page, 'peut-être pas encore')), 'pas « illisible »');
    // La détection a bien lu la base depuis la page (et l'a refermée : voir le test suivant).
    assert.ok(
      (await page.evaluate(() => window.__idbOpens)).includes('billard_cfa'),
      'la détection lit la base IndexedDB depuis la page',
    );

    // L'application ouvre la base APRÈS la détection : l'export relit le même contenu.
    await page.getByRole('button', { name: 'Exporter maintenant' }).click();
    await see(page, 'Ce que contient le fichier');
    await see(page, students(studentCount));
    await see(page, attempts(attemptCount));
    assert.deepEqual(blocked.size, 0, `hôtes refusés : ${[...blocked]}`);
    await context.close();
  });

  test('un onglet drift resté ouvert tient la base : elle est quand même relevée', async () => {
    const context = await newContext();
    // L'ancien onglet (ou l'application installée) n'est PAS fermé : sa connexion partagée
    // à la base reste vivante pendant que le build firestore démarre.
    await fillWithDriftBuild(context);
    const page = await openPage(context, firestoreRoot);
    await see(page, bannerText);
  });

  test('une base absente : ni bandeau, ni base créée par la détection', async () => {
    const context = await newContext();
    const page = await openPage(context, firestoreRoot);
    await see(page, 'Connexion à l’application');
    // Laisse au démarrage le temps d'achever détection et premier affichage.
    await page.waitForTimeout(3_000);
    assert.ok(!(await hasText(page, 'Des données de cet appareil')), 'aucun bandeau');
    // La détection n'a touché à aucune base IndexedDB « billard_cfa » depuis la page : ni lecture,
    // donc ni création. (Le build ouvre ensuite SA base, dans un worker : elle existe alors, vide.)
    assert.deepEqual(
      await page.evaluate(() => window.__idbOpens.filter((n) => n === 'billard_cfa')),
      [],
      'la détection ne doit pas ouvrir (donc créer) la base absente',
    );
    // Au démarrage suivant, la base vide créée par l'application n'est PAS une donnée à protéger.
    await page.reload();
    await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 60_000 });
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await see(page, 'Connexion à l’application');
    await page.waitForTimeout(3_000);
    assert.ok(!(await hasText(page, 'Des données de cet appareil')), 'toujours aucun bandeau');
    await context.close();
  });

  test('après la détection, la base s’ouvre et s’écrit normalement (build drift)', async () => {
    const context = await newContext();
    const filler = await fillWithDriftBuild(context);
    await filler.close();

    // Le build firestore relève la base (et l'application l'ouvre) ...
    const probed = await openPage(context, firestoreRoot);
    await see(probed, bannerText);
    await probed.close();

    // ... puis le build drift la rouvre : même contenu, et une écriture aboutit (un second
    // import fusionne par identifiant : il écrit, donc la base n'est ni verrouillée ni en
    // lecture seule).
    const page = await fillWithDriftBuild(context);
    await page.close();
    const again = await openPage(context, firestoreRoot);
    await see(again, bannerText);
    assert.equal(pageErrors.length, 0, `erreurs de page : ${pageErrors.join('\n')}`);
    await context.close();
  });
});
