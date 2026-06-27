import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/school_model.dart';

/// Service de gestion des établissements scolaires (collection `schools`).
///
/// Phase 2 (multi-établissements) — seul [kDefaultSchoolId] existe pour
/// l'instant. Les méthodes CRUD s'activent progressivement à mesure que
/// la migration avance.
class SchoolService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _schools =>
      _db.collection('schools');

  // ── Lectures ────────────────────────────────────────────────────────────────

  static Stream<List<SchoolModel>> allSchoolsStream() => _schools
      .where('statut', isEqualTo: 'actif')
      .snapshots()
      .map((s) => s.docs.map(SchoolModel.fromDoc).toList());

  static Stream<SchoolModel?> schoolStream(String id) => _schools
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? SchoolModel.fromDoc(doc) : null);

  static Future<SchoolModel?> getSchool(String id) async {
    final doc = await _schools.doc(id).get();
    if (!doc.exists) return null;
    return SchoolModel.fromDoc(doc);
  }

  // ── Écriture ─────────────────────────────────────────────────────────────────

  static Future<String> createSchool(SchoolModel school) async {
    final doc = await _schools.add({
      ...school.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': FirebaseAuth.instance.currentUser?.uid ?? '',
    });
    return doc.id;
  }

  static Future<void> updateSchool(
      String id, Map<String, dynamic> data) async {
    await _schools.doc(id).update(data);
  }

  static Future<void> suspendSchool(String id) async {
    await _schools.doc(id).update({'statut': 'suspendu'});
  }

  // ── Seed ────────────────────────────────────────────────────────────────────

  /// Crée le document de l'établissement par défaut s'il n'existe pas encore.
  /// À appeler depuis [seedReferentiel] ou au premier lancement Admin.
  static Future<void> seedDefaultSchool({String nom = 'Établissement Principal'}) async {
    final ref = _schools.doc(kDefaultSchoolId);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'nom': nom,
      'type': 'mixte',
      'statut': 'actif',
      'campusIds': [],
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': FirebaseAuth.instance.currentUser?.uid ?? '',
    });
  }
}
