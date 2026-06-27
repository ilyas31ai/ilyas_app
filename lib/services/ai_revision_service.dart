import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/devoir_model.dart';
import '../models/user_model.dart';
import 'ai_assistant_service.dart';
import 'maitrise_service.dart';
import 'quota_service.dart';

/// Service IA dédié aux révisions basées sur les devoirs professeurs.
/// Principe : l'IA aide à COMPRENDRE, jamais à COPIER.
class AiRevisionService {
  static const _model    = 'claude-haiku-4-5-20251001';
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _cache    = 'ai_rev_v1_';

  // ── Cache ──────────────────────────────────────────────────────────────────

  static Future<String?> _get(String key) async {
    final p = await SharedPreferences.getInstance();
    return p.getString('$_cache$key');
  }

  static Future<void> _set(String key, String val) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('$_cache$key', val);
  }

  // TTL-aware cache: stores {val, ts} JSON; returns null if older than maxAgeHours
  static Future<String?> _getWithTTL(String key, {int maxAgeHours = 24}) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('$_cache$key');
    if (raw == null) return null;
    try {
      final obj = jsonDecode(raw) as Map<String, dynamic>;
      final ts = obj['ts'] as int? ?? 0;
      final ageMs = DateTime.now().millisecondsSinceEpoch - ts;
      if (ageMs > maxAgeHours * 3600000) return null;
      return obj['val'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _setWithTimestamp(String key, String val) async {
    final p = await SharedPreferences.getInstance();
    final data = jsonEncode({
      'val': val,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    await p.setString('$_cache$key', data);
  }

  // ── Rôle utilisateur courant ───────────────────────────────────────────────

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

  // ── Appel API ──────────────────────────────────────────────────────────────

  static Future<String> _call({
    required String system,
    required String user,
    int maxTokens = 700,
  }) async {
    // Vérification quota avant tout appel réseau
    try {
      final role = await _currentRole();
      await QuotaService.checkAndIncrement(role);
    } on QuotaExceededException catch (e) {
      return '⚠️ $e';
    }

    final key = await AiAssistantService.getApiKey();
    if (key == null || key.isEmpty) {
      return '⚠️ Clé API non configurée.\nVa dans Paramètres pour l\'activer.';
    }
    try {
      final resp = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'x-api-key': key,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': maxTokens,
          'system': system,
          'messages': [
            {'role': 'user', 'content': user},
          ],
        }),
      ).timeout(const Duration(seconds: 25));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final content = (data['content'] as List?);
        if (content != null && content.isNotEmpty) {
          return (content.first as Map<String, dynamic>)['text'] as String? ?? '❌ Réponse vide.';
        }
      }
      return '❌ Erreur API (${resp.statusCode}).';
    } catch (e) {
      debugPrint('[AiRevisionService] _call error: $e');
      return '❌ Erreur de connexion.';
    }
  }

  // ── Contexte du devoir ─────────────────────────────────────────────────────

  static String _ctx(DevoirModel d) {
    final sb = StringBuffer()
      ..writeln('Matière : ${d.matiere}')
      ..writeln('Titre   : ${d.titre}');
    if (d.description.isNotEmpty) sb.writeln('Consigne : ${d.description}');
    if (d.questions.isNotEmpty) {
      sb.writeln('\nQuestions du devoir (${d.questions.length}) :');
      for (var i = 0; i < d.questions.length; i++) {
        final q = d.questions[i];
        sb.writeln('Q${i + 1}. ${q.enonce} [${q.type.name}]');
        if (q.choix.isNotEmpty) {
          for (var j = 0; j < q.choix.length; j++) {
            sb.write('   ${String.fromCharCode(65 + j)}. ${q.choix[j]}');
            if (j < q.choix.length - 1) sb.writeln();
          }
          sb.writeln();
        }
      }
    }
    return sb.toString();
  }

  // ── 1. Analyser le devoir ──────────────────────────────────────────────────

  /// Retourne {matiere, chapitre, notions, competences, difficulte, conseils}.
  static Future<Map<String, String>> analyserDevoir(DevoirModel d) async {
    final ck = 'analyse_${d.id}';
    final cached = await _get(ck);
    if (cached != null) {
      try { return Map<String, String>.from(jsonDecode(cached) as Map); } catch (_) {}
    }

    const system = '''Tu es un assistant pédagogique. Analyse ce devoir et réponds UNIQUEMENT en JSON valide.
Format EXACT (sans texte autour) :
{
  "matiere": "...",
  "chapitre": "...",
  "notions": "notion1, notion2, notion3",
  "competences": "comp1, comp2",
  "difficulte": "Facile|Intermédiaire|Avancé",
  "conseils": "Conseil court pour aborder ce devoir."
}''';

    final raw = await _call(system: system, user: _ctx(d), maxTokens: 400);
    try {
      final s = raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final start = s.indexOf('{'), end = s.lastIndexOf('}');
      if (start >= 0 && end > start) {
        final map = (jsonDecode(s.substring(start, end + 1)) as Map)
            .map((k, v) => MapEntry(k.toString(), v.toString()));
        await _set(ck, jsonEncode(map));
        return map;
      }
    } catch (e) {
      debugPrint('[AiRevisionService] analyserDevoir parse error: $e\nraw=$raw');
    }
    return {
      'matiere'     : d.matiere,
      'chapitre'    : 'À identifier',
      'notions'     : 'Voir la consigne du devoir',
      'competences' : 'Analyse, compréhension, application',
      'difficulte'  : 'Intermédiaire',
      'conseils'    : 'Lis attentivement la consigne avant de commencer.',
    };
  }

  // ── 2. Résumé de cours ─────────────────────────────────────────────────────

  static Future<String> genererResume(DevoirModel d) async {
    final ck = 'resume_${d.id}';
    final cached = await _get(ck);
    if (cached != null) return cached;

    final adapt = await MaitriseService.contexteAdaptatif(d.matiere);

    const system = '''Tu es un professeur bienveillant.
À partir de ce devoir, génère un résumé de cours sur les notions abordées.
Si un suivi pédagogique de l'élève est fourni à la fin du message, insiste davantage sur ses notions en difficulté.

Format :
📚 **Résumé du cours**
[2-3 paragraphes clairs]

🔑 **Points essentiels**
• ...
• ...
• ... (3 à 5 points max)

💡 **À retenir**
[1-2 phrases mémo percutantes]

Sois pédagogique, concis (max 250 mots), en français.
NE DONNE PAS la réponse au devoir.''';

    final result = await _call(system: system, user: 'Devoir :\n${_ctx(d)}$adapt', maxTokens: 700);
    if (!result.startsWith('❌') && !result.startsWith('⚠️')) {
      await _set(ck, result);
    }
    return result;
  }

  // ── 3. Exercices similaires ────────────────────────────────────────────────

  static Future<String> genererExercices(DevoirModel d, String niveau) async {
    final ck = 'exo_${d.id}_$niveau';
    final cached = await _get(ck);
    if (cached != null) return cached;

    final adapt = await MaitriseService.contexteAdaptatif(d.matiere);

    final system = '''Tu es un professeur. Génère 2 exercices d'ENTRAÎNEMENT de niveau $niveau
sur les mêmes NOTIONS que ce devoir, mais avec des données DIFFÉRENTES.
Si un suivi pédagogique est fourni, cible prioritairement les notions en difficulté de l'élève.
IMPORTANT : NE reprends PAS les mêmes questions que le devoir.

Format :
**Exercice 1 :**
[énoncé complet]

**Exercice 2 :**
[énoncé complet]

---
**Correction — Exercice 1 :**
[correction détaillée, étape par étape]

**Correction — Exercice 2 :**
[correction détaillée]''';

    final result = await _call(
      system: system,
      user: 'Devoir de référence :\n${_ctx(d)}$adapt',
      maxTokens: 900,
    );
    if (!result.startsWith('❌') && !result.startsWith('⚠️')) {
      await _set(ck, result);
    }
    return result;
  }

  // ── 4. Quiz ────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> genererQuiz(DevoirModel d) async {
    final ck = 'quiz_${d.id}';
    final cached = await _get(ck);
    if (cached != null) {
      try { return List<Map<String, dynamic>>.from(jsonDecode(cached) as List); } catch (_) {}
    }

    final adapt = await MaitriseService.contexteAdaptatif(d.matiere);

    const system = '''Tu es un professeur. Génère 5 questions QCM pour tester la compréhension des NOTIONS de ce devoir.
Si un suivi pédagogique est fourni, pose davantage de questions sur les notions en difficulté (🔴 et 🟡).
Format JSON EXACT (tableau, sans texte autour) :
[
  {
    "q": "Question sur la notion ?",
    "choices": ["A. ...", "B. ...", "C. ...", "D. ..."],
    "answer": 0,
    "explication": "Explication courte de la bonne réponse."
  }
]
- answer = index 0-3 de la bonne réponse
- Questions sur les NOTIONS, pas sur les données exactes du devoir
- NE demande pas la réponse directe au devoir''';

    final raw = await _call(
      system: system,
      user: 'Devoir :\n${_ctx(d)}$adapt',
      maxTokens: 900,
    );

    try {
      final s = raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final start = s.indexOf('['), end = s.lastIndexOf(']');
      if (start >= 0 && end > start) {
        final list = jsonDecode(s.substring(start, end + 1)) as List;
        final quiz = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        await _set(ck, jsonEncode(quiz));
        return quiz;
      }
    } catch (e) {
      debugPrint('[AiRevisionService] genererQuiz parse error: $e');
    }
    return [
      {
        'q': 'Quelle notion principale ce devoir met-il en pratique ?',
        'choices': ['A. Voir le cours', 'B. Relire la consigne', 'C. Demander au prof', 'D. Réessayer'],
        'answer': 1,
        'explication': 'Relis attentivement la consigne et tes notes de cours.',
      },
    ];
  }

  // ── 5. Aide à 4 niveaux ────────────────────────────────────────────────────

  /// niveau : 1=indice, 2=notion du cours, 3=méthode, 4=vérification réponse.
  static Future<String> obtenirAide({
    required DevoirModel devoir,
    required String questionEleve,
    required int niveau,
    String? reponseEleve,
  }) async {
    final instruction = switch (niveau) {
      1 => '''NIVEAU 1 — INDICE.
Donne UN seul indice court (1-2 phrases) qui oriente sans dévoiler ni la méthode, ni la réponse.
Commence par "💡 Indice :"
Sois encourageant.''',
      2 => '''NIVEAU 2 — NOTION DU COURS.
Explique la notion théorique liée à cette question SANS résoudre l'exercice du devoir.
Donne des définitions, des exemples génériques différents du devoir.
Commence par "📚 Notion :"''',
      3 => '''NIVEAU 3 — MÉTHODE.
Explique les étapes générales pour ce TYPE de problème, sans les appliquer aux données du devoir.
Ex : "Pour ce type de problème, on commence par... ensuite... enfin..."
Commence par "🔍 Méthode :"''',
      _ => '''NIVEAU 4 — VÉRIFICATION DU RAISONNEMENT.
Réponse proposée par l'élève : "${reponseEleve ?? '(aucune réponse fournie)'}"

Analyse le RAISONNEMENT (pas juste la réponse finale) :
- Si correct : explique pourquoi le raisonnement est juste, félicite.
- Si incorrect : identifie l'erreur précise, guide vers la correction SANS donner la réponse.
Commence par "✅ Raisonnement :" ou "⚠️ Point à revoir :"''',
    };

    final system = '''Tu es un professeur particulier bienveillant.
RÈGLE ABSOLUE : Ne JAMAIS donner la réponse finale d'un devoir noté.
Tu aides l'élève à COMPRENDRE et à APPRENDRE — jamais à copier.
Matière : ${devoir.matiere}

$instruction

Réponds en français. Sois pédagogique, concis (max 150 mots), encourageant.''';

    final adapt = await MaitriseService.contexteAdaptatif(devoir.matiere);

    final user = 'Contexte du devoir :\n${_ctx(devoir)}'
        '\n\nDifficulté signalée par l\'élève :\n"$questionEleve"'
        '$adapt';

    return await _call(system: system, user: user, maxTokens: 400);
  }

  // ── Vider le cache d'un devoir ─────────────────────────────────────────────

  static Future<void> clearCache(String devoirId) async {
    final p = await SharedPreferences.getInstance();
    for (final k in [
      'analyse_$devoirId',
      'resume_$devoirId',
      'exo_${devoirId}_Facile',
      'exo_${devoirId}_Intermédiaire',
      'exo_${devoirId}_Avancé',
      'quiz_$devoirId',
    ]) {
      await p.remove('$_cache$k');
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // MODE LIBRE — révision par matière sans devoir spécifique
  // ════════════════════════════════════════════════════════════════════════════

  static String _libreKey(String matiere, String categorie) =>
      '${matiere.toLowerCase().replaceAll(' ', '_')}_${categorie.toLowerCase()}';

  // ── L1. Cours libre ────────────────────────────────────────────────────────

  static Future<String> genererCoursLibre({
    required String matiere,
    required String categorie,
    String classeNom = '',
  }) async {
    final ck = 'libre_cours_${_libreKey(matiere, categorie)}';
    final cached = await _get(ck);
    if (cached != null) return cached;

    final adapt = await MaitriseService.contexteAdaptatif(matiere);
    final ctx = 'Matière : $matiere\nNiveau : $categorie${classeNom.isNotEmpty ? " ($classeNom)" : ""}$adapt';

    final system = '''Tu es un professeur expert en $matiere pour le niveau $categorie.
Génère un cours de révision structuré.
Si un suivi pédagogique est fourni, insiste sur les notions en difficulté de l'élève.

Format :
📚 **Programme de $matiere — $categorie**
[Introduction en 1-2 phrases]

🎯 **Notions fondamentales**
• **Notion 1 :** explication claire + exemple
• **Notion 2 :** explication claire + exemple
• **Notion 3 :** ...
(3 à 6 notions selon le niveau)

📝 **Points de méthode**
• Méthode 1
• Méthode 2
• Méthode 3

💡 **À retenir absolument**
[Formule mémo ou phrase clé]

Sois pédagogique, adapté au niveau $categorie, max 300 mots. En français.''';

    final result = await _call(system: system, user: ctx, maxTokens: 800);
    if (!result.startsWith('❌') && !result.startsWith('⚠️')) {
      await _set(ck, result);
    }
    return result;
  }

  // ── L2. Exercices libres ───────────────────────────────────────────────────

  static Future<String> genererExercicesLibres({
    required String matiere,
    required String categorie,
    required String difficulte,
  }) async {
    final ck = 'libre_exo_${_libreKey(matiere, categorie)}_$difficulte';
    final cached = await _get(ck);
    if (cached != null) return cached;

    final adapt = await MaitriseService.contexteAdaptatif(matiere);
    final ctx = 'Matière : $matiere | Niveau : $categorie | Difficulté : $difficulte$adapt';

    final system = '''Tu es un professeur de $matiere pour le niveau $categorie.
Génère 2 exercices d'entraînement de difficulté $difficulte adaptés au programme.
Si un suivi pédagogique est fourni, cible en priorité les notions en difficulté de l'élève.

Format :
**Exercice 1 :**
[énoncé complet et clair]

**Exercice 2 :**
[énoncé complet et clair]

---
**Correction — Exercice 1 :**
[correction détaillée étape par étape, avec explications]

**Correction — Exercice 2 :**
[correction détaillée]

En mode libre tu PEUX donner les solutions complètes — l'objectif est d'apprendre.''';

    final result = await _call(system: system, user: ctx, maxTokens: 900);
    if (!result.startsWith('❌') && !result.startsWith('⚠️')) {
      await _set(ck, result);
    }
    return result;
  }

  // ── L3. Quiz libre ─────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> genererQuizLibre({
    required String matiere,
    required String categorie,
  }) async {
    final ck = 'libre_quiz_${_libreKey(matiere, categorie)}';
    final cached = await _get(ck);
    if (cached != null) {
      try { return List<Map<String, dynamic>>.from(jsonDecode(cached) as List); } catch (_) {}
    }

    final adapt = await MaitriseService.contexteAdaptatif(matiere);
    final ctx   = 'Matière : $matiere | Niveau : $categorie$adapt';

    const system = '''Tu es un professeur. Génère 5 questions QCM variées couvrant les notions du programme.
Si un suivi pédagogique est fourni, pose davantage de questions sur les notions en difficulté (🔴 et 🟡).
Format JSON EXACT (tableau, sans texte autour) :
[
  {
    "q": "Question ?",
    "choices": ["A. ...", "B. ...", "C. ...", "D. ..."],
    "answer": 0,
    "explication": "Explication de la bonne réponse."
  }
]
- answer = index 0-3
- Questions progressives (facile → difficile)
- Couvre des notions variées du programme''';

    final raw = await _call(system: system, user: ctx, maxTokens: 900);
    try {
      final s = raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final start = s.indexOf('['), end = s.lastIndexOf(']');
      if (start >= 0 && end > start) {
        final list = jsonDecode(s.substring(start, end + 1)) as List;
        final quiz = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        await _set(ck, jsonEncode(quiz));
        return quiz;
      }
    } catch (e) {
      debugPrint('[AiRevisionService] genererQuizLibre parse error: $e');
    }
    return [
      {
        'q': 'Qu\'est-ce que l\'IA a du mal à analyser ici ?',
        'choices': ['A. Le contenu', 'B. Le niveau', 'C. La connexion', 'D. La clé API'],
        'answer': 3,
        'explication': 'Vérifie ta clé API dans les paramètres.',
      },
    ];
  }

  // ── L4. Aide libre à 4 niveaux ─────────────────────────────────────────────

  /// En mode libre : l'IA peut enseigner librement, corriger complètement
  /// des exercices d'entraînement, mais garde une approche pédagogique.
  /// niveau : 1=indice, 2=explication notion, 3=méthode, 4=vérification réponse.
  static Future<String> obtenirAideLibre({
    required String matiere,
    required String categorie,
    required String questionEleve,
    required int niveau,
    String? reponseEleve,
  }) async {
    final instruction = switch (niveau) {
      1 => '''NIVEAU 1 — INDICE.
Donne un indice court (1-2 phrases) qui oriente l'élève sans lui mâcher le travail.
L'élève doit encore chercher et réfléchir.
Commence par "💡 Indice :"''',
      2 => '''NIVEAU 2 — EXPLICATION DE LA NOTION.
Explique la notion ou le concept de façon claire avec :
- définition précise
- exemple concret adapté au niveau $categorie
- contre-exemple si utile
Commence par "📚 Notion :"''',
      3 => '''NIVEAU 3 — MÉTHODE PAS À PAS.
Explique la méthode générale pour résoudre ce type de problème en $matiere.
Détaille chaque étape. En mode libre tu peux être complet.
Commence par "🔍 Méthode :"''',
      _ => '''NIVEAU 4 — VÉRIFICATION ET CORRECTION.
Réponse de l'élève : "${reponseEleve ?? '(aucune réponse fournie)'}"

En mode libre (exercice d'entraînement, pas un devoir noté) :
- Analyse le raisonnement de l'élève
- Si correct : valide et explique pourquoi c'est juste
- Si incorrect : explique l'erreur précisément et donne la correction complète
- Ajoute un conseil pour ne pas refaire cette erreur
Commence par "✅ Correction :" ou "⚠️ À corriger :"''',
    };

    final system = '''Tu es un professeur particulier bienveillant et expert en $matiere, niveau $categorie.
Mode : RÉVISION LIBRE (pas un devoir noté — tu peux enseigner et corriger librement).
Objectif : que l'élève COMPRENNE et APPRENNE.

$instruction

Réponds en français. Sois pédagogique, encourageant, max 200 mots.''';

    final adapt = await MaitriseService.contexteAdaptatif(matiere);
    final user  = 'Question/difficulté de l\'élève en $matiere :\n"$questionEleve"$adapt';
    return await _call(system: system, user: user, maxTokens: 500);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ÉVALUATION PÉDAGOGIQUE — identifie les notions et leur niveau de maîtrise
  // ════════════════════════════════════════════════════════════════════════════

  /// Analyse les résultats d'un quiz et retourne les notions identifiées avec
  /// un score de maîtrise par notion (0-100).
  ///
  /// [questions] : liste de {q, choices, answer, explication}
  /// [resultatEleve] : true = bonne réponse, pour chaque question dans l'ordre
  static Future<List<Map<String, dynamic>>> evaluerNotions({
    required String matiere,
    required String categorie,
    required List<Map<String, dynamic>> questions,
    required List<bool> resultatEleve,
  }) async {
    if (questions.isEmpty) return [];

    final totalCorrect = resultatEleve.where((r) => r).length;
    final scoreGlobal  = questions.isEmpty ? 0 : (totalCorrect * 100 ~/ questions.length);

    final sb = StringBuffer(
      'Quiz en $matiere, niveau $categorie.\n'
      'Score global : $totalCorrect/${questions.length} ($scoreGlobal%)\n\n'
      'Détail des questions :\n',
    );
    for (var i = 0; i < questions.length; i++) {
      final correct = i < resultatEleve.length ? resultatEleve[i] : false;
      sb.writeln('Q${i + 1}: "${questions[i]['q']}" → ${correct ? "✓ Correcte" : "✗ Incorrecte"}');
    }

    const system = '''Tu es un évaluateur pédagogique expert.
Analyse ces résultats de quiz et identifie les NOTIONS SPÉCIFIQUES testées.

RÈGLES :
- Identifie 2 à 4 notions précises (pas juste la matière générale)
- Exemple : "Fractions — addition" plutôt que "Mathématiques"
- Score par notion : 0-100 selon les questions qui la testent
- Si plusieurs questions testent la même notion, fais la moyenne
- erreurs : liste courte des erreurs observées (tableau vide si score ≥ 70)
- id : slug court en minuscules, lettres et _ uniquement (ex: "fractions_addition")

Réponds UNIQUEMENT en JSON valide, sans texte autour :
{"notions": [{"id": "slug", "label": "Label lisible", "score": 75, "erreurs": []}]}''';

    final raw = await _call(system: system, user: sb.toString(), maxTokens: 400);
    try {
      final s     = raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final start = s.indexOf('{'), end = s.lastIndexOf('}');
      if (start >= 0 && end > start) {
        final data   = jsonDecode(s.substring(start, end + 1)) as Map;
        final notions = data['notions'] as List? ?? [];
        return notions.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[AiRevisionService] evaluerNotions parse error: $e\nraw=$raw');
    }
    // Fallback : une notion par matière avec le score global
    final slug = matiere.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return [{'id': slug, 'label': matiere, 'score': scoreGlobal, 'erreurs': <String>[]}];
  }

  // ── Recommandations pédagogiques pour le professeur ───────────────────────

  /// Génère des recommandations actionnables pour le professeur à partir
  /// des statistiques de révision IA de la classe pour une matière donnée.
  ///
  /// [statsEleves] : liste de maps avec nom, total, maitrise, enCours,
  ///                 aRetravailler, alertes (liste de strings)
  static Future<String> genererRecommandationsProfesseur({
    required String matiere,
    required String classeNom,
    required List<Map<String, dynamic>> statsEleves,
    bool forceRefresh = false,
  }) async {
    if (statsEleves.isEmpty) return '⚠️ Aucun élève n\'a encore utilisé les révisions IA pour cette matière.';

    final ck = 'reco_${classeNom}_$matiere';
    if (!forceRefresh) {
      final cached = await _getWithTTL(ck, maxAgeHours: 24);
      if (cached != null) return cached;
    }

    final sb = StringBuffer();
    sb.writeln('Classe : $classeNom | Matière : $matiere');
    sb.writeln('Données de révision IA — ${statsEleves.length} élève(s) actif(s) :');
    sb.writeln();
    for (final e in statsEleves) {
      final nom      = e['nom']           as String? ?? 'Élève';
      final total    = e['total']         as int?    ?? 0;
      final maitrise = e['maitrise']      as int?    ?? 0;
      final enCours  = e['enCours']       as int?    ?? 0;
      final aRetrav  = e['aRetravailler'] as int?    ?? 0;
      final alertes  = e['alertes']       as List?   ?? [];
      sb.writeln('• $nom : 🟢$maitrise 🟡$enCours 🔴$aRetrav / $total notions');
      if (alertes.isNotEmpty) {
        sb.writeln('  Difficultés : ${alertes.take(3).join(', ')}');
      }
    }

    const system = '''Tu es un conseiller pédagogique expert.
Sur la base des données de révision IA de la classe, génère des recommandations concrètes et actionnables pour le professeur.

Format EXACT :
📌 **Synthèse**
[1-2 phrases sur l'état de la classe]

🔴 **Notions à reprendre en classe entière**
• [notion — raison courte]

👤 **Élèves à accompagner individuellement**
• [prénom/nom] : [difficultés spécifiques]

💡 **Activités suggérées**
• [activité adaptée aux difficultés détectées]

Sois précis, concis, actionnable. Max 250 mots. Réponds en français.''';

    final result = await _call(system: system, user: sb.toString(), maxTokens: 600);
    await _setWithTimestamp('reco_${classeNom}_$matiere', result);
    return result;
  }

  // ── L5. Fiche de révision ──────────────────────────────────────────────────

  static Future<String> genererFicheRevision({
    required String matiere,
    required String categorie,
    String classeNom = '',
    String sujet = '',
  }) async {
    final extra = sujet.isNotEmpty ? '_${sujet.replaceAll(' ', '_')}' : '';
    final ck = 'libre_fiche_${_libreKey(matiere, categorie)}$extra';
    final cached = await _get(ck);
    if (cached != null) return cached;

    final adapt = await MaitriseService.contexteAdaptatif(matiere);
    final ctx = 'Matière : $matiere | Niveau : $categorie'
        '${classeNom.isNotEmpty ? " ($classeNom)" : ""}'
        '${sujet.isNotEmpty ? " | Sujet : $sujet" : ""}$adapt';

    final system = '''Tu es un professeur expert. Génère une fiche de révision synthétique et visuelle.
Si un suivi pédagogique est fourni, mets en avant les notions en difficulté.

Format EXACT :
📋 **FICHE DE RÉVISION — $matiere ($categorie)**
${sujet.isNotEmpty ? "📌 Sujet : $sujet\n" : ""}
━━━ DÉFINITIONS CLÉS ━━━
• **Terme 1** : définition claire
• **Terme 2** : définition claire
• **Terme 3** : définition claire
(3 à 6 définitions essentielles)

━━━ FORMULES / RÈGLES ━━━
• Formule ou règle 1
• Formule ou règle 2
• Formule ou règle 3

━━━ MÉTHODE EN 3 ÉTAPES ━━━
① Étape 1 — [action + explication]
② Étape 2 — [action + explication]
③ Étape 3 — [action + explication]

━━━ PIÈGE À ÉVITER ━━━
⚠️ [L'erreur la plus fréquente et comment l'éviter]

━━━ LE PLUS IMPORTANT ━━━
⭐ [1 phrase mémo percutante]

Max 280 mots. En français. Pédagogique et concis.''';

    final result = await _call(system: system, user: ctx, maxTokens: 800);
    if (!result.startsWith('❌') && !result.startsWith('⚠️')) {
      await _set(ck, result);
    }
    return result;
  }

  // ── L6. Flashcards ─────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> genererFlashcardsLibres({
    required String matiere,
    required String categorie,
  }) async {
    final ck = 'libre_flashcards_${_libreKey(matiere, categorie)}';
    final cached = await _get(ck);
    if (cached != null) {
      try { return List<Map<String, dynamic>>.from(jsonDecode(cached) as List); } catch (_) {}
    }

    final adapt = await MaitriseService.contexteAdaptatif(matiere);
    final ctx   = 'Matière : $matiere | Niveau : $categorie$adapt';

    const system = '''Tu es un professeur. Génère 8 flashcards (question/réponse) sur les notions clés.
Si un suivi pédagogique est fourni, cible les notions en difficulté.
Format JSON EXACT (tableau, sans texte autour) :
[
  {
    "front": "Question ou notion à définir ?",
    "back": "Réponse concise ou définition (max 2 lignes)",
    "theme": "sous-thème ou chapitre"
  }
]
- Variété : définitions, formules, exemples, méthodes
- Progressif : du plus simple au plus complexe
- 8 flashcards minimum''';

    final raw = await _call(system: system, user: ctx, maxTokens: 900);
    try {
      final s = raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final start = s.indexOf('['), end = s.lastIndexOf(']');
      if (start >= 0 && end > start) {
        final list = jsonDecode(s.substring(start, end + 1)) as List;
        final cards = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        await _set(ck, jsonEncode(cards));
        return cards;
      }
    } catch (e) {
      debugPrint('[AiRevisionService] genererFlashcardsLibres parse error: $e');
    }
    return [
      {'front': 'Notion principale de $matiere ?', 'back': 'Voir ton cours.', 'theme': matiere},
    ];
  }

  // ── L7. Sujet type BAC (Lycée) ─────────────────────────────────────────────

  static Future<String> genererSujetBac({
    required String matiere,
    String specialite = '',
    String niveau = 'Terminale',
  }) async {
    final ck = 'bac_${matiere.replaceAll(' ', '_')}_${niveau.replaceAll(' ', '_')}';
    final cached = await _get(ck);
    if (cached != null) return cached;

    final ctx = 'Matière : $matiere | Niveau : $niveau'
        '${specialite.isNotEmpty ? " | Spécialité : $specialite" : ""}';

    final system = '''Tu es un professeur qui prépare ses élèves au BAC.
Génère un sujet d'entraînement type BAC pour la matière $matiere.

Format :
🎓 **SUJET TYPE BAC — $matiere${specialite.isNotEmpty ? " (Spécialité)" : ""}**
📌 Durée : [durée habituelle] | Coefficient : [coeff indicatif]

**DOCUMENT / TEXTE D'APPUI** (si pertinent)
[texte, données ou situation de départ]

**Partie I — [Intitulé]** ([barème])
Question 1 : ...
Question 2 : ...

**Partie II — [Intitulé]** ([barème])
Question 1 : ...
Question 2 : ...

**Partie III — [Sujet de synthèse/dissertation/résolution]** ([barème])
[sujet complet]

---
🔑 **ÉLÉMENTS DE CORRECTION (Partie I)**
[correction détaillée, pas de copier-coller — guider l'élève]

Adapte le niveau Terminale, sois fidèle au format BAC.''';

    final result = await _call(system: system, user: ctx, maxTokens: 1200);
    if (!result.startsWith('❌') && !result.startsWith('⚠️')) {
      await _set(ck, result);
    }
    return result;
  }

  // ── L8. Préparation Grand Oral (Lycée Terminale) ───────────────────────────

  static Future<String> preparationGrandOral({
    required String specialite,
    String sujet = '',
  }) async {
    final ck = 'grandoral_${specialite.replaceAll(' ', '_')}';
    final cached = await _get(ck);
    if (cached != null) return cached;

    final ctx = 'Spécialité : $specialite'
        '${sujet.isNotEmpty ? " | Sujet envisagé : $sujet" : ""}';

    final system = '''Tu es un coach pour le Grand Oral du BAC.
Prépare l'élève au Grand Oral de sa spécialité.

Format :
🎤 **PRÉPARATION AU GRAND ORAL — $specialite**

**📚 Rappel des attentes du jury**
• ...

**💡 Sujets de Grand Oral recommandés en $specialite**
1. [sujet avec angle de questionnement]
2. [sujet avec angle de questionnement]
3. [sujet avec angle de questionnement]

**📝 Structure recommandée (20 min)**
• 5 min — Exposé libre
  - Introduction (accroche + problématique)
  - Développement (2-3 axes)
  - Conclusion
• 10 min — Questions du jury
  - Attendus typiques
  - Comment répondre aux contre-arguments
• 5 min — Question sur le projet d'orientation

**⭐ Conseils clés**
• ...

**🔑 Vocabulaire spécifique à maîtriser**
• ...

Sois concret, pratique et encourageant. Max 350 mots.''';

    final result = await _call(system: system, user: ctx, maxTokens: 1000);
    if (!result.startsWith('❌') && !result.startsWith('⚠️')) {
      await _set(ck, result);
    }
    return result;
  }

  // ── L9. Préparation partiel / examen (Université) ─────────────────────────

  static Future<String> preparerPartiel({
    required String ue,
    required String niveau,
    String semestre = '',
  }) async {
    final ck = 'partiel_${ue.replaceAll(' ', '_')}_$niveau';
    final cached = await _get(ck);
    if (cached != null) return cached;

    final ctx = 'UE : $ue | Niveau : $niveau'
        '${semestre.isNotEmpty ? " | Semestre : $semestre" : ""}';

    final system = '''Tu es un tuteur universitaire expert.
Prépare l'étudiant au partiel / examen de l'UE indiquée.

Format :
🎓 **PRÉPARATION PARTIEL — $ue ($niveau)**
${semestre.isNotEmpty ? "📅 Semestre : $semestre\n" : ""}
**📋 Programme essentiel à maîtriser**
• Chapitre/thème 1 : [notions clés]
• Chapitre/thème 2 : [notions clés]
• Chapitre/thème 3 : [notions clés]

**📝 Types d'exercices typiques**
• [type d'exercice 1 + conseil]
• [type d'exercice 2 + conseil]

**⚡ Points critiques souvent mal maîtrisés**
• ...

**📅 Plan de révision 7 jours avant l'examen**
J-7 : ...
J-5 : ...
J-3 : ...
J-1 : ...

**💡 Conseils le jour J**
• ...

Max 350 mots. En français. Pratique et orienté résultat.''';

    final result = await _call(system: system, user: ctx, maxTokens: 1000);
    if (!result.startsWith('❌') && !result.startsWith('⚠️')) {
      await _set(ck, result);
    }
    return result;
  }

  // ── L10. Assistant IA scolaire — réponse libre ─────────────────────────────

  static Future<String> repondreQuestion({
    required String question,
    required String matiere,
    required String categorie,
  }) async {
    final adapt = await MaitriseService.contexteAdaptatif(matiere);
    final system = '''Tu es un assistant pédagogique bienveillant et expert.
Matière : $matiere | Niveau : $categorie

Réponds à la question de l'élève de façon :
- Claire et structurée
- Adaptée au niveau $categorie
- Avec des exemples concrets si utile
- En encourageant l'élève à comprendre, pas à mémoriser bêtement

Si la question porte sur un exercice ou un devoir noté : guide sans donner la réponse finale.
Si c'est une question de cours : réponds complètement.

Réponds en français. Max 300 mots.''';

    final user = 'Question de l\'élève :\n"$question"'
        '${adapt.isNotEmpty ? "\n\nContexte pédagogique :$adapt" : ""}';

    return await _call(system: system, user: user, maxTokens: 700);
  }

  // ── Vider le cache libre d'une matière ────────────────────────────────────

  static Future<void> clearCacheLibre(String matiere, String categorie) async {
    final p = await SharedPreferences.getInstance();
    final k = _libreKey(matiere, categorie);
    for (final suffix in [
      'cours_$k', 'exo_${k}_Facile', 'exo_${k}_Intermédiaire',
      'exo_${k}_Avancé', 'quiz_$k', 'fiche_$k', 'flashcards_$k',
    ]) {
      await p.remove('${_cache}libre_$suffix');
    }
  }
}
