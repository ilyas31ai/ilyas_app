import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class DiscussionPage extends StatefulWidget {
  final String name;

  const DiscussionPage({super.key, required this.name});

  @override
  State<DiscussionPage> createState() => _DiscussionPageState();
}

class _DiscussionPageState extends State<DiscussionPage> {
  final TextEditingController controller = TextEditingController();
  final List<Map<String, dynamic>> messages = [];

  // 📩 envoyer texte
  void sendMessage() {
    if (controller.text.trim().isEmpty) return;

    setState(() {
      messages.add({
        "text": controller.text,
        "isMe": true,
        "time": TimeOfDay.now().format(context),
      });
    });

    controller.clear();
  }

  // 📸 envoyer image
  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        messages.add({
          "image": File(pickedFile.path),
          "isMe": true,
          "time": TimeOfDay.now().format(context),
        });
      });
    }
  }

  // 💬 afficher message
  Widget buildMessage(Map msg) {
    final isMe = msg["isMe"];

    return Align(
      alignment:
          isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
                  colors: [Colors.blue, Colors.cyan])
              : const LinearGradient(
                  colors: [Colors.grey, Colors.black54]),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 🖼 image
            if (msg["image"] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  msg["image"],
                  width: 150,
                ),
              ),

            // 💬 texte
            if (msg["text"] != null)
              Text(
                msg["text"],
                style: const TextStyle(color: Colors.white),
              ),

            const SizedBox(height: 5),

            Text(
              msg["time"],
              style: const TextStyle(
                  fontSize: 10, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),

      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Row(
          children: [
            const CircleAvatar(
              child: Icon(Icons.person),
            ),
            const SizedBox(width: 10),
            Text(widget.name),
          ],
        ),
      ),

      body: Column(
        children: [
          // 💬 messages
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          width: 120,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Aucun message",
                          style: TextStyle(
                              color: Colors.white54, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return buildMessage(messages[index]);
                    },
                  ),
          ),

          // ✍️ input
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.black26,
            child: Row(
              children: [
                // 📸 bouton image
                IconButton(
                  icon: const Icon(Icons.image,
                      color: Colors.white),
                  onPressed: pickImage,
                ),

                // champ texte
                Expanded(
                  child: TextField(
                    controller: controller,
                    style:
                        const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Écrire un message...",
                      hintStyle: const TextStyle(
                          color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // bouton envoyer
                GestureDetector(
                  onTap: sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.cyan,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send,
                        color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}