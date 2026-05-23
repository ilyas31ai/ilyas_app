import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class PrivateChatPage extends StatefulWidget {
  final String currentUser;
  final String otherUser;

  const PrivateChatPage({
    super.key,
    required this.currentUser,
    required this.otherUser,
  });

  @override
  State<PrivateChatPage> createState() => _PrivateChatPageState();
}

class _PrivateChatPageState extends State<PrivateChatPage> {
  final controller = TextEditingController();

  late DatabaseReference chatRef;

  @override
  void initState() {
    super.initState();

    // 🔥 room unique
    final roomId =
        [widget.currentUser, widget.otherUser]..sort();

    chatRef = FirebaseDatabase.instance
        .ref("messages/${roomId.join("_")}");
  }

  void sendMessage() {
    if (controller.text.isEmpty) return;

    chatRef.push().set({
      "text": controller.text,
      "sender": widget.currentUser,
      "time": DateTime.now().toString(),
    });

    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherUser)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: chatRef.onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value == null) {
                  return const Center(child: Text("Pas de messages"));
                }

                final data = Map<String, dynamic>.from(
                    snapshot.data!.snapshot.value as Map);

                final messages = data.values.toList();

                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg =
                        Map<String, dynamic>.from(messages[index]);

                    final isMe =
                        msg["sender"] == widget.currentUser;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(10),
                        color: isMe
                            ? Colors.blue
                            : Colors.grey,
                        child: Text(
                          msg["text"],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(controller: controller),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: sendMessage,
              )
            ],
          )
        ],
      ),
    );
  }
}