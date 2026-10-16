// Tests du comportement du service worker hors ligne (app/web/offline_sw.js) et
// du pont de la page (app/web/offline.js), avec de faux `self`, `caches`,
// `clients` et `navigator.serviceWorker`. Aucun navigateur : `node --test`.
//
//   node --test scripts/pwa_js_test.mjs
//
// Branché sur scripts/check.sh. Voir docs/engineering/hors-ligne-plan.md.
import nodeAssert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

// Les objets créés dans le contexte `vm` ont d'autres prototypes : comparer
// leur forme JSON.
const plain = (value) => JSON.parse(JSON.stringify(value));
const assert = {
  ...nodeAssert,
  deepEqual: (actual, expected, message) =>
    nodeAssert.deepEqual(plain(actual), plain(expected), message),
};

const WEB = new URL('../app/web/', import.meta.url);
const workerTemplate = readFileSync(new URL('offline_sw.js', WEB), 'utf8');
const pageScript = readFileSync(new URL('offline.js', WEB), 'utf8');

const SCOPE = 'https://app.test/';
const HTML = { 'content-type': 'text/html; charset=utf-8' };
const JS = { 'content-type': 'text/javascript' };

// ------------------------------------------------------------ service worker

function stamped(id = 'v1', precache = ['index.html', 'main.dart.js']) {
  return workerTemplate
    .replace("const BUILD_ID = '__BUILD_ID__';", `const BUILD_ID = '${id}';`)
    .replace('/*__PRECACHE__*/ []', JSON.stringify(precache));
}

class FakeCache {
  constructor() {
    this.entries = new Map();
  }
  async put(request, response) {
    this.entries.set(typeof request === 'string' ? request : request.url, response);
  }
  async match(request, options = {}) {
    let url = typeof request === 'string' ? request : request.url;
    if (options.ignoreSearch) url = url.split('?')[0];
    for (const [key, value] of this.entries) {
      const candidate = options.ignoreSearch ? key.split('?')[0] : key;
      if (candidate === url) return value.clone();
    }
    return undefined;
  }
}

function makeWorker({ source = stamped(), network = {}, existingCaches = [] } = {}) {
  const handlers = {};
  const calls = { skipWaiting: 0, claim: 0, unregister: 0, fetched: [] };
  const store = new Map(existingCaches.map((name) => [name, new FakeCache()]));
  const self = {
    registration: {
      scope: SCOPE,
      unregister: async () => {
        calls.unregister++;
      },
    },
    location: { origin: 'https://app.test' },
    clients: {
      claim: async () => {
        calls.claim++;
      },
    },
    skipWaiting: async () => {
      calls.skipWaiting++;
    },
    addEventListener: (type, handler) => {
      handlers[type] = handler;
    },
  };
  const caches = {
    open: async (name) => {
      if (!store.has(name)) store.set(name, new FakeCache());
      return store.get(name);
    },
    keys: async () => [...store.keys()],
    delete: async (name) => store.delete(name),
  };
  // `network` : chemin -> { status, headers, body } ; absent = 404.
  const fetch = async (request) => {
    const url = typeof request === 'string' ? request : request.url;
    calls.fetched.push(url);
    const entry = network[new URL(url).pathname.replace(/^\//, '')];
    if (!entry) return new Response('absent', { status: 404 });
    if (entry.throws) throw new TypeError('réseau coupé');
    const response = new Response(entry.body ?? 'contenu', {
      status: entry.status ?? 200,
      headers: entry.headers ?? JS,
    });
    // Une réponse construite à la main n'est pas « basic » comme celle du réseau.
    Object.defineProperty(response, 'type', { value: 'basic' });
    return response;
  };
  const context = vm.createContext({
    self,
    caches,
    fetch,
    URL,
    Request,
    Response,
    Promise,
    console,
    setTimeout: (callback) => {
      callback();
      return 0;
    },
  });
  vm.runInContext(source, context);
  return { handlers, calls, store, self };
}

/** Déclenche un évènement et attend les promesses données à waitUntil / respondWith. */
async function dispatch(worker, type, extra = {}) {
  const pending = [];
  const event = {
    ...extra,
    waitUntil: (promise) => pending.push(promise),
    respondWith: (promise) => pending.push(promise),
  };
  worker.handlers[type](event);
  const results = await Promise.allSettled(pending);
  return { event, results, responded: pending.length > 0 };
}

const goodNetwork = {
  'index.html': { headers: HTML, body: '<html>app</html>' },
  'main.dart.js': { body: 'main' },
};

test('worker : l\'installation précache tous les fichiers sans activer d\'office', async () => {
  const worker = makeWorker({ network: goodNetwork });

  const { results } = await dispatch(worker, 'install');

  assert.equal(results[0].status, 'fulfilled');
  assert.equal(worker.calls.skipWaiting, 0, 'une nouvelle version ne prend jamais la main seule');
  const cache = worker.store.get('cfa-v1');
  assert.deepEqual(
    [...cache.entries.keys()].sort(),
    [`${SCOPE}index.html`, `${SCOPE}main.dart.js`],
  );
});

test('worker : l\'installation échoue si un fichier manque (l\'ancienne version reste)', async () => {
  const worker = makeWorker({ network: { 'index.html': goodNetwork['index.html'] } });

  const { results } = await dispatch(worker, 'install');

  assert.equal(results[0].status, 'rejected');
});

test('worker : l\'installation réessaie un fichier qui échoue passagèrement', async () => {
  let attempts = 0;
  // La première tentative sur main.dart.js échoue.
  const flaky = makeWorker({
    network: {
      'index.html': goodNetwork['index.html'],
      get 'main.dart.js'() {
        attempts++;
        return attempts === 1 ? { throws: true } : { body: 'main' };
      },
    },
  });

  const { results } = await dispatch(flaky, 'install');

  assert.equal(results[0].status, 'fulfilled');
  assert.equal(attempts, 2);
});

test('worker : l\'installation refuse du HTML à la place d\'un fichier non HTML', async () => {
  // Réécriture ** -> /index.html de l'hébergement pour un fichier absent.
  const worker = makeWorker({
    network: {
      'index.html': goodNetwork['index.html'],
      'main.dart.js': { headers: HTML, body: '<html>app</html>' },
    },
  });

  const { results } = await dispatch(worker, 'install');

  assert.equal(results[0].status, 'rejected');
  assert.equal(worker.store.get('cfa-v1')?.entries.size ?? 0, 0, 'cache non conservé en l\'état');
});

test('worker : l\'activation supprime les anciens caches cfa-* et garde le courant', async () => {
  const worker = makeWorker({ existingCaches: ['cfa-old', 'cfa-v1', 'autre-cache'] });

  await dispatch(worker, 'activate');

  assert.deepEqual([...worker.store.keys()].sort(), ['autre-cache', 'cfa-v1']);
  assert.equal(worker.calls.claim, 1);
});

test('worker : SKIP_WAITING n\'active que sur demande de la page', async () => {
  const worker = makeWorker();

  worker.handlers.message({ data: { type: 'AUTRE' } });
  worker.handlers.message({ data: null });
  assert.equal(worker.calls.skipWaiting, 0);

  worker.handlers.message({ data: { type: 'SKIP_WAITING' } });
  assert.equal(worker.calls.skipWaiting, 1);
});

function request(path, { method = 'GET', mode = 'cors', origin = 'https://app.test' } = {}) {
  return { url: `${origin}${path}`, method, mode };
}

test('worker : n\'intercepte ni le cross-origin, ni le non GET, ni le worker, ni /__/', async () => {
  const worker = makeWorker({ network: goodNetwork });
  for (const req of [
    request('/main.dart.js', { origin: 'https://cdn.test' }),
    request('/main.dart.js', { method: 'POST' }),
    request('/offline_sw.js'),
    request('/__/auth/handler', { mode: 'navigate' }),
    request('/__/firebase/init.json'),
  ]) {
    const { responded } = await dispatch(worker, 'fetch', { request: req });
    assert.equal(responded, false, `${req.method} ${req.url} doit passer au réseau`);
  }
});

test('worker : sert le cache d\'abord', async () => {
  const worker = makeWorker({ network: goodNetwork });
  await dispatch(worker, 'install');
  worker.calls.fetched.length = 0;

  const { results } = await dispatch(worker, 'fetch', { request: request('/main.dart.js?v=2') });

  assert.equal(await results[0].value.text(), 'main');
  assert.deepEqual(worker.calls.fetched, [], 'aucun accès réseau pour un fichier précaché');
});

test('worker : une navigation hors cache reçoit index.html', async () => {
  const worker = makeWorker({ network: goodNetwork });
  await dispatch(worker, 'install');
  worker.calls.fetched.length = 0;

  const { results } = await dispatch(worker, 'fetch', {
    request: request('/students/42', { mode: 'navigate' }),
  });

  assert.equal(await results[0].value.text(), '<html>app</html>');
  assert.deepEqual(worker.calls.fetched, []);
});

test('worker : garde après un premier chargement un fichier non précaché', async () => {
  const worker = makeWorker({
    network: { ...goodNetwork, 'extra.js': { body: 'extra' } },
  });
  await dispatch(worker, 'install');

  const first = await dispatch(worker, 'fetch', { request: request('/extra.js') });
  assert.equal(await first.results[0].value.text(), 'extra');
  worker.calls.fetched.length = 0;
  await new Promise((resolve) => setImmediate(resolve));
  const second = await dispatch(worker, 'fetch', { request: request('/extra.js') });

  assert.equal(await second.results[0].value.text(), 'extra');
  assert.deepEqual(worker.calls.fetched, []);
});

test('worker non stampé : s\'active, ne met rien en cache et se désinscrit', async () => {
  const worker = makeWorker({ source: workerTemplate, existingCaches: ['cfa-old'] });

  await dispatch(worker, 'install');
  assert.equal(worker.calls.skipWaiting, 1);
  assert.equal(worker.store.size, 1, 'aucun nouveau cache');

  await dispatch(worker, 'activate');
  assert.equal(worker.store.size, 0, 'les caches cfa-* sont effacés');
  assert.equal(worker.calls.unregister, 1);
  assert.equal(worker.calls.claim, 0);

  const { responded } = await dispatch(worker, 'fetch', { request: request('/main.dart.js') });
  assert.equal(responded, false);
});

// ------------------------------------------------------------------- la page

class Emitter {
  constructor() {
    this.listeners = {};
  }
  addEventListener(type, listener) {
    (this.listeners[type] ??= []).push(listener);
  }
  emit(type) {
    (this.listeners[type] ?? []).slice().forEach((listener) => listener());
  }
}

function makePage({ controller = null, waiting = null, installing = null } = {}) {
  const win = new Emitter();
  const doc = Object.assign(new Emitter(), { visibilityState: 'visible' });
  const registration = Object.assign(new Emitter(), {
    waiting,
    installing,
    updates: 0,
    update: async () => {
      registration.updates++;
    },
  });
  const container = Object.assign(new Emitter(), {
    controller,
    registered: [],
    register: async (url, options) => {
      container.registered.push({ url, options });
      return registration;
    },
  });
  const state = { reloads: 0, intervals: [] };
  win.location = {
    reload: () => {
      state.reloads++;
    },
  };
  win.setInterval = (callback, delay) => state.intervals.push(delay);
  win.document = doc;
  const context = vm.createContext({
    window: win,
    document: doc,
    navigator: { serviceWorker: container, storage: { persist: async () => true } },
    console,
  });
  vm.runInContext(pageScript, context);
  return { win, doc, registration, container, state, bridge: win.cfaOffline };
}

const settle = () => new Promise((resolve) => setImmediate(resolve));

async function loaded(page) {
  page.win.emit('load');
  await settle();
}

function worker(state = 'installing') {
  return Object.assign(new Emitter(), { state, posted: [], postMessage(m) { this.posted.push(m); } });
}

test('page : enregistre le worker sans cache HTTP et vérifie toutes les heures', async () => {
  const page = makePage();

  await loaded(page);

  assert.deepEqual(page.container.registered, [
    { url: 'offline_sw.js', options: { updateViaCache: 'none' } },
  ]);
  assert.deepEqual(page.state.intervals, [60 * 60 * 1000]);
  assert.equal(page.bridge.updateAvailable, false);
});

test('page : une version installée pendant l\'utilisation est signalée', async () => {
  const page = makePage({ controller: {} });
  const seen = [];
  page.bridge.onUpdateChange((value) => seen.push(value));
  await loaded(page);

  const next = worker();
  page.registration.installing = next;
  page.registration.emit('updatefound');
  next.state = 'installed';
  next.emit('statechange');

  assert.equal(page.bridge.updateAvailable, true);
  assert.deepEqual(seen, [true]);
});

test('page : la première visite ne propose pas de mise à jour', async () => {
  const page = makePage({ controller: null });
  await loaded(page);

  const first = worker();
  page.registration.installing = first;
  page.registration.emit('updatefound');
  first.state = 'installed';
  first.emit('statechange');
  page.container.emit('controllerchange');

  assert.equal(page.bridge.updateAvailable, false);
  assert.equal(page.state.reloads, 0);
});

test('page : une version déjà en attente à l\'ouverture est signalée', async () => {
  const page = makePage({ controller: {}, waiting: worker('installed') });

  await loaded(page);

  assert.equal(page.bridge.updateAvailable, true);
});

test('page : une installation déjà en cours à l\'enregistrement est suivie', async () => {
  const running = worker('installing');
  const page = makePage({ controller: {}, installing: running });
  await loaded(page);
  assert.equal(page.bridge.updateAvailable, false);

  running.state = 'installed';
  running.emit('statechange');

  assert.equal(page.bridge.updateAvailable, true);
});

test('page : « mettre à jour » demande l\'activation puis recharge une fois', async () => {
  const waiting = worker('installed');
  const page = makePage({ controller: {}, waiting });
  await loaded(page);

  page.bridge.applyUpdate();
  assert.deepEqual(waiting.posted, [{ type: 'SKIP_WAITING' }]);
  assert.equal(page.state.reloads, 0, 'pas de rechargement avant l\'activation');

  page.container.emit('controllerchange');
  page.container.emit('controllerchange');
  assert.equal(page.state.reloads, 1);
});

test('page : sans version en attente, « mettre à jour » recharge simplement', async () => {
  const page = makePage({ controller: {} });
  await loaded(page);

  page.bridge.applyUpdate();

  assert.equal(page.state.reloads, 1);
});

test('page : un autre onglet qui active la version est signalé sans recharger', async () => {
  // Onglet B : l'onglet A a activé la nouvelle version ; le contrôleur change
  // sous une page qui tourne encore avec les anciens fichiers.
  const page = makePage({ controller: {} });
  await loaded(page);

  page.container.emit('controllerchange');

  assert.equal(page.bridge.updateAvailable, true);
  assert.equal(page.state.reloads, 0, 'la saisie en cours n\'est pas interrompue');
});

test('page : vérifie la présence d\'une version au retour au premier plan', async () => {
  const page = makePage();
  await loaded(page);

  page.doc.emit('visibilitychange');

  assert.equal(page.registration.updates, 1);
});

test('page : un abonné défaillant ne bloque pas les autres', async () => {
  const page = makePage({ controller: {}, waiting: worker('installed') });
  const seen = [];
  page.bridge.onUpdateChange(() => {
    throw new Error('abonné défaillant');
  });
  page.bridge.onUpdateChange((value) => seen.push(value));

  page.win.emit('load');
  await settle();

  assert.deepEqual(seen, [true]);
});
