import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class DiscussionPage extends StatefulWidget {
  final String name;
  final String user;

  const DiscussionPage({
    super.key,
    required this.name,
    required this.user,
  });

  @override
  State<DiscussionPage> createState() => _DiscussionPageState();
}

class _DiscussionPageState extends State<DiscussionPage> {
  final db = FirebaseDatabase.instance.ref();

  final TextEditingController controller =
      TextEditingController();

  final ScrollController scrollController =
      ScrollController();

  bool isSending = false;

  // 🔥 CHAT ID
  String get chatId {
    final users = [widget.user, widget.name]..sort();
    return users.join("_");
  }

  @override
  void initState() {
    super.initState();

    // ✅ marquer vu UNE SEULE FOIS
    Future.delayed(
      const Duration(milliseconds: 500),
      () {
        markAsSeen();
      },
    );
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  // ✅ VU OPTIMISÉ
  Future<void> markAsSeen() async {
    final snapshot =
        await db.child("messages/$chatId").get();

    if (!snapshot.exists) return;

    final data =
        Map<dynamic, dynamic>.from(snapshot.value as Map);

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value["sender"] != widget.user &&
          value["seen"] != true) {
        await db
            .child("messages/$chatId/$key/seen")
            .set(true);
      }
    }
  }

  // 🚀 ENVOI MESSAGE
  Future<void> sendMessage() async {
    if (isSending) return;

    final text = controller.text.trim();

    if (text.isEmpty) return;

    isSending = true;

    final time = DateTime.now().millisecondsSinceEpoch;

    try {
      // 🔥 MESSAGE
      await db.child("messages/$chatId").push().set({
        "text": text,
        "sender": widget.user,
        "time": time,
        "seen": false,
      });

      // 🔔 NOTIFICATION
      await db
          .child("notifications/${widget.name}")
          .push()
          .set({
        "title": widget.user,
        "body": text,
        "time": time,
      });

      controller.clear();

      // 🔽 SCROLL
      Future.delayed(
        const Duration(milliseconds: 100),
        () {
          if (scrollController.hasClients) {
            scrollController.animateTo(
              0,
              duration:
                  const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e")),
      );
    }

    isSending = false;
  }

  // ➕ AJOUT CONTACT
  Future<void> addContact() async {
    await db
        .child(
            "users/${widget.user}/contacts/${widget.name}")
        .set(true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${widget.name} ajouté ✅"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),

      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.name),

        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: addContact,
          ),
        ],
      ),

      body: Column(
        children: [
          // 💬 MESSAGES
          Expanded(
            child: StreamBuilder(
              stream: db
                  .child("messages/$chatId")
                  .limitToLast(50)
                  .onValue,

              builder: (context, snapshot) {
                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value ==
                        null) {
                  return const Center(
                    child: Text(
                      "Aucun message",
                      style:
                          TextStyle(color: Colors.white),
                    ),
                  );
                }

                final data =
                    Map<dynamic, dynamic>.from(
                  snapshot.data!.snapshot.value
                      as Map,
                );

                final messages =
                    data.values.toList();

                // ✅ TRI
                messages.sort(
                  (a, b) =>
                      b["time"].compareTo(a["time"]),
                );

                return ListView.builder(
                  controller: scrollController,

                  reverse: true,

                  padding:
                      const EdgeInsets.all(10),

                  itemCount: messages.length,

                  itemBuilder: (context, index) {
                    final msg = messages[index];

                    final isMe =
                        msg["sender"] == widget.user;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,

                      child: Container(
                        constraints:
                            const BoxConstraints(
                          maxWidth: 300,
                        ),

                        margin:
                            const EdgeInsets.symmetric(
                          vertical: 4,
                        ),

                        padding:
                            const EdgeInsets.all(12),

                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.green
                              : Colors.grey.shade800,

                          borderRadius:
                              BorderRadius.circular(
                                  15),
                        ),

                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.end,

                          children: [
                            Text(
                              msg["text"] ?? "",

                              style:
                                  const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),

                            const SizedBox(height: 5),

                            if (isMe)
                              Icon(
                                msg["seen"] == true
                                    ? Icons.done_all
                                    : Icons.check,

                                size: 16,

                                color:
                                    msg["seen"] == true
                                        ? Colors.blue
                                        : Colors.white70,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ✏️ INPUT
          SafeArea(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),

              color: Colors.black,

              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,

                      style: const TextStyle(
                        color: Colors.white,
                      ),

                      decoration: InputDecoration(
                        hintText: "Message...",

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
                                  25),

                          borderSide:
                              BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 5),

                  CircleAvatar(
                    backgroundColor: Colors.green,

                    child: IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                      ),

                      onPressed: sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}