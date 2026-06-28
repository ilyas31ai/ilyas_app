import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/disponibilite_model.dart';
import '../models/remplacement_model.dart';

class RemplacementService {
  static final _db = FirebaseFirestore.instance;

  // ─── Disponibilités ────────────────────────────────────────────────────────

  static Future<void> saveDisponibilite(
      String uid, DisponibiliteEnseignant dispo) async {
    await _db.collection('disponibilites').doc(uid).set(
          dispo.toMap(),
          SetOptions(merge: true),
        );
  }

  static Stream<DisponibiliteEnseignant?> disponibiliteStream(String uid) {
    return _db
        .collection('disponibilites')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists
            ? DisponibiliteEnseignant.fromMap(
                uid, snap.data() as Map<String, dynamic>)
            : null);
  }

  static Stream<List<DisponibiliteEnseignant>> allDisponibilitesStream() {
    return _db
        .collection('disponibilites')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => DisponibiliteEnseignant.fromMap(
                doc.id, doc.data()))
            .toList());
  }

  // ─── Absences ─────────────────────────────────────────────────────────────

  /// Déclare une absence pour un enseignant.
  /// Crée un document dans la sous-collection absences/{uid}/absences/{id}.
  static Future<String> declareAbsence({
    required String uid,
    required String nom,
    required String date,
    required String motif,
    String? commentaire,
  }) async {
    // 1. Créer le document de disponibilité s'il n'existe pas encore
    final parentRef = _db.collection('disponibilites').doc(uid);
    final parentSnap = await parentRef.get();
    if (!parentSnap.exists) {
      await parentRef.set({
        'uid': uid,
        'nom': nom,
        'email': '',
        'jours': [],
        'creneaux': [],
        'matieres': [],
        'niveaux': [],
        'classes': [],
        'disponibleAujourdhui': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // 2. Ajouter à la sous-collection absences
    final absRef = await parentRef.collection('absences').add({
      'uid': uid,
      'nom': nom,
      'date': date,
      'motif': motif,
      if (commentaire != null && commentaire.isNotEmpty)
        'commentaire': commentaire,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3. Marquer l'enseignant comme indisponible aujourd'hui si la date est aujourd'hui
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if (date == todayStr) {
      await parentRef.update({'disponibleAujourdhui': false});
    }

    return absRef.id;
  }

  // ─── Remplacements CRUD ───────────────────────────────────────────────────

  static Future<String> creerRemplacement(Remplacement r) async {
    final ref = await _db.collection('remplacements').add(r.toMap());
    // TODO: envoyer notification au remplaçant proposé
    return ref.id;
  }

  static Future<void> updateStatut(
    String id,
    RemplacementStatut statut, {
    String? remplacantUid,
    String? remplacantNom,
    String? validePar,
    String? valideParNom,
  }) async {
    final data = <String, dynamic>{
      'statut': statut.value,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (remplacantUid != null) {
      data['professeurRemplacantUid'] = remplacantUid;
    }
    if (remplacantNom != null) {
      data['professeurRemplacantNom'] = remplacantNom;
    }
    if (validePar != null) {
      data['valideParUid'] = validePar;
    }
    if (valideParNom != null) {
      data['valideParNom'] = valideParNom;
    }
    await _db.collection('remplacements').doc(id).update(data);
    // TODO: envoyer notification au remplaçant proposé
  }

  static Stream<List<Remplacement>> remplacementsStream(
      {RemplacementStatut? statut}) {
    Query<Map<String, dynamic>> query = _db
        .collection('remplacements')
        .orderBy('createdAt', descending: true);
    if (statut != null) {
      query = query.where('statut', isEqualTo: statut.value);
    }
    return query.snapshots().map((snap) =>
        snap.docs.map((doc) => Remplacement.fromFirestore(doc)).toList());
  }

  static Stream<List<Remplacement>> remplacementsDuJourStream(String date) {
    return _db
        .collection('remplacements')
        .where('date', isEqualTo: date)
        .orderBy('heureDebut')
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => Remplacement.fromFirestore(doc)).toList());
  }

  static Stream<List<Remplacement>> remplacementsParEnseignantStream(
      String uid) {
    return _db
        .collection('remplacements')
        .where('professeurRemplacantUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => Remplacement.fromFirestore(doc)).toList());
  }

  // ─── Stats ────────────────────────────────────────────────────────────────

  /// Retourne des stats rapides pour le tableau de bord.
  /// {disponibles, absents, courssSansEnseignant, enAttente, valides}
  static Future<Map<String, int>> statsRapides() async {
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final jourFr = _jourFr(today.weekday);

    // Disponibles aujourd'hui
    final dispoSnap = await _db
        .collection('disponibilites')
        .where('jours', arrayContains: jourFr)
        .get();
    final disponibles = dispoSnap.docs.length;

    // Absents aujourd'hui : compter les absences du jour
    int absents = 0;
    for (final doc in dispoSnap.docs) {
      final absSnap = await doc.reference
          .collection('absences')
          .where('date', isEqualTo: todayStr)
          .limit(1)
          .get();
      if (absSnap.docs.isNotEmpty) {
        absents++;
      }
    }

    // En attente
    final enAttenteSnap = await _db
        .collection('remplacements')
        .where('statut', isEqualTo: RemplacementStatut.enAttente.value)
        .get();
    final enAttente = enAttenteSnap.docs.length;

    // Validés aujourd'hui
    final valideSnap = await _db
        .collection('remplacements')
        .where('date', isEqualTo: todayStr)
        .where('statut', isEqualTo: RemplacementStatut.confirme.value)
        .get();
    final valides = valideSnap.docs.length;

    // Cours sans enseignant = remplacements en attente du jour
    final sansEnseignantSnap = await _db
        .collection('remplacements')
        .where('date', isEqualTo: todayStr)
        .where('statut', isEqualTo: RemplacementStatut.enAttente.value)
        .get();
    final courssSansEnseignant = sansEnseignantSnap.docs.length;

    return {
      'disponibles': disponibles,
      'absents': absents,
      'courssSansEnseignant': courssSansEnseignant,
      'enAttente': enAttente,
      'valides': valides,
    };
  }

  // ─── Recherche remplaçant (avec scoring) ─────────────────────────────────

  /// Recherche des remplaçants potentiels en scorant les candidats.
  // TODO: intégrer moteur IA pour ranking avancé
  static Future<List<DisponibiliteEnseignant>> rechercherRemplacants({
    required String matiere,
    required String jour,
    required String heureDebut,
    required String heureFin,
    String? niveau,
    String? cycle,
  }) async {
    final snap = await _db
        .collection('disponibilites')
        .where('jours', arrayContains: jour)
        .get();

    final today = DateTime.now();
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    // Compter les remplacements de la semaine par uid
    final remplacementsSnap = await _db
        .collection('remplacements')
        .where('date',
            isGreaterThanOrEqualTo:
                '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}')
        .where('date',
            isLessThan:
                '${weekEnd.year}-${weekEnd.month.toString().padLeft(2, '0')}-${weekEnd.day.toString().padLeft(2, '0')}')
        .get();

    final remplacementsParUid = <String, int>{};
    for (final doc in remplacementsSnap.docs) {
      final uid =
          (doc.data()['professeurRemplacantUid'] as String?) ?? '';
      if (uid.isNotEmpty) {
        remplacementsParUid[uid] = (remplacementsParUid[uid] ?? 0) + 1;
      }
    }

    final candidates = <MapEntry<DisponibiliteEnseignant, int>>[];

    for (final doc in snap.docs) {
      final dispo = DisponibiliteEnseignant.fromMap(doc.id, doc.data());

      // Vérifier créneau disponible
      bool creneauOk = dispo.creneaux.any((c) =>
          c.jour == jour &&
          _heureToMin(c.heureDebut) <= _heureToMin(heureDebut) &&
          _heureToMin(c.heureFin) >= _heureToMin(heureFin));

      int score = 0;
      if (creneauOk) {
        score += 40;
      }
      if (dispo.matieres.contains(matiere)) {
        score += 30;
      }
      if (niveau != null && dispo.niveaux.contains(niveau)) {
        score += 20;
      }
      final nbRempl = remplacementsParUid[dispo.uid] ?? 0;
      if (nbRempl == 0) {
        score += 10;
      }

      if (score > 0) {
        candidates.add(MapEntry(dispo, score));
      }
    }

    // Trier par score décroissant
    candidates.sort((a, b) => b.value.compareTo(a.value));
    return candidates.map((e) => e.key).toList();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  static int _heureToMin(String heure) {
    final parts = heure.split(':');
    if (parts.length < 2) {
      return 0;
    }
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  static String _jourFr(int weekday) {
    const jours = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];
    return jours[(weekday - 1).clamp(0, 6)];
  }

  static String todayStr() {
    final today = DateTime.now();
    return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  }
}
