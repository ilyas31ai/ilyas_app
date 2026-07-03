import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'social_service.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static final List<StreamSubscription> _parentSubs = [];
  static final List<StreamSubscription> _eleveSubs = [];
  static final Set<String> _notifiedBulletins = {};

  static Future<void> init(String currentUser) async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(
        const InitializationSettings(android: androidSettings));

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
    final k = SocialService.encodeKey(currentUser);
    FirebaseDatabase.instance
        .ref('notifications/$k')
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

  // ── Listeners parent en temps réel ────────────────────────────────────────

  static Future<void> initParentListeners(List<String> enfantIds) async {
    await disposeParentListeners();
    if (enfantIds.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    // First install: anchor lastSeen to now — don't notify for existing data
    if (prefs.getString('pn_notes_at') == null) {
      await prefs.setString('pn_notes_at', DateTime.now().toIso8601String());
    }
    if (prefs.getString('pn_pres_at') == null) {
      await prefs.setString('pn_pres_at', _todayStr());
    }

    // Notes: one listener per child
    for (final childId in enfantIds) {
      _parentSubs.add(
        FirebaseFirestore.instance
            .collection('notes')
            .where('eleveId', isEqualTo: childId)
            .where('publie', isEqualTo: true)
            .orderBy('date', descending: true)
            .limit(3)
            .snapshots()
            .listen((snap) async {
          if (snap.docs.isEmpty) return;
          final lastAt =
              DateTime.tryParse(prefs.getString('pn_notes_at') ?? '') ??
                  DateTime.now();
          for (final doc in snap.docs) {
            final d = doc.data();
            final ts = d['date'] as Timestamp?;
            if (ts == null) break;
            final date = ts.toDate();
            if (!date.isAfter(lastAt)) break;
            final matiere = d['matiere'] as String? ?? 'Matière';
            final note = (d['note'] as num?)?.toDouble() ?? 0;
            final bareme = (d['bareme'] as num?)?.toDouble() ?? 20;
            final sur20 = bareme == 0 ? 0.0 : (note / bareme) * 20;
            final prenom = d['elevePrenom'] as String? ?? '';
            final nom = d['eleveNom'] as String? ?? '';
            final enfantNom = '$prenom $nom'.trim();
            await _showOnChannel(
              id: 10,
              title: 'Nouvelle note${enfantNom.isNotEmpty ? " · $enfantNom" : ""}',
              body: '$matiere · ${sur20.toStringAsFixed(1)}/20',
              channelId: 'parent_notes',
              channelName: 'Notes enfants',
            );
            await prefs.setString(
                'pn_notes_at', DateTime.now().toIso8601String());
            break;
          }
        }),
      );
    }

    // Présences: one listener per child (absences & retards)
    for (final childId in enfantIds) {
      _parentSubs.add(
        FirebaseFirestore.instance
            .collection('presences')
            .where('eleveId', isEqualTo: childId)
            .orderBy('date', descending: true)
            .limit(5)
            .snapshots()
            .listen((snap) async {
          if (snap.docs.isEmpty) return;
          final lastDate = prefs.getString('pn_pres_at') ?? '';
          for (final doc in snap.docs) {
            final d = doc.data();
            final statut = d['statut'] as String? ?? '';
            if (statut != 'absent' && statut != 'retard') continue;
            final date = d['date'] as String? ?? '';
            if (date.compareTo(lastDate) <= 0) break;
            await prefs.setString('pn_pres_at', date);
            final prenom = d['elevePrenom'] as String? ?? '';
            final nomE = d['eleveNom'] as String? ?? '';
            final enfantNom = '$prenom $nomE'.trim();
            await _showOnChannel(
              id: 11,
              title: statut == 'absent'
                  ? 'Absence enregistrée'
                  : 'Retard enregistré',
              body: enfantNom.isNotEmpty ? enfantNom : 'Votre enfant',
              channelId: 'parent_presences',
              channelName: 'Présences enfants',
            );
            break;
          }
        }),
      );
    }

    // RDV: notifier lors d'un changement de statut
    final parentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (parentUid.isNotEmpty) {
      _parentSubs.add(
        FirebaseFirestore.instance
            .collection('rdv')
            .where('parentUid', isEqualTo: parentUid)
            .orderBy('createdAt', descending: true)
            .limit(5)
            .snapshots()
            .listen((snap) async {
          for (final change in snap.docChanges) {
            if (change.type != DocumentChangeType.modified) continue;
            final d = change.doc.data() ?? {};
            final statut = d['statut'] as String? ?? '';
            final profNom =
                d['professeurNom'] as String? ?? 'Professeur';
            String title, body;
            switch (statut) {
              case 'accepte':
              case 'confirme':
                title = 'RDV confirmé';
                body = 'Avec $profNom';
              case 'refuse':
              case 'annule':
                title = 'RDV refusé';
                body = 'Avec $profNom';
              case 'proposeAutreDate':
                title = 'Nouvelle date proposée';
                body = 'RDV avec $profNom';
              default:
                continue;
            }
            await _showOnChannel(
              id: 12,
              title: title,
              body: body,
              channelId: 'parent_rdv',
              channelName: 'RDV Parents',
            );
          }
        }),
      );
    }
  }

  // ── Listeners élève bulletin ──────────────────────────────────────────────

  /// Écoute les publications de bulletins pour l'élève connecté.
  /// Déclenche une notification locale quand la Direction publie un bulletin.
  static Future<void> initEleveListeners(
      String classeId, int anneeScol) async {
    await disposeEleveListeners();
    if (classeId.isEmpty) return;

    for (int t = 1; t <= 3; t++) {
      final docId = '${classeId}_t${t}_$anneeScol';
      _eleveSubs.add(
        FirebaseFirestore.instance
            .collection('bulletin_validations')
            .doc(docId)
            .snapshots()
            .listen((snap) async {
          if (!snap.exists) return;
          final publie = snap.data()?['publie'] as bool? ?? false;
          if (!publie || _notifiedBulletins.contains(docId)) return;
          _notifiedBulletins.add(docId);
          final prefs = await SharedPreferences.getInstance();
          final key = 'bn_$docId';
          if (prefs.getBool(key) == true) return;
          await prefs.setBool(key, true);
          await _showOnChannel(
            id: 20 + t,
            title: 'Bulletin disponible',
            body:
                'Ton bulletin du Trimestre $t a ete publie par la Direction',
            channelId: 'bulletins',
            channelName: 'Bulletins',
          );
        }),
      );
    }
  }

  static Future<void> disposeEleveListeners() async {
    for (final sub in _eleveSubs) {
      await sub.cancel();
    }
    _eleveSubs.clear();
  }

  static Future<void> disposeParentListeners() async {
    for (final sub in _parentSubs) {
      await sub.cancel();
    }
    _parentSubs.clear();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<void> _showOnChannel({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    await _local.show(
        id, title, body, NotificationDetails(android: androidDetails));
  }

  static Future<void> _saveFcmToken() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final token = await _fcm.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcmToken': token});
    } catch (_) {}
  }

  static Future<void> _updateFcmToken(String token) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcmToken': token});
    } catch (_) {}
  }

  static Future<void> showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    await _local.show(
        0, title, body, const NotificationDetails(android: androidDetails));
  }
}