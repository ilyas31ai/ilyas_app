import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ai_assistant_service.dart';
import '../services/etudiant_service.dart';

// ─── Hiérarchie scolaire ──────────────────────────────────────────────────────

/// Matières disponibles par catégorie
const _kMatieres = <String, List<String>>{
  'Maternelle': ['Éveil', 'Lecture & Écriture', 'Calcul', 'Arts plastiques', 'Motricité'],
  'Primaire':   ['Mathématiques', 'Français', 'Histoire-Géo', 'Sciences', 'Anglais', 'Arts'],
  'Collège':    ['Mathématiques', 'Français', 'Histoire-Géo', 'SVT', 'Physique-Chimie', 'Anglais', 'Espagnol', 'Informatique'],
  'Lycée':      ['Mathématiques', 'Français', 'Histoire-Géo', 'SVT', 'Physique-Chimie', 'Anglais', 'Philosophie', 'Spécialité'],
  'Université': ['Mathématiques', 'Informatique', 'Économie', 'Droit', 'Sciences', 'Langues', 'Lettres', 'Autre'],
};

const _kDefaultMatieres = ['Mathématiques', 'Français', 'Histoire-Géo', 'SVT', 'Physique-Chimie', 'Anglais'];

const _kMatierIcons = <String, IconData>{
  'Mathématiques':      Icons.calculate_outlined,
  'Français':           Icons.menu_book_outlined,
  'Histoire-Géo':       Icons.public_outlined,
  'SVT':                Icons.eco_outlined,
  'Physique-Chimie':    Icons.science_outlined,
  'Anglais':            Icons.language_outlined,
  'Espagnol':           Icons.translate_outlined,
  'Informatique':       Icons.computer_outlined,
  'Philosophie':        Icons.lightbulb_outline,
  'Économie':           Icons.bar_chart_outlined,
  'Droit':              Icons.gavel_outlined,
  'Sciences':           Icons.biotech_outlined,
  'Langues':            Icons.record_voice_over_outlined,
  'Lettres':            Icons.edit_note_outlined,
  'Éveil':              Icons.child_friendly_outlined,
  'Lecture & Écriture': Icons.auto_stories_outlined,
  'Calcul':             Icons.calculate_outlined,
  'Arts plastiques':    Icons.palette_outlined,
  'Motricité':          Icons.directions_run_outlined,
  'Arts':               Icons.palette_outlined,
  'Spécialité':         Icons.star_outline,
  'Autre':              Icons.more_horiz_outlined,
};

const _kGradients = <String, List<Color>>{
  'Mathématiques':      [Color(0xFF2563EB), Color(0xFF0891B2)],
  'Français':           [Color(0xFF7C3AED), Color(0xFF6C47FF)],
  'Histoire-Géo':       [Color(0xFFB45309), Color(0xFFD97706)],
  'SVT':                [Color(0xFF15803D), Color(0xFF16A34A)],
  'Physique-Chimie':    [Color(0xFFDC2626), Color(0xFFEA580C)],
  'Anglais':            [Color(0xFF0F766E), Color(0xFF0891B2)],
  'Espagnol':           [Color(0xFFD97706), Color(0xFFCA8A04)],
  'Informatique':       [Color(0xFF374151), Color(0xFF4B5563)],
  'Philosophie':        [Color(0xFF6C47FF), Color(0xFF9333EA)],
  'Économie':           [Color(0xFF0891B2), Color(0xFF0E7490)],
  'Droit':              [Color(0xFF1D4ED8), Color(0xFF1E40AF)],
  'Sciences':           [Color(0xFF047857), Color(0xFF065F46)],
  'Éveil':              [Color(0xFFF59E0B), Color(0xFFD97706)],
  'Lecture & Écriture': [Color(0xFF7C3AED), Color(0xFF6C47FF)],
  'Calcul':             [Color(0xFF2563EB), Color(0xFF0891B2)],
  'Arts plastiques':    [Color(0xFFDB2777), Color(0xFFBE185D)],
  'Motricité':          [Color(0xFF16A34A), Color(0xFF15803D)],
  'Arts':               [Color(0xFFDB2777), Color(0xFFBE185D)],
  'Spécialité':         [Color(0xFF6C47FF), Color(0xFF2563EB)],
  'Langues':            [Color(0xFF0F766E), Color(0xFF0891B2)],
  'Lettres':            [Color(0xFF7C3AED), Color(0xFF6C47FF)],
  'Autre':              [Color(0xFF374151), Color(0xFF4B5563)],
};

List<Color> _gradient(String m) =>
    _kGradients[m] ?? const [Color(0xFF6C47FF), Color(0xFF2563EB)];

IconData _icon(String m) => _kMatierIcons[m] ?? Icons.school_outlined;

// ─── Contenu pédagogique adapté ───────────────────────────────────────────────

/// Points clés par matière et catégorie
const _kPointsCles = <String, Map<String, List<String>>>{
  'Mathématiques': {
    'Maternelle':   ['Compter jusqu\'à 10', 'Formes géométriques simples', 'Plus grand / plus petit'],
    'Primaire':     ['Tables de multiplication (1→10)', 'Fractions simples', 'Périmètre et aire', 'Résoudre des problèmes'],
    'Collège':      ['Équations du 1er degré', 'Fonctions linéaires', 'Théorème de Pythagore', 'Statistiques de base'],
    'Lycée':        ['Dérivées et primitives', 'Suites numériques', 'Probabilités conditionnelles', 'Logarithmes & exponentielles'],
    'Université':   ['Algèbre linéaire', 'Analyse réelle', 'Probabilités avancées', 'Équations différentielles'],
  },
  'Français': {
    'Maternelle':   ['Reconnaître les lettres', 'Sons et syllabes', 'Écouter une histoire'],
    'Primaire':     ['Accord sujet-verbe', 'Temps simples (présent, passé, futur)', 'Types de phrases', 'Lecture fluide'],
    'Collège':      ['Accord du participe passé', 'Subjonctif vs indicatif', 'Figures de style', 'Structure d\'un texte argumentatif'],
    'Lycée':        ['Dissertation littéraire', 'Commentaire composé', 'Mouvements littéraires', 'Analyse de l\'implicite'],
    'Université':   ['Stylistique avancée', 'Analyse textuelle', 'Rhétorique classique', 'Linguistique générale'],
  },
  'Histoire-Géo': {
    'Primaire':     ['Les grandes civilisations', 'La France et ses régions', 'Lire une carte simple'],
    'Collège':      ['Chronologie des grandes périodes', 'Révolution française', 'Mondialisation', 'Lecture de cartes thématiques'],
    'Lycée':        ['Géopolitique mondiale', 'Guerres mondiales', 'Construction européenne', 'Développement durable'],
    'Université':   ['Historiographie critique', 'Géographie économique', 'Relations internationales', 'Études de cas régionales'],
  },
  'SVT': {
    'Collège':      ['Cellule et organisation du vivant', 'Écosystèmes et chaînes alimentaires', 'Reproduction sexuée', 'Corps humain'],
    'Lycée':        ['Génétique et expression des gènes', 'Évolution des espèces', 'Système nerveux', 'Bilan de matière et d\'énergie'],
    'Université':   ['Biologie moléculaire', 'Écologie avancée', 'Physiologie cellulaire', 'Biochimie structurale'],
  },
  'Physique-Chimie': {
    'Collège':      ['États de la matière', 'Circuits électriques', 'Réactions chimiques simples', 'Forces et mouvements'],
    'Lycée':        ['Lois de Newton', 'Thermodynamique', 'Ondes électromagnétiques', 'Chimie organique de base'],
    'Université':   ['Mécanique quantique', 'Électromagnétisme avancé', 'Cinétique chimique', 'Thermodynamique statistique'],
  },
  'Anglais': {
    'Primaire':     ['Vocabulaire de base (famille, couleurs, animaux)', 'Salutations et formules polies', 'Compter en anglais'],
    'Collège':      ['Present simple vs continuous', 'Past simple & past perfect', 'Vocabulaire thématique', 'Compréhension de textes courts'],
    'Lycée':        ['Discours indirect', 'Conditionnel 3', 'Vocabulaire avancé', 'Expression orale et débat'],
    'Université':   ['Anglais académique', 'Rédaction d\'essais', 'Lecture de publications scientifiques', 'Présentation orale en anglais'],
  },
};

List<String> _pointsCles(String categorie, String matiere) {
  final byLevel = _kPointsCles[matiere];
  if (byLevel == null) return ['Consulte tes cours et fiches de révision.'];
  return byLevel[categorie] ?? byLevel.values.first;
}

// ─── Quiz par niveau ──────────────────────────────────────────────────────────

const _kQuiz = <String, Map<String, List<Map<String, dynamic>>>>{
  'Mathématiques': {
    'Primaire': [
      {'q': 'Combien font 7 × 8 ?', 'choices': ['54', '56', '63', '64'], 'answer': 1},
      {'q': 'Quelle est la moitié de 48 ?', 'choices': ['22', '24', '26', '28'], 'answer': 1},
      {'q': '3/4 + 1/4 = ?', 'choices': ['4/8', '4/4', '1', '2/4'], 'answer': 2},
      {'q': 'Périmètre d\'un carré de côté 6 cm ?', 'choices': ['12 cm', '18 cm', '24 cm', '36 cm'], 'answer': 2},
      {'q': '2³ = ?', 'choices': ['6', '8', '9', '16'], 'answer': 1},
    ],
    'Collège': [
      {'q': 'Résoudre 2x + 6 = 14. x = ?', 'choices': ['2', '3', '4', '5'], 'answer': 2},
      {'q': 'Quelle est la racine carrée de 169 ?', 'choices': ['11', '12', '13', '14'], 'answer': 2},
      {'q': 'Dans un triangle rectangle, sin(30°) = ?', 'choices': ['√3/2', '1/2', '√2/2', '1'], 'answer': 1},
      {'q': 'Si f(x) = 3x − 2, f(5) = ?', 'choices': ['11', '12', '13', '14'], 'answer': 2},
      {'q': 'Factoriser x² − 9.', 'choices': ['(x−3)(x+3)', '(x−9)(x+1)', '(x−3)²', 'x(x−9)'], 'answer': 0},
    ],
    'Lycée': [
      {'q': 'Dérivée de f(x) = 3x² − 2x + 1 ?', 'choices': ['6x − 2', '3x − 2', '6x + 1', '3x²'], 'answer': 0},
      {'q': 'ln(e²) = ?', 'choices': ['e²', '2e', '2', '1'], 'answer': 2},
      {'q': 'Limite de (2x³ + x)/(x³) quand x → +∞ ?', 'choices': ['0', '1', '2', '+∞'], 'answer': 2},
      {'q': 'P(A∩B) si P(A)=0.4, P(B|A)=0.5 ?', 'choices': ['0.1', '0.2', '0.4', '0.9'], 'answer': 1},
      {'q': '∫₀¹ 2x dx = ?', 'choices': ['0', '1', '2', '4'], 'answer': 1},
    ],
    'Université': [
      {'q': 'Le déterminant de [[2,1],[3,4]] ?', 'choices': ['5', '6', '7', '8'], 'answer': 0},
      {'q': 'Convergence de Σ 1/n² ?', 'choices': ['Diverge', 'Converge (π²/6)', 'Converge (1)', 'Oscillante'], 'answer': 1},
      {'q': 'Transformée de Laplace de e^(at) ?', 'choices': ['1/(s−a)', 'a/(s²)', 's/(s−a)', '1/s'], 'answer': 0},
      {'q': 'Dimension du noyau si rang = 3, dim = 5 ?', 'choices': ['1', '2', '3', '4'], 'answer': 1},
      {'q': 'Équation différentielle y\' = ky → solution ?', 'choices': ['y = Ce^(kx)', 'y = kx + C', 'y = k ln(x)', 'y = Cx^k'], 'answer': 0},
    ],
  },
  'Français': {
    'Primaire': [
      {'q': 'Quel est le pluriel de "bal" ?', 'choices': ['bals', 'baux', 'bal', 'bales'], 'answer': 0},
      {'q': 'Le verbe "chanter" au présent avec "nous" ?', 'choices': ['chantons', 'chantez', 'chantent', 'chanto'], 'answer': 0},
      {'q': 'Quel mot est un adjectif ?', 'choices': ['courir', 'beau', 'table', 'rapidement'], 'answer': 1},
      {'q': '"Le chat mange la souris." Quel est le sujet ?', 'choices': ['chat', 'le chat', 'mange', 'la souris'], 'answer': 1},
      {'q': 'Féminin de "chanteur" ?', 'choices': ['chanteuse', 'chanteresse', 'chanteura', 'chantrice'], 'answer': 0},
    ],
    'Collège': [
      {'q': '"Je ne sais pas si tu viendras." Le verbe est au...', 'choices': ['présent', 'futur', 'conditionnel', 'subjonctif'], 'answer': 1},
      {'q': 'Figure de style : "Vif comme l\'éclair" ?', 'choices': ['métaphore', 'comparaison', 'allitération', 'hyperbole'], 'answer': 1},
      {'q': '"Ils ont été félicités." Accorder le participe... car ?', 'choices': ['COD après', 'COD avant "les"', 'Sujet après', 'Jamais accordé'], 'answer': 1},
      {'q': 'Quel genre littéraire raconte des aventures fictives ?', 'choices': ['biographie', 'roman', 'essai', 'discours'], 'answer': 1},
      {'q': '"Il faut que je sache." Temps de "sache" ?', 'choices': ['indicatif présent', 'subjonctif présent', 'impératif', 'conditionnel'], 'answer': 1},
    ],
    'Lycée': [
      {'q': 'Le "nouveau roman" (1950-60) rejette... ?', 'choices': ['le style', 'le personnage traditionnel', 'la ponctuation', 'les dialogues'], 'answer': 1},
      {'q': '"L\'homme est condamné à être libre" — qui ?', 'choices': ['Camus', 'Sartre', 'Beauvoir', 'Nietzsche'], 'answer': 1},
      {'q': 'Forme fixe de 14 vers en 2 quatrains + 2 tercets ?', 'choices': ['ode', 'ballade', 'sonnet', 'haïku'], 'answer': 2},
      {'q': 'La "catharsis" selon Aristote est...', 'choices': ['la tension dramatique', 'la purification des passions', 'le monologue intérieur', 'le dénouement'], 'answer': 1},
      {'q': 'Écriture inclusive : forme "iel" désigne ?', 'choices': ['féminin', 'masculin', 'genre non-binaire', 'pluriel'], 'answer': 2},
    ],
  },
  'Anglais': {
    'Primaire': [
      {'q': '"Hello, my name ___ Emma."', 'choices': ['am', 'is', 'are', 'be'], 'answer': 1},
      {'q': 'Couleur : rouge en anglais ?', 'choices': ['blue', 'green', 'red', 'yellow'], 'answer': 2},
      {'q': '"I have ___ apple."', 'choices': ['a', 'an', 'the', 'some'], 'answer': 1},
      {'q': 'Nombre : 15 en anglais ?', 'choices': ['thirteen', 'fourteen', 'fifteen', 'sixteen'], 'answer': 2},
      {'q': 'Pluriel de "child" ?', 'choices': ['childs', 'childes', 'children', 'childre'], 'answer': 2},
    ],
    'Collège': [
      {'q': '"She ___ TV every evening." (habitude)', 'choices': ['watch', 'watches', 'is watching', 'watched'], 'answer': 1},
      {'q': 'Traduction : "J\'aurais dû partir plus tôt."', 'choices': ['I should leave earlier', 'I should have left earlier', 'I must have left', 'I would leave earlier'], 'answer': 1},
      {'q': 'Forme passive de "They built the house."', 'choices': ['The house builds', 'The house was built', 'The house is built', 'The house built'], 'answer': 1},
      {'q': '"Although" introduit...', 'choices': ['une cause', 'une conséquence', 'une concession', 'une condition'], 'answer': 2},
      {'q': 'Reported speech : "I am tired" → He said...', 'choices': ['he is tired', 'he was tired', 'he has been tired', 'he were tired'], 'answer': 1},
    ],
    'Lycée': [
      {'q': '"Had she known, she ___ helped." (conditionnel 3)', 'choices': ['would help', 'would have helped', 'will help', 'would helped'], 'answer': 1},
      {'q': 'Style "stream of consciousness" inventé par ?', 'choices': ['Hemingway', 'Woolf', 'Dickens', 'Orwell'], 'answer': 1},
      {'q': '"The more you practice, ___ you become."', 'choices': ['better', 'the better', 'more better', 'the best'], 'answer': 1},
      {'q': 'Subjonctif anglais dans : "It is vital that she ___ on time."', 'choices': ['is', 'be', 'will be', 'was'], 'answer': 1},
      {'q': 'Nuance : "I could" vs "I was able to" ?', 'choices': ['identiques', '"could" = capacité générale, "was able to" = succès réel', '"was able to" = futur', '"could" = passé spécifique'], 'answer': 1},
    ],
  },
};

List<Map<String, dynamic>> _quiz(String categorie, String matiere) {
  final byLevel = _kQuiz[matiere];
  if (byLevel == null) return _defaultQuiz(matiere);
  return byLevel[categorie] ?? byLevel.values.first;
}

List<Map<String, dynamic>> _defaultQuiz(String matiere) => [
  {'q': 'Quiz pour "$matiere" en cours de construction. Utilise l\'assistant IA pour réviser.', 'choices': ['OK', 'Compris', '👍', '✓'], 'answer': 0},
];

// ─── Examens blancs par niveau ────────────────────────────────────────────────

const _kExamensBlancs = <String, List<Map<String, dynamic>>>{
  'Collège': [
    {
      'titre': 'Brevet Blanc — Mathématiques',
      'dureeMinutes': 120,
      'matiere': 'Mathématiques',
      'questions': [
        {'q': 'Développer et réduire : (x+3)(x−2)', 'choices': ['x²+x−6', 'x²−x−6', 'x²+5x−6', 'x²−5x−6'], 'answer': 0},
        {'q': 'Calculer l\'hypoténuse d\'un triangle rectangle de côtés 6 et 8.', 'choices': ['10', '12', '14', '√48'], 'answer': 0},
        {'q': '60% de 150 = ?', 'choices': ['80', '85', '90', '95'], 'answer': 2},
        {'q': 'Si P(A) = 0,3, P(A̅) = ?', 'choices': ['0,3', '0,6', '0,7', '1,3'], 'answer': 2},
        {'q': 'Équation : 5x − 3 = 2x + 9. x = ?', 'choices': ['2', '3', '4', '5'], 'answer': 2},
      ],
    },
    {
      'titre': 'Brevet Blanc — Français',
      'dureeMinutes': 90,
      'matiere': 'Français',
      'questions': [
        {'q': 'Accord : "Les élèves que j\'ai VU travailler"', 'choices': ['vu', 'vus', 'vue', 'vues'], 'answer': 0},
        {'q': '"Blanche comme neige" est une...', 'choices': ['métaphore', 'comparaison', 'métonymie', 'personnification'], 'answer': 1},
        {'q': 'Mode du verbe : "Bien que je sois fatigué…"', 'choices': ['indicatif', 'conditionnel', 'subjonctif', 'impératif'], 'answer': 2},
        {'q': '"Victor Hugo" appartient au mouvement...', 'choices': ['classicisme', 'romantisme', 'réalisme', 'surréalisme'], 'answer': 1},
        {'q': 'Registre d\'un texte qui suscite l\'effroi ?', 'choices': ['comique', 'lyrique', 'fantastique', 'épique'], 'answer': 2},
      ],
    },
  ],
  'Lycée': [
    {
      'titre': 'Bac Blanc — Mathématiques',
      'dureeMinutes': 180,
      'matiere': 'Mathématiques',
      'questions': [
        {'q': 'Dérivée de f(x) = e^(2x) × sin(x) ?', 'choices': ['2e^(2x)sin(x)+e^(2x)cos(x)', 'e^(2x)(2sin(x)+cos(x))', '2e^(2x)cos(x)', 'e^(2x)sin(x)+cos(x)'], 'answer': 1},
        {'q': 'Limite de x·e^(−x) quand x → +∞ ?', 'choices': ['+∞', '1', '0', '−∞'], 'answer': 2},
        {'q': '∫₀^π sin(x) dx = ?', 'choices': ['0', '1', '2', 'π'], 'answer': 2},
        {'q': 'Vecteur directeur de la droite y = 3x − 1 ?', 'choices': ['(1,3)', '(3,1)', '(1,−1)', '(−1,3)'], 'answer': 0},
        {'q': 'P(X=2) si X~B(5, 0.4) ?', 'choices': ['0,230', '0,346', '0,312', '0,400'], 'answer': 0},
      ],
    },
    {
      'titre': 'Bac Blanc — Philosophie',
      'dureeMinutes': 240,
      'matiere': 'Philosophie',
      'questions': [
        {'q': '"La liberté des uns s\'arrête où commence celle des autres." Auteur ?', 'choices': ['Kant', 'Sartre', 'Mill', 'Rousseau'], 'answer': 2},
        {'q': '"Cogito, ergo sum" est de ?', 'choices': ['Platon', 'Aristote', 'Descartes', 'Hegel'], 'answer': 2},
        {'q': 'Le mythe de la caverne illustre...', 'choices': ['le relativisme', 'l\'allégorie du réel vs apparences', 'l\'empirisme', 'le nihilisme'], 'answer': 1},
        {'q': 'Selon Kant, un acte moral est accompli...', 'choices': ['par intérêt', 'par devoir', 'par instinct', 'par plaisir'], 'answer': 1},
        {'q': 'L\'utilitarisme prône...', 'choices': ['le bonheur de tous', 'le maximum de bonheur pour le maximum', 'la vertu individuelle', 'l\'abstinence'], 'answer': 1},
      ],
    },
  ],
  'Université': [
    {
      'titre': 'Examen Blanc — Analyse L1',
      'dureeMinutes': 120,
      'matiere': 'Mathématiques',
      'questions': [
        {'q': 'Limite de (1+1/n)^n quand n→∞ ?', 'choices': ['1', 'e', 'π', '∞'], 'answer': 1},
        {'q': 'f est dérivable en a si...', 'choices': ['f est continue', 'la limite du taux d\'accroissement existe', 'f est bornée', 'f est positive'], 'answer': 1},
        {'q': 'ℕ ⊂ ℤ ⊂ ℚ ⊂ ℝ : vrai ou faux ?', 'choices': ['Vrai', 'Faux — ℤ⊄ℚ', 'Faux — ℚ⊄ℝ', 'Faux — ℕ⊄ℤ'], 'answer': 0},
        {'q': 'Série géométrique de raison r converge si...', 'choices': ['r > 1', '|r| < 1', 'r = 1', 'r > 0'], 'answer': 1},
        {'q': 'Gradient de f(x,y) = x²y en (1,2) ?', 'choices': ['(4,1)', '(2,2)', '(4,2)', '(2,1)'], 'answer': 0},
      ],
    },
  ],
  'Primaire': [
    {
      'titre': 'Évaluation — CE2 Mathématiques',
      'dureeMinutes': 45,
      'matiere': 'Mathématiques',
      'questions': [
        {'q': '45 + 37 = ?', 'choices': ['71', '72', '82', '83'], 'answer': 2},
        {'q': '8 × 7 = ?', 'choices': ['54', '56', '58', '64'], 'answer': 1},
        {'q': '100 − 28 = ?', 'choices': ['62', '72', '78', '82'], 'answer': 1},
        {'q': 'La moitié de 36 ?', 'choices': ['12', '16', '18', '20'], 'answer': 2},
        {'q': '4 × 9 = ?', 'choices': ['32', '34', '36', '38'], 'answer': 2},
      ],
    },
  ],
};

List<Map<String, dynamic>> _examens(String categorie) =>
    _kExamensBlancs[categorie] ?? [];

// ─── SharedPreferences ────────────────────────────────────────────────────────

const _kPrefPrefix = 'revisions_v2_';

Future<Map<String, int>> _loadProgress() async {
  final prefs = await SharedPreferences.getInstance();
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  final raw = prefs.getString('${_kPrefPrefix}progress_$uid') ?? '{}';
  return Map<String, int>.from(jsonDecode(raw) as Map);
}

Future<void> _saveProgress(Map<String, int> p) async {
  final prefs = await SharedPreferences.getInstance();
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  await prefs.setString('${_kPrefPrefix}progress_$uid', jsonEncode(p));
}

Future<List<Map<String, dynamic>>> _loadExamenHistory() async {
  final prefs = await SharedPreferences.getInstance();
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  final raw = prefs.getString('${_kPrefPrefix}examens_$uid') ?? '[]';
  return List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
}

Future<void> _saveExamenHistory(List<Map<String, dynamic>> h) async {
  final prefs = await SharedPreferences.getInstance();
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  await prefs.setString('${_kPrefPrefix}examens_$uid', jsonEncode(h));
}

// ═══════════════════════════════════════════════════════════════════════════════
// Page principale
// ═══════════════════════════════════════════════════════════════════════════════

class EtudiantRevisionsPage extends StatefulWidget {
  const EtudiantRevisionsPage({super.key});

  @override
  State<EtudiantRevisionsPage> createState() => _EtudiantRevisionsPageState();
}

class _EtudiantRevisionsPageState extends State<EtudiantRevisionsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, int> _progress = {};
  List<Map<String, dynamic>> _examenHistory = [];
  Map<String, String> _profil = {};
  bool _loading = true;

  String get _categorie => _profil['categorie'] ?? '';
  String get _niveau    => _profil['niveau'] ?? '';
  String get _classeNom => _profil['classeNom'] ?? '';

  List<String> get _matieres =>
      _kMatieres[_categorie] ?? _kDefaultMatieres;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _init();
  }

  Future<void> _init() async {
    final progress = await _loadProgress();
    final history = await _loadExamenHistory();
    // Wait for first profil event
    final profil = await EtudiantService.profilStream().first;
    if (mounted) {
      setState(() {
        _progress = progress;
        _examenHistory = history;
        _profil = profil;
        _loading = false;
      });
    }
  }

  void _onProgressUpdate(String matiere, int score) {
    final updated = Map<String, int>.from(_progress)..[matiere] = score;
    setState(() => _progress = updated);
    _saveProgress(updated);
  }

  void _onExamenDone(Map<String, dynamic> result) {
    final updated = List<Map<String, dynamic>>.from(_examenHistory)..insert(0, result);
    if (updated.length > 20) updated.removeLast();
    setState(() => _examenHistory = updated);
    _saveExamenHistory(updated);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Révisions',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            if (_categorie.isNotEmpty)
              Text('$_categorie${_niveau.isNotEmpty ? ' · $_niveau' : ''}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Matières'),
            Tab(text: 'Examens blancs'),
            Tab(text: 'Progression'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : TabBarView(
              controller: _tabs,
              children: [
                _MatieresTab(
                  matieres: _matieres,
                  categorie: _categorie,
                  classeNom: _classeNom,
                  progress: _progress,
                  onProgressUpdate: _onProgressUpdate,
                ),
                _ExamensBlancsTab(
                  categorie: _categorie,
                  history: _examenHistory,
                  onDone: _onExamenDone,
                ),
                _ProgressionTab(
                  matieres: _matieres,
                  progress: _progress,
                  history: _examenHistory,
                  categorie: _categorie,
                  niveau: _niveau,
                ),
              ],
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Onglet 1 — Matières
// ═══════════════════════════════════════════════════════════════════════════════

class _MatieresTab extends StatelessWidget {
  final List<String> matieres;
  final String categorie;
  final String classeNom;
  final Map<String, int> progress;
  final void Function(String, int) onProgressUpdate;

  const _MatieresTab({
    required this.matieres,
    required this.categorie,
    required this.classeNom,
    required this.progress,
    required this.onProgressUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final mastered  = progress.values.where((v) => v >= 80).length;
    final total     = matieres.length;

    return CustomScrollView(
      slivers: [
        // ── Banner ──────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _ProgressBanner(mastered: mastered, total: total, progress: progress),
        ),
        // ── Grid ────────────────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final m = matieres[i];
                return _MatiereCard(
                  matiere: m,
                  score: progress[m],
                  onTap: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => _MatiereDetailPage(
                        matiere: m,
                        categorie: categorie,
                        classeNom: classeNom,
                        score: progress[m] ?? 0,
                        onScoreUpdate: (s) => onProgressUpdate(m, s),
                      ),
                    ),
                  ),
                );
              },
              childCount: matieres.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressBanner extends StatelessWidget {
  final int mastered, total;
  final Map<String, int> progress;
  const _ProgressBanner({required this.mastered, required this.total, required this.progress});

  @override
  Widget build(BuildContext context) {
    final toReinforce = progress.values.where((v) => v > 0 && v < 80).length;
    final pct = total == 0 ? 0 : (mastered * 100 ~/ total);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ma progression', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text('$mastered / $total matières maîtrisées',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                if (toReinforce > 0)
                  Text('$toReinforce à renforcer', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 56, height: 56,
                child: CircularProgressIndicator(
                  value: pct / 100,
                  backgroundColor: Colors.white30,
                  color: Colors.white,
                  strokeWidth: 5,
                ),
              ),
              Text('$pct%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MatiereCard extends StatelessWidget {
  final String matiere;
  final int? score;
  final VoidCallback onTap;
  const _MatiereCard({required this.matiere, required this.score, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = score ?? 0;
    final statusColor = pct >= 80
        ? const Color(0xFF16A34A)
        : pct >= 40
            ? const Color(0xFFD97706)
            : Colors.white38;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _gradient(matiere)),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(_icon(matiere), color: Colors.white, size: 20),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(matiere,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 6),
            if (pct > 0) ...[
              LinearProgressIndicator(
                value: pct / 100,
                backgroundColor: Colors.white12,
                color: statusColor,
                minHeight: 4,
              ),
              const SizedBox(height: 4),
              Text('$pct%', style: TextStyle(color: statusColor, fontSize: 10)),
            ] else
              const Text('Non démarré', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Détail d'une matière (Cours / Exercices / Quiz)
// ═══════════════════════════════════════════════════════════════════════════════

class _MatiereDetailPage extends StatefulWidget {
  final String matiere, categorie, classeNom;
  final int score;
  final void Function(int) onScoreUpdate;
  const _MatiereDetailPage({
    required this.matiere,
    required this.categorie,
    required this.classeNom,
    required this.score,
    required this.onScoreUpdate,
  });
  @override
  State<_MatiereDetailPage> createState() => _MatiereDetailPageState();
}

class _MatiereDetailPageState extends State<_MatiereDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Text(widget.matiere,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Cours'), Tab(text: 'Exercices'), Tab(text: 'Quiz')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _CoursTab(matiere: widget.matiere, categorie: widget.categorie, classeNom: widget.classeNom),
          _ExercicesTab(matiere: widget.matiere, categorie: widget.categorie, classeNom: widget.classeNom),
          _QuizTab(
            matiere: widget.matiere,
            categorie: widget.categorie,
            initialScore: widget.score,
            onScoreUpdate: widget.onScoreUpdate,
          ),
        ],
      ),
    );
  }
}

// ── Cours ─────────────────────────────────────────────────────────────────────

class _CoursTab extends StatefulWidget {
  final String matiere, categorie, classeNom;
  const _CoursTab({required this.matiere, required this.categorie, required this.classeNom});
  @override
  State<_CoursTab> createState() => _CoursTabState();
}

class _CoursTabState extends State<_CoursTab> {
  final _ctrl = TextEditingController();
  String? _explication;
  bool _loading = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _explain() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _explication = null; });
    final result = await AiAssistantService.expliquerNotion(
      notion: _ctrl.text.trim(),
      matiere: widget.matiere,
      classeNom: widget.classeNom.isNotEmpty ? widget.classeNom : widget.categorie,
    );
    if (mounted) setState(() { _explication = result; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final pts = _pointsCles(widget.categorie, widget.matiere);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Aide IA ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: _gradient(widget.matiere)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Assistant IA — Cours', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              const Text('Demande une explication sur n\'importe quelle notion.',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _ctrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Ex : "Qu\'est-ce qu\'une dérivée ?" ou "Explique la photosynthèse"',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF161B22),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _gradient(widget.matiere).first,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(44),
          ),
          onPressed: _loading ? null : _explain,
          icon: _loading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.auto_fix_high, size: 18),
          label: const Text('Expliquer'),
        ),
        if (_explication != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(_explication!, style: const TextStyle(color: Colors.white, height: 1.6)),
          ),
        ],
        const SizedBox(height: 24),

        // ── Points clés ────────────────────────────────────────────────────
        _SectionHeader('Points clés à maîtriser'),
        const SizedBox(height: 10),
        ...pts.map((p) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: _gradient(widget.matiere).last, size: 16),
              const SizedBox(width: 10),
              Expanded(child: Text(p, style: const TextStyle(color: Colors.white70, fontSize: 13))),
            ],
          ),
        )),
      ],
    );
  }
}

// ── Exercices ──────────────────────────────────────────────────────────────────

class _ExercicesTab extends StatefulWidget {
  final String matiere, categorie, classeNom;
  const _ExercicesTab({required this.matiere, required this.categorie, required this.classeNom});
  @override
  State<_ExercicesTab> createState() => _ExercicesTabState();
}

class _ExercicesTabState extends State<_ExercicesTab> {
  String _level = 'Intermédiaire';
  String? _exercise;
  String? _correction;
  bool _loading = false;
  bool _showCorrection = false;

  Future<void> _generate() async {
    setState(() { _loading = true; _exercise = null; _correction = null; _showCorrection = false; });

    final apiKey = await AiAssistantService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      if (mounted) {
        setState(() {
          _exercise = '⚠️ Clé API non configurée.\n\nVa dans Paramètres → Clé API pour activer la génération d\'exercices.';
          _loading = false;
        });
      }
      return;
    }

    final niveauCtx = widget.classeNom.isNotEmpty ? widget.classeNom : widget.categorie;
    final prompt = 'Génère un exercice de niveau $_level en ${widget.matiere} '
        'pour un élève de $niveauCtx. '
        'Réponds EXACTEMENT dans ce format :\n'
        '**Exercice :**\n[énoncé de l\'exercice]\n\n'
        '**Correction :**\n[correction détaillée étape par étape]';

    final result = await AiAssistantService.expliquerNotion(
      notion: prompt,
      matiere: widget.matiere,
      classeNom: niveauCtx,
    );

    if (mounted) {
      // Parse the response
      final corrIdx = result.indexOf('**Correction');
      final exIdx   = result.indexOf('**Exercice');
      String ex = result;
      String? corr;
      if (corrIdx > 0) {
        ex   = result.substring(exIdx >= 0 ? exIdx : 0, corrIdx).trim();
        corr = result.substring(corrIdx).trim();
        ex   = ex.replaceAll(RegExp(r'\*\*Exercice\s*:\*\*\s*', caseSensitive: false), '').trim();
        corr = corr.replaceAll(RegExp(r'\*\*Correction\s*:\*\*\s*', caseSensitive: false), '').trim();
      }
      setState(() { _exercise = ex; _correction = corr; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Niveau selector
        Row(
          children: ['Facile', 'Intermédiaire', 'Avancé'].map((l) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(l, style: const TextStyle(fontSize: 12)),
              selected: l == _level,
              onSelected: (_) => setState(() => _level = l),
              selectedColor: _gradient(widget.matiere).first,
              labelStyle: TextStyle(color: l == _level ? Colors.white : Colors.white60),
            ),
          )).toList(),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _gradient(widget.matiere).first,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(44),
          ),
          onPressed: _loading ? null : _generate,
          icon: _loading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.refresh, size: 18),
          label: Text('Générer un exercice $_level'),
        ),
        if (_exercise != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(_exercise!, style: const TextStyle(color: Colors.white, height: 1.6)),
          ),
          if (_correction != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => setState(() => _showCorrection = !_showCorrection),
              icon: Icon(_showCorrection ? Icons.visibility_off : Icons.visibility, size: 16),
              label: Text(_showCorrection ? 'Masquer la correction' : 'Voir la correction'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
            ),
            if (_showCorrection)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1F0A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
                ),
                child: Text(_correction!, style: const TextStyle(color: Colors.white, height: 1.6)),
              ),
          ],
        ],
      ],
    );
  }
}

// ── Quiz ──────────────────────────────────────────────────────────────────────

class _QuizTab extends StatefulWidget {
  final String matiere, categorie;
  final int initialScore;
  final void Function(int) onScoreUpdate;
  const _QuizTab({
    required this.matiere,
    required this.categorie,
    required this.initialScore,
    required this.onScoreUpdate,
  });
  @override
  State<_QuizTab> createState() => _QuizTabState();
}

class _QuizTabState extends State<_QuizTab> {
  late List<Map<String, dynamic>> _questions;
  int _qi = 0;
  int? _selected;
  bool _answered = false;
  int _correct = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _questions = _quiz(widget.categorie, widget.matiere);
  }

  void _select(int i) {
    if (_answered) return;
    setState(() {
      _selected = i;
      _answered = true;
      if (i == _questions[_qi]['answer'] as int) _correct++;
    });
  }

  void _next() {
    if (_qi < _questions.length - 1) {
      setState(() { _qi++; _selected = null; _answered = false; });
    } else {
      final pct = (_correct * 100 ~/ _questions.length);
      setState(() => _done = true);
      widget.onScoreUpdate(pct);
    }
  }

  void _restart() => setState(() { _qi = 0; _selected = null; _answered = false; _correct = 0; _done = false; });

  @override
  Widget build(BuildContext context) {
    if (_done) return _buildResult();
    final q       = _questions[_qi];
    final choices = List<String>.from(q['choices'] as List);
    final answer  = q['answer'] as int;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: (_qi + 1) / _questions.length,
            backgroundColor: Colors.white12,
            color: _gradient(widget.matiere).first,
            minHeight: 5,
          ),
          const SizedBox(height: 8),
          Text('Question ${_qi + 1} / ${_questions.length} · $_correct correcte(s)',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(q['q'] as String,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 14),
          ...choices.asMap().entries.map((e) {
            Color bg = const Color(0xFF161B22);
            Color border = Colors.white.withValues(alpha: 0.08);
            if (_answered) {
              if (e.key == answer)        { bg = const Color(0xFF0A1F0A); border = const Color(0xFF16A34A); }
              else if (e.key == _selected){ bg = const Color(0xFF1F0A0A); border = const Color(0xFFDC2626); }
            }
            return GestureDetector(
              onTap: () => _select(e.key),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border)),
                child: Row(
                  children: [
                    if (_answered && e.key == answer)
                      const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18)
                    else if (_answered && e.key == _selected)
                      const Icon(Icons.cancel, color: Color(0xFFDC2626), size: 18)
                    else
                      const Icon(Icons.radio_button_unchecked, color: Colors.white38, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(e.value, style: const TextStyle(color: Colors.white, fontSize: 14))),
                  ],
                ),
              ),
            );
          }),
          const Spacer(),
          if (_answered)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gradient(widget.matiere).first,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: _next,
              child: Text(_qi < _questions.length - 1 ? 'Question suivante' : 'Voir les résultats'),
            ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final pct   = _correct * 100 ~/ _questions.length;
    final color = pct >= 80 ? const Color(0xFF16A34A) : pct >= 50 ? const Color(0xFFD97706) : const Color(0xFFDC2626);
    final msg   = pct >= 80 ? 'Excellent ! Matière maîtrisée.' : pct >= 50 ? 'Bien ! Continue à réviser.' : 'Il faut réviser davantage.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 52,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Text('$pct%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            ),
            const SizedBox(height: 16),
            Text('$_correct / ${_questions.length} bonnes réponses',
                style: const TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 6),
            Text(msg, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.refresh),
              label: const Text('Recommencer'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Onglet 2 — Examens blancs
// ═══════════════════════════════════════════════════════════════════════════════

class _ExamensBlancsTab extends StatelessWidget {
  final String categorie;
  final List<Map<String, dynamic>> history;
  final void Function(Map<String, dynamic>) onDone;

  const _ExamensBlancsTab({
    required this.categorie,
    required this.history,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final examens = _examens(categorie);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (examens.isEmpty) ...[
          const SizedBox(height: 40),
          const Center(
            child: Text('Aucun examen blanc disponible pour ce niveau.',
                style: TextStyle(color: Colors.white54), textAlign: TextAlign.center),
          ),
        ] else ...[
          _SectionHeader('Examens blancs disponibles'),
          const SizedBox(height: 12),
          ...examens.map((e) => _ExamenBlanCard(
            examen: e,
            onStart: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _ExamenBlanPage(
                  examen: e,
                  categorie: categorie,
                  onDone: onDone,
                ),
              ),
            ),
          )),
        ],
        if (history.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionHeader('Historique des examens'),
          const SizedBox(height: 12),
          ...history.take(5).map((h) => _HistoriqueCard(result: h)),
        ],
      ],
    );
  }
}

class _ExamenBlanCard extends StatelessWidget {
  final Map<String, dynamic> examen;
  final VoidCallback onStart;
  const _ExamenBlanCard({required this.examen, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final matiere = examen['matiere'] as String;
    final duree   = examen['dureeMinutes'] as int;
    final nb      = (examen['questions'] as List).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _gradient(matiere)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon(matiere), color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(examen['titre'] as String,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('$nb questions · $duree min',
                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.timer_outlined, color: Colors.white38, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gradient(matiere).first,
                foregroundColor: Colors.white,
              ),
              onPressed: onStart,
              child: const Text('Commencer l\'examen'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoriqueCard extends StatelessWidget {
  final Map<String, dynamic> result;
  const _HistoriqueCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final pct   = result['pct'] as int? ?? 0;
    final color = pct >= 80 ? const Color(0xFF16A34A) : pct >= 50 ? const Color(0xFFD97706) : const Color(0xFFDC2626);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(result['titre'] as String? ?? 'Examen',
              style: const TextStyle(color: Colors.white70, fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text('$pct%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Page examen blanc avec chronomètre
// ═══════════════════════════════════════════════════════════════════════════════

class _ExamenBlanPage extends StatefulWidget {
  final Map<String, dynamic> examen;
  final String categorie;
  final void Function(Map<String, dynamic>) onDone;
  const _ExamenBlanPage({required this.examen, required this.categorie, required this.onDone});
  @override
  State<_ExamenBlanPage> createState() => _ExamenBlanPageState();
}

class _ExamenBlanPageState extends State<_ExamenBlanPage> {
  late List<Map<String, dynamic>> _questions;
  late int _secondsLeft;
  Timer? _timer;
  int _qi = 0;
  int? _selected;
  bool _answered = false;
  int _correct = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _questions = List<Map<String, dynamic>>.from(widget.examen['questions'] as List);
    _secondsLeft = (widget.examen['dureeMinutes'] as int) * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 0) { _timer?.cancel(); _autoFinish(); return; }
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  void _autoFinish() {
    if (!_done) _finish();
  }

  Future<void> _confirmQuit(BuildContext ctx) async {
    final nav = Navigator.of(ctx);
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Quitter l\'examen ?', style: TextStyle(color: Colors.white)),
        content: const Text('Vos réponses seront perdues.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuer', style: TextStyle(color: Colors.white38))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Quitter', style: TextStyle(color: Color(0xFFDC2626)))),
        ],
      ),
    );
    if (ok == true) nav.pop();
  }

  void _finish() {
    _timer?.cancel();
    final pct = _questions.isEmpty ? 0 : (_correct * 100 ~/ _questions.length);
    setState(() => _done = true);
    widget.onDone({
      'titre': widget.examen['titre'],
      'pct': pct,
      'correct': _correct,
      'total': _questions.length,
      'date': DateTime.now().toIso8601String(),
    });
  }

  void _select(int i) {
    if (_answered) return;
    setState(() {
      _selected = i;
      _answered = true;
      if (i == _questions[_qi]['answer'] as int) _correct++;
    });
  }

  void _next() {
    if (_qi < _questions.length - 1) {
      setState(() { _qi++; _selected = null; _answered = false; });
    } else {
      _finish();
    }
  }

  String _fmtTime(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_done) return _buildResult();

    final matiere = widget.examen['matiere'] as String;
    final q       = _questions[_qi];
    final choices = List<String>.from(q['choices'] as List);
    final answer  = q['answer'] as int;
    final isLow   = _secondsLeft < 120;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Text(widget.examen['titre'] as String,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isLow ? const Color(0xFF7F1D1D) : const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isLow ? const Color(0xFFDC2626) : Colors.white24),
            ),
            child: Row(
              children: [
                Icon(Icons.timer, size: 14, color: isLow ? const Color(0xFFDC2626) : Colors.white60),
                const SizedBox(width: 4),
                Text(_fmtTime(_secondsLeft),
                    style: TextStyle(
                      color: isLow ? const Color(0xFFDC2626) : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    )),
              ],
            ),
          ),
        ],
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white54),
          onPressed: () => _confirmQuit(context),
        ),
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmQuit(context);
        },
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: (_qi + 1) / _questions.length,
              backgroundColor: Colors.white12,
              color: _gradient(matiere).first,
              minHeight: 5,
            ),
            const SizedBox(height: 8),
            Text('Question ${_qi + 1} / ${_questions.length}',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(q['q'] as String,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 14),
            ...choices.asMap().entries.map((e) {
              Color bg = const Color(0xFF161B22);
              Color border = Colors.white.withValues(alpha: 0.08);
              if (_answered) {
                if (e.key == answer)        { bg = const Color(0xFF0A1F0A); border = const Color(0xFF16A34A); }
                else if (e.key == _selected){ bg = const Color(0xFF1F0A0A); border = const Color(0xFFDC2626); }
              }
              return GestureDetector(
                onTap: () => _select(e.key),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: border)),
                  child: Row(
                    children: [
                      if (_answered && e.key == answer)
                        const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18)
                      else if (_answered && e.key == _selected)
                        const Icon(Icons.cancel, color: Color(0xFFDC2626), size: 18)
                      else
                        const Icon(Icons.radio_button_unchecked, color: Colors.white38, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(e.value, style: const TextStyle(color: Colors.white, fontSize: 14))),
                    ],
                  ),
                ),
              );
            }),
            const Spacer(),
            if (_answered)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gradient(matiere).first,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: _next,
                child: Text(_qi < _questions.length - 1 ? 'Question suivante' : 'Terminer l\'examen'),
              ),
          ],
        ),
      ), // Padding
      ), // PopScope
    );
  }

  Widget _buildResult() {
    final pct   = _questions.isEmpty ? 0 : (_correct * 100 ~/ _questions.length);
    final color = pct >= 80 ? const Color(0xFF16A34A) : pct >= 50 ? const Color(0xFFD97706) : const Color(0xFFDC2626);
    final msg   = pct >= 80 ? 'Excellent résultat !' : pct >= 50 ? 'Résultat moyen. Continuez à réviser.' : 'Résultat insuffisant. Révisez davantage.';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Résultats', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Text('$pct%', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: color)),
                ),
                const SizedBox(height: 16),
                Text('$_correct / ${_questions.length} questions correctes',
                    style: const TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 6),
                Text(msg, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // ── Correction détaillée ─────────────────────────────────────────
          _SectionHeader('Correction détaillée'),
          const SizedBox(height: 12),
          ..._questions.asMap().entries.map((e) {
            final q      = e.value;
            final answer = q['answer'] as int;
            final choices= List<String>.from(q['choices'] as List);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${e.key + 1}. ${q['q']}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 16),
                      const SizedBox(width: 6),
                      Text('Bonne réponse : ${choices[answer]}',
                          style: const TextStyle(color: Color(0xFF16A34A), fontSize: 13)),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Retour aux examens'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Onglet 3 — Progression
// ═══════════════════════════════════════════════════════════════════════════════

class _ProgressionTab extends StatelessWidget {
  final List<String> matieres;
  final Map<String, int> progress;
  final List<Map<String, dynamic>> history;
  final String categorie, niveau;

  const _ProgressionTab({
    required this.matieres,
    required this.progress,
    required this.history,
    required this.categorie,
    required this.niveau,
  });

  @override
  Widget build(BuildContext context) {
    final mastered   = matieres.where((m) => (progress[m] ?? 0) >= 80).toList();
    final toReinforce= matieres.where((m) { final s = progress[m] ?? 0; return s > 0 && s < 80; }).toList();
    final notStarted = matieres.where((m) => (progress[m] ?? 0) == 0).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── En-tête ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (categorie.isNotEmpty)
                Text('Niveau : $categorie${niveau.isNotEmpty ? ' ($niveau)' : ''}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatChip('Maîtrisées', mastered.length, const Color(0xFF16A34A)),
                  _StatChip('À renforcer', toReinforce.length, const Color(0xFFD97706)),
                  _StatChip('Non démarrées', notStarted.length, Colors.white38),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Matières maîtrisées ─────────────────────────────────────────────
        if (mastered.isNotEmpty) ...[
          _SectionHeader('Matières maîtrisées (≥80%)'),
          const SizedBox(height: 8),
          ...mastered.map((m) => _ProgressRow(matiere: m, score: progress[m]!, color: const Color(0xFF16A34A))),
          const SizedBox(height: 16),
        ],

        // ── À renforcer ─────────────────────────────────────────────────────
        if (toReinforce.isNotEmpty) ...[
          _SectionHeader('À renforcer'),
          const SizedBox(height: 8),
          ...toReinforce.map((m) => _ProgressRow(matiere: m, score: progress[m]!, color: const Color(0xFFD97706))),
          const SizedBox(height: 16),
        ],

        // ── Non démarrées ───────────────────────────────────────────────────
        if (notStarted.isNotEmpty) ...[
          _SectionHeader('Non démarrées'),
          const SizedBox(height: 8),
          ...notStarted.map((m) => _ProgressRow(matiere: m, score: 0, color: Colors.white24)),
          const SizedBox(height: 16),
        ],

        // ── Historique examens ──────────────────────────────────────────────
        if (history.isNotEmpty) ...[
          _SectionHeader('Historique des examens blancs'),
          const SizedBox(height: 8),
          ...history.take(10).map((h) {
            final pct   = h['pct'] as int? ?? 0;
            final color = pct >= 80 ? const Color(0xFF16A34A) : pct >= 50 ? const Color(0xFFD97706) : const Color(0xFFDC2626);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h['titre'] as String? ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      if (h['date'] != null)
                        Text(_fmtDate(h['date'] as String),
                            style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  )),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text('$pct%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    } catch (_) { return iso; }
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('$value', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
    ],
  );
}

class _ProgressRow extends StatelessWidget {
  final String matiere;
  final int score;
  final Color color;
  const _ProgressRow({required this.matiere, required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(_icon(matiere), color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(matiere, style: const TextStyle(color: Colors.white70, fontSize: 13))),
          if (score > 0)
            Text('$score%', style: TextStyle(color: color, fontWeight: FontWeight.bold))
          else
            const Text('—', style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600),
  );
}
