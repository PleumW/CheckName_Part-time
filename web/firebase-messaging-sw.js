// Firebase Messaging Service Worker for Web PWA
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyC59Zw3swj6k3MGCpzUxXClT6MpLsUZzIY',
  appId: '1:489256214674:web:3c5906a5a4c57fa90fc64b',
  messagingSenderId: '489256214674',
  projectId: 'kitatokiofrashy',
  authDomain: 'kitatokiofrashy.firebaseapp.com',
  storageBucket: 'kitatokiofrashy.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification ? payload.notification.title : 'ChcekName';
  const notificationOptions = {
    body: payload.notification ? payload.notification.body : 'คุณได้รับการแจ้งเตือนใหม่จากระบบ',
    icon: '/icons/Icon-192.png',
    badge: '/favicon.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
