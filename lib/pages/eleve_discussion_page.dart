import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../widgets/user_avatar.dart';

/// Page Discussion de l'élève — permet de contacter ses professeurs assignés.
/// La liste des profs est dérivée de la classe de l'élève (emplois_du_temps).
class EleveDiscussionPage extends StatefulWidget {
  const EleveDiscussionPage({super.key});

  @override
  State<EleveDiscussionPage> createState() => _EleveDiscussionPageState();
}

class _EleveDiscussionPageState extends State<EleveDiscussionPage> {
  static final _fs = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  static String get _email => FirebaseAuth.instance.currentUser?.email ?? '';

  late final Future<List<UserModel>> _profsFuture;

  @override
  void initState() {
    super.initState();
    _profsFuture = _loadProfesseurs();
  }

  Future<List<UserModel>> _loadProfesseurs() async {
    if (_uid.isEmpty) {
      throw Exception('Session expirée. Reconnectez-vous.');
    }
    // Lecture du profil — vérification du rôle et récupération de classeId
    final userDoc = await _fs.collection('users').doc(_uid).get();
    final data = userDoc.data() ?? {};

    // Garde de rôle : cette page est réservée aux élèves
    final role = data['role'] as String? ?? '';
    if (role.isNotEmpty && role != 'eleve') {
      throw Exception(
          'Cette fonctionnalité est réservée aux élèves.');
    }
    var classeId = data['classeId'] as String? ?? '';

    if (classeId.isEmpty) {
      // Auto-réparation : chercher la classe dont eleveIds contient cet élève
      // (classes est lisible par tous les utilisateurs authentifiés)
      try {
        final snap = await _fs
            .collection('classes')
            .where('eleveIds', arrayContains: _uid)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final cd = snap.docs.first.data();
          classeId = snap.docs.first.id;
          // Mise à jour silencieuse du profil (owner rule — champs non restreints)
          _fs.collection('users').doc(_uid).update({
            'classeId': classeId,
            if ((cd['nom'] as String? ?? '').isNotEmpty) 'classeNom': cd['nom'],
            if ((cd['niveau'] as String? ?? '').isNotEmpty) 'niveau': cd['niveau'],
            if ((cd['professeurId'] as String? ?? '').isNotEmpty) 'profId': cd['professeurId'],
            if ((cd['professeurEmail'] as String? ?? '').isNotEmpty) 'profEmail': cd['professeurEmail'],
            if ((cd['professeurDisplayName'] as String? ?? '').isNotEmpty)
              'profDisplayName': cd['professeurDisplayName'],
          }).ignore();
          // Retour anticipé si le professeurId est disponible dans le document classe
          final rProfId = cd['professeurId'] as String? ?? '';
          final rProfEmail = cd['professeurEmail'] as String? ?? '';
          if (rProfId.isNotEmpty) {
            final dn = cd['professeurDisplayName'] as String? ?? '';
            final mat = cd['professeurMatiere'] as String? ?? '';
            return [
              UserModel(
                uid: rProfId,
                email: rProfEmail,
                displayName: dn.isNotEmpty ? dn : rProfEmail.split('@').first,
                role: UserRole.professeur,
                matiere: mat.isNotEmpty ? mat : null,
              )
            ];
          }
        }
      } catch (_) {}
      if (classeId.isEmpty) {
        throw Exception(
            'Aucune classe assignée. Contactez la Direction pour être affecté à une classe.');
      }
    }

    final profId = data['profId'] as String? ?? '';
    final profEmail = data['profEmail'] as String? ?? '';

    if (profId.isNotEmpty && profEmail.isNotEmpty) {
      final displayName = (data['profDisplayName'] as String? ?? '').isNotEmpty
          ? data['profDisplayName'] as String
          : profEmail.split('@').first;
      final matiere = data['profMatiere'] as String?;
      return [
        UserModel(
          uid: profId,
          email: profEmail,
          displayName: displayName,
          role: UserRole.professeur,
          matiere: (matiere != null && matiere.isNotEmpty) ? matiere : null,
        )
      ];
    }

    // profId absent — fallbacks
    // Fallback A : emplois_du_temps
    final profIds = <String>{};
    try {
      final emploiSnap = await _fs
          .collection('emplois_du_temps')
          .where('classeId', isEqualTo: classeId)
          .get();
      profIds.addAll(emploiSnap.docs
          .map((d) => d.data()['professeurId'] as String? ?? '')
          .where((id) => id.isNotEmpty && id != _uid));
    } catch (_) {}

    // Fallback B : professeurId depuis le document classe
    String classProfId = '';
    Map<String, dynamic> classeData = {};
    try {
      final classeDoc = await _fs.collection('classes').doc(classeId).get();
      classeData = classeDoc.data() ?? {};
      classProfId = classeData['professeurId'] as String? ?? '';
      if (classProfId.isNotEmpty && classProfId != _uid) profIds.add(classProfId);
    } catch (_) {}

    if (profIds.isEmpty) {
      throw Exception(
          'Aucun professeur assigné à votre classe. Contactez la Direction.');
    }

    // Fallback C : charger le profil depuis users/
    final profs = <UserModel>[];
    for (final pid in profIds.take(15)) {
      try {
        final doc = await _fs.collection('users').doc(pid).get();
        if (doc.exists) {
          final model = UserModel.fromDoc(doc);
          if (model.role == UserRole.professeur) {
            profs.add(model);
            continue;
          }
        }
      } catch (_) {}
      // Fallback D : email stocké dans le document classe
      if (pid == classProfId) {
        final email = classeData['professeurEmail'] as String? ?? '';
        if (email.isNotEmpty) {
          final dn = classeData['professeurDisplayName'] as String?;
          final mat = classeData['professeurMatiere'] as String?;
          profs.add(UserModel(
            uid: pid,
            email: email,
            displayName: (dn != null && dn.isNotEmpty) ? dn : email.split('@').first,
            role: UserRole.professeur,
            matiere: (mat != null && mat.isNotEmpty) ? mat : null,
          ));
        }
      }
    }

    if (profs.isEmpty) {
      throw Exception(
          'Profil professeur introuvable. Contactez la Direction.');
    }

    profs.sort((a, b) => a.displayName.compareTo(b.displayName));
    return profs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Contacter mes professeurs',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: FutureBuilder<List<UserModel>>(
        future: _profsFuture,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)));
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_off_outlined,
                        color: Colors.white24, size: 48),
                    const SizedBox(height: 14),
                    Text(
                      '${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }
          final profs = snap.data ?? [];
          if (profs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_off_outlined,
                        color: Colors.white24, size: 52),
                    SizedBox(height: 14),
                    Text(
                      'Aucun professeur assigné à votre classe.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Contactez la Direction pour être affecté à une classe.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }
          return Column(
            children: [
              _InfoBanner(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: profs.length,
                  itemBuilder: (ctx, i) => _ProfContactTile(
                    prof: profs[i],
                    currentEmail: _email,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Bannière info ────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 16),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Posez vos questions pédagogiques à vos professeurs. '
              'Conversations privées et sécurisées.',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tuile professeur ─────────────────────────────────────────────────────────

class _ProfContactTile extends StatelessWidget {
  final UserModel prof;
  final String currentEmail;

  const _ProfContactTile(
      {required this.prof, required this.currentEmail});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        '/discussion',
        arguments: {
          'name': prof.email,
          'user': currentEmail,
          'displayName':
              prof.displayName.isNotEmpty ? prof.displayName : prof.username,
        },
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            UserAvatar(
                username: prof.email,
                radius: 22,
                showStatus: true,
                photoUrl: prof.photoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prof.displayName.isNotEmpty
                        ? prof.displayName
                        : prof.username,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                  if (prof.matiere != null && prof.matiere!.isNotEmpty)
                    Text(
                      prof.matiere!,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Professeur',
                style: TextStyle(
                    color: Color(0xFF0F766E),
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }
}
