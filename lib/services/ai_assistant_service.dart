import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import 'quota_service.dart';

class AiAssistantService {
  static const _keyPref     = 'anthropic_api_key';
  // Nom de la clé dans le keystore sécurisé (différent pour éviter collision)
  static const _keySecure   = 'anthropic_api_key_secure';
  static const _model       = 'claude-haiku-4-5-20251001';
  static const _endpoint    = 'https://api.anthropic.com/v1/messages';

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ── Lecture / écriture sécurisées ─────────────────────────────────────────

  static Future<String?> getApiKey() async {
    // Priorité : keystore sécurisé
    try {
      final key = await _secure.read(key: _keySecure);
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}

    // Fallback + migration : SharedPreferences (anciens appareils / premier lancement)
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_keyPref);
      if (legacy != null && legacy.isNotEmpty) {
        // Migrer silencieusement vers le stockage sécurisé
        await _migrateToSecure(legacy, prefs);
        return legacy;
      }
    } catch (_) {}

    return null;
  }

  static Future<void> setApiKey(String key) async {
    final trimmed = key.trim();
    // Écriture dans le keystore sécurisé
    await _secure.write(key: _keySecure, value: trimmed);
    // Supprimer l'ancienne valeur en clair si elle existe encore
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPref);
    } catch (_) {}
  }

  static Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Migration silencieuse depuis SharedPreferences → secure storage.
  static Future<void> _migrateToSecure(
      String key, SharedPreferences prefs) async {
    try {
      await _secure.write(key: _keySecure, value: key);
      await prefs.remove(_keyPref);
    } catch (_) {}
  }

  // ── Rôle courant ──────────────────────────────────────────────────────────

  static Future<UserRole> _currentRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return UserRole.eleve;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      return UserRoleX.fromString(snap.data()?['role'] as String?);
    } catch (_) {
      return UserRole.eleve;
    }
  }

  // ── Hints pédagogiques à 3 niveaux ───────────────────────────────────────

  /// [niveau] 1 = indice, 2 = méthode, 3 = résolution guidée
  static Future<String> getHint({
    required String enonce,
    required String matiere,
    required int niveau,
    String classeNom = '',
    String? reponseEleve,
  }) async {
    try {
      final role = await _currentRole();
      await QuotaService.checkAndIncrement(role);
    } on QuotaExceededException catch (e) {
      return '⚠️ $e';
    }

    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) return _fallbackHint(niveau);

    final niveauInstr = switch (niveau) {
      1 => 'Donne UNIQUEMENT un bref indice (1-2 phrases max) qui oriente '
          "l'élève sans révéler la réponse. Commence par \"💡 Indice :\".",
      2 => 'Explique la MÉTHODE à utiliser (3-5 phrases), sans donner '
          "la réponse finale. Commence par \"🔍 Méthode :\".",
      _ => "Guide l'élève pas à pas avec des questions progressives. "
          "Ne donne jamais la réponse directement. "
          "Commence par \"🎯 Résolution guidée :\".",
    };

    final system =
        "Tu es un assistant pédagogique bienveillant pour des élèves"
        "${classeNom.isNotEmpty ? ' de $classeNom' : ''}. "
        "Matière : $matiere. "
        "Tu dois AIDER à comprendre, JAMAIS donner la réponse directement. "
        "Réponds en français. Sois concis et encourageant.";

    final user = 'Question du devoir : "$enonce"'
        '${reponseEleve != null && reponseEleve.isNotEmpty ? '\n\nRéponse actuelle : "$reponseEleve"' : ''}'
        '\n\n$niveauInstr';

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'max_tokens': 300,
              'system': system,
              'messages': [
                {'role': 'user', 'content': user},
              ],
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content = data['content'] as List?;
        if (content != null && content.isNotEmpty) {
          return (content.first as Map<String, dynamic>)['text'] as String? ??
              _fallbackHint(niveau);
        }
      }
      return _fallbackHint(niveau);
    } catch (_) {
      return _fallbackHint(niveau);
    }
  }

  // ── Explication de notion ─────────────────────────────────────────────────

  static Future<String> expliquerNotion({
    required String notion,
    required String matiere,
    String classeNom = '',
  }) async {
    try {
      final role = await _currentRole();
      await QuotaService.checkAndIncrement(role);
    } on QuotaExceededException catch (e) {
      return '⚠️ $e';
    }

    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return '💡 Configure la clé API dans les paramètres pour activer '
          "l'assistant IA.";
    }

    final system =
        "Tu es un professeur expert et bienveillant pour des élèves"
        "${classeNom.isNotEmpty ? ' de $classeNom' : ''}. "
        "Matière : $matiere. "
        "Explique clairement, avec des exemples simples. "
        "Réponds en français. Sois pédagogique et concis (max 200 mots).";

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'max_tokens': 400,
              'system': system,
              'messages': [
                {
                  'role': 'user',
                  'content': 'Explique-moi la notion suivante : "$notion"',
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content = data['content'] as List?;
        if (content != null && content.isNotEmpty) {
          return (content.first as Map<String, dynamic>)['text'] as String? ??
              '❌ Réponse invalide.';
        }
      }
      return '❌ Erreur API (${response.statusCode}).';
    } catch (_) {
      return '❌ Erreur de connexion.';
    }
  }

  // ── Fallback sans clé ─────────────────────────────────────────────────────

  static String _fallbackHint(int niveau) {
    switch (niveau) {
      case 1:
        return "💡 Indice : Relis l'énoncé attentivement et identifie "
            'les mots-clés importants.';
      case 2:
        return '🔍 Méthode : Décompose le problème en petites étapes. '
            'Commence par ce que tu sais, puis progresse.';
      default:
        return "🎯 Résolution guidée : Quel est l'objectif ? "
            "Quelles informations as-tu déjà ? "
            "Essaie d'avancer étape par étape.";
    }
  }
}
