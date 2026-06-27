import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cycle_model.dart';

/// Service de lecture et d'initialisation des référentiels cycles/niveaux.
///
/// Les collections `cycles` et `niveaux` sont globales (pas de `schoolId`).
/// [seedReferentiel] ne doit être déclenché qu'une seule fois depuis l'interface
/// Admin — il utilise `SetOptions(merge: true)` donc il est idempotent.
class CycleService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _cycles =>
      _db.collection('cycles');

  static CollectionReference<Map<String, dynamic>> get _niveaux =>
      _db.collection('niveaux');

  // ── Lectures ────────────────────────────────────────────────────────────────

  static Stream<List<CycleModel>> cyclesStream() => _cycles
      .snapshots()
      .map((s) => s.docs.map(CycleModel.fromFirestore).toList());

  static Stream<List<NiveauModel>> niveauxByCycleStream(String cycleId) =>
      _niveaux
          .where('cycleId', isEqualTo: cycleId)
          .orderBy('ordre')
          .snapshots()
          .map((s) => s.docs.map(NiveauModel.fromFirestore).toList());

  static Stream<List<NiveauModel>> allNiveauxStream() => _niveaux
      .orderBy('ordre')
      .snapshots()
      .map((s) => s.docs.map(NiveauModel.fromFirestore).toList());

  static Future<NiveauModel?> getNiveau(String niveauId) async {
    final doc = await _niveaux.doc(niveauId).get();
    if (!doc.exists) return null;
    return NiveauModel.fromFirestore(doc);
  }

  /// Vérifie si le référentiel est déjà initialisé.
  static Future<bool> isSeeded() async {
    final snap = await _cycles.limit(1).get();
    return snap.docs.isNotEmpty;
  }

  // ── Seed ────────────────────────────────────────────────────────────────────

  /// Initialise le référentiel algérien cycles/niveaux. Idempotent (merge).
  static Future<void> seedReferentiel() async {
    const data = [
      (
        id: 'maternelle',
        nom: 'Maternelle',
        niveaux: [
          (id: 'ps', nom: 'PS', ordre: 1),
          (id: 'ms', nom: 'MS', ordre: 2),
          (id: 'gs', nom: 'GS', ordre: 3),
        ]
      ),
      (
        id: 'primaire',
        nom: 'Primaire',
        niveaux: [
          (id: '1ap', nom: '1ère AP', ordre: 1),
          (id: '2ap', nom: '2ème AP', ordre: 2),
          (id: '3ap', nom: '3ème AP', ordre: 3),
          (id: '4ap', nom: '4ème AP', ordre: 4),
          (id: '5ap', nom: '5ème AP', ordre: 5),
        ]
      ),
      (
        id: 'college',
        nom: 'Moyen',
        niveaux: [
          (id: '1am', nom: '1AM', ordre: 1),
          (id: '2am', nom: '2AM', ordre: 2),
          (id: '3am', nom: '3AM', ordre: 3),
          (id: '4am', nom: '4AM', ordre: 4),
        ]
      ),
      (
        id: 'lycee',
        nom: 'Secondaire',
        niveaux: [
          (id: '1as', nom: '1AS', ordre: 1),
          (id: '2as', nom: '2AS', ordre: 2),
          (id: '3as', nom: '3AS', ordre: 3),
        ]
      ),
      (
        id: 'universite',
        nom: 'Université',
        niveaux: [
          (id: 'l1', nom: 'L1', ordre: 1),
          (id: 'l2', nom: 'L2', ordre: 2),
          (id: 'l3', nom: 'L3', ordre: 3),
          (id: 'm1', nom: 'M1', ordre: 4),
          (id: 'm2', nom: 'M2', ordre: 5),
        ]
      ),
    ];

    // Firestore batch max = 500 writes — notre seed est bien en dessous.
    final batch = _db.batch();

    for (final cycle in data) {
      final niveauIds = <String>[];
      for (final n in cycle.niveaux) {
        final niveauId = '${cycle.id}_${n.id}';
        niveauIds.add(niveauId);
        batch.set(
          _niveaux.doc(niveauId),
          {'cycleId': cycle.id, 'nom': n.nom, 'ordre': n.ordre},
          SetOptions(merge: true),
        );
      }
      batch.set(
        _cycles.doc(cycle.id),
        {'nom': cycle.nom, 'niveauIds': niveauIds},
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }
}
