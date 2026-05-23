import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_database/firebase_database.dart';

class NotificationService {

  static final FirebaseMessaging _fcm =
      FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  // 🔥 INITIALISATION
  static Future<void> init(String currentUser) async {

    // 🔐 Permission notifications
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 📱 Android local notification
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
        InitializationSettings(
      android: androidSettings,
    );

    await _local.initialize(settings);

    // 🔥 Message reçu quand app ouverte
    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) {

        showLocalNotification(
          message.notification?.title ?? "Notification",
          message.notification?.body ?? "",
        );
      },
    );

    // 🔥 Click notification
    FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) {

        print("Notification ouverte");
      },
    );

    // 🔥 Firebase Realtime Database
    final DatabaseReference db =
        FirebaseDatabase.instance.ref();

    db
        .child("notifications/$currentUser")
        .onChildAdded
        .listen((event) {

      if (event.snapshot.value != null) {

        final data =
            Map<dynamic, dynamic>.from(
          event.snapshot.value as Map,
        );

        showLocalNotification(
          data["title"] ?? "Message",
          data["body"] ?? "",
        );
      }
    });
  }

  // 🔔 Notification locale
  static Future<void> showLocalNotification(
    String title,
    String body,
  ) async {

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details =
        NotificationDetails(
      android: androidDetails,
    );

    await _local.show(
      0,
      title,
      body,
      details,
    );
  }
}