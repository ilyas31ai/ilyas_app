import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/school_model.dart';
import '../models/support_ticket_model.dart';
import '../models/user_model.dart';
import 'storage_service.dart';

/// Module Support & Suggestions : envoi de demandes (bug/suggestion/
/// question/avis) par tout utilisateur, consultation et suivi par la
/// Direction. Voir [SupportTicketModel] pour la structure des données.
class SupportService {
  static final _db = FirebaseFirestore.instance;
  static const _collection = 'support_tickets';
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Crée une demande. [screenshot] est optionnel — envoyé sur Firebase
  /// Storage avant l'écriture du document si fourni. Retourne un message
  /// d'erreur (à afficher à l'utilisateur) ou `null` en cas de succès.
  static Future<String?> creerTicket({
    required SupportTicketType type,
    required String sujet,
    required String description,
    File? screenshot,
  }) async {
    final uid = _uid;
    if (uid.isEmpty) return 'Vous devez être connecté pour envoyer une demande.';

    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      final profile = userDoc.exists ? UserModel.fromDoc(userDoc) : null;

      String? etablissementNom;
      final schoolId = profile?.schoolId ?? kDefaultSchoolId;
      try {
        final schoolDoc = await _db.collection('schools').doc(schoolId).get();
        if (schoolDoc.exists) {
          etablissementNom = SchoolModel.fromDoc(schoolDoc).nom;
        }
      } catch (_) {}

      final docRef = _db.collection(_collection).doc();

      String? screenshotUrl;
      if (screenshot != null) {
        screenshotUrl =
            await StorageService.uploadSupportScreenshot(screenshot, docRef.id);
      }

      final ticket = SupportTicketModel(
        id: docRef.id,
        userId: uid,
        userName: profile?.displayName.isNotEmpty == true
            ? profile!.displayName
            : (FirebaseAuth.instance.currentUser?.email ?? 'Utilisateur'),
        userEmail: FirebaseAuth.instance.currentUser?.email ?? '',
        userRole: profile?.role.value ?? '',
        etablissementNom: etablissementNom,
        type: type,
        sujet: sujet.trim(),
        description: description.trim(),
        screenshotUrl: screenshotUrl,
        appVersion: await _appVersion(),
        deviceInfo: await _deviceInfo(),
      );

      await docRef.set(ticket.toMap());
      return null;
    } catch (e) {
      return 'Erreur lors de l\'envoi de la demande : $e';
    }
  }

  /// Toutes les demandes, triées de la plus récente à la plus ancienne —
  /// utilisé par le tableau de bord Direction.
  static Stream<List<SupportTicketModel>> ticketsStream() {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(SupportTicketModel.fromDoc).toList());
  }

  static Future<void> changerStatut(
      String ticketId, SupportTicketStatut statut) {
    return _db.collection(_collection).doc(ticketId).update({
      'statut': statut.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Enregistre une réponse interne à une demande. Ne notifie pas encore
  /// l'utilisateur et n'est affichée dans aucune UI côté utilisateur — voir
  /// la note de [SupportTicketModel] : structure prête pour une future
  /// fonctionnalité de réponse directe.
  static Future<void> enregistrerReponse(
      String ticketId, String reponse) async {
    final user = FirebaseAuth.instance.currentUser;
    await _db.collection(_collection).doc(ticketId).update({
      'reponse': reponse.trim(),
      'reponseAt': FieldValue.serverTimestamp(),
      'reponseParNom': user?.displayName?.isNotEmpty == true
          ? user!.displayName
          : (user?.email ?? ''),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<String> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return 'inconnue';
    }
  }

  static Future<String> _deviceInfo() async {
    try {
      if (kIsWeb) return 'Web';
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await plugin.androidInfo;
        return '${a.manufacturer} ${a.model} • Android ${a.version.release}';
      }
      if (Platform.isIOS) {
        final i = await plugin.iosInfo;
        return '${i.name} ${i.utsname.machine} • iOS ${i.systemVersion}';
      }
      return Platform.operatingSystem;
    } catch (_) {
      return 'inconnu';
    }
  }
}
