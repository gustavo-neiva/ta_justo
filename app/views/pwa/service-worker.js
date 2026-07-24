const CACHE = "ta-justo-v1";
const OFFLINE = "/";

self.addEventListener("install", (e) => {
  e.waitUntil(
    caches.open(CACHE).then((c) => c.add(OFFLINE))
  );
  self.skipWaiting();
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys().then((ks) =>
      Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (e) => {
  const { request } = e;

  if (request.method !== "GET") return;
  if (request.headers.get("Turbo-Frame") || request.headers.get("Accept")?.includes("text/vnd.turbo-stream.html")) return;

  if (request.mode === "navigate") {
    e.respondWith(
      fetch(request).catch(() => caches.match(OFFLINE))
    );
    return;
  }

  e.respondWith(
    caches.match(request).then((cached) => {
      const fetched = fetch(request).then((response) => {
        if (response.ok) {
          const clone = response.clone();
          caches.open(CACHE).then((c) => c.put(request, clone));
        }
        return response;
      });
      return cached || fetched;
    })
  );
});
