import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/school_model.dart';
import '../models/user_model.dart';

class UserService {
  static final _db = FirebaseFirestore.instance;

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  static String get _email => FirebaseAuth.instance.currentUser?.email ?? '';

  /// True while RegisterPage is writing the initial `users/{uid}` (+ `schools/{uid}`
  /// for direction) document for a brand new account. `authStateChanges()` fires the
  /// instant `createUserWithEmailAndPassword` resolves — before those writes happen —
  /// so without this guard the app root can mount MainShell early and its own
  /// `syncProfile()` call races the registration write, sometimes overwriting the
  /// just-chosen role/schoolId with defaults (role: eleve, schoolId: kDefaultSchoolId).
  static final ValueNotifier<bool> signupInProgress = ValueNotifier(false);

  /// Create profile on first signup, update lastSeen on subsequent logins.
  /// Silently ignores transient Firestore errors.
  static Future<void> syncProfile({UserRole? role}) async {
    final uid = _uid;
    final email = _email;
    if (uid.isEmpty || email.isEmpty) return;

    try {
      final ref = _db.collection('users').doc(uid);
      final snap = await ref.get();

      // Préfère le displayName Firebase Auth (défini à l'inscription via updateDisplayName)
      final authDisplayName = FirebaseAuth.instance.currentUser?.displayName;

      if (snap.exists) {
        final updates = <String, dynamic>{'lastSeen': FieldValue.serverTimestamp()};
        final storedRole = snap.data()?['role'] as String?;

        // Corrige le displayName si Firebase Auth a un vrai nom mais Firestore a
        // l'email en guise de nom (cas d'une inscription partiellement ratée)
        final storedName = snap.data()?['displayName'] as String?;
        if (authDisplayName != null &&
            authDisplayName.isNotEmpty &&
            authDisplayName != storedName) {
          updates['displayName'] = authDisplayName;
        }

        // Auto-correction du role : cherche d'abord schools/{uid} (accès direct O(1)),
        // puis si absent fait une requête par directeurId (cas migration).
        // Ne s'applique que si le role stocké est 'eleve' — valeur de secours.
        if (storedRole == 'eleve') {
          try {
            String? correctedSchoolId;
            final schoolDirect = await _db.collection('schools').doc(uid).get();
            if (schoolDirect.exists &&
                (schoolDirect.data()?['directeurId'] as String?) == uid) {
              correctedSchoolId = uid;
            } else {
              final schoolQuery = await _db
                  .collection('schools')
                  .where('directeurId', isEqualTo: uid)
                  .limit(1)
                  .get();
              if (schoolQuery.docs.isNotEmpty) {
                correctedSchoolId = schoolQuery.docs.first.id;
              }
            }
            if (correctedSchoolId != null) {
              updates['role'] = 'direction';
              updates['schoolId'] = correctedSchoolId;
            }
          } catch (_) {}
        }

        await ref.update(updates);
        // Re-run parent link in case children have logged in since last parent login
        if (storedRole == 'parent') {
          await _syncParentEnfantIds(uid, snap.data()?['email'] as String? ?? email);
        }
      } else {
        final displayName = (authDisplayName != null && authDisplayName.isNotEmpty)
            ? authDisplayName
            : (email.contains('@') ? email.split('@').first : email);
        // Detect if this email belongs to a parent before creating the profile
        final detectedRole = role ?? await _detectRole(email);
        await ref.set({
          'uid': uid,
          'email': email,
          'displayName': displayName,
          'role': detectedRole.value,
          // Établissement unique actuel (Phase 2) — tout nouveau compte y est
          // rattaché par défaut tant qu'un second établissement n'existe pas.
          'schoolId': kDefaultSchoolId,
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        });
        if (detectedRole == UserRole.parent) {
          await _syncParentEnfantIds(uid, email);
        } else {
          // Try to link pre-existing validated inscription
          await _linkEleveInscription(uid, email);
        }
      }
    } catch (_) {
      // Transient network error — will retry on next launch
    }
  }

  /// If a validated inscription exists for this email, copy classeId/classeNom/niveau
  /// and add the uid to classes/{classeId}.eleveIds.
  static Future<void> _linkEleveInscription(String uid, String email) async {
    try {
      final snap = await _db
          .collection('eleves')
          .where('email', isEqualTo: email)
          .where('statutInscription', isEqualTo: 'validee')
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return;

      final d = snap.docs.first.data();
      final classeId = d['classeId'] as String?;
      final classeNom = d['classeNom'] as String?;
      final niveau = d['niveau'] as String?;
      if (classeId == null || classeId.isEmpty) return;

      // 1. Mise à jour du profil élève — toujours autorisé (owner update)
      await _db.collection('users').doc(uid).update({
        'classeId': classeId,
        if (classeNom != null && classeNom.isNotEmpty) 'classeNom': classeNom,
        if (niveau != null && niveau.isNotEmpty) 'niveau': niveau,
      });
      // 2. Ajout dans classes.eleveIds — soft-fail (géré aussi par Direction)
      try {
        await _db.collection('classes').doc(classeId).update({
          'eleveIds': FieldValue.arrayUnion([uid]),
        });
      } catch (_) {}
      // Write authUid back so professors can link by UID instead of name
      await _db.collection('eleves').doc(snap.docs.first.id).update({'authUid': uid});
      // Update any already-logged-in parent's enfantIds
      final parentIds = List<String>.from(d['parentIds'] as List? ?? []);
      for (final parentDocId in parentIds) {
        try {
          final parentDoc = await _db.collection('parents').doc(parentDocId).get();
          final parentEmail = parentDoc.data()?['email'] as String?;
          if (parentEmail == null || parentEmail.isEmpty) continue;
          final parentUsers = await _db
              .collection('users')
              .where('email', isEqualTo: parentEmail)
              .where('role', isEqualTo: 'parent')
              .limit(1)
              .get();
          if (parentUsers.docs.isNotEmpty) {
            final updateMap = <String, dynamic>{
              'enfantIds': FieldValue.arrayUnion([uid]),
            };
            updateMap['enfantClasseIds'] = FieldValue.arrayUnion([classeId]);
            await _db.collection('users').doc(parentUsers.docs.first.id).update(updateMap);
          }
        } catch (_) {}
      }
    } catch (_) {
      // Best-effort
    }
  }

  /// Checks if an email belongs to a parent in the `parents` collection.
  static Future<UserRole> _detectRole(String email) async {
    try {
      final snap = await _db
          .collection('parents')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return UserRole.parent;
    } catch (_) {}
    return UserRole.eleve;
  }

  /// Resolves children's Auth UIDs from the `parents` collection and writes
  /// them to `users/{uid}.enfantIds`. Updates the parent's role if needed.
  static Future<bool> _syncParentEnfantIds(String uid, String email) async {
    try {
      final parentSnap = await _db
          .collection('parents')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (parentSnap.docs.isEmpty) return false;

      final eleveDocIds =
          List<String>.from(parentSnap.docs.first.data()['enfantIds'] as List? ?? []);
      if (eleveDocIds.isEmpty) return false;

      final authUids = <String>[];
      final classeIds = <String>[];
      for (final eleveDocId in eleveDocIds) {
        final eleveDoc = await _db.collection('eleves').doc(eleveDocId).get();
        final data = eleveDoc.data() ?? {};
        final authUid = data['authUid'] as String?;
        final classeId = data['classeId'] as String?;
        if (authUid != null && authUid.isNotEmpty) authUids.add(authUid);
        if (classeId != null && classeId.isNotEmpty) classeIds.add(classeId);
      }

      final update = <String, dynamic>{};
      if (authUids.isNotEmpty) update['enfantIds'] = authUids;
      if (classeIds.isNotEmpty) update['enfantClasseIds'] = classeIds;
      if (update.isNotEmpty) {
        await _db.collection('users').doc(uid).update(update);
        return true;
      }
      return false;
    } catch (_) {
      // Best-effort
      return false;
    }
  }

  /// Lie un parent à un enfant en cherchant l'enfant par email dans `users`.
  /// Met à jour enfantIds / enfantClasseIds du parent. Retourne `true` si la
  /// liaison a effectivement été établie (utilisé par l'inscription en
  /// fire-and-forget, et par l'Espace Parent pour permettre une nouvelle
  /// tentative si l'enfant ne s'était pas encore inscrit à ce moment-là).
  static Future<bool> linkParentToChildByEmail(
      String parentUid, String childEmail) async {
    if (parentUid.isEmpty || childEmail.isEmpty) return false;
    try {
      final snap = await _db
          .collection('users')
          .where('email', isEqualTo: childEmail)
          .limit(1)
          .get();

      final update = <String, dynamic>{};
      if (snap.docs.isNotEmpty) {
        final child = snap.docs.first.data();
        final childUid = child['uid'] as String? ?? snap.docs.first.id;
        final classeId = child['classeId'] as String? ?? '';
        if (childUid.isNotEmpty) {
          update['enfantIds'] = FieldValue.arrayUnion([childUid]);
        }
        if (classeId.isNotEmpty) {
          update['enfantClasseIds'] = FieldValue.arrayUnion([classeId]);
        }
        if (update.isNotEmpty) {
          await _db.collection('users').doc(parentUid).update(update);
          return true;
        }
      }

      // Fallback via collection `parents` (liaison pré-inscription)
      final parentEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      if (parentEmail.isNotEmpty) {
        return await _syncParentEnfantIds(parentUid, parentEmail);
      }
      return false;
    } catch (_) {
      // Best-effort — la liaison sera complétée à la prochaine connexion
      return false;
    }
  }

  /// Stream of the current authenticated user's profile.
  static Stream<UserModel?> currentUserStream() {
    final uid = _uid;
    if (uid.isEmpty) return Stream.value(null);
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map<UserModel?>(
            (snap) => snap.exists ? UserModel.fromDoc(snap) : null)
        .asBroadcastStream();
  }

  /// Établissement de l'utilisateur courant (Phase 2). Tant que le backfill
  /// n'a pas été exécuté, vaut [kDefaultSchoolId] pour tout profil existant.
  static Stream<String> currentSchoolIdStream() =>
      currentUserStream().map((u) => u?.schoolId ?? kDefaultSchoolId);

  /// Lecture ponctuelle du schoolId courant (premier élément du stream).
  static Future<String> currentSchoolId() => currentSchoolIdStream().first;

  /// All registered users except the current one.
  static Stream<List<UserModel>> allUsersStream() {
    final uid = _uid;
    return _db
        .collection('users')
        .snapshots()
        .map<List<UserModel>>((snap) => snap.docs
            .where((d) => d.id != uid)
            .map((d) => UserModel.fromDoc(d))
            .toList())
        .asBroadcastStream();
  }

  /// Users filtered by role ('eleve', 'professeur', 'admin').
  static Stream<List<UserModel>> usersByRoleStream(String role) {
    return _db
        .collection('users')
        .where('role', isEqualTo: role)
        .snapshots()
        .map<List<UserModel>>(
            (snap) => snap.docs.map((d) => UserModel.fromDoc(d)).toList())
        .asBroadcastStream();
  }

  /// Update fields on the current user's profile document.
  static Future<void> updateProfile(Map<String, dynamic> data) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    await _db.collection('users').doc(uid).update(data);
  }

  // Cache simple du schoolId courant — mis à jour à chaque appel de
  // currentUserStream(). Utilisé par les pages qui ont besoin du schoolId
  // sans pouvoir attendre un Future.
  static String? _cachedSchoolId;
  static String? get cachedSchoolId => _cachedSchoolId;

  /// Initialise le cache schoolId et retourne un Stream pour mise à jour continue.
  static Stream<UserModel?> currentUserStreamWithCache() {
    return currentUserStream().map((u) {
      if (u != null) _cachedSchoolId = u.schoolId;
      return u;
    });
  }
}
