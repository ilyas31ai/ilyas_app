import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();

  bool isLogin = true;
  bool loading = false;
  UserRole _selectedRole = UserRole.eleve;

  // 🔐 LOGIN / SIGNUP
  void submit() async {
    final mail = email.text.trim();
    final pass = password.text.trim();

    if (mail.isEmpty || pass.isEmpty) {
      showMsg("Remplis tous les champs");
      return;
    }

    if (!mail.contains("@") || !mail.contains(".")) {
      showMsg("Email invalide");
      return;
    }

    if (pass.length < 6) {
      showMsg("Mot de passe trop court (min 6)");
      return;
    }

    setState(() => loading = true);

    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: mail,
          password: pass,
        );
        await UserService.syncProfile();
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: mail,
          password: pass,
        );
        await UserService.syncProfile(role: _selectedRole);
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Erreur";

      switch (e.code) {
        case 'email-already-in-use':
          msg = "Email déjà utilisé";
          break;
        case 'invalid-email':
          msg = "Email invalide";
          break;
        case 'weak-password':
          msg = "Mot de passe trop faible";
          break;
        case 'user-not-found':
          msg = "Utilisateur introuvable";
          break;
        case 'wrong-password':
          msg = "Mot de passe incorrect";
          break;
        default:
          msg = e.message ?? "Erreur inconnue";
      }

      showMsg(msg);
    } catch (e) {
      showMsg("Erreur: $e");
    }

    if (mounted) setState(() => loading = false);
  }

  // 🔁 RESET PASSWORD
  void resetPassword() async {
    final mail = email.text.trim();

    if (mail.isEmpty) {
      showMsg("Entre ton email d'abord");
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: mail);
      showMsg("Email envoyé 📩");
    } on FirebaseAuthException catch (e) {
      showMsg(e.message ?? "Erreur");
    }
  }

  void showMsg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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

        // 🔥 IMPORTANT (évite overflow clavier)
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 80),

              // 🔷 LOGO
              Image.asset("assets/logo.png", height: 80),

              const SizedBox(height: 30),

              // 📧 EMAIL
              TextField(
                controller: email,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Email",
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // 🔑 PASSWORD
              TextField(
                controller: password,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Mot de passe",
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // 🎭 ROLE SELECTOR (signup only)
              if (!isLogin) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UserRole>(
                      value: _selectedRole,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF203A43),
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      items: [
                        DropdownMenuItem(
                          value: UserRole.eleve,
                          child: Row(children: [
                            const Icon(Icons.school_outlined,
                                color: Colors.white54, size: 18),
                            const SizedBox(width: 8),
                            const Text('Élève'),
                          ]),
                        ),
                        DropdownMenuItem(
                          value: UserRole.professeur,
                          child: Row(children: [
                            const Icon(Icons.person_outline,
                                color: Colors.white54, size: 18),
                            const SizedBox(width: 8),
                            const Text('Professeur'),
                          ]),
                        ),
                      ],
                      onChanged: (r) {
                        if (r != null) setState(() => _selectedRole = r);
                      },
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // 🔁 RESET PASSWORD
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: resetPassword,
                  child: const Text(
                    "Mot de passe oublié ?",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // 🔘 BUTTON
              ElevatedButton(
                onPressed: loading ? null : submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(isLogin ? "Connexion" : "Créer compte"),
              ),

              const SizedBox(height: 10),

              // 🔁 SWITCH
              TextButton(
                onPressed: () {
                  setState(() => isLogin = !isLogin);
                },
                child: Text(
                  isLogin
                      ? "Créer un compte"
                      : "Déjà un compte ?",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}