import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class UsersPage extends StatefulWidget {
  final String currentUser;

  const UsersPage({
    super.key,
    required this.currentUser,
  });

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final db = FirebaseDatabase.instance.ref();

  final TextEditingController controller =
      TextEditingController();

  // 🔥 CHAT ID
  String getChatId(String otherUser) {
    final users = [
      widget.currentUser,
      otherUser,
    ]..sort();

    return users.join("_");
  }

  // ➕ AJOUT USER
  Future<void> addUser() async {
    final name = controller.text.trim();

    if (name.isEmpty) return;

    await db.child("users/$name").set({
      "name": name,
    });

    await db
        .child(
          "users/${widget.currentUser}/contacts/$name",
        )
        .set(true);

    controller.clear();
  }

  // 🟢 ONLINE
  @override
  void initState() {
    super.initState();

    db.child("status/${widget.currentUser}").set({
      "online": true,
      "lastSeen": DateTime.now().toString(),
    });
  }

  // 🔴 OFFLINE
  @override
  void dispose() {
    db.child("status/${widget.currentUser}").set({
      "online": false,
      "lastSeen": DateTime.now().toString(),
    });

    controller.dispose();

    super.dispose();
  }

  // ⏰ FORMAT
  String formatTime(int? timestamp) {
    if (timestamp == null) return "";

    final date =
        DateTime.fromMillisecondsSinceEpoch(timestamp);

    return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  // 📸 PHOTO
  Widget buildAvatar(String userName) {
    return FutureBuilder(
      future: db.child("users/$userName/photo").get(),

      builder: (context, snap) {
        if (snap.hasData &&
            snap.data != null &&
            snap.data!.value != null) {
          return CircleAvatar(
            radius: 25,

            backgroundImage: NetworkImage(
              snap.data!.value.toString(),
            ),
          );
        }

        return CircleAvatar(
          radius: 25,
          child: Text(
            userName[0].toUpperCase(),
          ),
        );
      },
    );
  }

  // 🟢 ONLINE DOT
  Widget buildStatusDot(String userName) {
    return StreamBuilder(
      stream: db
          .child("status/$userName")
          .onValue,

      builder: (context, snap) {
        bool online = false;

        if (snap.hasData &&
            snap.data!.snapshot.value != null) {
          final d = Map<dynamic, dynamic>.from(
            snap.data!.snapshot.value as Map,
          );

          online = d["online"] == true;
        }

        return Container(
          width: 12,
          height: 12,

          decoration: BoxDecoration(
            color:
                online ? Colors.green : Colors.grey,

            shape: BoxShape.circle,

            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),

      appBar: AppBar(
        title: const Text("Messages"),
        backgroundColor: Colors.black,
      ),

      body: Column(
        children: [
          // ➕ AJOUT USER
          Padding(
            padding: const EdgeInsets.all(10),

            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,

                    style: const TextStyle(
                      color: Colors.white,
                    ),

                    decoration: InputDecoration(
                      hintText: "Nom utilisateur",

                      hintStyle:
                          const TextStyle(
                        color: Colors.white54,
                      ),

                      filled: true,

                      fillColor:
                          Colors.grey.shade900,

                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                                15),
                      ),
                    ),
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: addUser,
                ),
              ],
            ),
          ),

          // 📋 CONTACTS
          Expanded(
            child: StreamBuilder(
              stream: db
                  .child(
                    "users/${widget.currentUser}/contacts",
                  )
                  .onValue,

              builder: (context, snapshot) {
                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value ==
                        null) {
                  return const Center(
                    child: Text(
                      "Aucun contact",
                      style:
                          TextStyle(color: Colors.white),
                    ),
                  );
                }

                final contacts =
                    Map<dynamic, dynamic>.from(
                  snapshot.data!.snapshot.value
                      as Map,
                );

                final users =
                    contacts.keys.toList();

                return ListView.builder(
                  itemCount: users.length,

                  itemBuilder: (context, index) {
                    final userName =
                        users[index];

                    final chatId =
                        getChatId(userName);

                    return StreamBuilder(
                      // ✅ ULTRA IMPORTANT
                      stream: db
                          .child(
                              "messages/$chatId")
                          .limitToLast(1)
                          .onValue,

                      builder:
                          (context, chatSnap) {
                        String lastMessage =
                            "Aucun message";

                        int? lastTime;

                        int unread = 0;

                        if (chatSnap.hasData &&
                            chatSnap
                                    .data!
                                    .snapshot
                                    .value !=
                                null) {
                          final msgs =
                              Map<dynamic,
                                  dynamic>.from(
                            chatSnap
                                    .data!
                                    .snapshot
                                    .value
                                as Map,
                          );

                          msgs.forEach(
                              (key, msg) {
                            lastMessage =
                                msg["text"] ??
                                    "";

                            lastTime =
                                msg["time"];

                            if (msg["sender"] !=
                                    widget
                                        .currentUser &&
                                msg["seen"] !=
                                    true) {
                              unread++;
                            }
                          });
                        }

                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),

                          // 👤 AVATAR
                          leading: Stack(
                            children: [
                              buildAvatar(
                                  userName),

                              Positioned(
                                bottom: 0,
                                right: 0,

                                child:
                                    buildStatusDot(
                                  userName,
                                ),
                              ),
                            ],
                          ),

                          // 👤 NOM
                          title: Text(
                            userName,

                            style:
                                const TextStyle(
                              color: Colors.white,

                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          // 💬 MESSAGE
                          subtitle: Text(
                            lastMessage,

                            maxLines: 1,

                            overflow:
                                TextOverflow
                                    .ellipsis,

                            style:
                                const TextStyle(
                              color: Colors.grey,
                            ),
                          ),

                          // ⏰ + BADGE
                          trailing: Column(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,

                            children: [
                              Text(
                                formatTime(
                                    lastTime),

                                style:
                                    const TextStyle(
                                  color:
                                      Colors.white70,

                                  fontSize: 10,
                                ),
                              ),

                              const SizedBox(
                                  height: 5),

                              if (unread > 0)
                                CircleAvatar(
                                  radius: 10,

                                  backgroundColor:
                                      Colors.green,

                                  child: Text(
                                    "$unread",

                                    style:
                                        const TextStyle(
                                      fontSize:
                                          10,

                                      color:
                                          Colors
                                              .white,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          // 👉 OUVRIR CHAT
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/discussion',

                              arguments: {
                                "name":
                                    userName,

                                "user": widget
                                    .currentUser,
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}