const CACHE_NAME = 'burner-list-shell-v41-sidebar-details';
const SHELL_ASSETS = [
  '/',
  '/index.html',
  '/manifest.webmanifest?v=39',
  '/assets/generated/design-tokens.css?v=40',
  '/assets/design-system/components.css?v=40',
  '/assets/app.css?v=41',
  '/assets/brand/burner-list-wordmark.svg?v=38',
  '/assets/brand/burner-list-wordmark-dark.svg?v=38',
  '/assets/icons/favicon.png?v=39',
  '/assets/icons/Icon.png?v=39'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(SHELL_ASSETS))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  // Brand and icon files are edited directly during design iteration. Always
  // revalidate them so a normal refresh shows the latest visual assets.
  if (url.pathname.startsWith('/assets/brand/') || url.pathname.startsWith('/assets/icons/')) {
    event.respondWith(
      fetch(request, { cache: 'no-store' })
        .then(async response => {
          if (response.ok) {
            const cache = await caches.open(CACHE_NAME);
            await cache.put(request, response.clone());
          }
          return response;
        })
        .catch(async () => (await caches.match(request)) || Response.error())
    );
    return;
  }

  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then(response => {
          const copy = response.clone();
          caches.open(CACHE_NAME).then(cache => cache.put('/index.html', copy));
          return response;
        })
        .catch(() => caches.match('/index.html'))
    );
    return;
  }

  event.respondWith(
    fetch(request)
      .then(async response => {
        if (response.ok) {
          const cache = await caches.open(CACHE_NAME);
          await cache.put(request, response.clone());
        }
        return response;
      })
      .catch(async () => (await caches.match(request)) || Response.error())
  );
});
