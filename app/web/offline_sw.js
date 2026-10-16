// Service worker hors ligne (docs/engineering/hors-ligne-plan.md).
//
// Stratégie : précache versionné, « cache d'abord ».
// - `scripts/pwa.dart stamp` remplace les deux marqueurs ci-dessous après
//   `flutter build web` : l'identifiant de build (hash du contenu) et la liste
//   des fichiers à précacher. Le fichier change donc à chaque version, ce qui
//   déclenche la mise à jour par le navigateur.
// - À l'installation, tous les fichiers sont téléchargés dans un cache propre
//   à la version ; chaque fichier est retenté en cas d'échec réseau, et
//   l'installation échoue (l'ancienne version reste en place) si l'un d'eux
//   manque ou si l'hébergement répond par du HTML à la place d'un fichier
//   (réécriture `** -> /index.html`).
// - Une nouvelle version reste « en attente » : elle ne prend la main que sur
//   demande de la page (message SKIP_WAITING) ou quand plus aucun onglet
//   n'utilise l'ancienne. Une page ouverte garde ainsi ses fichiers.
// - Non stampé (flutter run, build sans pwa.dart) : le worker se désinscrit
//   et ne met rien en cache.
'use strict';

const BUILD_ID = '__BUILD_ID__';
const PRECACHE = /*__PRECACHE__*/ [];

const STAMPED = BUILD_ID !== '__' + 'BUILD_ID__';
const CACHE_PREFIX = 'cfa-';
const CACHE_NAME = CACHE_PREFIX + BUILD_ID;
const SCOPE = self.registration.scope;
const INDEX = new URL('index.html', SCOPE).href;
const ATTEMPTS = 3;
const RETRY_DELAY_MS = 1000;

// Télécharge un fichier du précache (sans le cache HTTP) et le range. Un réseau
// mobile instable ne doit pas faire échouer 21 Mo pour une requête perdue.
async function precacheOne(cache, path) {
  const url = new URL(path, SCOPE).href;
  let failure;
  for (let attempt = 1; attempt <= ATTEMPTS; attempt++) {
    try {
      const response = await fetch(new Request(url, { cache: 'reload' }));
      if (!response.ok) throw new Error(path + ' : HTTP ' + response.status);
      const type = response.headers.get('content-type') || '';
      if (!path.endsWith('.html') && type.includes('text/html')) {
        throw new Error(path + ' : HTML reçu à la place du fichier');
      }
      await cache.put(url, response);
      return;
    } catch (error) {
      failure = error;
      if (attempt < ATTEMPTS) {
        await new Promise((resolve) => setTimeout(resolve, RETRY_DELAY_MS * attempt));
      }
    }
  }
  throw failure;
}

self.addEventListener('install', (event) => {
  if (!STAMPED) {
    event.waitUntil(self.skipWaiting());
    return;
  }
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE_NAME);
      try {
        await Promise.all(PRECACHE.map((path) => precacheOne(cache, path)));
      } catch (error) {
        // Pas de cache à moitié rempli : la prochaine tentative repart de zéro.
        await caches.delete(CACHE_NAME);
        throw error;
      }
    })()
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const names = await caches.keys();
      await Promise.all(
        names
          .filter((name) => name.startsWith(CACHE_PREFIX) && name !== CACHE_NAME)
          .map((name) => caches.delete(name))
      );
      if (!STAMPED) {
        await self.registration.unregister();
        return;
      }
      await self.clients.claim();
    })()
  );
});

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') self.skipWaiting();
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (!STAMPED || request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  // Le worker lui-même est géré par le navigateur.
  if (url.pathname.endsWith('/offline_sw.js')) return;
  // Gestionnaires d'authentification Firebase (`/__/auth/handler`…) : ni
  // remplacés par index.html, ni mis en cache.
  if (url.pathname.startsWith('/__/')) return;
  event.respondWith(respond(request));
});

async function respond(request) {
  const cache = await caches.open(CACHE_NAME);
  const cached = await cache.match(request, { ignoreSearch: true });
  if (cached) return cached;

  if (request.mode === 'navigate') {
    // Toute navigation (racine, route profonde) est servie par la page de l'application.
    const shell = await cache.match(INDEX);
    if (shell) return shell;
  }

  const response = await fetch(request);
  // Fichiers non précachés (ex. variante de moteur propre à un navigateur) :
  // gardés après un premier chargement réussi.
  if (response.ok && response.status === 200 && response.type === 'basic') {
    cache.put(request, response.clone()).catch(() => {});
  }
  return response;
}
