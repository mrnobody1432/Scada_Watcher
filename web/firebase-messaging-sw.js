importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyBvGqq5JDjVb-b2sdP1kqCgX2d858X4E2k",
  appId: "1:932777127221:web:94b95413180801325b707c",
  messagingSenderId: "932777127221",
  projectId: "scadadataserver",
  authDomain: "scadadataserver.firebaseapp.com",
  storageBucket: "scadadataserver.firebasestorage.app",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("[firebase-messaging-sw.js] Received background message ", payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: "/favicon.png",
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
