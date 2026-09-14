// Firebase Messaging Service Worker
//
// Required for FCM push notifications on Flutter Web.
// The firebase_messaging plugin will look for this file at:
//   /firebase-messaging-sw.js
//
// IMPORTANT:
// - The config below MUST match your Firebase Web app (see lib/firebase_options.dart).
// - If you rotate Firebase keys, update this file.

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDq5JGJ_9F90jmqEfZ1ac7JqYyodIA7Om4',
  authDomain: 'thix-id.firebaseapp.com',
  projectId: 'thix-id',
  storageBucket: 'thix-id.firebasestorage.app',
  messagingSenderId: '27116360434',
  appId: '1:27116360434:web:926a689f227db09243766b',
  measurementId: 'G-C0SZGLX5FV',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notificationTitle = (payload?.notification?.title) || 'THIX ID';
  const notificationOptions = {
    body: (payload?.notification?.body) || '',
    data: payload?.data || {},
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
