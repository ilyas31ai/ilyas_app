import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static Future<void> init(String currentUser) async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(
        const InitializationSettings(android: androidSettings));

    // Save FCM token to Firestore for push targeting
    await _saveFcmToken();
    _fcm.onTokenRefresh.listen(_updateFcmToken);

    // Foreground FCM messages
    FirebaseMessaging.onMessage.listen((msg) {
      showLocalNotification(
        msg.notification?.title ?? 'Notification',
        msg.notification?.body ?? '',
      );
    });

    // RTDB-based in-app chat notifications
    FirebaseDatabase.instance
        .ref('notifications/$currentUser')
        .onChildAdded
        .listen((event) {
      if (event.snapshot.value == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      showLocalNotification(
        data['title'] as String? ?? 'Message',
        data['body'] as String? ?? '',
      );
    });
  }

  static Future<void> _saveFcmToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final token = await _fcm.getToken();
    if (token == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'fcmToken': token});
  }

  static Future<void> _updateFcmToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'fcmToken': token});
  }

  static Future<void> showLocalNotification(
      String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    await _local.show(
      0,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }
}