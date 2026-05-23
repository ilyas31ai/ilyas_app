import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'private_chat_page.dart';

class InboxPage extends StatefulWidget {
  final String currentUser;

  const InboxPage({super.key, required this.currentUser});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final db = FirebaseDatabase.instance.ref();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        backgroundColor: Colors.blue,
      ),
      body: StreamBuilder(
        stream: db.child("messages").onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData ||
              snapshot.data!.snapshot.value == null) {
            return const Center(child: Text("Aucun message"));
          }

          final data = snapshot.data!.snapshot.value as Map;
          final rooms = data.entries.toList();

          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final roomId = rooms[index].key;
              final messages = rooms[index].value as Map;

              final users = roomId.split("_");
              final otherUser =
                  users.firstWhere((u) => u != widget.currentUser);

              final msgList = messages.entries.toList();

              // 🔥 dernier message
              msgList.sort((a, b) => b.key.compareTo(a.key));
              final lastMsg = msgList.first.value;

              final text = lastMsg["text"] ?? "";
              final time = lastMsg["time"]
                  .toString()
                  .substring(11, 16);

              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(otherUser),
                subtitle: Text(text),
                trailing: Text(
                  time,
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PrivateChatPage(
                        currentUser: widget.currentUser,
                        otherUser: otherUser,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}