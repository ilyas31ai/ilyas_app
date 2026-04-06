import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<String> notifications = [];

  @override
  void initState() {
    super.initState();
    generateSmartNotifications();
  }

  // 🔥 IA notifications basée sur flashcards
  Future<void> generateSmartNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('flashcards');

    List cards = [];

    if (data != null) {
      cards = jsonDecode(data);
    }

    List<String> newNotifications = [];

    if (cards.isEmpty) {
      newNotifications.add("📭 Aucune carte. Ajoute des flashcards !");
    } else {
      newNotifications.add("📚 Tu as ${cards.length} cartes à réviser");

      if (cards.length >= 5) {
        newNotifications.add("🔥 Tu progresses bien !");
      }

      if (cards.length >= 10) {
        newNotifications.add("🚀 Niveau avancé atteint !");
      }

      if (cards.length < 3) {
        newNotifications.add("💡 Ajoute plus de cartes pour progresser");
      }
    }

    setState(() {
      notifications = newNotifications;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("🔔 Notifications"),
      ),

      body: Column(
        children: [
          const SizedBox(height: 20),

          // 🔥 LOGO
          Image.asset("assets/logo.png", height: 80),

          const SizedBox(height: 10),

          const Text(
            "Centre intelligent",
            style: TextStyle(color: Colors.white),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: notifications.isEmpty
                ? const Center(
                    child: Text(
                      "Aucune notification",
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          notifications[index],
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}