import 'package:cloud_firestore/cloud_firestore.dart';

class XpModel {
  final String uid;
  final String displayName;
  final String photoUrl;
  final int xp;
  final List<String> badges;

  const XpModel({
    required this.uid,
    required this.displayName,
    this.photoUrl = '',
    required this.xp,
    required this.badges,
  });

  int get level => (xp / 200).floor() + 1;
  int get xpInCurrentLevel => xp % 200;
  int get xpToNextLevel => 200 - xpInCurrentLevel;
  double get levelProgress => xpInCurrentLevel / 200;

  String get levelTitle {
    if (level >= 20) return 'Maître';
    if (level >= 15) return 'Expert';
    if (level >= 10) return 'Avancé';
    if (level >= 5) return 'Intermédiaire';
    return 'Débutant';
  }

  factory XpModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return XpModel(
      uid: doc.id,
      displayName: d['displayName'] as String? ?? (d['email'] as String? ?? ''),
      photoUrl: d['photoUrl'] as String? ?? '',
      xp: (d['xp'] as num?)?.toInt() ?? 0,
      badges: List<String>.from(d['badges'] as List? ?? []),
    );
  }
}
