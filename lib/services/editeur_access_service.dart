import 'package:firebase_auth/firebase_auth.dart';

/// Liste blanche des UID Firebase autorisés à accéder à l'Espace Éditeur
/// (propriétaire de SCOLARAI). Volontairement indépendant du rôle Firestore
/// (`users/{uid}.role`) : un compte Direction/admin n'y a pas accès s'il
/// n'est pas dans cette liste, et cette liste reste valable même si le rôle
/// Firestore de l'exploitant venait à changer.
class EditeurAccessService {
  EditeurAccessService._();

  static const Set<String> _allowedUids = {
    'of6wqbqQCKdffN7E4N9Od8TZyGX2', // ilyas31ai@outlook.fr — propriétaire SCOLARAI
  };

  /// true si l'utilisateur Firebase actuellement connecté figure dans la
  /// liste blanche. Vérifié à la fois côté client (cet appel, pour l'UI) et
  /// côté serveur (règles Firestore `isEditeurUid()`), qui restent la seule
  /// protection réelle des données.
  static bool get isAuthorized {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && _allowedUids.contains(uid);
  }
}
