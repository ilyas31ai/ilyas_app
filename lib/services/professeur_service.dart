import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/classe_model.dart';
import '../models/devoir_model.dart';
import '../models/document_model.dart';
import '../models/note_model.dart';
import '../models/presence_model.dart';
import '../models/school_model.dart' show kDefaultSchoolId;
import '../models/submission_model.dart';
import '../models/user_model.dart';
import 'user_service.dart';

class ProfesseurService {
  static final _db = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instanceFor(bucket: 'gs://ilyasapp-4762c.firebasestorage.app');

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static CollectionReference<Map<String, dynamic>> get _classes =>
      _db.collection('classes');
  static CollectionReference<Map<String, dynamic>> get _presences =>
      _db.collection('presences');
  static CollectionReference<Map<String, dynamic>> get _notes =>
      _db.collection('notes');
  static CollectionReference<Map<String, dynamic>> get _devoirs =>
      _db.collection('devoirs');
  static CollectionReference<Map<String, dynamic>> get _documents =>
      _db.collection('documents_prof');
  static CollectionReference<Map<String, dynamic>> get _emplois =>
      _db.collection('emplois_du_temps');

  // ── Classes ───────────────────────────────────────────────────────────────

  static Stream<List<ClasseModel>> classesStream() {
    return _classes
        .where('professeurId', isEqualTo: _uid)
        .snapshots()
        .map((s) {
      final list = s.docs.map(ClasseModel.fromFirestore).toList();
      list.sort((a, b) => a.nom.compareTo(b.nom));
      return list;
    });
  }

  static Future<String> addClass({
    required String nom,
    required String niveau,
  }) async {
    final uid = _uid;
    if (uid.isEmpty) {
      throw Exception('Utilisateur non authentifié (uid vide)');
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      final doc = await _classes.add({
        'nom': nom,
        'niveau': niveau,
        'professeurId': uid,
        'professeurEmail': user?.email ?? '',
        'professeurDisplayName': user?.displayName ?? '',
        'eleveIds': <String>[],
        'anneeScol': DateTime.now().year,
      });
      return doc.id;
    } catch (e) {
      debugPrint('[ProfService] addClass: ERREUR — $e');
      rethrow;
    }
  }

  static Future<void> deleteClass(String id) async {
    await _classes.doc(id).delete();
  }

  static Future<void> addEleveToClasse(String classeId, String eleveId) async {
    await _classes.doc(classeId).update({
      'eleveIds': FieldValue.arrayUnion([eleveId]),
    });
  }

  static Future<void> removeEleveFromClasse(
      String classeId, String eleveId) async {
    await _classes.doc(classeId).update({
      'eleveIds': FieldValue.arrayRemove([eleveId]),
    });
  }

  // ── Emploi du temps ───────────────────────────────────────────────────────

  static Stream<List<EmploiSlot>> emploiStream() {
    return _emplois
        .where('professeurId', isEqualTo: _uid)
        .snapshots()
        .map((s) {
      final list = s.docs.map(EmploiSlot.fromFirestore).toList();
      list.sort((a, b) {
        final j = a.jour.compareTo(b.jour);
        if (j != 0) return j;
        return a.heureDebut.compareTo(b.heureDebut);
      });
      return list;
    });
  }

  static Future<void> addSlot({
    required int jour,
    required String heureDebut,
    required String heureFin,
    required String matiere,
    required String classeNom,
    required String classeId,
    required String salle,
  }) async {
    await _emplois.add({
      'jour': jour,
      'heureDebut': heureDebut,
      'heureFin': heureFin,
      'matiere': matiere,
      'classeNom': classeNom,
      'classeId': classeId,
      'salle': salle,
      'professeurId': _uid,
    });
  }

  static Future<void> deleteSlot(String id) async {
    await _emplois.doc(id).delete();
  }

  // ── Élèves (issus de la collection Direction) ─────────────────────────────

  static Stream<List<Map<String, dynamic>>> elevesParClasseStream(
      String classeNom) {
    if (classeNom.isEmpty) return Stream.value(const []);
    return _db
        .collection('users')
        .where('role', isEqualTo: 'eleve')
        .where('classeNom', isEqualTo: classeNom)
        .snapshots()
        .asyncMap((s) async {
          // Isolation multi-établissement : deux écoles peuvent avoir une
          // classe du même nom (ex: "6ème A") — on ne garde que les élèves
          // de l'établissement du professeur connecté.
          final mySchoolId = await UserService.currentSchoolId();
          final list = s.docs
              .where((d) =>
                  (d.data()['schoolId'] as String? ?? kDefaultSchoolId) ==
                  mySchoolId)
              .map((d) {
            final data = d.data();
            // Dériver prenom/nom depuis displayName si les champs séparés sont absents
            final displayName = (data['displayName'] as String? ?? '').trim();
            final parts = displayName.isEmpty ? <String>[] : displayName.split(RegExp(r'\s+'));
            final prenom = data['prenom'] as String? ?? (parts.isNotEmpty ? parts.first : '');
            final nom = data['nom'] as String? ?? (parts.length > 1 ? parts.skip(1).join(' ') : '');
            return {
              'id': d.id,
              ...data,
              'prenom': prenom,
              'nom': nom,
            };
          }).toList();
          list.sort((a, b) {
            final na = '${a['prenom']} ${a['nom']}';
            final nb = '${b['prenom']} ${b['nom']}';
            return na.compareTo(nb);
          });
          return list;
        });
  }

  // ── Présences ─────────────────────────────────────────────────────────────

  static Stream<List<PresenceRecord>> presencesParJourStream(
      String classeId, DateTime date) {
    final debut = DateTime(date.year, date.month, date.day);
    final fin = debut.add(const Duration(days: 1));
    return _presences
        .where('classeId', isEqualTo: classeId)
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(debut),
            isLessThan: Timestamp.fromDate(fin))
        .snapshots()
        .map((s) => s.docs.map(PresenceRecord.fromFirestore).toList());
  }

  static Stream<List<PresenceRecord>> historiquePresencesStream(
      String classeId) {
    return _presences
        .where('classeId', isEqualTo: classeId)
        .orderBy('date', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(PresenceRecord.fromFirestore).toList());
  }

  static Future<void> saveAppel({
    required String classeId,
    required String classeNom,
    required DateTime date,
    required List<Map<String, dynamic>> eleves, // [{id, nom, prenom}]
    required Map<String, PresenceStatut> statuts,
    required Map<String, String> motifs,
  }) async {
    final batch = _db.batch();
    for (final eleve in eleves) {
      final eid = eleve['id'] as String;
      final ref = _presences.doc('${classeId}_${eid}_${date.toIso8601String().substring(0, 10)}');
      batch.set(ref, {
        'eleveId': eid,
        'eleveNom': eleve['nom'] as String? ?? '',
        'elevePrenom': eleve['prenom'] as String? ?? '',
        'classeId': classeId,
        'classeNom': classeNom,
        'professeurId': _uid,
        'date': Timestamp.fromDate(date),
        'statut': (statuts[eid] ?? PresenceStatut.present).value,
        'motif': motifs[eid] ?? '',
      });
    }
    await batch.commit();
  }

  // ── Notes ─────────────────────────────────────────────────────────────────

  static Stream<List<NoteModel>> notesStream(
      String classeId, String matiere) {
    var query = _notes
        .where('classeId', isEqualTo: classeId)
        .where('professeurId', isEqualTo: _uid);
    if (matiere.isNotEmpty) {
      query = query.where('matiere', isEqualTo: matiere);
    }
    return query.snapshots().map((s) {
      final list = s.docs.map(NoteModel.fromFirestore).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  static Future<void> addNote({
    required String eleveId,
    String eleveUid = '',
    required String eleveNom,
    required String elevePrenom,
    required String classeId,
    required String classeNom,
    required String matiere,
    required double note,
    required double bareme,
    required String intitule,
  }) async {
    await _notes.add({
      'eleveId': eleveId,
      if (eleveUid.isNotEmpty) 'eleveUid': eleveUid,
      'eleveNom': eleveNom,
      'elevePrenom': elevePrenom,
      'classeId': classeId,
      'classeNom': classeNom,
      'matiere': matiere,
      'professeurId': _uid,
      'note': note,
      'bareme': bareme,
      'intitule': intitule,
      'date': FieldValue.serverTimestamp(),
      'publie': false,
    });
  }

  static Future<void> updateNote(
    String id, {
    required double note,
    String? intitule,
  }) async {
    await _notes.doc(id).update({
      'note': note,
      if (intitule != null) 'intitule': intitule,
    });
  }

  static Future<void> publierNotes(String classeId, String matiere) async {
    final snap = await _notes
        .where('classeId', isEqualTo: classeId)
        .where('matiere', isEqualTo: matiere)
        .where('professeurId', isEqualTo: _uid)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'publie': true});
    }
    await batch.commit();
  }

  static Future<void> deleteNote(String id) async {
    await _notes.doc(id).delete();
  }

  // ── Devoirs ───────────────────────────────────────────────────────────────

  static Stream<List<DevoirModel>> devoirsStream() {
    return _devoirs
        .where('professeurId', isEqualTo: _uid)
        .orderBy('dateEnvoi', descending: true)
        .snapshots()
        .map((s) => s.docs.map(DevoirModel.fromFirestore).toList());
  }

  static Future<void> sendDevoir({
    required String titre,
    required String description,
    required String matiere,
    required String classeId,
    required String classeNom,
    DateTime? dateLimite,
    File? fichier,
    String? fichierNom,
  }) async {
    String fichierUrl = '';
    String nom = '';

    if (fichier != null && fichierNom != null) {
      final bytes = await fichier.readAsBytes();
      final token = _generateDownloadToken();
      final ref = _storage
          .ref('devoirs/$_uid/${DateTime.now().millisecondsSinceEpoch}_$fichierNom');
      final snap = await ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'application/octet-stream',
          customMetadata: {'firebaseStorageDownloadTokens': token},
        ),
      );
      if (snap.state != TaskState.success) {
        throw Exception('Upload devoir échoué (état: ${snap.state}).');
      }
      final bucket      = snap.ref.bucket;
      final encodedPath = Uri.encodeComponent(snap.ref.fullPath);
      fichierUrl = 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media&token=$token';
      nom = fichierNom;
    }

    await _devoirs.add({
      'titre': titre,
      'description': description,
      'matiere': matiere,
      'classeId': classeId,
      'classeNom': classeNom,
      'professeurId': _uid,
      'dateEnvoi': FieldValue.serverTimestamp(),
      if (dateLimite != null) 'dateLimite': Timestamp.fromDate(dateLimite),
      'fichierUrl': fichierUrl,
      'fichierNom': nom,
    });
  }

  static Future<void> deleteDevoir(String id) async {
    final doc = await _devoirs.doc(id).get();
    final url = doc.data()?['fichierUrl'] as String?;
    if (url != null && url.isNotEmpty) {
      try {
        await _storage.refFromURL(url).delete();
      } catch (_) {
        // Fichier déjà absent du Storage — on supprime l'entrée Firestore quand même.
      }
    }
    await _devoirs.doc(id).delete();
  }

  static Future<void> updateDevoir(String id, Map<String, dynamic> data) async {
    await _devoirs.doc(id).update(data);
  }

  // Envoi un devoir complet avec pièces jointes multiples et barème
  static Future<String> sendDevoirComplet({
    required String titre,
    required String description,
    required String matiere,
    required String classeId,
    required String classeNom,
    required int bareme,
    DateTime? dateLimite,
    DateTime? datePublication,
    List<File> fichiers = const [],
    List<String> nomsF = const [],
  }) async {
    final uid = _uid;
    final user = FirebaseAuth.instance.currentUser;
    final profNom = user?.displayName ?? '';

    final piecesJointes = <Map<String, String>>[];
    for (var i = 0; i < fichiers.length; i++) {
      final nom = i < nomsF.length ? nomsF[i] : fichiers[i].path.split('/').last;
      final token = _generateDownloadToken();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref('devoirs/$uid/${ts}_$nom');
      final bytes = await fichiers[i].readAsBytes();
      final snap = await ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'application/octet-stream',
          customMetadata: {'firebaseStorageDownloadTokens': token},
        ),
      );
      if (snap.state == TaskState.success) {
        final bucket = snap.ref.bucket;
        final encoded = Uri.encodeComponent(snap.ref.fullPath);
        final url = 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encoded?alt=media&token=$token';
        final ext = nom.split('.').last.toLowerCase();
        piecesJointes.add({'url': url, 'nom': nom, 'type': ext});
      }
    }

    final doc = await _devoirs.add({
      'titre': titre,
      'description': description,
      'matiere': matiere,
      'classeId': classeId,
      'classeNom': classeNom,
      'professeurId': uid,
      'professeurNom': profNom,
      'dateEnvoi': FieldValue.serverTimestamp(),
      if (dateLimite != null) 'dateLimite': Timestamp.fromDate(dateLimite),
      if (datePublication != null)
        'datePublication': Timestamp.fromDate(datePublication),
      'fichierUrl': '',
      'fichierNom': '',
      'piecesJointes': piecesJointes,
      'bareme': bareme,
      'estExamen': false,
      'aiActive': true,
    });
    return doc.id;
  }

  // Stream des soumissions pour un devoir donné (avec classeId pour prof principal)
  static Stream<List<SubmissionModel>> submissionsForDevoirStream(String devoirId) {
    return _db
        .collection('submissions')
        .where('assignmentId', isEqualTo: devoirId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(SubmissionModel.fromFirestore).toList());
  }

  static Future<void> graderSubmission(
      String subId, double grade, String teacherComment) async {
    await _db.collection('submissions').doc(subId).update({
      'grade': grade,
      'teacherComment': teacherComment,
      'status': 'corrected',
    });
  }

  // ── Documents pédagogiques ────────────────────────────────────────────────

  static Stream<List<DocumentPedagogique>> documentsStream() {
    return _documents
        .where('professeurId', isEqualTo: _uid)
        .snapshots()
        .map((s) {
          final list = s.docs.map(DocumentPedagogique.fromFirestore).toList();
          list.sort((a, b) => b.dateDepot.compareTo(a.dateDepot));
          return list;
        });
  }

  // Génère un token aléatoire compatible Firebase Storage download token
  static String _generateDownloadToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(36, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  static Future<void> addDocument({
    required String titre,
    required String description,
    required String matiere,
    required String classeId,
    required String classeNom,
    required String type,
    File? fichier,
    String? fichierNom,
    String devoirId = '',
  }) async {
    final uid = _uid;
    debugPrint('══════════════════════════════════════════════════');
    debugPrint('[addDocument] ► DÉBUT');
    debugPrint('[addDocument] uid=$uid');
    debugPrint('[addDocument] titre="$titre" matiere="$matiere" classeNom="$classeNom" type=$type');
    debugPrint('[addDocument] fichier=${fichier?.path} | fichierNom=$fichierNom');

    if (uid.isEmpty) {
      throw Exception('Utilisateur non authentifié — reconnectez-vous.');
    }

    String fichierUrl = '';
    String nom = '';

    // ── BLOC STORAGE (ignoré si aucun fichier) ────────────────────────────────
    if (fichier != null && fichierNom != null) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'documents_prof/$uid/${ts}_$fichierNom';

      debugPrint('[addDocument] ► STORAGE');
      debugPrint('[addDocument] bucket configuré : ${_storage.bucket}');
      debugPrint('[addDocument] storagePath      : $storagePath');

      try {
        // 1. Lire les octets (putData évite les content-URI Android)
        final bytes = await fichier.readAsBytes();
        debugPrint('[addDocument] fichier lu : ${bytes.length} octets');

        if (bytes.isEmpty) {
          throw Exception('Fichier vide (0 octet) — upload annulé.');
        }

        // 2. Déterminer le content-type
        final ext = fichierNom.split('.').last.toLowerCase();
        final contentType = switch (ext) {
          'pdf'  => 'application/pdf',
          'doc'  => 'application/msword',
          'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'ppt'  => 'application/vnd.ms-powerpoint',
          'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
          _      => 'application/octet-stream',
        };
        debugPrint('[addDocument] contentType : $contentType');

        // 3. Générer un token de téléchargement (compatible appspot + firebasestorage.app)
        //    → évite d'appeler getDownloadURL() qui échoue sur les buckets new-gen
        final downloadToken = _generateDownloadToken();
        debugPrint('[addDocument] downloadToken : $downloadToken');

        final ref = _storage.ref(storagePath);
        debugPrint('[addDocument] ref.bucket   : ${ref.bucket}');
        debugPrint('[addDocument] ref.fullPath : ${ref.fullPath}');

        // 4. Upload — le token est injecté dans les métadonnées
        debugPrint('[addDocument] ► putData démarrage...');
        TaskSnapshot snapshot;
        try {
          snapshot = await ref.putData(
            bytes,
            SettableMetadata(
              contentType: contentType,
              customMetadata: {'firebaseStorageDownloadTokens': downloadToken},
            ),
          );
        } on FirebaseException catch (e, st) {
          debugPrint('[addDocument] putData ÉCHEC');
          debugPrint('[addDocument]   code    : ${e.code}');
          debugPrint('[addDocument]   message : ${e.message}');
          debugPrint('[addDocument]   stack   : $st');
          rethrow;
        }

        debugPrint('[addDocument] putData OK');
        debugPrint('[addDocument]   TaskState          : ${snapshot.state}');
        debugPrint('[addDocument]   octets transférés  : ${snapshot.bytesTransferred}/${snapshot.totalBytes}');
        debugPrint('[addDocument]   snapshot.ref.bucket: ${snapshot.ref.bucket}');
        debugPrint('[addDocument]   snapshot.ref.path  : ${snapshot.ref.fullPath}');

        if (snapshot.state != TaskState.success) {
          throw Exception(
              'Upload échoué (état: ${snapshot.state}) — le serveur a refusé le fichier.\n'
              'Vérifiez les règles Firebase Storage sur le bucket "${snapshot.ref.bucket}".');
        }

        // 5. Construire l'URL directement avec le token — pas besoin de getDownloadURL()
        //    Format : https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{path}?alt=media&token={token}
        final bucket      = snapshot.ref.bucket;
        final encodedPath = Uri.encodeComponent(snapshot.ref.fullPath);
        fichierUrl = 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media&token=$downloadToken';
        nom = fichierNom;

        debugPrint('[addDocument] URL fichier : $fichierUrl');

      } catch (e, st) {
        debugPrint('[addDocument] ► ERREUR STORAGE : $e');
        debugPrint('[addDocument]   stack : $st');
        rethrow;
      }
    } else {
      debugPrint('[addDocument] Aucun fichier joint → dépôt sans PDF');
    }

    // ── BLOC FIRESTORE ─────────────────────────────────────────────────────────
    debugPrint('[addDocument] ► FIRESTORE WRITE');
    final data = {
      'titre': titre,
      'description': description,
      'matiere': matiere,
      'classeId': classeId,
      'classeNom': classeNom,
      'professeurId': uid,
      'fichierUrl': fichierUrl,
      'fichierNom': nom,
      'dateDepot': FieldValue.serverTimestamp(),
      'type': type,
      if (devoirId.isNotEmpty) 'devoirId': devoirId,
    };
    debugPrint('[addDocument] data : $data');

    try {
      final docRef = await _documents.add(data);
      debugPrint('[addDocument] ► FIRESTORE OK — docId: ${docRef.id}');
    } catch (e, st) {
      debugPrint('[addDocument] ► ERREUR FIRESTORE : $e');
      debugPrint('[addDocument]   stack : $st');
      rethrow;
    }

    debugPrint('[addDocument] ► TERMINÉ');
    debugPrint('══════════════════════════════════════════════════');
  }

  static Future<void> deleteDocument(String id) async {
    final doc = await _documents.doc(id).get();
    final url = doc.data()?['fichierUrl'] as String?;
    if (url != null && url.isNotEmpty) {
      try {
        await _storage.refFromURL(url).delete();
      } catch (_) {
        // Fichier déjà absent du Storage — on supprime l'entrée Firestore quand même.
      }
    }
    await _documents.doc(id).delete();
  }

  // ── Statistiques tableau de bord ──────────────────────────────────────────

  static Stream<int> totalClassesStream() {
    return _classes
        .where('professeurId', isEqualTo: _uid)
        .snapshots()
        .map((s) => s.docs.length);
  }

  static Stream<int> totalElevesStream() {
    return _classes
        .where('professeurId', isEqualTo: _uid)
        .snapshots()
        .map((s) => s.docs.fold<int>(
            0,
            (acc, doc) =>
                acc +
                ((doc.data()['eleveIds'] as List?)?.length ?? 0)));
  }

  static Stream<int> totalDevoirsStream() {
    return _devoirs
        .where('professeurId', isEqualTo: _uid)
        .snapshots()
        .map((s) => s.docs.length);
  }

  static Stream<int> totalDocumentsStream() {
    return _documents
        .where('professeurId', isEqualTo: _uid)
        .snapshots()
        .map((s) => s.docs.length);
  }

  // ── Suivi IA — élèves par classe (depuis users/{uid}) ────────────────────

  /// Élèves qui ont utilisé l'app IA et ont enregistré `classeNom` dans leur profil.
  /// Source : collection `users` (et non `eleves`), pour avoir accès au suivi maîtrise.
  static Stream<List<UserModel>> elevesMaitriseStream(String classeNom) {
    if (classeNom.isEmpty) return Stream.value(const []);
    return _db
        .collection('users')
        .where('role', isEqualTo: 'eleve')
        .where('classeNom', isEqualTo: classeNom)
        .snapshots()
        .asyncMap((s) async {
      // Isolation multi-établissement : voir elevesParClasseStream ci-dessus.
      final mySchoolId = await UserService.currentSchoolId();
      final list = s.docs
          .map((d) => UserModel.fromDoc(d))
          .where((u) => u.schoolId == mySchoolId)
          .toList();
      list.sort((a, b) => a.displayName.compareTo(b.displayName));
      return list;
    });
  }

  /// Nombre total d'élèves ayant au moins une notion 🔴 dans les classes du professeur.
  static Stream<int> totalElevesEnDifficulteStream() {
    final uid = _uid;
    if (uid.isEmpty) return Stream.value(0);
    return _classes
        .where('professeurId', isEqualTo: uid)
        .snapshots()
        .asyncMap((classeSnap) async {
      final noms = classeSnap.docs
          .map((d) => d.data()['nom'] as String? ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      if (noms.isEmpty) return 0;
      // Isolation multi-établissement : voir elevesParClasseStream ci-dessus.
      final mySchoolId = await UserService.currentSchoolId();
      int count = 0;
      for (final nom in noms) {
        final snap = await _db
            .collection('users')
            .where('role', isEqualTo: 'eleve')
            .where('classeNom', isEqualTo: nom)
            .where('maitrise_en_difficulte', isEqualTo: true)
            .get();
        count += snap.docs
            .where((d) =>
                (d.data()['schoolId'] as String? ?? kDefaultSchoolId) ==
                mySchoolId)
            .length;
      }
      return count;
    });
  }

  // ── Communication — contacts autorisés (Direction uniquement) ────────────

  static Stream<List<UserModel>> contactsAutorises() {
    return _db
        .collection('users')
        .where('role', isEqualTo: UserRole.admin.value)
        .snapshots()
        .map((s) {
          final seen = <String>{};
          return s.docs
              .map((d) => UserModel.fromDoc(d))
              .where((u) => u.uid != _uid && seen.add(u.email))
              .toList();
        });
  }
}
