import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
        // Le rôle n'est plus auto-déclarable : seul "élève" peut s'inscrire
        // librement (détection automatique de "parent" par email côté
        // serveur). Professeur/Direction sont attribués manuellement
        // jusqu'à l'écran d'administration des comptes (Phase 3).
        await UserService.syncProfile();
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = "Email déjà utilisé";
          break;
        case 'invalid-email':
          msg = "Email invalide";
          break;
        case 'weak-password':
          msg = "Mot de passe trop faible (min 6 caractères)";
          break;
        case 'user-not-found':
          msg = "Compte introuvable — vérifiez l'email";
          break;
        case 'wrong-password':
          msg = "Mot de passe incorrect";
          break;
        case 'invalid-credential':
          msg = "Email ou mot de passe incorrect [invalid-credential]";
          break;
        case 'too-many-requests':
          msg = "Trop de tentatives — réessayez plus tard";
          break;
        case 'network-request-failed':
          msg = "Pas de connexion réseau";
          break;
        default:
          msg = "[${e.code}] ${e.message ?? 'Erreur inconnue'}";
      }
      showMsg(msg, duration: const Duration(seconds: 8));
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
      showMsg(
        "Email de réinitialisation envoyé à $mail — vérifiez Spam/Junk et l'onglet \"Autres\" Outlook",
        duration: const Duration(seconds: 10),
      );
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = "Aucun compte trouvé pour cet email";
          break;
        case 'invalid-email':
          msg = "Email invalide";
          break;
        case 'too-many-requests':
          msg = "Trop de tentatives — réessayez plus tard";
          break;
        default:
          msg = "[${e.code}] ${e.message ?? 'Erreur'}";
      }
      showMsg(msg, duration: const Duration(seconds: 8));
    } catch (e) {
      showMsg("Erreur: $e");
    }
  }

  void showMsg(String text, {Duration duration = const Duration(seconds: 4)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: duration),
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