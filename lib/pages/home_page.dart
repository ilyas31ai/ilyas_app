import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // 🔘 BOUTON
  Widget buildButton(
    BuildContext context,
    String title,
    IconData icon,
    String route,
    List<Color> colors,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),

      onTap: () {
        if (route == '/discussion') {
          Navigator.pushNamed(
            context,
            '/discussion',
            arguments: {
              'name': 'general',
              'user': FirebaseAuth.instance.currentUser?.email ?? '',
            },
          );
        } else {
          Navigator.pushNamed(context, route);
        }
      },

      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),

        padding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 20,
        ),

        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),

          borderRadius: BorderRadius.circular(30),

          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),

        child: Row(
          children: [
            Icon(icon, color: Colors.white),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),

      appBar: AppBar(
        title: const Text("ILYAS31AI"),

        backgroundColor: Colors.transparent,

        elevation: 0,

        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications,
              color: Colors.white,
            ),

            onPressed: () {
              Navigator.pushNamed(
                context,
                '/notifications',
              );
            },
          ),

          IconButton(
            icon: const Icon(
              Icons.logout,
              color: Colors.white,
            ),

            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),

      body: Container(
        width: double.infinity,

        padding: const EdgeInsets.all(20),

        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color(0xFF2C5364),
            ],

            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 10),

              // 🔷 LOGO
              Image.asset(
                'assets/logo.png',
                height: 90,
              ),

              const SizedBox(height: 10),

              const Text(
                "ILYAS31AI",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const Text(
                "Bienvenue 👋",
                style: TextStyle(
                  color: Colors.white70,
                ),
              ),

              const SizedBox(height: 30),

              buildButton(
                context,
                "Espace Élèves",
                Icons.school,
                '/eleves',
                [
                  Colors.blue,
                  Colors.blueAccent,
                ],
              ),

              buildButton(
                context,
                "Professeurs",
                Icons.person,
                '/professeurs',
                [
                  Colors.orange,
                  Colors.deepOrange,
                ],
              ),

              buildButton(
                context,
                "Discussion",
                Icons.chat,
                '/discussion',
                [
                  Colors.purple,
                  Colors.deepPurple,
                ],
              ),

              buildButton(
                context,
                "Contacts",
                Icons.people,
                '/users',
                [
                  Colors.green,
                  Colors.teal,
                ],
              ),

              buildButton(
                context,
                "Chat IA",
                Icons.smart_toy,
                '/chat',
                [
                  Colors.indigo,
                  Colors.deepPurple,
                ],
              ),

              buildButton(
                context,
                "Scan devoirs",
                Icons.camera_alt,
                '/scan',
                [
                  Colors.teal,
                  Colors.green,
                ],
              ),

              buildButton(
                context,
                "Monde Enfants",
                Icons.child_care,
                '/monde_enfants',
                [
                  Colors.pink,
                  Colors.purpleAccent,
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}