import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/annonce_model.dart';
import '../models/classe_model.dart';
import '../models/devoir_model.dart';
import '../models/document_model.dart';
import '../models/note_model.dart';
import '../models/submission_model.dart';

class EtudiantService {
  static final _db = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instanceFor(bucket: 'gs://ilyasapp-4762c.firebasestorage.app');

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static String _storageToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(36, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Classe de l'élève ───────────────────────────────────────────────────────
  static Stream<String?> classeNomStream() {
    final uid = _uid;
    if (uid.isEmpty) return Stream.value(null);

    return _db
        .collection('classes')
        .where('eleveIds', arrayContains: uid)
        .limit(1)
        .snapshots()
        .asyncMap((snap) async {
      if (snap.docs.isNotEmpty) {
        final d = snap.docs.first.data();
        return d['nom'] as String?;
      }

      DocumentSnapshot userDoc;
      try {
        userDoc = await _db.collection('users').doc(uid).get();
      } catch (e) {
        debugPrint('[Etudiant] classeNomStream: ERREUR lecture users/$uid → $e');
        return null;
      }

      if (!userDoc.exists) return null;

      final d = userDoc.data() as Map<String, dynamic>? ?? {};

      // Priorité : classeNom direct > classeId → fetch nom > niveau
      final classeNomDirect = d['classeNom'] as String?;
      if (classeNomDirect != null && classeNomDirect.isNotEmpty) {
        return classeNomDirect;
      }

      final classeId = d['classeId'] as String?;
      if (classeId != null && classeId.isNotEmpty) {
        try {
          final classeDoc = await _db.collection('classes').doc(classeId).get();
          if (classeDoc.exists) {
            return classeDoc.data()?['nom'] as String?;
          }
        } catch (e) {
          debugPrint('[Etudiant] classeNomStream: ERREUR lecture classes/$classeId → $e');
        }
      }

      return d['niveau'] as String?;
    });
  }

  // ── Profil complet de l'élève ────────────────────────────────────────────────
  /// Retourne {categorie, niveau, classeNom, displayName}.
  /// Cherche dans users/{uid}, puis dans la collection classes (eleveIds),
  /// puis via users/{uid}.classeId — en loggant chaque étape pour diagnostic.
  static Stream<Map<String, String>> profilStream() {
    final uid = _uid;
    if (uid.isEmpty) return Stream.value({});
    return _db.collection('users').doc(uid).snapshots().asyncMap((doc) async {
      final d = doc.exists ? (doc.data() ?? <String, dynamic>{}) : <String, dynamic>{};

      debugPrint('[EtudiantService] profilStream users/$uid → tous les champs: ${d.keys.toList()}');
      debugPrint('[EtudiantService] profilStream: categorie="${d['categorie']}" niveau="${d['niveau']}" classeNom="${d['classeNom']}" role="${d['role']}"');

      var cat    = (d['categorie'] as String?) ?? '';
      var niv    = (d['niveau'] as String?) ?? '';
      var cn     = (d['classeNom'] as String?) ?? '';
      final name = (d['displayName'] as String?) ?? '';

      // Fallback 1 : collection classes (eleveIds contient uid)
      if (cat.isEmpty || niv.isEmpty || cn.isEmpty) {
        try {
          final classSnap = await _db
              .collection('classes')
              .where('eleveIds', arrayContains: uid)
              .limit(1)
              .get();
          if (classSnap.docs.isNotEmpty) {
            final cd = classSnap.docs.first.data();
            debugPrint('[EtudiantService] profilStream: classe trouvée → nom="${cd['nom']}" niveau="${cd['niveau']}" categorie="${cd['categorie']}"');
            if (niv.isEmpty) niv = (cd['niveau'] as String?) ?? '';
            if (cn.isEmpty)  cn  = (cd['nom'] as String?) ?? '';
            if (cat.isEmpty) cat = (cd['categorie'] as String?) ?? '';
          } else {
            debugPrint('[EtudiantService] profilStream: aucune classe avec eleveIds contenant $uid');
          }
        } catch (e) {
          debugPrint('[EtudiantService] profilStream: erreur lookup classes: $e');
        }
      }

      // Fallback 2 : users/{uid}.classeId
      if (cn.isEmpty || niv.isEmpty) {
        final classeId = (d['classeId'] as String?) ?? '';
        if (classeId.isNotEmpty) {
          try {
            final classeDoc = await _db.collection('classes').doc(classeId).get();
            if (classeDoc.exists) {
              final cd = classeDoc.data() ?? <String, dynamic>{};
              debugPrint('[EtudiantService] profilStream: classeId=$classeId → nom="${cd['nom']}" niveau="${cd['niveau']}"');
              if (niv.isEmpty) niv = (cd['niveau'] as String?) ?? '';
              if (cn.isEmpty)  cn  = (cd['nom'] as String?) ?? '';
              if (cat.isEmpty) cat = (cd['categorie'] as String?) ?? '';
            }
          } catch (e) {
            debugPrint('[EtudiantService] profilStream: erreur lookup classeId=$classeId: $e');
          }
        }
      }

      debugPrint('[EtudiantService] profilStream RÉSULTAT → categorie="$cat" niveau="$niv" classeNom="$cn"');
      return {'categorie': cat, 'niveau': niv, 'classeNom': cn, 'displayName': name};
    });
  }

  // ── Devoirs ─────────────────────────────────────────────────────────────────
  static Stream<List<DevoirModel>> devoirsStream(String classeNom) {
    return _db
        .collection('devoirs')
        .where('classeNom', isEqualTo: classeNom)
        .snapshots()
        .handleError((Object e) {
      debugPrint('[Etudiant] devoirsStream ERROR [collection=devoirs, classeNom=$classeNom, uid=$_uid]: $e');
      throw e;
    }).map((s) {
      final list = s.docs.map(DevoirModel.fromFirestore).toList();
      list.sort((a, b) => b.dateEnvoi.compareTo(a.dateEnvoi));
      return list;
    });
  }

  // ── Tous les devoirs d'une classe (interactifs + PDF) ──────────────────────
  static Stream<List<DevoirModel>> allDevoirsStream(String classeNom) {
    if (classeNom.isEmpty) return Stream.value([]);
    return _db
        .collection('devoirs')
        .where('classeNom', isEqualTo: classeNom)
        .orderBy('dateEnvoi', descending: true)
        .snapshots()
        .handleError((Object e) {
      debugPrint('[Etudiant] allDevoirsStream ERROR [classeNom=$classeNom]: $e');
      throw e;
    }).map((s) => s.docs.map(DevoirModel.fromFirestore).toList());
  }

  // ── Soumissions ─────────────────────────────────────────────────────────────
  static Stream<List<SubmissionModel>> submissionsStream() {
    final uid = _uid;
    return _db
        .collection('submissions')
        .where('studentId', isEqualTo: uid)
        .snapshots()
        .handleError((Object e) {
      debugPrint('[Etudiant] submissionsStream ERROR [collection=submissions, uid=$uid]: $e');
      throw e;
    }).map((s) {
      final list = s.docs.map(SubmissionModel.fromFirestore).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  static Stream<SubmissionModel?> submissionForDevoir(String assignmentId) {
    final uid = _uid;
    return _db
        .collection('submissions')
        .where('studentId', isEqualTo: uid)
        .where('assignmentId', isEqualTo: assignmentId)
        .limit(1)
        .snapshots()
        .handleError((Object e) {
      debugPrint('[Etudiant] submissionForDevoir ERROR [uid=$uid, assignmentId=$assignmentId]: $e');
      throw e;
    }).map((s) {
      if (s.docs.isEmpty) return null;
      return SubmissionModel.fromFirestore(s.docs.first);
    });
  }

  // Soumission avec texte + pièces jointes multiples
  static Future<void> submitDevoirComplet({
    required String assignmentId,
    required String teacherId,
    required String devoirTitre,
    required String classeId,
    required String classeNom,
    String textReponse = '',
    List<File> fichiers = const [],
    List<String> nomsFichiers = const [],
    String commentaire = '',
  }) async {
    final uid = _uid;
    final user = FirebaseAuth.instance.currentUser;

    final piecesJointes = <Map<String, String>>[];
    for (var i = 0; i < fichiers.length; i++) {
      final nom = i < nomsFichiers.length
          ? nomsFichiers[i]
          : fichiers[i].path.split('/').last;
      final token = _storageToken();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref('submissions/$uid/${ts}_$nom');
      final bytes = await fichiers[i].readAsBytes();
      final snap = await ref.putData(
        bytes,
        SettableMetadata(
            customMetadata: {'firebaseStorageDownloadTokens': token}),
      );
      if (snap.state == TaskState.success) {
        final bucket = snap.ref.bucket;
        final encoded = Uri.encodeComponent(snap.ref.fullPath);
        final url =
            'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encoded?alt=media&token=$token';
        final ext = nom.split('.').last.toLowerCase();
        piecesJointes.add({'url': url, 'nom': nom, 'type': ext});
      }
    }

    final existingSnap = await _db
        .collection('submissions')
        .where('studentId', isEqualTo: uid)
        .where('assignmentId', isEqualTo: assignmentId)
        .limit(1)
        .get();

    final data = {
      'studentId': uid,
      'studentEmail': user?.email ?? '',
      'studentNom': user?.displayName ?? '',
      'assignmentId': assignmentId,
      'teacherId': teacherId,
      'devoirTitre': devoirTitre,
      'classeId': classeId,
      'classeNom': classeNom,
      'fileUrl': '',
      'fileType': '',
      'comment': commentaire,
      'textReponse': textReponse,
      'piecesJointes': piecesJointes,
      'createdAt': Timestamp.now(),
      'status': 'pending',
    };

    if (existingSnap.docs.isNotEmpty) {
      await existingSnap.docs.first.reference.update(data);
    } else {
      await _db.collection('submissions').add(data);
    }
  }

  static Future<void> submitDevoir({
    required String assignmentId,
    required String teacherId,
    File? file,
    String? fileName,
    String comment = '',
  }) async {
    final uid = _uid;
    final user = FirebaseAuth.instance.currentUser;
    String fileUrl = '';
    String fileType = '';

    if (file != null && fileName != null) {
      final token = _storageToken();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref('submissions/$uid/${ts}_$fileName');
      final bytes = await file.readAsBytes();
      final snap = await ref.putData(
        bytes,
        SettableMetadata(customMetadata: {'firebaseStorageDownloadTokens': token}),
      );
      if (snap.state != TaskState.success) {
        throw Exception('Upload soumission échoué (état: ${snap.state}).');
      }
      final bucket      = snap.ref.bucket;
      final encodedPath = Uri.encodeComponent(snap.ref.fullPath);
      fileUrl = 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media&token=$token';
      final ext = fileName.split('.').last.toLowerCase();
      fileType = ext;
    }

    await _db.collection('submissions').add({
      'studentId': uid,
      'studentEmail': user?.email ?? '',
      'assignmentId': assignmentId,
      'teacherId': teacherId,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'comment': comment,
      'createdAt': Timestamp.now(),
      'status': 'pending',
    });
  }

  // ── Notes ───────────────────────────────────────────────────────────────────
  // Filtre par eleveId : la règle Firestore n'autorise l'élève à lire
  // que ses propres notes — une requête par classeNom retournerait les
  // notes des autres élèves et serait refusée (permission-denied).
  static Stream<List<NoteModel>> notesStream(String classeNom) {
    final uid = _uid;
    return _db
        .collection('notes')
        .where('eleveId', isEqualTo: uid)
        .snapshots()
        .handleError((Object e) {
      debugPrint('[Etudiant] notesStream ERROR [collection=notes, eleveId=$uid]: $e');
      throw e;
    }).map((s) {
      final list = s.docs
          .map(NoteModel.fromFirestore)
          .where((n) => n.publie)
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  // ── Emploi du temps ─────────────────────────────────────────────────────────
  static Stream<List<EmploiSlot>> emploiStream(String classeNom) {
    return _db
        .collection('emplois_du_temps')
        .where('classeNom', isEqualTo: classeNom)
        .snapshots()
        .handleError((Object e) {
      debugPrint('[Etudiant] emploiStream ERROR [collection=emplois_du_temps, classeNom=$classeNom, uid=$_uid]: $e');
      throw e;
    }).map((s) {
      final list = s.docs.map(EmploiSlot.fromFirestore).toList();
      list.sort((a, b) {
        final cmp = a.jour.compareTo(b.jour);
        if (cmp != 0) return cmp;
        return a.heureDebut.compareTo(b.heureDebut);
      });
      return list;
    });
  }

  // ── Documents pédagogiques ──────────────────────────────────────────────────
  static Stream<List<DocumentPedagogique>> documentsStream(String classeNom) {
    final uid = _uid;
    Query<Map<String, dynamic>> query = _db.collection('documents_prof');
    if (classeNom.isNotEmpty) {
      query = query.where('classeNom', isEqualTo: classeNom);
    }

    return query.snapshots().handleError((Object e) {
      debugPrint('[Etudiant] documentsStream ERROR '
          '[collection=documents_prof, classeNom="$classeNom", uid=$uid, '
          'role=vérifier users/$uid]: $e');
      throw e;
    }).map((s) {
      final list = s.docs
          .map((doc) {
            try {
              return DocumentPedagogique.fromFirestore(doc);
            } catch (e) {
              debugPrint('[Etudiant] documentsStream: parse error doc=${doc.id} → $e');
              return null;
            }
          })
          .whereType<DocumentPedagogique>()
          .toList();
      list.sort((a, b) => b.dateDepot.compareTo(a.dateDepot));
      return list;
    });
  }

  // ── Annonces ────────────────────────────────────────────────────────────────
  static Stream<List<AnnonceModel>> annoncesStream() {
    final uid = _uid;
    return _db.collection('annonces').snapshots().handleError((Object e) {
      debugPrint('[Etudiant] annoncesStream ERROR '
          '[collection=annonces, uid=$uid, '
          'role=vérifier users/$uid, règle=annonces/{id} allow read]: $e');
      throw e;
    }).map((s) {
      final list = s.docs
          .map((doc) {
            try {
              return AnnonceModel.fromFirestore(doc);
            } catch (e) {
              debugPrint('[Etudiant] annoncesStream: parse error doc=${doc.id} → $e');
              return null;
            }
          })
          .whereType<AnnonceModel>()
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      if (list.length > 30) return list.sublist(0, 30);
      return list;
    });
  }

  // ── Compteurs ───────────────────────────────────────────────────────────────
  static Stream<int> devoirsEnAttenteStream(String classeNom) {
    final uid = _uid;
    return _db
        .collection('devoirs')
        .where('classeNom', isEqualTo: classeNom)
        .snapshots()
        .handleError((Object e) {
      debugPrint('[Etudiant] devoirsEnAttenteStream ERROR [classeNom=$classeNom, uid=$uid]: $e');
      throw e;
    }).asyncMap((devoirSnap) async {
      final subSnap = await _db
          .collection('submissions')
          .where('studentId', isEqualTo: uid)
          .get();
      final submittedIds = subSnap.docs
          .map((d) => d.data()['assignmentId'] as String? ?? '')
          .toSet();
      return devoirSnap.docs
          .where((d) => !submittedIds.contains(d.id))
          .length;
    });
  }

  static Stream<int> totalNotesStream(String classeNom) {
    final uid = _uid;
    return _db
        .collection('notes')
        .where('eleveId', isEqualTo: uid)
        .snapshots()
        .handleError((Object e) {
      debugPrint('[Etudiant] totalNotesStream ERROR [eleveId=$uid]: $e');
      throw e;
    }).map((s) => s.docs
            .where((d) => d.data()['publie'] == true)
            .length);
  }

  static Stream<int> documentsCountStream(String classeNom) {
    Query<Map<String, dynamic>> query = _db.collection('documents_prof');
    if (classeNom.isNotEmpty) {
      query = query.where('classeNom', isEqualTo: classeNom);
    }
    return query.snapshots().handleError((Object e) {
      debugPrint('[Etudiant] documentsCountStream ERROR [classeNom=$classeNom, uid=$_uid]: $e');
      throw e;
    }).map((s) => s.docs.length);
  }

  // ── Absences du mois en cours ─────────────────────────────────────────────
  /// Compte les enregistrements de présence avec statut='absent' pour l'élève
  /// courant sur le mois en cours. Les dates sont stockées en format 'YYYY-MM-DD'
  /// — la comparaison lexicographique fonctionne pour les filtres >= et <=.
  static Stream<int> absencesMonthStream() {
    final uid = _uid;
    if (uid.isEmpty) return Stream.value(0);
    final now = DateTime.now();
    final debut = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final finMois = DateTime(now.year, now.month + 1, 0);
    final fin = '${finMois.year}-${finMois.month.toString().padLeft(2, '0')}-${finMois.day.toString().padLeft(2, '0')}';
    return _db
        .collection('presences')
        .where('eleveId', isEqualTo: uid)
        .where('statut', isEqualTo: 'absent')
        .where('date', isGreaterThanOrEqualTo: debut)
        .where('date', isLessThanOrEqualTo: fin)
        .snapshots()
        .handleError((Object e) {
      debugPrint('[Etudiant] absencesMonthStream ERROR [uid=$uid]: $e');
      return;
    }).map((s) => s.docs.length);
  }
}
