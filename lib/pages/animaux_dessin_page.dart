import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // ✅ IMPORTANT

import 'package:permission_handler/permission_handler.dart';

class AnimauxDessinPage extends StatefulWidget {
  const AnimauxDessinPage({super.key});

  @override
  State<AnimauxDessinPage> createState() => _AnimauxDessinPageState();
}

class _AnimauxDessinPageState extends State<AnimauxDessinPage> {
  List<Offset?> points = [];

  Color selectedColor = Colors.black;
  double strokeWidth = 4;

  String animal = "🐶";

  final GlobalKey repaintKey = GlobalKey();

  void clearCanvas() {
    setState(() {
      points.clear();
    });
  }

  void changeAnimal(String newAnimal) {
    setState(() {
      animal = newAnimal;
      points.clear();
    });
  }

  // 💾 SAUVEGARDE IMAGE
  Future<void> saveImage() async {
    // ✅ Permission
    var status = await Permission.storage.request();
    if (!status.isGranted) return;

    try {
      final boundary =
          repaintKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;

      final image = await boundary.toImage(pixelRatio: 3);

      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image sauvegardée 📸")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur sauvegarde ❌")),
      );
    }
  }

  void showReward() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Bravo ⭐"),
        content: const Text("Super dessin ! 👏"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dessine 🎨"),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: saveImage,
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),

          // 🐶 ANIMAL
          Text(animal, style: const TextStyle(fontSize: 50)),

          const SizedBox(height: 10),

          // 🐾 CHOIX ANIMAUX
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              animalBtn("🐶"),
              animalBtn("🐱"),
              animalBtn("🦁"),
              animalBtn("🐸"),
            ],
          ),

          const SizedBox(height: 10),

          // 🎨 COULEURS
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              colorBtn(Colors.black),
              colorBtn(Colors.red),
              colorBtn(Colors.blue),
              colorBtn(Colors.green),
              colorBtn(Colors.orange),
            ],
          ),

          // 🖌️ TAILLE PINCEAU
          Slider(
            value: strokeWidth,
            min: 2,
            max: 12,
            onChanged: (value) {
              setState(() {
                strokeWidth = value;
              });
            },
          ),

          // 🎨 ZONE DESSIN
          Expanded(
            child: RepaintBoundary(
              key: repaintKey,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    points.add(details.localPosition);
                  });
                },
                onPanEnd: (_) => points.add(null),
                child: Container(
                  color: Colors.white,
                  child: CustomPaint(
                    painter:
                        DrawingPainter(points, selectedColor, strokeWidth),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 🔘 BOUTONS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: clearCanvas,
                child: const Text("Effacer 🧹"),
              ),
              ElevatedButton(
                onPressed: showReward,
                child: const Text("Valider ⭐"),
              ),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget animalBtn(String emoji) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: ElevatedButton(
        onPressed: () => changeAnimal(emoji),
        child: Text(emoji, style: const TextStyle(fontSize: 22)),
      ),
    );
  }

  Widget colorBtn(Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedColor = color;
        });
      },
      child: Container(
        margin: const EdgeInsets.all(5),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(width: 2, color: Colors.black),
        ),
      ),
    );
  }
}

// 🎨 PAINTER
class DrawingPainter extends CustomPainter {
  final List<Offset?> points;
  final Color color;
  final double strokeWidth;

  DrawingPainter(this.points, this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}