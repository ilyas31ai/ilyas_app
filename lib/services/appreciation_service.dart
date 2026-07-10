import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/appreciation_model.dart';
import '../models/note_model.dart';
import '../models/user_model.dart';
import 'user_service.dart';

class AppreciationService {
  static final _db = FirebaseFirestore.instance;
  static final _col = _db.collection('appreciations');

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Lecture ───────────────────────────────────────────────────────────────

  /// Stream de toutes les appréciations d'une classe pour un trimestre.
  static Stream<List<AppreciationModel>> streamByClasse({
    required String classeId,
    required int trimestre,
    required int anneeScol,
  }) {
    return _col
        .where('classeId', isEqualTo: classeId)
        .where('trimestre', isEqualTo: trimestre)
        .where('anneeScol', isEqualTo: anneeScol)
        .where('professeurId', isEqualTo: _uid)
        .snapshots()
        .map((s) =>
            s.docs.map(AppreciationModel.fromFirestore).toList());
  }

  /// Stream des appréciations d'un élève (pour la page élève / parent).
  static Stream<List<AppreciationModel>> streamByEleve({
    required String eleveId,
    int? trimestre,
  }) {
    Query<Map<String, dynamic>> q =
        _col.where('eleveId', isEqualTo: eleveId);
    if (trimestre != null) {
      q = q.where('trimestre', isEqualTo: trimestre);
    }
    return q.snapshots().map((s) =>
        s.docs.map(AppreciationModel.fromFirestore).toList());
  }

  // ── Écriture ──────────────────────────────────────────────────────────────

  /// Upsert d'une appréciation.  L'ID est prédictible → idempotent.
  static Future<void> save({
    required String eleveId,
    required String eleveNom,
    required String elevePrenom,
    required String classeId,
    required String classeNom,
    required String matiere,
    required int trimestre,
    required int anneeScol,
    required String texte,
    String professeurNom = '',
    String schoolId = 'ecole_default',
  }) async {
    final uid = _uid;
    if (uid.isEmpty) throw Exception('Non authentifié');

    final id = AppreciationModel.docId(
      professeurId: uid,
      eleveId: eleveId,
      classeId: classeId,
      trimestre: trimestre,
      anneeScol: anneeScol,
    );

    await _col.doc(id).set(
      {
        'schoolId': schoolId,
        'professeurId': uid,
        'professeurNom': professeurNom,
        'eleveId': eleveId,
        'eleveNom': eleveNom,
        'elevePrenom': elevePrenom,
        'classeId': classeId,
        'classeNom': classeNom,
        'matiere': matiere,
        'trimestre': trimestre,
        'anneeScol': anneeScol,
        'texte': texte.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // ── Helpers notes ─────────────────────────────────────────────────────────

  /// Calcule les moyennes par élève pour une classe/trimestre donnés.
  /// Ne lit que les notes du professeur connecté.
  static Future<Map<String, double>> moyennesParEleve({
    required String classeId,
    required int trimestre,
  }) async {
    final snap = await _db
        .collection('notes')
        .where('classeId', isEqualTo: classeId)
        .where('professeurId', isEqualTo: _uid)
        .where('publie', isEqualTo: true)
        .get();

    final byEleve = <String, List<double>>{};
    for (final doc in snap.docs) {
      final n = NoteModel.fromFirestore(doc);
      if (_trimestreDe(n.date) != trimestre) continue;
      (byEleve[n.eleveId] ??= []).add(n.sur20);
    }
    return byEleve.map(
      (uid, vals) =>
          MapEntry(uid, vals.reduce((a, b) => a + b) / vals.length),
    );
  }

  static int _trimestreDe(DateTime d) {
    final m = d.month;
    if (m >= 9 && m <= 11) return 1;
    if (m == 12 || m <= 2) return 2;
    return 3;
  }

  /// Liste des élèves d'une classe depuis `users`.
  static Stream<List<UserModel>> elevesStream(String classeNom) {
    if (classeNom.isEmpty) return Stream.value([]);
    return _db
        .collection('users')
        .where('role', isEqualTo: 'eleve')
        .where('classeNom', isEqualTo: classeNom)
        .snapshots()
        .asyncMap((s) async {
      // Isolation multi-établissement : deux écoles peuvent avoir une classe
      // du même nom — ne garder que les élèves de l'établissement du
      // professeur connecté (cf. ProfesseurService.elevesParClasseStream).
      final mySchoolId = await UserService.currentSchoolId();
      final list = s.docs
          .map(UserModel.fromDoc)
          .where((u) => u.schoolId == mySchoolId)
          .toList();
      list.sort((a, b) => a.displayName.compareTo(b.displayName));
      return list;
    });
  }

  /// Liste des matières déjà saisies par le prof pour une classe.
  static Future<List<String>> matieresForClasse(String classeId) async {
    final snap = await _db
        .collection('notes')
        .where('classeId', isEqualTo: classeId)
        .where('professeurId', isEqualTo: _uid)
        .get();
    final mats = snap.docs
        .map((d) => d.data()['matiere'] as String? ?? '')
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return mats;
  }
}
