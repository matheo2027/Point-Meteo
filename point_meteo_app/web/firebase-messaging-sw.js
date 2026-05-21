// Service Worker pour Firebase Cloud Messaging (web)
// Ce fichier doit être à la racine du domaine pour recevoir les notifications en arrière-plan.

importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

// ⚠️  REMPLACE ces valeurs avec ta configuration web Firebase
// Firebase Console > Paramètres > Tes applications > Web > Config Firebase
firebase.initializeApp({
  apiKey: "REMPLACE-PAR-TA-CLE-WEB",
  authDomain: "point-meteo.firebaseapp.com",
  projectId: "point-meteo",
  storageBucket: "point-meteo.firebasestorage.app",
  messagingSenderId: "1061820774452",
  appId: "REMPLACE-PAR-APP-ID-WEB",
});

const messaging = firebase.messaging();

// Gestion des notifications en arrière-plan (background)
messaging.onBackgroundMessage((payload) => {
  console.log('[SW] Notification reçue en background:', payload);

  const { title, body } = payload.notification || {};
  if (!title) return;

  self.registration.showNotification(title, {
    body: body || '',
    icon: '/icons/Icon-192.png',
    badge: '/favicon.png',
  });
});
