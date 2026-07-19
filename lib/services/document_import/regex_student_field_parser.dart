import '../../models/student_import_result.dart';
import 'document_field_parser.dart';

/// Parseur générique par reconnaissance de libellés (regex), conçu pour des
/// dossiers d'inscription "classiques" en français, quel que soit
/// l'établissement d'origine (labels usuels : "Nom", "Prénom", "Date de
/// naissance", "Sexe", "Classe", "Matricule", "Père", "Mère", "Téléphone",
/// "Email", "Adresse", "Ville", "Contact d'urgence"…).
///
/// N'invente jamais de valeur : un champ absent du texte reste
/// [ExtractedField.empty]. Pour un établissement au formulaire trop
/// différent, ajouter un [DocumentFieldParser] dédié plutôt que de
/// complexifier celui-ci — voir [StudentDocumentParsing].
class RegexStudentFieldParser implements DocumentFieldParser {
  @override
  final String name = 'regex-fr-generic';

  static final _emailRe =
      RegExp(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}');
  static final _phoneRe = RegExp(
      r'(?:\+?\d{1,3}[ .\-]?)?0?[1-9](?:[ .\-]?\d{2}){4}');
  static final _dateRe = RegExp(r'(\d{1,2})\s*[/\-.]\s*(\d{1,2})\s*[/\-.]\s*(\d{2,4})');

  @override
  StudentImportResult parse(String rawText) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final consumed = List<bool>.filled(lines.length, false);

    // Un label court comme "nom" ne doit matcher que comme mot entier — sans
    // cette garde, "nom" matche aussi à l'intérieur de "prénom" (p-r-é-NOM),
    // faisant capturer par erreur la ligne "Prénom : Ahmed" par le champ Nom.
    int findWordBoundaryMatch(String norm, String labelNorm) {
      var searchFrom = 0;
      while (true) {
        final idx = norm.indexOf(labelNorm, searchFrom);
        if (idx < 0) return -1;
        final beforeOk = idx == 0 || !RegExp(r'[a-z0-9]').hasMatch(norm[idx - 1]);
        final afterPos = idx + labelNorm.length;
        final afterOk = afterPos >= norm.length ||
            !RegExp(r'[a-z0-9]').hasMatch(norm[afterPos]);
        if (beforeOk && afterOk) return idx;
        searchFrom = idx + 1;
      }
    }

    ExtractedField findLabeled(List<String> labels, {List<String> avoid = const []}) {
      for (var i = 0; i < lines.length; i++) {
        if (consumed[i]) continue;
        final norm = _normalize(lines[i]);
        if (avoid.any((a) => norm.contains(_normalize(a)))) continue;
        for (final label in labels) {
          final labelNorm = _normalize(label);
          final idx = findWordBoundaryMatch(norm, labelNorm);
          if (idx < 0) continue;
          // Valeur sur la même ligne, après le libellé et un séparateur.
          final after = lines[i].substring(_mapIndex(lines[i], idx) + label.length);
          final sameLine = after.replaceFirst(RegExp(r'^\s*[:\-–]\s*'), '').trim();
          if (sameLine.isNotEmpty) {
            consumed[i] = true;
            return ExtractedField(value: sameLine, found: true);
          }
          // Sinon, valeur sur la ligne suivante non consommée.
          for (var j = i + 1; j < lines.length; j++) {
            if (consumed[j]) continue;
            if (lines[j].isEmpty) continue;
            consumed[i] = true;
            consumed[j] = true;
            return ExtractedField(value: lines[j], found: true);
          }
        }
      }
      return const ExtractedField.empty();
    }

    // ── Élève ──────────────────────────────────────────────────────────────
    // `avoid` empêche les libellés génériques ("nom", "prénom") de capturer
    // par erreur une ligne "Nom du père"/"Prénom de la mère" lorsque la
    // section parents précède la section élève dans le document.
    const avoidParent = ['pere', 'mere', 'parent'];
    final nom = findLabeled([
      "nom de l'élève", 'nom de l eleve', "nom de l'enfant", 'nom élève',
      'nom eleve', 'nom :', 'nom',
    ], avoid: avoidParent);
    final prenom = findLabeled([
      "prénom de l'élève", 'prenom de l eleve', "prénom de l'enfant",
      'prénom élève', 'prenom eleve', 'prénom :', 'prénom', 'prenom',
    ], avoid: avoidParent);
    final dateNaissanceRaw = findLabeled([
      'date de naissance', 'né(e) le', 'nee le', 'né le', 'née le', 'naissance',
    ]);
    final sexeRaw = findLabeled(['sexe', 'genre']);
    final classe = findLabeled([
      'classe demandée', 'classe demandee', 'classe souhaitée', 'classe',
      'niveau demandé', 'niveau',
    ]);
    final matricule = findLabeled([
      'numéro matricule', 'numero matricule', "n° matricule", 'matricule',
    ]);

    // ── Père / Mère ────────────────────────────────────────────────────────
    // `avoidEmailTel` empêche les libellés génériques ("père", "mère") de
    // capturer par erreur une ligne "Email père : …"/"Téléphone père : …" —
    // ces lignes contiennent aussi le mot "père"/"mère".
    const avoidEmailTel = ['email', 'telephone', 'tel'];
    final pereNom = findLabeled([
      'nom du père', 'nom du pere', 'père :', 'pere :', 'père', 'pere',
    ], avoid: avoidEmailTel);
    final pereTelephone = findLabeled([
      'téléphone du père', 'telephone du pere', 'tél père', 'tel pere',
      'téléphone père', 'telephone pere',
    ]);
    final pereEmail = _cleanEmail(findLabeled([
      'email du père', 'email du pere', 'email père', 'email pere',
      'e-mail père', 'e-mail pere',
    ]));
    final mereNom = findLabeled([
      'nom de la mère', 'nom de la mere', 'mère :', 'mere :', 'mère', 'mere',
    ], avoid: avoidEmailTel);
    final mereTelephone = findLabeled([
      'téléphone de la mère', 'telephone de la mere', 'tél mère', 'tel mere',
      'téléphone mère', 'telephone mere',
    ]);
    final mereEmail = _cleanEmail(findLabeled([
      'email de la mère', 'email de la mere', 'email mère', 'email mere',
      'e-mail mère', 'e-mail mere',
    ]));

    // ── Informations générales ───────────────────────────────────────────────
    final adresse = findLabeled(['adresse']);
    final ville = findLabeled(['ville']);
    final contactUrgenceNom = findLabeled([
      "personne à contacter en cas d'urgence",
      "personne a contacter en cas d'urgence",
      "contact d'urgence",
      'contact urgence',
    ]);
    final contactUrgenceTelephone = findLabeled([
      "téléphone d'urgence",
      "telephone d'urgence",
      'téléphone urgence',
      'telephone urgence',
    ]);

    // Repli : si les emails/téléphones "père"/"mère" nommés n'ont rien
    // trouvé, on tente d'extraire par motif générique dans tout le texte.
    // Les valeurs déjà attribuées via un libellé spécifique (ex. l'email de
    // la mère a été trouvé nommément) sont retirées du "pot commun" avant
    // de combler les champs restants, pour ne jamais réattribuer la même
    // valeur au mauvais parent quand un seul des deux est identifié.
    final emailPool =
        _emailRe.allMatches(rawText).map((m) => m.group(0)!).toSet().toList();
    final phonePool =
        _phoneRe.allMatches(rawText).map((m) => m.group(0)!).toSet().toList();
    emailPool.remove(pereEmail.value);
    emailPool.remove(mereEmail.value);
    phonePool.remove(pereTelephone.value);
    phonePool.remove(mereTelephone.value);
    phonePool.remove(contactUrgenceTelephone.value);

    ExtractedField takeFromPool(ExtractedField specific, List<String> pool) {
      if (specific.found) return specific;
      if (pool.isEmpty) return const ExtractedField.empty();
      return ExtractedField(value: pool.removeAt(0), found: true);
    }

    final finalPereEmail = takeFromPool(pereEmail, emailPool);
    final finalMereEmail = takeFromPool(mereEmail, emailPool);
    final finalPereTelephone = takeFromPool(pereTelephone, phonePool);
    final finalMereTelephone = takeFromPool(mereTelephone, phonePool);
    final finalContactUrgenceTelephone =
        takeFromPool(contactUrgenceTelephone, phonePool);

    final sexe = _normalizeSexe(sexeRaw);
    final dateNaissance = _normalizeDate(dateNaissanceRaw);

    final autres = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (!consumed[i]) autres.add(lines[i]);
    }

    return StudentImportResult(
      nom: nom,
      prenom: prenom,
      dateNaissance: dateNaissance,
      sexe: sexe,
      classe: classe,
      matricule: matricule,
      pereNom: pereNom,
      pereTelephone: finalPereTelephone,
      pereEmail: finalPereEmail,
      mereNom: mereNom,
      mereTelephone: finalMereTelephone,
      mereEmail: finalMereEmail,
      adresse: adresse,
      ville: ville,
      contactUrgenceNom: contactUrgenceNom,
      contactUrgenceTelephone: finalContactUrgenceTelephone,
      autresInfos: autres.join('\n'),
      rawText: rawText,
      parserName: name,
    );
  }

  /// Retire les espaces parasites que l'OCR insère parfois autour de
  /// symboles comme "@" (ex. "karim.benali @ example.com") — une adresse
  /// email ne contient jamais d'espace, contrairement aux autres champs où
  /// un espace pourrait être légitime.
  ExtractedField _cleanEmail(ExtractedField raw) {
    if (!raw.found || raw.value == null) return raw;
    return ExtractedField(
        value: raw.value!.replaceAll(RegExp(r'\s+'), ''), found: true);
  }

  ExtractedField _normalizeSexe(ExtractedField raw) {
    if (!raw.found || raw.value == null) return raw;
    final v = _normalize(raw.value!);
    if (v.startsWith('m') || v.contains('masculin') || v.contains('garcon')) {
      return const ExtractedField(value: 'M', found: true);
    }
    if (v.startsWith('f') || v.contains('feminin') || v.contains('fille')) {
      return const ExtractedField(value: 'F', found: true);
    }
    return raw;
  }

  ExtractedField _normalizeDate(ExtractedField raw) {
    if (!raw.found || raw.value == null) return raw;
    final m = _dateRe.firstMatch(raw.value!);
    if (m == null) return raw;
    final d = m.group(1)!.padLeft(2, '0');
    final mo = m.group(2)!.padLeft(2, '0');
    var y = m.group(3)!;
    if (y.length == 2) y = '20$y';
    return ExtractedField(value: '$y-$mo-$d', found: true);
  }

  /// Retire les accents et met en minuscule pour un matching robuste aux
  /// variations d'accentuation produites par l'OCR.
  static String _normalize(String s) {
    const from = 'àâäéèêëîïôöùûüçÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ';
    const to = 'aaaeeeeiioouuucAAAEEEEIIOOUUUC';
    var out = s.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i].toLowerCase(), to[i].toLowerCase());
    }
    return out;
  }

  /// Retrouve l'index dans la chaîne originale correspondant à un index
  /// calculé sur la version normalisée (même longueur car substitution 1↔1).
  static int _mapIndex(String original, int normalizedIndex) => normalizedIndex;
}
