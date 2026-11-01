// Service Worker for ChcekName (PWA & System Notifications)
const CACHE_NAME = 'chcekname-v1';

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(clients.claim());
});

// Handle notification clicks (Open or Focus the web app window when user taps the notification)
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // If a window is already open, focus it
      for (let i = 0; i < clientList.length; i++) {
        const client = clientList[i];
        if (client.url && 'focus' in client) {
          return client.focus();
        }
      }
      // Otherwise open a new window
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});

// Handle background push messages
self.addEventListener('push', (event) => {
  let title = 'ChcekName';
  let body = 'คุณได้รับการแจ้งเตือนใหม่จากระบบ';
  let icon = 'icons/Icon-192.png';
  let badge = 'icons/Icon-192.png';

  if (event.data) {
    try {
      const data = event.data.json();
      if (data.title) title = data.title;
      if (data.body) body = data.body;
      if (data.icon) icon = data.icon;
    } catch (e) {
      title = event.data.text();
    }
  }

  const options = {
    body: body,
    icon: icon,
    badge: badge,
    vibrate: [200, 100, 200],
    tag: 'chcekname-shift-' + Date.now(),
    renotify: true,
    data: {
      url: '/'
    }
  };

  event.waitUntil(self.registration.showNotification(title, options));
});
