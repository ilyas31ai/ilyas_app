import 'dart:io';

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
  static final _storage = FirebaseStorage.instance;

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

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
  /// Retourne {categorie, niveau, classeNom, displayName} depuis users/{uid}.
  static Stream<Map<String, String>> profilStream() {
    final uid = _uid;
    if (uid.isEmpty) return Stream.value({});
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return <String, String>{};
      final d = (doc.data() as Map<String, dynamic>?) ?? {};
      return {
        'categorie': (d['categorie'] as String?) ?? '',
        'niveau': (d['niveau'] as String?) ?? '',
        'classeNom': (d['classeNom'] as String?) ?? '',
        'displayName': (d['displayName'] as String?) ?? '',
      };
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
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref('submissions/$uid/${ts}_$fileName');
      await ref.putFile(file);
      fileUrl = await ref.getDownloadURL();
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
}
