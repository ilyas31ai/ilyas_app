import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/social_service.dart';

class NotificationsPage extends StatefulWidget {
  final String currentUser;

  const NotificationsPage({super.key, required this.currentUser});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final db = FirebaseDatabase.instance.ref();

  List<String> smartNotifications = [];

  @override
  void initState() {
    super.initState();
    loadSmartNotifications();
  }

  // 🔥 NOTIFICATIONS IA (flashcards + amis)
  Future<void> loadSmartNotifications() async {
    List<String> all = [];

    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('flashcards');

    if (data != null) {
      final cards = jsonDecode(data);
      all.add("📚 ${cards.length} cartes à réviser");

      if (cards.length >= 5) {
        all.add("🔥 Tu progresses !");
      }
    } else {
      all.add("📭 Ajoute des flashcards !");
    }

    final reqSnapshot = await db
        .child('friend_requests/${SocialService.encodeKey(widget.currentUser)}')
        .get();

    if (reqSnapshot.exists) {
      final data =
          Map<dynamic, dynamic>.from(reqSnapshot.value as Map);
      all.add("👥 ${data.length} demande(s) d'ami");
    }

    setState(() {
      smartNotifications = all;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("🔔 Notifications"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 🔥 LOGO
          Image.asset("assets/logo.png", height: 80),
          const SizedBox(height: 10),

          const Text(
            "Centre intelligent",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),

          const SizedBox(height: 20),

          // 🧠 NOTIFICATIONS IA
          ...smartNotifications.map((notif) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                notif,
                style: const TextStyle(color: Colors.white),
              ),
            );
          }),

          const SizedBox(height: 20),

          // 🔔 NOTIFICATIONS CHAT (REALTIME)
          const Text(
            "💬 Messages",
            style: TextStyle(color: Colors.white70),
          ),

          const SizedBox(height: 10),

          StreamBuilder(
            stream: db
                .child('notifications/${SocialService.encodeKey(widget.currentUser)}')
                .orderByChild('time')
                .onValue,
            builder: (context, snapshot) {
              if (!snapshot.hasData ||
                  snapshot.data!.snapshot.value == null) {
                return const Text(
                  "Aucune notification",
                  style: TextStyle(color: Colors.white54),
                );
              }

              final data = Map<dynamic, dynamic>.from(
                  snapshot.data!.snapshot.value as Map);

              final list = data.values.toList();

              list.sort((a, b) => b["time"].compareTo(a["time"]));

              return Column(
                children: list.map((notif) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications,
                            color: Colors.blue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                notif["title"] ?? "",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                notif["body"] ?? "",
                                style: const TextStyle(
                                    color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 20),

          // 🔴 BADGE NON LU GLOBAL
          StreamBuilder(
            stream: db.child("messages").onValue,
            builder: (context, snapshot) {
              if (!snapshot.hasData ||
                  snapshot.data!.snapshot.value == null) {
                return const SizedBox();
              }

              final data = Map<dynamic, dynamic>.from(
                  snapshot.data!.snapshot.value as Map);

              int unread = 0;

              data.forEach((chatId, messages) {
                final msgs =
                    Map<dynamic, dynamic>.from(messages as Map);

                msgs.forEach((key, msg) {
                  if (msg["sender"] != widget.currentUser &&
                      msg["seen"] != true) {
                    unread++;
                  }
                });
              });

              if (unread == 0) return const SizedBox();

              return Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  "💬 $unread message(s) non lus",
                  style: const TextStyle(color: Colors.white),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}