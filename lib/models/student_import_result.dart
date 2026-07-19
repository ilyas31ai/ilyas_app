/// Résultat d'une extraction de champ : la valeur trouvée (ou null) et si
/// elle a réellement été reconnue dans le document — permet de distinguer
/// "champ vide car absent du document" de "champ vide car non reconnu",
/// et à l'UI de mettre en évidence les champs non reconnus.
class ExtractedField {
  final String? value;
  final bool found;

  const ExtractedField({this.value, this.found = false});
  const ExtractedField.empty() : value = null, found = false;

  bool get isEmpty => value == null || value!.trim().isEmpty;
}

/// Données d'un élève (+ parents) extraites d'un document (PDF, image…) par
/// un [DocumentFieldParser]. Toutes les données de la spécification
/// "Informations à extraire" y figurent ; les champs absents du document
/// restent à [ExtractedField.empty] plutôt que d'être devinés.
class StudentImportResult {
  // Élève
  final ExtractedField nom;
  final ExtractedField prenom;
  final ExtractedField dateNaissance;
  final ExtractedField sexe;
  final ExtractedField classe;
  final ExtractedField matricule;

  // Père
  final ExtractedField pereNom;
  final ExtractedField pereTelephone;
  final ExtractedField pereEmail;

  // Mère
  final ExtractedField mereNom;
  final ExtractedField mereTelephone;
  final ExtractedField mereEmail;

  // Informations générales
  final ExtractedField adresse;
  final ExtractedField ville;
  final ExtractedField contactUrgenceNom;
  final ExtractedField contactUrgenceTelephone;

  /// Lignes du document non rattachées à un champ reconnu — conservées
  /// telles quelles pour que la Direction ne perde aucune information utile
  /// même si le parseur ne les a pas comprises.
  final String autresInfos;

  /// Texte brut complet issu de l'OCR (toutes pages concaténées) — utile
  /// pour diagnostiquer une mauvaise reconnaissance.
  final String rawText;

  /// Nom du parseur ayant produit ce résultat (diagnostic / sélection du
  /// meilleur parseur parmi plusieurs modèles).
  final String parserName;

  const StudentImportResult({
    this.nom = const ExtractedField.empty(),
    this.prenom = const ExtractedField.empty(),
    this.dateNaissance = const ExtractedField.empty(),
    this.sexe = const ExtractedField.empty(),
    this.classe = const ExtractedField.empty(),
    this.matricule = const ExtractedField.empty(),
    this.pereNom = const ExtractedField.empty(),
    this.pereTelephone = const ExtractedField.empty(),
    this.pereEmail = const ExtractedField.empty(),
    this.mereNom = const ExtractedField.empty(),
    this.mereTelephone = const ExtractedField.empty(),
    this.mereEmail = const ExtractedField.empty(),
    this.adresse = const ExtractedField.empty(),
    this.ville = const ExtractedField.empty(),
    this.contactUrgenceNom = const ExtractedField.empty(),
    this.contactUrgenceTelephone = const ExtractedField.empty(),
    this.autresInfos = '',
    this.rawText = '',
    this.parserName = '',
  });

  /// Nombre de champs structurés effectivement reconnus — sert à comparer
  /// plusieurs parseurs/modèles et retenir le meilleur résultat.
  int get champsReconnus => [
        nom,
        prenom,
        dateNaissance,
        sexe,
        classe,
        matricule,
        pereNom,
        pereTelephone,
        pereEmail,
        mereNom,
        mereTelephone,
        mereEmail,
        adresse,
        ville,
        contactUrgenceNom,
        contactUrgenceTelephone,
      ].where((f) => f.found).length;
}
