import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'user_service.dart';

/// Crée les comptes élève (manuellement ou via import PDF/OCR) — logique
/// unique partagée par [DirectionElevesPage] et la page d'import PDF, pour
/// que les deux parcours produisent des comptes strictement identiques et
/// que l'élève importé apparaisse immédiatement dans la liste "Gestion des
/// élèves" (qui interroge users.role == 'eleve').
class EleveAccountService {
  /// Crée un compte Firebase Auth + document Firestore pour un élève.
  /// Utilise une application secondaire pour ne pas déconnecter l'admin.
  /// Les écritures Firestore (users + classes) se font via le compte
  /// Direction en batch atomique pour garantir la cohérence classe ↔ élèves.
  /// Retourne null si succès, ou le message d'erreur.
  static Future<String?> creerEleve({
    required String prenom,
    required String nom,
    required String email,
    required String password,
    String? adresse,
    String? telephone,
    String? ville,
    String? categorie,
    String? classeId,
    String? classeNom,
    String? niveau,
    String? dateNaissance,
    String? sexe,
    String? matricule,
    String? pereNom,
    String? pereTelephone,
    String? pereEmail,
    String? mereNom,
    String? mereTelephone,
    String? mereEmail,
    String? contactUrgenceNom,
    String? contactUrgenceTelephone,
    String? autresInfos,
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
      if (telephone != null && telephone.isNotEmpty) {
        data['telephone'] = telephone;
      }
      if (ville != null && ville.isNotEmpty) data['ville'] = ville;
      if (categorie != null && categorie.isNotEmpty) {
        data['categorie'] = categorie;
      }
      if (niveau != null && niveau.isNotEmpty) data['niveau'] = niveau;
      if (dateNaissance != null && dateNaissance.isNotEmpty) {
        data['dateNaissance'] = dateNaissance;
      }
      if (sexe != null && sexe.isNotEmpty) data['sexe'] = sexe;
      if (matricule != null && matricule.isNotEmpty) {
        data['matricule'] = matricule;
      }
      if (pereNom != null && pereNom.isNotEmpty) data['pereNom'] = pereNom;
      if (pereTelephone != null && pereTelephone.isNotEmpty) {
        data['pereTelephone'] = pereTelephone;
      }
      if (pereEmail != null && pereEmail.isNotEmpty) {
        data['pereEmail'] = pereEmail;
      }
      if (mereNom != null && mereNom.isNotEmpty) data['mereNom'] = mereNom;
      if (mereTelephone != null && mereTelephone.isNotEmpty) {
        data['mereTelephone'] = mereTelephone;
      }
      if (mereEmail != null && mereEmail.isNotEmpty) {
        data['mereEmail'] = mereEmail;
      }
      if (contactUrgenceNom != null && contactUrgenceNom.isNotEmpty) {
        data['contactUrgenceNom'] = contactUrgenceNom;
      }
      if (contactUrgenceTelephone != null &&
          contactUrgenceTelephone.isNotEmpty) {
        data['contactUrgenceTelephone'] = contactUrgenceTelephone;
      }
      if (autresInfos != null && autresInfos.isNotEmpty) {
        data['autresInfos'] = autresInfos;
      }
      if (classeId != null && classeId.isNotEmpty) {
        data['classeId'] = classeId;
        if (classeNom != null && classeNom.isNotEmpty) {
          data['classeNom'] = classeNom;
        }

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
}
