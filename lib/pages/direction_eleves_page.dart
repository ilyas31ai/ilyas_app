import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/classe_model.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

/// Hiérarchie scolaire : catégorie → niveaux.
const Map<String, List<String>> _kNiveauxParCategorie = {
  'Maternelle': ['PS', 'MS', 'GS'],
  'Primaire':   ['CP', 'CE1', 'CE2', 'CM1', 'CM2'],
  'Collège':    ['6e', '5e', '4e', '3e'],
  'Lycée':      ['Seconde', 'Première', 'Terminale'],
  'Université': ['L1', 'L2', 'L3', 'M1', 'M2', 'Doctorat'],
};

/// Liste tous les élèves (users.role == eleve) et permet à la Direction
/// d'affecter ou de changer leur classe.
class DirectionElevesPage extends StatefulWidget {
  const DirectionElevesPage({super.key});

  @override
  State<DirectionElevesPage> createState() => _DirectionElevesPageState();
}

class _DirectionElevesPageState extends State<DirectionElevesPage> {
  String? _filtreCategorie;
  bool _repairing = false;

  // ── Création d'un compte élève ──────────────────────────────────────────────

  Future<void> _showAddEleveDialog(BuildContext context) async {
    final prenomCtrl = TextEditingController();
    final nomCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final adresseCtrl = TextEditingController();
    final telephoneCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();
    bool pwdVisible = false;
    bool sendReset = true;
    String? selectedCategorie;
    ClasseModel? selectedClasse;
    bool busy = false;

    // Charger toutes les classes avant d'ouvrir la dialog
    List<ClasseModel> allClasses = [];
    bool loadFailed = false;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('classes')
          .orderBy('nom')
          .get();
      allClasses = snap.docs.map(ClasseModel.fromFirestore).toList();
    } catch (e) {
      debugPrint('[DirectionEleves] chargement classes ERROR: $e');
      loadFailed = true;
    }

    if (!mounted) return;
    if (loadFailed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Impossible de charger les classes. Vérifiez votre connexion.'),
        backgroundColor: Color(0xFFDC2626),
      ));
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          // Classes filtrées par catégorie — fallback local si Firestore est vide
          final filteredClasses = () {
            if (selectedCategorie == null) return <ClasseModel>[];
            final niveaux = _kNiveauxParCategorie[selectedCategorie!] ?? [];
            final fromFirestore = allClasses
                .where((c) => niveaux
                    .any((n) => n.toLowerCase() == c.niveau.toLowerCase()))
                .toList();
            if (fromFirestore.isNotEmpty) return fromFirestore;
            // Aucune classe Firestore → entrées locales (id vide)
            return niveaux
                .map((n) => ClasseModel(
                      id: '',
                      nom: n,
                      niveau: n,
                      professeurId: '',
                      eleveIds: const [],
                      anneeScol: DateTime.now().year,
                    ))
                .toList();
          }();

          return AlertDialog(
            backgroundColor: const Color(0xFF161B22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Ajouter un élève',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Identité ──────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                          child: _dialogField(prenomCtrl, 'Prénom',
                              Icons.person_outline, TextInputType.text)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _dialogField(nomCtrl, 'Nom',
                              Icons.person_outline, TextInputType.text)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _dialogField(emailCtrl, 'Adresse email', Icons.email_outlined, TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _dialogField(adresseCtrl, 'Adresse (optionnel)',
                      Icons.home_outlined, TextInputType.streetAddress),
                  const SizedBox(height: 12),
                  _dialogField(telephoneCtrl, 'Numéro de téléphone (optionnel)',
                      Icons.phone_outlined, TextInputType.phone),
                  const SizedBox(height: 12),
                  // ── Mot de passe ──────────────────────────────────────────
                  TextField(
                    controller: pwdCtrl,
                    obscureText: !pwdVisible,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Mot de passe temporaire',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.white38, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          pwdVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: Colors.white38, size: 18,
                        ),
                        onPressed: () => setDlg(() => pwdVisible = !pwdVisible),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0D1117),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF2563EB))),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── Étape 1 : Catégorie ───────────────────────────────────
                  const Text('Scolarité', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 6),
                  _styledDropdown<String>(
                    value: selectedCategorie,
                    hint: 'Catégorie (Maternelle, Primaire…)',
                    items: _kNiveauxParCategorie.keys
                        .map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat,
                                  style: const TextStyle(color: Colors.white, fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) => setDlg(() {
                      selectedCategorie = v;
                      selectedClasse = null; // réinitialise la classe
                    }),
                  ),
                  // ── Étape 2 : Classe (visible après sélection catégorie) ──
                  if (selectedCategorie != null) ...[
                    const SizedBox(height: 12),
                    _styledDropdown<ClasseModel>(
                      value: selectedClasse,
                      hint: 'Sélectionner un niveau / classe',
                      items: filteredClasses
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c.id.isEmpty
                                      ? c.niveau
                                      : '${c.nom} (${c.niveau})',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setDlg(() => selectedClasse = v),
                    ),
                    if (selectedClasse != null) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          '$selectedCategorie · ${selectedClasse!.niveau} · ${selectedClasse!.nom}',
                          style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 11),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  // ── Option invitation ─────────────────────────────────────
                  Row(
                    children: [
                      Checkbox(
                        value: sendReset,
                        onChanged: busy ? null : (v) => setDlg(() => sendReset = v ?? true),
                        activeColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Colors.white38),
                      ),
                      const Expanded(
                        child: Text(
                          "Envoyer un email d'invitation",
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('Annuler', style: TextStyle(color: Colors.white60)),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        final prenom = prenomCtrl.text.trim();
                        final nom = nomCtrl.text.trim();
                        final email = emailCtrl.text.trim();
                        final adresse = adresseCtrl.text.trim();
                        final telephone = telephoneCtrl.text.trim();
                        final pwd = pwdCtrl.text.trim();
                        if (prenom.isEmpty || nom.isEmpty || email.isEmpty || pwd.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Remplissez le prénom, le nom, l\'email et le mot de passe'),
                            backgroundColor: Color(0xFFDC2626),
                          ));
                          return;
                        }
                        if (pwd.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Mot de passe trop court (minimum 6 caractères)'),
                            backgroundColor: Color(0xFFDC2626),
                          ));
                          return;
                        }
                        setDlg(() => busy = true);
                        final err = await _createEleveCompte(
                          prenom: prenom,
                          nom: nom,
                          email: email,
                          password: pwd,
                          adresse: adresse.isNotEmpty ? adresse : null,
                          telephone: telephone.isNotEmpty ? telephone : null,
                          categorie: selectedCategorie,
                          classeId: selectedClasse?.id,
                          classeNom: selectedClasse?.nom,
                          niveau: selectedClasse?.niveau,
                          sendResetEmail: sendReset,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (err != null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(err),
                            backgroundColor: const Color(0xFFDC2626),
                            duration: const Duration(seconds: 6),
                          ));
                        } else {
                          final loc = selectedClasse != null
                              ? ' · $selectedCategorie ${selectedClasse!.niveau}'
                              : '';
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(sendReset
                                ? 'Compte créé$loc — invitation envoyée à $email'
                                : 'Compte élève créé$loc'),
                            backgroundColor: const Color(0xFF16A34A),
                          ));
                        }
                      },
                child: busy
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF2563EB)))
                    : const Text('Créer',
                        style: TextStyle(
                            color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    prenomCtrl.dispose();
    nomCtrl.dispose();
    emailCtrl.dispose();
    adresseCtrl.dispose();
    telephoneCtrl.dispose();
    pwdCtrl.dispose();
  }

  /// Dropdown stylisé réutilisable dans la dialog.
  Widget _styledDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF161B22),
          hint: Text(hint, style: const TextStyle(color: Colors.white38, fontSize: 13)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String hint, IconData icon,
      TextInputType type) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled: true,
        fillColor: const Color(0xFF0D1117),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2563EB)),
        ),
      ),
    );
  }

  /// Crée un compte Firebase Auth + document Firestore pour un élève.
  /// Utilise une application secondaire pour ne pas déconnecter l'admin.
  /// Les écritures Firestore (users + classes) se font via le compte Direction
  /// en batch atomique pour garantir la cohérence classe ↔ élèves.
  /// Retourne null si succès, ou le message d'erreur.
  Future<String?> _createEleveCompte({
    required String prenom,
    required String nom,
    required String email,
    required String password,
    String? adresse,
    String? telephone,
    String? categorie,
    String? classeId,
    String? classeNom,
    String? niveau,
    bool sendResetEmail = true,
  }) async {
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'eleve_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );

      // Création du compte Auth via app secondaire (préserve la session admin)
      final cred = await FirebaseAuth.instanceFor(app: secondaryApp)
          .createUserWithEmailAndPassword(email: email, password: password);
      final uid = cred.user!.uid;

      // schoolId de la Direction courante — sans ce champ, le nouvel élève
      // retombait sur kDefaultSchoolId (repli de UserModel.fromDoc) au lieu
      // d'être rattaché au bon établissement en contexte multi-écoles.
      final schoolId = await UserService.currentSchoolId();

      final displayName = '$prenom $nom'.trim();
      final data = <String, dynamic>{
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'nom': nom,
        'prenom': prenom,
        'role': 'eleve',
        'schoolId': schoolId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        // Champs prof — toujours présents (vides si aucune classe/prof assigné)
        'profId': '',
        'profEmail': '',
        'profDisplayName': '',
        'profMatiere': '',
      };
      if (adresse != null && adresse.isNotEmpty) data['adresse'] = adresse;
      if (telephone != null && telephone.isNotEmpty) data['telephone'] = telephone;
      if (categorie != null && categorie.isNotEmpty) data['categorie'] = categorie;
      if (niveau != null && niveau.isNotEmpty) data['niveau'] = niveau;
      if (classeId != null && classeId.isNotEmpty) {
        data['classeId'] = classeId;
        if (classeNom != null && classeNom.isNotEmpty) data['classeNom'] = classeNom;

        // Lecture des infos professeur depuis le document classe
        try {
          final classeDoc = await FirebaseFirestore.instance
              .collection('classes')
              .doc(classeId)
              .get();
          final cd = classeDoc.data() ?? {};
          data['profId'] = cd['professeurId'] as String? ?? '';
          data['profEmail'] = cd['professeurEmail'] as String? ?? '';
          data['profDisplayName'] = cd['professeurDisplayName'] as String? ?? '';
          data['profMatiere'] = cd['professeurMatiere'] as String? ?? '';
        } catch (_) {}
      }

      // Batch atomique via Firestore admin (isDirection → accès complet)
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.set(db.collection('users').doc(uid), data);
      if (classeId != null && classeId.isNotEmpty) {
        batch.update(
          db.collection('classes').doc(classeId),
          {'eleveIds': FieldValue.arrayUnion([uid])},
        );
      }
      await batch.commit();

      if (sendResetEmail) {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      }

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Un compte existe déjà avec cet email';
        case 'invalid-email':
          return 'Adresse email invalide';
        case 'weak-password':
          return 'Mot de passe trop faible (minimum 6 caractères)';
        default:
          return '[${e.code}] ${e.message ?? 'Erreur inconnue'}';
      }
    } catch (e) {
      return 'Erreur : $e';
    } finally {
      try {
        await FirebaseAuth.instanceFor(app: secondaryApp!).signOut();
      } catch (_) {}
      try {
        await secondaryApp?.delete();
      } catch (_) {}
    }
  }

  // ── Synchronisation données existantes ───────────────────────────────────────

  Future<void> _showRepairDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Synchroniser les données',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Cette opération resynchronise automatiquement la liaison '
          'entre les élèves et leurs classes :\n\n'
          '• users/{uid}.classeId ↔ classes/{id}.eleveIds\n'
          '• profId, profEmail mis à jour si manquants\n\n'
          'Opération sécurisée et réversible.',
          style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Annuler', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Synchroniser',
                style: TextStyle(
                    color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _repairing = true);
    try {
      final result = await _runRepairSync();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Synchronisation terminée',
            style: TextStyle(
                color: Color(0xFF4ADE80),
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          content: Text(
            '${result['repaired']} élève(s) réparé(s)\n'
            '${result['alreadyOk']} élève(s) déjà corrects\n'
            '${result['errors']} erreur(s)',
            style:
                const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer',
                  style: TextStyle(color: Color(0xFF2563EB))),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur de synchronisation : $e'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 6),
        ));
      }
    } finally {
      if (mounted) setState(() => _repairing = false);
    }
  }

  /// Resynchronise la liaison classe ↔ élèves pour tous les comptes eleve.
  ///
  /// Cas A — classeId présent dans users/{uid} :
  ///   • Ajoute uid dans classes/{classeId}.eleveIds si absent
  ///   • Complète profId/profEmail si manquants et classe a un professeur
  ///
  /// Cas B — classeId absent dans users/{uid} :
  ///   • Cherche si uid apparaît dans le tableau eleveIds d'une classe
  ///   • Si oui, met à jour le profil avec classeId, classeNom, niveau, profId
  Future<Map<String, int>> _runRepairSync() async {
    final db = FirebaseFirestore.instance;

    // Charger tous les élèves et toutes les classes en parallèle
    final results = await Future.wait([
      db.collection('users').where('role', isEqualTo: 'eleve').get(),
      db.collection('classes').get(),
    ]);
    final elevesSnap = results[0];
    final classesSnap = results[1];

    // Index 1 : classeId → données de la classe
    final classeById = <String, Map<String, dynamic>>{};
    // Index 2 : uid élève → classeId (depuis eleveIds des classes)
    final uidToClasseId = <String, String>{};
    // Index 3 : classeId → ensemble des UIDs (pour vérification O(1))
    final classeEleveSet = <String, Set<String>>{};

    for (final d in classesSnap.docs) {
      final data = d.data();
      classeById[d.id] = data;
      final ids = List<String>.from(data['eleveIds'] as List? ?? []);
      classeEleveSet[d.id] = ids.toSet();
      for (final uid in ids) {
        if (uid.isNotEmpty) uidToClasseId[uid] = d.id;
      }
    }

    int repaired = 0;
    int alreadyOk = 0;
    int errors = 0;

    // Gestion des batches — limite Firestore : 500 ops par batch
    final batches = <WriteBatch>[];
    var currentBatch = db.batch();
    int opsInBatch = 0;

    void addOp(void Function(WriteBatch b) op) {
      if (opsInBatch >= 490) {
        batches.add(currentBatch);
        currentBatch = db.batch();
        opsInBatch = 0;
      }
      op(currentBatch);
      opsInBatch++;
    }

    for (final eleveDoc in elevesSnap.docs) {
      try {
        final uid = eleveDoc.id;
        final data = eleveDoc.data();
        final classeId = data['classeId'] as String? ?? '';
        final profId = data['profId'] as String? ?? '';
        bool needsRepair = false;

        if (classeId.isNotEmpty) {
          // ── Cas A : l'élève a un classeId ──────────────────────────────────
          final inEleveIds =
              classeEleveSet[classeId]?.contains(uid) ?? false;

          // A1 : uid absent de classes/{classeId}.eleveIds
          if (!inEleveIds) {
            addOp((b) => b.update(
              db.collection('classes').doc(classeId),
              {'eleveIds': FieldValue.arrayUnion([uid])},
            ));
            needsRepair = true;
          }

          // A2 : profId manquant alors que la classe a un professeur
          if (profId.isEmpty) {
            final cd = classeById[classeId];
            if (cd != null) {
              final classeProfId = cd['professeurId'] as String? ?? '';
              if (classeProfId.isNotEmpty) {
                addOp((b) => b.update(
                  db.collection('users').doc(uid),
                  {
                    'profId': classeProfId,
                    'profEmail': cd['professeurEmail'] as String? ?? '',
                    'profDisplayName':
                        cd['professeurDisplayName'] as String? ?? '',
                    'profMatiere': cd['professeurMatiere'] as String? ?? '',
                  },
                ));
                needsRepair = true;
              }
            }
          }
        } else {
          // ── Cas B : l'élève n'a pas de classeId ────────────────────────────
          final foundClasseId = uidToClasseId[uid];
          if (foundClasseId != null) {
            final cd = classeById[foundClasseId] ?? {};
            addOp((b) => b.update(
              db.collection('users').doc(uid),
              {
                'classeId': foundClasseId,
                'classeNom': cd['nom'] as String? ?? '',
                'niveau': cd['niveau'] as String? ?? '',
                'profId': cd['professeurId'] as String? ?? '',
                'profEmail': cd['professeurEmail'] as String? ?? '',
                'profDisplayName':
                    cd['professeurDisplayName'] as String? ?? '',
                'profMatiere': cd['professeurMatiere'] as String? ?? '',
              },
            ));
            needsRepair = true;
          }
        }

        if (needsRepair) repaired++; else alreadyOk++;
      } catch (_) {
        errors++;
      }
    }

    // Soumettre le dernier batch s'il contient des opérations
    if (opsInBatch > 0) batches.add(currentBatch);
    for (final b in batches) await b.commit();

    return {'repaired': repaired, 'alreadyOk': alreadyOk, 'errors': errors};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Gestion des élèves',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          _repairing
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF2563EB)),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.sync, color: Colors.white60, size: 22),
                  tooltip: 'Synchroniser les données élèves ↔ classes',
                  onPressed: () => _showRepairDialog(context),
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2563EB),
        tooltip: 'Ajouter un élève',
        onPressed: () => _showAddEleveDialog(context),
        child: const Icon(Icons.person_add_outlined, color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: UserService.usersByRoleStream('eleve'),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF2563EB)));
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Erreur stream:\n${snap.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  );
                }
                final eleves = snap.data ?? [];

                if (eleves.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Aucun élève inscrit pour le moment.\n'
                        'Les élèves apparaissent ici après leur inscription.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                  );
                }

                // Catégories présentes dans les données
                final categories = _kNiveauxParCategorie.keys
                    .where((cat) => eleves.any((e) => e.categorie == cat))
                    .toList();

                // Filtre côté client
                final displayed = _filtreCategorie == null
                    ? eleves
                    : eleves
                        .where((e) => e.categorie == _filtreCategorie)
                        .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Statistiques ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          Text(
                            '${eleves.length} élève${eleves.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                          ...categories.map((cat) {
                            final count =
                                eleves.where((e) => e.categorie == cat).length;
                            return Text(
                              '$cat : $count',
                              style: TextStyle(
                                color: _filtreCategorie == cat
                                    ? const Color(0xFF2563EB)
                                    : Colors.white30,
                                fontSize: 11,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    // ── Filtres par catégorie ─────────────────────────────
                    if (categories.isNotEmpty)
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: categories.length + 1,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final isAll = i == 0;
                            final cat = isAll ? null : categories[i - 1];
                            final label = isAll ? 'Tous' : cat!;
                            final isSelected = isAll
                                ? _filtreCategorie == null
                                : _filtreCategorie == cat;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _filtreCategorie = cat),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF161B22),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF2563EB)
                                        : Colors.white
                                            .withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white60,
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 6),
                    // ── Liste filtrée ─────────────────────────────────────
                    Expanded(
                      child: displayed.isEmpty
                          ? Center(
                              child: Text(
                                'Aucun élève en $_filtreCategorie',
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 13),
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 32),
                              itemCount: displayed.length,
                              itemBuilder: (_, i) =>
                                  _EleveItem(eleve: displayed[i]),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EleveItem extends StatefulWidget {
  final UserModel eleve;
  const _EleveItem({required this.eleve});

  @override
  State<_EleveItem> createState() => _EleveItemState();
}

class _EleveItemState extends State<_EleveItem> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final eleve = widget.eleve;
    final hasClasse = eleve.classeNom != null && eleve.classeNom!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline,
                color: Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eleve.displayName.isNotEmpty ? eleve.displayName : eleve.email,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(eleve.email,
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
                if (eleve.telephone != null && eleve.telephone!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(eleve.telephone!,
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 11)),
                  ),
                if (eleve.adresse != null && eleve.adresse!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(eleve.adresse!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 11)),
                  ),
                const SizedBox(height: 4),
                if (hasClasse)
                  _ClasseChip(
                      classeNom: eleve.classeNom!,
                      niveau: eleve.niveau ?? '',
                      categorie: eleve.categorie)
                else
                  const Text(
                    'Aucune classe assignée',
                    style: TextStyle(color: Color(0xFFD97706), fontSize: 11),
                  ),
              ],
            ),
          ),
          if (_busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF2563EB)),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  color: Colors.white38, size: 18),
              color: const Color(0xFF161B22),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    _showEditEleveDialog(context);
                    break;
                  case 'classe':
                    _showClassePicker(context);
                    break;
                  case 'delete':
                    _showDeleteEleveDialog(context);
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Modifier les informations',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
                PopupMenuItem(
                  value: 'classe',
                  child: Text('Affecter une classe',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Supprimer l\'élève',
                      style: TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Modifier les informations ───────────────────────────────────────────

  Future<void> _showEditEleveDialog(BuildContext context) async {
    final eleve = widget.eleve;
    final prenomCtrl = TextEditingController(text: eleve.prenom ?? '');
    final nomCtrl = TextEditingController(text: eleve.nom ?? '');
    final adresseCtrl = TextEditingController(text: eleve.adresse ?? '');
    final telephoneCtrl = TextEditingController(text: eleve.telephone ?? '');
    bool busy = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Modifier les informations',
              style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _EditField(prenomCtrl, 'Prénom',
                            Icons.person_outline)),
                    const SizedBox(width: 10),
                    Expanded(
                        child:
                            _EditField(nomCtrl, 'Nom', Icons.person_outline)),
                  ],
                ),
                const SizedBox(height: 12),
                _EditField(adresseCtrl, 'Adresse', Icons.home_outlined),
                const SizedBox(height: 12),
                _EditField(
                    telephoneCtrl, 'Numéro de téléphone', Icons.phone_outlined),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.email_outlined,
                          color: Colors.white24, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(eleve.email,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 13)),
                            const Text(
                                'Non modifiable — identifiant de connexion',
                                style: TextStyle(
                                    color: Colors.white24, fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white60)),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final prenom = prenomCtrl.text.trim();
                      final nom = nomCtrl.text.trim();
                      if (prenom.isEmpty || nom.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Le prénom et le nom sont obligatoires'),
                          backgroundColor: Color(0xFFDC2626),
                        ));
                        return;
                      }
                      setDlg(() => busy = true);
                      try {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(eleve.uid)
                            .update({
                          'nom': nom,
                          'prenom': prenom,
                          'displayName': '$prenom $nom'.trim(),
                          'adresse': adresseCtrl.text.trim(),
                          'telephone': telephoneCtrl.text.trim(),
                        });
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Informations mises à jour'),
                            backgroundColor: Color(0xFF16A34A),
                          ));
                        }
                      } catch (e) {
                        setDlg(() => busy = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Erreur : $e'),
                            backgroundColor: const Color(0xFFDC2626),
                            duration: const Duration(seconds: 6),
                          ));
                        }
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF2563EB)))
                  : const Text('Enregistrer',
                      style: TextStyle(
                          color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    prenomCtrl.dispose();
    nomCtrl.dispose();
    adresseCtrl.dispose();
    telephoneCtrl.dispose();
  }

  // ── Suppression ──────────────────────────────────────────────────────────

  Future<void> _showDeleteEleveDialog(BuildContext context) async {
    final eleve = widget.eleve;
    final label = eleve.displayName.isNotEmpty ? eleve.displayName : eleve.email;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer cet élève ?',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'Cette action supprime définitivement le compte de $label.\n\n'
          'L\'élève sera retiré de sa classe et de la liste des enfants de '
          'ses parents éventuellement liés. Les notes, devoirs et bulletins '
          'déjà enregistrés ne sont pas supprimés.\n\n'
          'Cette action est irréversible.',
          style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer',
                style: TextStyle(
                    color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _deleteEleve(eleve);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$label supprimé(e)'),
          backgroundColor: const Color(0xFF16A34A),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur lors de la suppression : $e'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 6),
        ));
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Supprime le compte élève et nettoie les références croisées :
  /// classe.eleveIds et parent.enfantIds. Les données académiques
  /// historiques (notes, devoirs, bulletins) restent en base, rattachées à
  /// l'ancien uid — non supprimées pour ne pas casser les historiques.
  Future<void> _deleteEleve(UserModel eleve) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    if (eleve.classeId != null && eleve.classeId!.isNotEmpty) {
      batch.update(
        db.collection('classes').doc(eleve.classeId!),
        {'eleveIds': FieldValue.arrayRemove([eleve.uid])},
      );
    }

    // Retire l'élève des enfantIds de tout parent qui l'aurait lié.
    final parentsSnap = await db
        .collection('users')
        .where('role', isEqualTo: 'parent')
        .where('enfantIds', arrayContains: eleve.uid)
        .get();
    for (final p in parentsSnap.docs) {
      batch.update(p.reference, {
        'enfantIds': FieldValue.arrayRemove([eleve.uid]),
      });
    }

    batch.delete(db.collection('users').doc(eleve.uid));
    await batch.commit();
  }

  Future<void> _showClassePicker(BuildContext context) async {
    // Charger la liste des classes
    List<ClasseModel> classes = [];
    bool loadFailed = false;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('classes')
          .orderBy('nom')
          .get();
      classes = snap.docs.map(ClasseModel.fromFirestore).toList();
    } catch (e) {
      debugPrint('[DirectionEleves] _showClassePicker chargement classes ERROR: $e');
      loadFailed = true;
    }

    if (!mounted) return;
    if (loadFailed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Impossible de charger les classes. Vérifiez votre connexion.'),
        backgroundColor: Color(0xFFDC2626),
      ));
    }

    ClasseModel? selected;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: Text(
            'Affecter une classe\n'
            '${widget.eleve.displayName.isNotEmpty ? widget.eleve.displayName : widget.eleve.email}',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          content: classes.isEmpty
              ? const Text(
                  'Aucune classe disponible.\n'
                  'Créez d\'abord une classe depuis l\'espace Professeur.',
                  style: TextStyle(color: Color(0xFFD97706), fontSize: 13),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ClasseModel>(
                      value: selected,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF161B22),
                      hint: const Text('Choisir une classe',
                          style: TextStyle(color: Colors.white38, fontSize: 13)),
                      items: classes
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text('${c.nom} — ${c.niveau}',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) => setDlgState(() => selected = v),
                    ),
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white60)),
            ),
            if (classes.isNotEmpty)
              TextButton(
                onPressed: selected == null ? null : () => Navigator.pop(ctx, true),
                child: Text(
                  'Confirmer',
                  style: TextStyle(
                      color: selected == null
                          ? Colors.white24
                          : const Color(0xFF2563EB),
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );

    if (confirmed != true || selected == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await _assignClasse(selected!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${widget.eleve.displayName.isNotEmpty ? widget.eleve.displayName : widget.eleve.email}'
              ' → classe ${selected!.nom}'),
          backgroundColor: const Color(0xFF16A34A),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur affectation: $e'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 6),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assignClasse(ClasseModel classe) async {
    final eleve = widget.eleve;
    final db = FirebaseFirestore.instance;

    // Lecture des infos professeur — toujours incluses (vides si aucun prof)
    // pour effacer tout résidu d'un ancien professeur lors d'un changement de classe
    final profFields = <String, dynamic>{
      'profId': '',
      'profEmail': '',
      'profDisplayName': '',
      'profMatiere': '',
    };
    try {
      final classeDoc = await db.collection('classes').doc(classe.id).get();
      final cd = classeDoc.data() ?? {};
      profFields['profId'] = cd['professeurId'] as String? ?? '';
      profFields['profEmail'] = cd['professeurEmail'] as String? ?? '';
      profFields['profDisplayName'] = cd['professeurDisplayName'] as String? ?? '';
      profFields['profMatiere'] = cd['professeurMatiere'] as String? ?? '';
    } catch (_) {}

    // Batch atomique : mise à jour du profil élève + synchronisation eleveIds
    final batch = db.batch();

    batch.set(
      db.collection('users').doc(eleve.uid),
      {
        'role': 'eleve',
        'classeId': classe.id,
        'classeNom': classe.nom,
        'niveau': classe.niveau,
        ...profFields,
      },
      SetOptions(merge: true),
    );

    // Retrait de l'ancienne classe si différente
    if (eleve.classeId != null &&
        eleve.classeId!.isNotEmpty &&
        eleve.classeId != classe.id) {
      batch.update(
        db.collection('classes').doc(eleve.classeId!),
        {'eleveIds': FieldValue.arrayRemove([eleve.uid])},
      );
    }

    // Ajout dans la nouvelle classe
    batch.update(
      db.collection('classes').doc(classe.id),
      {'eleveIds': FieldValue.arrayUnion([eleve.uid])},
    );

    await batch.commit();
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ClasseChip extends StatelessWidget {
  final String classeNom;
  final String niveau;
  final String? categorie;
  const _ClasseChip({
    required this.classeNom,
    required this.niveau,
    this.categorie,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (categorie != null && categorie!.isNotEmpty) categorie!,
      if (niveau.isNotEmpty) niveau,
      if (classeNom.isNotEmpty && classeNom != niveau) classeNom,
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border:
            Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
      ),
      child: Text(
        parts.isNotEmpty ? parts.join(' · ') : classeNom,
        style: const TextStyle(
            color: Color(0xFF16A34A),
            fontSize: 11,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Champ texte réutilisé dans les dialogs d'édition des informations élève.
class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  const _EditField(this.controller, this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled: true,
        fillColor: const Color(0xFF0D1117),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2563EB)),
        ),
      ),
    );
  }
}
