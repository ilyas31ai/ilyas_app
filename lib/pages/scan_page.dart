import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  File? image;

  Future<void> takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);

    if (picked != null) {
      setState(() {
        image = File(picked.path);
      });
    }
  }

  Future<void> pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        image = File(picked.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text("Scan devoir"),
        backgroundColor: Colors.teal,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🔷 LOGO
            Image.asset(
              'assets/logo.png',
              height: 80,
            ),

            const SizedBox(height: 20),

            // 📸 IMAGE
            image != null
                ? Image.file(image!, height: 250)
                : const Text(
                    "Aucune image",
                    style: TextStyle(color: Colors.white),
                  ),

            const SizedBox(height: 30),

            // 📷 CAMERA
            ElevatedButton.icon(
              onPressed: takePhoto,
              icon: const Icon(Icons.camera),
              label: const Text("Prendre une photo"),
            ),

            const SizedBox(height: 10),

            // 🖼 GALERIE
            ElevatedButton.icon(
              onPressed: pickFromGallery,
              icon: const Icon(Icons.image),
              label: const Text("Choisir depuis galerie"),
            ),
          ],
        ),
      ),
    );
  }
}