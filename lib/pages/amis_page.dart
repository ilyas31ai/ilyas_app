import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AmisPage extends StatefulWidget {
  final String currentUser;

  const AmisPage({super.key, required this.currentUser});

  @override
  State<AmisPage> createState() => _AmisPageState();
}

class _AmisPageState extends State<AmisPage> {
  final db = FirebaseDatabase.instance.ref();
  String search = "";

  // 🔥 ENVOYER DEMANDE
  void sendFriendRequest(String targetUser) async {
    if (targetUser == widget.currentUser) return;

    await db
        .child("friend_requests/$targetUser/${widget.currentUser}")
        .set(true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Demande envoyée à $targetUser ✅")),
    );
  }

  // ✅ ACCEPTER
  void acceptRequest(String user) async {
    await db.child("friends/${widget.currentUser}/$user").set(true);
    await db.child("friends/$user/${widget.currentUser}").set(true);
    await db
        .child("friend_requests/${widget.currentUser}/$user")
        .remove();
  }

  // ❌ REFUSER
  void rejectRequest(String user) async {
    await db
        .child("friend_requests/${widget.currentUser}/$user")
        .remove();
  }

  // ❌ SUPPRIMER AMI
  void removeFriend(String user) async {
    await db.child("friends/${widget.currentUser}/$user").remove();
    await db.child("friends/$user/${widget.currentUser}").remove();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Amis"),
        centerTitle: true,
      ),

      // 🔥 SCROLL GLOBAL
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),

            // 🔥 LOGO
            Image.asset("assets/logo.png", height: 70),
            const SizedBox(height: 10),

            const Text(
              "Gestion des amis",
              style: TextStyle(color: Colors.white70),
            ),

            const SizedBox(height: 20),

            // 🔍 RECHERCHE
            Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                onChanged: (value) =>
                    setState(() => search = value),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Rechercher utilisateur...",
                  hintStyle:
                      const TextStyle(color: Colors.white54),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.white),
                  filled: true,
                  fillColor: Colors.black45,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 📥 DEMANDES
            const Text("📥 Demandes",
                style: TextStyle(color: Colors.white)),

            StreamBuilder(
              stream: db
                  .child("friend_requests/${widget.currentUser}")
                  .onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value == null) {
                  return const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text("Aucune demande",
                        style: TextStyle(color: Colors.white54)),
                  );
                }

                final data = Map<dynamic, dynamic>.from(
                    snapshot.data!.snapshot.value as Map);

                final requests = data.keys.toList();

                return Column(
                  children: requests.map((user) {
                    return ListTile(
                      title: Text(user),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check,
                                color: Colors.green),
                            onPressed: () =>
                                acceptRequest(user),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.red),
                            onPressed: () =>
                                rejectRequest(user),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 20),

            // 👥 AMIS
            const Text("👥 Mes amis",
                style: TextStyle(color: Colors.white)),

            StreamBuilder(
              stream:
                  db.child("friends/${widget.currentUser}").onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value == null) {
                  return const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text("Aucun ami",
                        style: TextStyle(color: Colors.white54)),
                  );
                }

                final data = Map<dynamic, dynamic>.from(
                    snapshot.data!.snapshot.value as Map);

                final friends = data.keys.toList();

                return Column(
                  children: friends.map((user) {
                    return ListTile(
                      title: Text(user),

                      // 💬 CHAT
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/discussion',
                          arguments: {
                            "name": user,
                            "user": widget.currentUser,
                          },
                        );
                      },

                      trailing: IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.red),
                        onPressed: () =>
                            removeFriend(user),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 20),

            // 🔍 UTILISATEURS
            const Text("🔍 Trouver des utilisateurs",
                style: TextStyle(color: Colors.white)),

            StreamBuilder(
              stream: db.child("users").onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value == null) {
                  return const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text("Aucun utilisateur",
                        style: TextStyle(color: Colors.white54)),
                  );
                }

                final data = Map<dynamic, dynamic>.from(
                    snapshot.data!.snapshot.value as Map);

                final users = data.keys
                    .where((u) => u != widget.currentUser)
                    .toList();

                final filtered = users
                    .where((u) => u
                        .toLowerCase()
                        .contains(search.toLowerCase()))
                    .toList();

                return Column(
                  children: filtered.map((user) {
                    return ListTile(
                      title: Text(user),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_add,
                            color: Colors.blue),
                        onPressed: () =>
                            sendFriendRequest(user),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}