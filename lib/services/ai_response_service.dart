import 'dart:math';

class AiResponseService {
  static final _rand = Random();

  static Future<String> getResponse({
    required String question,
    required String level,
    required String subject,
  }) async {
    await Future.delayed(Duration(milliseconds: 700 + _rand.nextInt(1300)));
    return _generate(question.toLowerCase().trim(), level, subject);
  }

  static String _generate(String q, String level, String subject) {
    if (_has(q, ['bonjour', 'salut', 'hello', 'bonsoir', 'coucou', 'hey'])) {
      return _greeting(level, subject);
    }
    if (_has(q, ['merci', 'thanks', 'super', 'parfait', 'genial', 'excellent', 'bravo', 'top'])) {
      return _thanks();
    }
    if (_has(q, ['aide', 'help', 'comprends pas', 'difficile', 'complique', 'perdu', 'bloque'])) {
      return _helpMsg(subject, level);
    }
    return _subjectResponse(q, subject, level);
  }

  static bool _has(String q, List<String> kw) => kw.any((k) => q.contains(k));

  // --- Messages generaux ---

  static String _greeting(String level, String subject) {
    final topicMap = {
      'Maths': 'les equations, la geometrie ou les probabilites',
      'Français': 'la grammaire, la conjugaison ou la redaction',
      'Anglais': 'la grammaire anglaise ou le vocabulaire',
      'Histoire': 'les grandes periodes historiques',
      'Géographie': 'les continents, les pays ou le climat',
      'Physique': 'la mecanique, l electricite ou les ondes',
      'Chimie': 'les atomes, les molecules ou les reactions',
      'SVT': 'la biologie, la genetique ou la geologie',
      'Philosophie': 'les grandes notions et les auteurs cles',
      'Informatique': 'les algorithmes, Python ou Flutter',
    };
    final topic = topicMap[subject] ?? 'ta matiere';
    return 'Bonjour ! Je suis **SCOLAR AI**, ton assistant scolaire.\n\n'
        'Je suis configure pour t aider en **$subject** au niveau **$level**.\n\n'
        'Ce que je peux faire :\n'
        '- Expliquer des notions et concepts\n'
        '- Resoudre des exercices pas a pas\n'
        '- Repondre a tes questions sur $topic\n\n'
        'Pose-moi ta premiere question !';
  }

  static String _thanks() {
    final msgs = [
      'Avec plaisir ! N hesite pas si tu as d autres questions.',
      'Super ! Continue comme ca, tu progresses bien.',
      'De rien ! Je suis la pour t aider a tout moment.',
      'Avec plaisir ! La cle, c est de pratiquer regulierement.',
    ];
    return msgs[_rand.nextInt(msgs.length)];
  }

  static String _helpMsg(String subject, String level) {
    return 'Je comprends que c est difficile. Voici comment je vais t aider :\n\n'
        '1. **Decompose** ton probleme en petites etapes\n'
        '2. **Explique**-moi ce que tu ne comprends pas precisement\n'
        '3. **Donne**-moi l enonce ou la notion qui te pose probleme\n\n'
        'En $subject au niveau $level, je peux t expliquer '
        'n importe quelle notion etape par etape. Qu est-ce qui te bloque ?';
  }

  static String _subjectResponse(String q, String subject, String level) {
    switch (subject) {
      case 'Maths':
        return _maths(q, level);
      case 'Français':
        return _francais(q, level);
      case 'Anglais':
        return _anglais(q, level);
      case 'Histoire':
        return _histoire(q, level);
      case 'Géographie':
        return _geo(q, level);
      case 'Physique':
        return _physique(q, level);
      case 'Chimie':
        return _chimie(q, level);
      case 'SVT':
        return _svt(q, level);
      case 'Philosophie':
        return _philo(q, level);
      case 'Informatique':
        return _info(q, level);
      default:
        return _generic(subject, level);
    }
  }

  // --- MATHS ---

  static String _maths(String q, String level) {
    if (_has(q, ['fraction', 'fractions', 'numerateur', 'denominateur'])) {
      return '**Les fractions** :\n\n'
          'Une fraction a/b represente a parties sur b.\n\n'
          '**Addition** : a/b + c/d = (ad + bc) / (bd)\n'
          '**Multiplication** : a/b x c/d = (ac) / (bd)\n'
          '**Division** : a/b / c/d = a/b x d/c\n\n'
          'Exemple : 1/2 + 1/3 = 3/6 + 2/6 = 5/6\n\n'
          'Astuce : toujours simplifier la fraction finale par le PGCD.';
    }
    if (_has(q, ['equation', 'equations', 'resoudre', 'inconnue', 'variable'])) {
      return '**Resoudre une equation** :\n\n'
          'Le but est d isoler l inconnue x d un cote de l egal.\n\n'
          '**Regles de base** :\n'
          '- On peut additionner/soustraire le meme nombre des deux cotes\n'
          '- On peut multiplier/diviser les deux cotes par le meme nombre (non nul)\n\n'
          '**Exemple** : 2x + 5 = 13\n'
          '  2x = 13 - 5 = 8\n'
          '  x = 8 / 2 = 4\n\n'
          '**Verification** : 2(4) + 5 = 13. Correct !';
    }
    if (_has(q, ['geometrie', 'triangle', 'cercle', 'rectangle', 'perimetre', 'aire', 'surface', 'volume'])) {
      return '**Formules de geometrie essentielles** :\n\n'
          '**Rectangle** :\n'
          '  Perimetre = 2(L + l)\n'
          '  Aire = L x l\n\n'
          '**Triangle** :\n'
          '  Perimetre = a + b + c\n'
          '  Aire = (base x hauteur) / 2\n\n'
          '**Cercle** (r = rayon) :\n'
          '  Perimetre = 2 x pi x r\n'
          '  Aire = pi x r^2\n\n'
          '**Cube** :\n'
          '  Volume = cote^3\n'
          '  Surface = 6 x cote^2';
    }
    if (_has(q, ['probabilite', 'probabilites', 'chance', 'hasard', 'evenement'])) {
      return '**Les probabilites** :\n\n'
          'La probabilite d un evenement A est :\n'
          '  P(A) = (nombre de cas favorables) / (nombre de cas possibles)\n\n'
          'P(A) est toujours entre 0 et 1.\n\n'
          '**Exemple** : Lancer un de a 6 faces.\n'
          '  P(obtenir 3) = 1/6\n'
          '  P(obtenir un nombre pair) = 3/6 = 1/2\n\n'
          '**Complement** : P(non A) = 1 - P(A)';
    }
    if (_has(q, ['fonction', 'fonctions', 'courbe', 'graphe', 'derivee', 'derive'])) {
      return '**Les fonctions** :\n\n'
          'Une fonction f associe a chaque x un unique f(x).\n\n'
          '**Fonction lineaire** : f(x) = ax (droite passant par l origine)\n'
          '**Fonction affine** : f(x) = ax + b\n'
          '**Fonction carree** : f(x) = x^2 (parabole)\n\n'
          '**Derivee** (calcul de pente instantanee) :\n'
          '  Si f(x) = x^n, alors f (x) = n * x^(n-1)\n'
          '  Si f(x) = ax + b, alors f (x) = a\n\n'
          'La derivee s annule aux extremums (maximum, minimum).';
    }
    if (_has(q, ['pgcd', 'ppcm', 'diviseur', 'multiple', 'premier', 'diviser'])) {
      return '**PGCD et PPCM** :\n\n'
          '**PGCD** (Plus Grand Commun Diviseur) :\n'
          'Algorithme d Euclide : on divise successivement.\n'
          'Exemple : PGCD(48, 18)\n'
          '  48 = 2 x 18 + 12\n'
          '  18 = 1 x 12 + 6\n'
          '  12 = 2 x 6 + 0  -> PGCD = 6\n\n'
          '**PPCM** = (a x b) / PGCD(a, b)\n'
          'Exemple : PPCM(48, 18) = (48 x 18) / 6 = 144\n\n'
          'Utilite : simplifier les fractions, trouver un denominateur commun.';
    }
    if (_has(q, ['statistique', 'statistiques', 'moyenne', 'mediane', 'mode', 'ecart'])) {
      return '**Statistiques** :\n\n'
          '**Moyenne** : somme des valeurs / nombre de valeurs\n'
          '  Exemple : (5 + 8 + 12 + 7) / 4 = 32 / 4 = 8\n\n'
          '**Mediane** : valeur centrale (serie triee)\n'
          '  Si nombre pair de valeurs : moyenne des deux centraux\n\n'
          '**Mode** : valeur la plus frequente\n\n'
          '**Etendue** : valeur max - valeur min\n\n'
          '**Ecart-type** : mesure de la dispersion autour de la moyenne.';
    }
    if (_has(q, ['pythagore', 'pytagore', 'hypotenuse', 'trigonometrie', 'sinus', 'cosinus', 'tangente'])) {
      return '**Pythagore et trigonometrie** :\n\n'
          '**Theoreme de Pythagore** (triangle rectangle) :\n'
          '  hypotenuse^2 = cote1^2 + cote2^2\n'
          '  c^2 = a^2 + b^2\n\n'
          '**Trigonometrie** (angle A dans un triangle rectangle) :\n'
          '  sin(A) = cote oppose / hypotenuse\n'
          '  cos(A) = cote adjacent / hypotenuse\n'
          '  tan(A) = cote oppose / cote adjacent\n\n'
          'Moyen memorique : SOH-CAH-TOA';
    }
    if (_has(q, ['puissance', 'exposant', 'racine', 'carre'])) {
      return '**Puissances et racines** :\n\n'
          '**Regles des puissances** :\n'
          '  a^m x a^n = a^(m+n)\n'
          '  a^m / a^n = a^(m-n)\n'
          '  (a^m)^n = a^(mn)\n'
          '  a^0 = 1 (pour a non nul)\n'
          '  a^(-n) = 1 / a^n\n\n'
          '**Racine carree** :\n'
          '  racine(a x b) = racine(a) x racine(b)\n'
          '  racine(a/b) = racine(a) / racine(b)\n\n'
          'Exemples : 2^3 = 8, racine(16) = 4';
    }
    return '**Mathematiques - $level** :\n\n'
        'Je peux t aider avec :\n'
        '- Les fractions et calculs\n'
        '- Les equations du 1er et 2nd degre\n'
        '- La geometrie (aires, volumes, Pythagore)\n'
        '- Les probabilites et statistiques\n'
        '- Les fonctions et leurs proprietes\n'
        '- Les puissances et racines\n\n'
        'Pose-moi ta question precise avec l enonce si possible !';
  }

  // --- FRANCAIS ---

  static String _francais(String q, String level) {
    if (_has(q, ['grammaire', 'sujet', 'verbe', 'complement', 'cod', 'coi', 'ccs'])) {
      return '**Grammaire - Analyse de phrase** :\n\n'
          '**Sujet** : qui fait l action ? (Qui est-ce qui... ?)\n'
          '**Verbe** : l action ou l etat\n'
          '**COD** (Complement d Objet Direct) : quoi ? qui ? (sans preposition)\n'
          '**COI** (Complement d Objet Indirect) : a qui ? de quoi ? (avec preposition)\n'
          '**CC** (Complement Circonstanciel) : ou ? quand ? comment ?\n\n'
          '**Exemple** : "Le chat mange la souris dans le jardin."\n'
          '  Sujet : Le chat\n'
          '  Verbe : mange\n'
          '  COD : la souris\n'
          '  CC de lieu : dans le jardin';
    }
    if (_has(q, ['conjugaison', 'conjugue', 'conjuguer', 'present', 'passe', 'futur', 'imparfait', 'subjonctif'])) {
      return '**Conjugaison** :\n\n'
          '**Indicatif present** (verbe finir) :\n'
          '  je finis, tu finis, il finit\n'
          '  nous finissons, vous finissez, ils finissent\n\n'
          '**Passe compose** : auxiliaire (avoir/etre) + participe passe\n'
          '  "j ai mange", "je suis alle"\n'
          '  Attention aux verbes avec etre : aller, venir, partir, sortir...\n\n'
          '**Imparfait** : base du present + -ais, -ais, -ait, -ions, -iez, -aient\n\n'
          '**Subjonctif** : apres "que" + doute, volonte, sentiment\n'
          '  "Il faut que tu finisses"';
    }
    if (_has(q, ['redaction', 'paragraphe', 'dissertation', 'ecrire', 'introduction', 'conclusion', 'plan', 'essai'])) {
      return '**Redaction - Structure** :\n\n'
          '**Introduction** :\n'
          '  1. Accroche (citation, question, fait marquant)\n'
          '  2. Presentation du sujet\n'
          '  3. Problematique\n'
          '  4. Annonce du plan\n\n'
          '**Developpement** (2 ou 3 parties) :\n'
          '  - Idee principale\n'
          '  - Argument + exemple\n'
          '  - Transition vers la partie suivante\n\n'
          '**Conclusion** :\n'
          '  1. Bilan des arguments\n'
          '  2. Reponse a la problematique\n'
          '  3. Ouverture (question plus large)';
    }
    if (_has(q, ['figure', 'metaphore', 'comparaison', 'personnification', 'style', 'rhetorique', 'hyperbole'])) {
      return '**Figures de style** :\n\n'
          '**Comparaison** : avec "comme", "tel que"\n'
          '  Ex : "Rapide comme l eclair"\n\n'
          '**Metaphore** : comparaison sans outil\n'
          '  Ex : "Tu es mon soleil"\n\n'
          '**Personnification** : donner des attributs humains a une chose\n'
          '  Ex : "Le vent murmure"\n\n'
          '**Hyperbole** : exageration\n'
          '  Ex : "Je meurs de faim"\n\n'
          '**Anaphore** : repetition en debut de phrases\n'
          '  Ex : "Je me bats pour... je me bats pour..."';
    }
    if (_has(q, ['poeme', 'poesie', 'vers', 'rime', 'alexandrin', 'sonnet'])) {
      return '**La poesie** :\n\n'
          '**Vers** : ligne d un poeme\n'
          '**Strophe** : groupe de vers (quatrain = 4 vers, tercet = 3 vers)\n\n'
          '**Types de rimes** :\n'
          '  - Suivies (AABB) : vent / lent / feu / jeu\n'
          '  - Embrassees (ABBA)\n'
          '  - Croisees (ABAB)\n\n'
          '**Alexandrin** : vers de 12 syllabes (poesie classique)\n\n'
          '**Sonnet** : 2 quatrains + 2 tercets (forme fixe)\n\n'
          'Pour compter les syllabes : attention au "e" muet en fin de mot !';
    }
    if (_has(q, ['orthographe', 'accord', 'pluriel', 'feminin', 'masculin', 'participe'])) {
      return '**Orthographe et accords** :\n\n'
          '**Accord du participe passe** :\n'
          '  Avec "avoir" : accord avec le COD si place avant\n'
          '  Ex : "La lettre que j ai ecrite" (COD "que" avant)\n\n'
          '  Avec "etre" : accord avec le sujet\n'
          '  Ex : "Elles sont parties"\n\n'
          '**Pluriel des noms** :\n'
          '  Regle generale : + s\n'
          '  -al -> -aux (cheval -> chevaux)\n'
          '  -eau -> -eaux (gateau -> gateaux)\n'
          '  Exceptions : bal, carnaval, festival -> -als';
    }
    return '**Francais - $level** :\n\n'
        'Je peux t aider avec :\n'
        '- La grammaire et l analyse de phrases\n'
        '- La conjugaison (tous les temps)\n'
        '- La redaction et la dissertation\n'
        '- Les figures de style\n'
        '- La poesie\n'
        '- L orthographe et les accords\n\n'
        'Pose-moi ta question ou donne-moi ton enonce !';
  }

  // --- ANGLAIS ---

  static String _anglais(String q, String level) {
    if (_has(q, ['tense', 'present', 'past', 'future', 'tenses', 'temps'])) {
      return '**English Tenses** :\n\n'
          '**Present Simple** : habitudes, verites generales\n'
          '  "I eat breakfast every day."\n\n'
          '**Present Continuous** : actions en cours (to be + -ing)\n'
          '  "I am eating now."\n\n'
          '**Past Simple** : actions terminees (verbe + -ed ou irregulier)\n'
          '  "I ate yesterday."\n\n'
          '**Past Continuous** : action en cours dans le passe\n'
          '  "I was eating when you called."\n\n'
          '**Present Perfect** : have/has + participe passe (lien avec le present)\n'
          '  "I have already eaten."\n\n'
          '**Future** : will + infinitif\n'
          '  "I will eat later."';
    }
    if (_has(q, ['irregular', 'irregulier', 'verb', 'verbe', 'infinitive'])) {
      return '**Irregular Verbs** :\n\n'
          '| Infinitive | Past Simple | Past Participle |\n'
          '|------------|-------------|------------------|\n'
          '| be         | was/were    | been             |\n'
          '| go         | went        | gone             |\n'
          '| have       | had         | had              |\n'
          '| do         | did         | done             |\n'
          '| make       | made        | made             |\n'
          '| take       | took        | taken            |\n'
          '| come       | came        | come             |\n'
          '| see        | saw         | seen             |\n'
          '| know       | knew        | known            |\n'
          '| give       | gave        | given            |\n\n'
          'Conseil : apprends-les par groupes de sons similaires !';
    }
    if (_has(q, ['conditional', 'conditionnel', 'if', 'si', 'would', 'could'])) {
      return '**Conditionals** :\n\n'
          '**Zero Conditional** : verites generales\n'
          '  If + present, present\n'
          '  "If you heat water, it boils."\n\n'
          '**First Conditional** : situations possibles dans le futur\n'
          '  If + present simple, will + infinitif\n'
          '  "If it rains, I will stay home."\n\n'
          '**Second Conditional** : situations hypothetiques\n'
          '  If + past simple, would + infinitif\n'
          '  "If I had money, I would travel."\n\n'
          '**Third Conditional** : regrets sur le passe\n'
          '  If + past perfect, would have + participe passe\n'
          '  "If I had studied, I would have passed."';
    }
    if (_has(q, ['vocabulary', 'vocabulaire', 'words', 'mots', 'synonym', 'synonyme'])) {
      return '**Vocabulary Tips** :\n\n'
          '**Pour apprendre le vocabulaire** :\n'
          '  1. Lis en anglais chaque jour (livres, articles, films)\n'
          '  2. Fais des flashcards avec le mot + exemple\n'
          '  3. Utilise le mot dans une phrase propre\n'
          '  4. Repete avec la methode espacee\n\n'
          '**Synonymes utiles** :\n'
          '  big -> large, huge, enormous\n'
          '  good -> great, excellent, wonderful\n'
          '  bad -> terrible, awful, horrible\n'
          '  say -> tell, state, mention, claim\n\n'
          'Astuce : evite de sur-utiliser "very". Utilise des adjectifs forts !';
    }
    if (_has(q, ['passive', 'passif', 'voice', 'voix'])) {
      return '**Passive Voice** :\n\n'
          'Structure : to be + past participle\n\n'
          '**Present** : "The book is written by the author."\n'
          '**Past** : "The letter was sent yesterday."\n'
          '**Future** : "The project will be finished tomorrow."\n\n'
          'On utilise la voix passive quand :\n'
          '  - On ne sait pas qui fait l action\n'
          '  - L action est plus importante que l agent\n'
          '  - Style formel/scientifique\n\n'
          'Transformation :\n'
          '  Active : "The chef cooked the meal."\n'
          '  Passive : "The meal was cooked by the chef."';
    }
    return '**English - $level** :\n\n'
        'I can help you with:\n'
        '- All English tenses and grammar\n'
        '- Irregular verbs\n'
        '- Conditionals\n'
        '- Vocabulary and synonyms\n'
        '- Passive voice\n'
        '- Writing and comprehension\n\n'
        'Ask me your question in French or English!';
  }

  // --- HISTOIRE ---

  static String _histoire(String q, String level) {
    if (_has(q, ['revolution', 'francaise', '1789', 'bastille', 'roi', 'monarchie', 'republique'])) {
      return '**La Revolution francaise (1789)** :\n\n'
          '**Causes** :\n'
          '  - Crise financiere du royaume\n'
          '  - Inegalites entre les 3 ordres (Clerge, Noblesse, Tiers-Etat)\n'
          '  - Influence des philosophes des Lumieres\n\n'
          '**Evenements cles** :\n'
          '  - 5 mai 1789 : Etats generaux\n'
          '  - 14 juillet 1789 : Prise de la Bastille\n'
          '  - 26 aout 1789 : Declaration des Droits de l Homme\n'
          '  - 21 janvier 1793 : Execution de Louis XVI\n\n'
          '**Consequences** :\n'
          '  - Fin de la monarchie absolue\n'
          '  - Naissance des ideaux de liberte, egalite, fraternite';
    }
    if (_has(q, ['premiere', 'guerre', 'mondiale', '1914', '1918', 'ww1', 'verdun', 'tranchee'])) {
      return '**Premiere Guerre Mondiale (1914-1918)** :\n\n'
          '**Causes** :\n'
          '  - Nationalisme exacerbe en Europe\n'
          '  - Imperialisme et rivalites entre puissances\n'
          '  - Systeme d alliances (Triple Entente vs Triple Alliance)\n'
          '  - Assassinat de Francois-Ferdinand (28 juin 1914)\n\n'
          '**Caracteristiques** :\n'
          '  - Guerre de tranchees (front occidental)\n'
          '  - Nouvelles armes : gaz, chars, avions\n'
          '  - Bataille de Verdun (1916) : 700 000 morts\n\n'
          '**Fin** : Armistice le 11 novembre 1918\n'
          '**Bilan** : 18 millions de morts, Traite de Versailles (1919)';
    }
    if (_has(q, ['deuxieme', 'seconde', 'guerre', 'mondiale', '1939', '1945', 'ww2', 'hitler', 'nazi', 'holocaust'])) {
      return '**Seconde Guerre Mondiale (1939-1945)** :\n\n'
          '**Causes** :\n'
          '  - Montee du nazisme en Allemagne\n'
          '  - Politique expansionniste d Hitler\n'
          '  - Echec de la politique d apaisement\n'
          '  - Invasion de la Pologne (1er sept. 1939)\n\n'
          '**Grandes etapes** :\n'
          '  - 1940 : Chute de la France, Bataille d Angleterre\n'
          '  - 1941 : Entree des USA et de l URSS\n'
          '  - 1944 : Debarquement en Normandie (6 juin)\n'
          '  - 1945 : Victoire des Allies, liberation des camps\n\n'
          '**Bilan** : 60 millions de morts, Shoah (6 millions de Juifs)';
    }
    if (_has(q, ['antiquite', 'rome', 'grec', 'grece', 'egypte', 'mesopotamie', 'pharaon'])) {
      return '**L Antiquite** :\n\n'
          '**Egypte ancienne** (3000 av. J.-C. - 30 av. J.-C.) :\n'
          '  - Pharaon : roi-dieu, Manetho recense 31 dynasties\n'
          '  - Grandes constructions : pyramides, temples\n'
          '  - Ecriture : hieroglyphes\n\n'
          '**Grece antique** :\n'
          '  - Cite-Etat (polis) : Athenes, Sparte\n'
          '  - Naissance de la democratie (Athenes, Ve siecle av. J.-C.)\n'
          '  - Philosophes : Socrate, Platon, Aristote\n\n'
          '**Rome antique** :\n'
          '  - Republique (509-27 av. J.-C.) puis Empire\n'
          '  - Jules Cesar, Auguste premier empereur\n'
          '  - Chute de l Empire romain d Occident : 476 ap. J.-C.';
    }
    if (_has(q, ['moyen', 'age', 'medieval', 'feodalite', 'croisade', 'seigneur', 'serf'])) {
      return '**Le Moyen Age (Ve - XVe siecle)** :\n\n'
          '**Feodalite** :\n'
          '  - Seigneur -> vassal -> serf\n'
          '  - Chateau fort, fief\n'
          '  - Chevaliers et leur code d honneur\n\n'
          '**L Eglise** :\n'
          '  - Pouvoir immense (politique, social, culture)\n'
          '  - Croisades (1095-1291) pour conquerir Jerusalem\n\n'
          '**Fin du Moyen Age** :\n'
          '  - Peste noire (1347) : 1/3 de la population europeenne\n'
          '  - Guerre de Cent Ans (1337-1453)\n'
          '  - Jeanne d Arc et liberation de la France';
    }
    return '**Histoire - $level** :\n\n'
        'Je peux t aider sur :\n'
        '- L Antiquite (Egypte, Grece, Rome)\n'
        '- Le Moyen Age et la feodalite\n'
        '- La Revolution francaise\n'
        '- Les deux Guerres Mondiales\n'
        '- La Guerre Froide et le monde contemporain\n\n'
        'Quelle periode ou quel evenement veux-tu etudier ?';
  }

  // --- GEOGRAPHIE ---

  static String _geo(String q, String level) {
    if (_has(q, ['continent', 'continents', 'afrique', 'europe', 'asie', 'amerique', 'oceanie'])) {
      return '**Les continents** :\n\n'
          '**Afrique** : 54 pays, 1.4 mrd habitants\n'
          '  Plus grand desert : Sahara\n'
          '  Plus long fleuve : Nil\n\n'
          '**Europe** : 44 pays, 748 millions habitants\n'
          '  Plus haut sommet : Mont Blanc (4808 m)\n\n'
          '**Asie** : plus grand continent, 4.7 mrd habitants\n'
          '  Plus haut sommet : Everest (8849 m)\n\n'
          '**Amerique du Nord** : 23 pays\n'
          '**Amerique du Sud** : 12 pays\n'
          '  Plus long fleuve du monde : Amazone\n\n'
          '**Oceanie** : 14 pays, Australie = pays le plus grand\n\n'
          '**Antarctique** : continent inhabite (sauf scientifiques)';
    }
    if (_has(q, ['climat', 'meteo', 'temperature', 'precipitation', 'tropical', 'desert', 'polaire'])) {
      return '**Les grands types de climats** :\n\n'
          '**Equatorial** : chaud et humide toute l annee\n'
          '  Regions : Amazonie, Bassin du Congo\n\n'
          '**Tropical** : saison seche + saison des pluies\n'
          '  Regions : Afrique sub-saharienne, Inde\n\n'
          '**Desert** : tres sec, ecarts de temperature extremes\n'
          '  Regions : Sahara, Arabie, Atacama\n\n'
          '**Mediterraneen** : ete sec et chaud, hiver doux et pluvieux\n'
          '  Regions : pourtour de la Mediterranee\n\n'
          '**Tempere oceanique** : doux, pluies reparties\n'
          '  Regions : Europe de l Ouest, France\n\n'
          '**Polaire** : froid extreme, precipitation faible\n'
          '  Regions : Arctique, Antarctique';
    }
    if (_has(q, ['france', 'regions', 'departements', 'capitale', 'fleuve', 'montagne'])) {
      return '**La France** :\n\n'
          '**Donnees cles** :\n'
          '  Superficie : 551 000 km2 (metropolitaine)\n'
          '  Population : ~68 millions hab.\n'
          '  Capitale : Paris\n\n'
          '**Grands fleuves** :\n'
          '  Loire (1013 km), Rhone, Seine, Garonne, Rhin\n\n'
          '**Reliefs** :\n'
          '  - Alpes (Mont Blanc 4808 m)\n'
          '  - Pyrenees (Pic d Aneto 3404 m)\n'
          '  - Massif Central, Vosges, Jura\n\n'
          '**Organisation** : 13 regions metropolitaines, 101 departements\n\n'
          '**DOM-TOM** : Guyane, Guadeloupe, Martinique, Reunion, Mayotte...';
    }
    if (_has(q, ['population', 'demographie', 'natalite', 'mortalite', 'migration', 'urbanisation'])) {
      return '**Demographie mondiale** :\n\n'
          '**Population mondiale** : ~8 milliards (2023)\n\n'
          '**Taux de natalite** : naissances / 1000 habitants\n'
          '**Taux de mortalite** : deces / 1000 habitants\n'
          '**Accroissement naturel** = natalite - mortalite\n\n'
          '**Transition demographique** :\n'
          '  1. Forte natalite + forte mortalite (pays peu developpes)\n'
          '  2. Forte natalite + mortalite qui baisse (explosion demographique)\n'
          '  3. Natalite baisse + faible mortalite\n'
          '  4. Faible natalite + faible mortalite (pays developpes)\n\n'
          '**Urbanisation** : 56% de la population mondiale vit en ville';
    }
    return '**Geographie - $level** :\n\n'
        'Je peux t aider sur :\n'
        '- Les continents et pays du monde\n'
        '- Les types de climats\n'
        '- La France (regions, fleuves, reliefs)\n'
        '- La demographie et urbanisation\n'
        '- Les grandes metropoles mondiales\n\n'
        'Quelle region ou notion geographique veux-tu etudier ?';
  }

  // --- PHYSIQUE ---

  static String _physique(String q, String level) {
    if (_has(q, ['electricite', 'electrique', 'circuit', 'tension', 'courant', 'resistance', 'ohm'])) {
      return '**Electricite - Loi d Ohm** :\n\n'
          '**Grandeurs fondamentales** :\n'
          '  - Tension U (en Volts, V)\n'
          '  - Intensite I (en Amperes, A)\n'
          '  - Resistance R (en Ohms)\n\n'
          '**Loi d Ohm** : U = R x I\n'
          '  Donc : I = U/R et R = U/I\n\n'
          '**Circuits** :\n'
          '  Serie : meme intensite partout, tensions s additionnent\n'
          '    U_total = U1 + U2, I meme partout\n\n'
          '  Parallele : meme tension, intensites s additionnent\n'
          '    U meme partout, I_total = I1 + I2\n\n'
          '**Puissance** : P = U x I = R x I^2 (en Watts)';
    }
    if (_has(q, ['mecanique', 'vitesse', 'acceleration', 'force', 'newton', 'mouvement', 'masse'])) {
      return '**Mecanique** :\n\n'
          '**Vitesse** : v = distance / temps\n'
          '  Unite : m/s ou km/h (1 m/s = 3.6 km/h)\n\n'
          '**Acceleration** : a = variation de vitesse / temps\n'
          '  Unite : m/s^2\n\n'
          '**Lois de Newton** :\n'
          '  1. Inertie : un corps reste au repos ou en mouvement rectiligne uniforme si les forces se compensent\n'
          '  2. F = m x a (somme des forces = masse x acceleration)\n'
          '  3. Action-reaction : a toute force correspond une force egale et opposee\n\n'
          '**Poids** : P = m x g (g = 9.8 m/s^2 sur Terre)\n'
          '  Poids en N, masse en kg';
    }
    if (_has(q, ['optique', 'lumiere', 'rayon', 'lentille', 'refraction', 'reflection', 'prisme'])) {
      return '**Optique** :\n\n'
          '**Vitesse de la lumiere** : c = 3 x 10^8 m/s dans le vide\n\n'
          '**Reflection** : angle d incidence = angle de reflection\n\n'
          '**Refraction** : changement de milieu -> changement de direction\n'
          '  Loi de Descartes : n1 x sin(i1) = n2 x sin(i2)\n\n'
          '**Lentille convergente** (convexe) :\n'
          '  Fait converger les rayons paralleles au foyer F\n'
          '  Image reelle si objet au-dela du foyer\n\n'
          '**Formule conjuguee** : 1/OA - 1/OA = 1/f\n'
          '  f = distance focale (en m ou cm)\n\n'
          'Application : lunettes, microscope, telescope, appareil photo';
    }
    if (_has(q, ['energie', 'travail', 'puissance', 'joule', 'watt', 'cinematique', 'potentielle'])) {
      return '**Energie** :\n\n'
          '**Travail** : W = F x d x cos(angle) (en Joules)\n'
          '  Si force parallele au deplacement : W = F x d\n\n'
          '**Energie cinetique** : Ec = 1/2 x m x v^2\n\n'
          '**Energie potentielle de pesanteur** : Ep = m x g x h\n\n'
          '**Energie mecanique** : Em = Ec + Ep\n'
          '  Conservation si pas de frottements\n\n'
          '**Puissance** : P = W / t = F x v\n'
          '  Unite : Watt (W) = J/s\n\n'
          '**Conversion** : 1 kWh = 3 600 000 J = 3.6 MJ';
    }
    if (_has(q, ['onde', 'son', 'frequence', 'amplitude', 'longueur', 'decibel'])) {
      return '**Les ondes** :\n\n'
          '**Onde mecanique** : necessite un milieu (son)\n'
          '**Onde electromagnetique** : se propage dans le vide (lumiere)\n\n'
          '**Caracteristiques** :\n'
          '  - Frequence f (en Hz) : nombre d oscillations par seconde\n'
          '  - Periode T = 1/f (en secondes)\n'
          '  - Longueur d onde : lambda = v / f\n'
          '  - Amplitude : hauteur maximale de l onde\n\n'
          '**Son** :\n'
          '  Vitesse : 340 m/s dans l air\n'
          '  Frequences audibles : 20 Hz - 20 000 Hz\n'
          '  Infra-sons < 20 Hz, Ultra-sons > 20 000 Hz\n\n'
          '**Lumiere visible** : longueurs d onde de 380 nm a 780 nm';
    }
    return '**Physique - $level** :\n\n'
        'Je peux t aider avec :\n'
        '- L electricite et les circuits (loi d Ohm)\n'
        '- La mecanique (forces, Newton, mouvement)\n'
        '- L optique (lentilles, refraction)\n'
        '- L energie et la puissance\n'
        '- Les ondes et le son\n\n'
        'Donne-moi ton enonce ou ta notion a etudier !';
  }

  // --- CHIMIE ---

  static String _chimie(String q, String level) {
    if (_has(q, ['atome', 'electron', 'proton', 'neutron', 'noyau', 'couche', 'electronique'])) {
      return '**Structure de l atome** :\n\n'
          '**Composition** :\n'
          '  - Noyau : protons (charge +) + neutrons (neutres)\n'
          '  - Electrons (charge -) : autour du noyau sur des couches\n\n'
          '**Notation** : A(Z)X ou X = symbole, Z = numero atomique, A = masse\n'
          '  Nombre de protons = Z\n'
          '  Nombre de neutrons = A - Z\n'
          '  Atome neutre : electrons = protons = Z\n\n'
          '**Configuration electronique** :\n'
          '  Couche K : max 2 electrons\n'
          '  Couche L : max 8 electrons\n'
          '  Couche M : max 18 electrons\n\n'
          'Exemple : Carbone (Z=6) -> K(2) L(4)';
    }
    if (_has(q, ['molecule', 'molecules', 'liaison', 'covalente', 'ionique', 'formule', 'chimique'])) {
      return '**Les molecules et liaisons** :\n\n'
          '**Liaison covalente** : partage d une paire d electrons entre 2 atomes\n'
          '  - Simple : H-H (H2)\n'
          '  - Double : O=O (O2)\n'
          '  - Triple : N=N=N (N2)\n\n'
          '**Liaison ionique** : transfert d electron (metal + non-metal)\n'
          '  Ex : NaCl (Na+ et Cl-)\n\n'
          '**Formules importantes** :\n'
          '  H2O : eau\n'
          '  CO2 : dioxyde de carbone\n'
          '  H2SO4 : acide sulfurique\n'
          '  NaOH : soude (hydroxyde de sodium)\n'
          '  HCl : acide chlorhydrique\n\n'
          '**Mole** : 6.02 x 10^23 entites (nombre d Avogadro)';
    }
    if (_has(q, ['reaction', 'reactif', 'produit', 'equation', 'bilan', 'combustion', 'oxydation'])) {
      return '**Reactions chimiques** :\n\n'
          '**Equation de reaction** : reactifs -> produits\n'
          '  La reaction doit etre equilibree (memes atomes des 2 cotes)\n\n'
          '**Exemple - Combustion du methane** :\n'
          '  CH4 + 2O2 -> CO2 + 2H2O\n\n'
          '**Equilibrage** :\n'
          '  1. Compter les atomes de chaque element\n'
          '  2. Ajuster les coefficients\n'
          '  3. Verifier l egalite de chaque element\n\n'
          '**Types de reactions** :\n'
          '  - Combustion : + dioxygene, produit CO2 et H2O\n'
          '  - Oxydation : gain d oxygene ou perte d electrons\n'
          '  - Neutralisation : acide + base -> sel + eau';
    }
    if (_has(q, ['acide', 'base', 'ph', 'neutralisation', 'solution', 'ion', 'hydroxyde'])) {
      return '**Acides et bases** :\n\n'
          '**pH** : mesure l acidite d une solution\n'
          '  pH < 7 : solution acide\n'
          '  pH = 7 : solution neutre\n'
          '  pH > 7 : solution basique\n\n'
          '**Acides** : donnent des ions H+ en solution\n'
          '  Ex : HCl -> H+ + Cl- (acide chlorhydrique)\n'
          '  Vinaigre (acide acetique), jus de citron\n\n'
          '**Bases** : donnent des ions OH- en solution\n'
          '  Ex : NaOH -> Na+ + OH- (soude)\n'
          '  Eau de Javel, ammoniaque\n\n'
          '**Neutralisation** : acide + base -> sel + eau\n'
          '  HCl + NaOH -> NaCl + H2O';
    }
    if (_has(q, ['tableau', 'mendeleiev', 'periodique', 'periode', 'groupe', 'famille'])) {
      return '**Tableau periodique** :\n\n'
          '**Organisation** :\n'
          '  - Lignes (periodes) : elements classes par Z croissant\n'
          '  - Colonnes (groupes/familles) : proprietes similaires\n\n'
          '**Familles importantes** :\n'
          '  - Groupe 1 : metaux alcalins (Li, Na, K...)\n'
          '  - Groupe 2 : metaux alcalino-terreux (Be, Mg, Ca...)\n'
          '  - Groupe 17 : halogenes (F, Cl, Br, I)\n'
          '  - Groupe 18 : gaz nobles (He, Ne, Ar, Kr)\n\n'
          '**Tendances** :\n'
          '  De gauche a droite : electronegativite augmente\n'
          '  De haut en bas : rayon atomique augmente\n\n'
          '**Elements a connaitre** :\n'
          '  H, He, Li, Be, B, C, N, O, F, Ne (Z = 1 a 10)';
    }
    return '**Chimie - $level** :\n\n'
        'Je peux t aider avec :\n'
        '- La structure de l atome\n'
        '- Les molecules et liaisons chimiques\n'
        '- Les equations et bilans de reaction\n'
        '- Les acides et bases (pH)\n'
        '- Le tableau periodique\n\n'
        'Pose-moi ton enonce ou ta question !';
  }

  // --- SVT ---

  static String _svt(String q, String level) {
    if (_has(q, ['cellule', 'cellules', 'adn', 'chromosome', 'noyau', 'mitose', 'meiose'])) {
      return '**La cellule et la genetique** :\n\n'
          '**Cellule eucaryote** :\n'
          '  - Membrane, cytoplasme, noyau\n'
          '  - Organites : mitochondries (energie), chloroplastes (photosynthese)\n\n'
          '**ADN** (Acide Desoxyribonucleique) :\n'
          '  - Double helice composee de 4 bases : A, T, G, C\n'
          '  - A s apparie avec T, G s apparie avec C\n'
          '  - Porteur de l information genetique\n\n'
          '**Chromosome** : ADN condense\n'
          '  Homme : 46 chromosomes (23 paires)\n\n'
          '**Mitose** : division cellulaire (2 cellules filles identiques)\n'
          '**Meiose** : division pour la reproduction (4 cellules haploides)';
    }
    if (_has(q, ['evolution', 'darwin', 'selection', 'naturelle', 'mutation', 'espece', 'phylogenetique'])) {
      return '**L evolution des especes** :\n\n'
          '**Darwin et la selection naturelle** :\n'
          '  1. Variabilite individuelle dans une population\n'
          '  2. Transmission hereditaire des caracteres\n'
          '  3. Surproduction de descendants\n'
          '  4. Competition + selection : les plus adaptes survivent\n\n'
          '**Mutation** : modification aleatoire de l ADN\n'
          '  - Peut etre neutre, benefique ou deletere\n'
          '  - Source principale de variabilite\n\n'
          '**Speciation** : formation d une nouvelle espece\n'
          '  Isolement geographique -> divergence genetique\n\n'
          '**Preuves de l evolution** :\n'
          '  - Fossiles, anatomie comparee, genetique moleculaire';
    }
    if (_has(q, ['corps', 'humain', 'organe', 'systeme', 'digestion', 'respiration', 'circulation', 'sang'])) {
      return '**Le corps humain** :\n\n'
          '**Systeme digestif** :\n'
          '  Bouche -> oesophage -> estomac -> intestin grele -> gros intestin\n'
          '  Foie et pancreas secretent des enzymes digestives\n\n'
          '**Systeme respiratoire** :\n'
          '  Air entre par la bouche/nez -> trachee -> bronches -> alveoles\n'
          '  Echange : O2 entre dans le sang, CO2 en sort\n\n'
          '**Systeme circulatoire** :\n'
          '  Coeur : 4 cavites (2 oreillettes + 2 ventricules)\n'
          '  Grande circulation : coeur -> corps -> coeur\n'
          '  Petite circulation : coeur -> poumons -> coeur\n\n'
          '**Sang** : globules rouges (O2), globules blancs (immunitaire), plaquettes';
    }
    if (_has(q, ['ecologie', 'ecosysteme', 'biodiversite', 'chaine', 'alimentaire', 'biome', 'environnement'])) {
      return '**Ecologie et ecosystemes** :\n\n'
          '**Ecosysteme** : milieu de vie + ses etres vivants\n'
          '  Ex : foret, ocean, prairie, desert\n\n'
          '**Chaine alimentaire** :\n'
          '  Producteurs (plantes) -> consommateurs primaires (herbivores)\n'
          '  -> consommateurs secondaires (carnivores) -> decomposeurs\n\n'
          '**Reseau trophique** : ensemble des chaines alimentaires liees\n\n'
          '**Biodiversite** :\n'
          '  - Diversite des especes\n'
          '  - Diversite genetique\n'
          '  - Diversite des ecosystemes\n\n'
          '**Menaces** : deforestation, pollution, changement climatique, surpeche\n\n'
          '**Cycle du carbone** : photosynthese <-> respiration <-> decomposition';
    }
    if (_has(q, ['photosynthese', 'chlorophylle', 'glucose', 'plante', 'vegetal', 'lumiere'])) {
      return '**La photosynthese** :\n\n'
          '**Equation** :\n'
          '  6CO2 + 6H2O + lumiere -> C6H12O6 + 6O2\n'
          '  (dioxyde de carbone + eau + lumiere -> glucose + dioxygene)\n\n'
          '**Lieu** : chloroplastes des cellules vegetales\n'
          '**Pigment** : chlorophylle (absorbe la lumiere rouge et bleue)\n\n'
          '**Deux phases** :\n'
          '  1. Phase lumineuse : conversion de la lumiere en energie (ATP)\n'
          '  2. Cycle de Calvin : fixation du CO2 en glucose\n\n'
          '**Role** :\n'
          '  - Produit le O2 que nous respirons\n'
          '  - Base de toutes les chaines alimentaires\n'
          '  - Capture le CO2 (regulation climatique)';
    }
    return '**SVT - $level** :\n\n'
        'Je peux t aider avec :\n'
        '- La cellule et la genetique (ADN, chromosomes)\n'
        '- L evolution des especes (Darwin)\n'
        '- Le corps humain et ses systemes\n'
        '- L ecologie et les ecosystemes\n'
        '- La photosynthese\n\n'
        'Quelle notion veux-tu approfondir ?';
  }

  // --- PHILOSOPHIE ---

  static String _philo(String q, String level) {
    if (_has(q, ['liberte', 'libre', 'determinisme', 'arbitre', 'choix', 'volonte'])) {
      return '**La liberte** :\n\n'
          '**Definitions** :\n'
          '  - Liberte d action : faire ce qu on veut sans contrainte\n'
          '  - Libre arbitre : capacite de choisir librement\n'
          '  - Autonomie : se donner sa propre loi (Kant)\n\n'
          '**Le determinisme** (these opposee) :\n'
          '  Tout acte est cause par des facteurs anterieurs\n'
          '  (heredite, education, circonstances)\n'
          '  Auteurs : Spinoza, Marx\n\n'
          '**Positions** :\n'
          '  - Sartre : "l existence precede l essence" -> liberte radicale\n'
          '  - Descartes : la volonte est infinie, seul attribut qui nous rend semblables a Dieu\n'
          '  - Spinoza : la liberte n est que la conscience de notre determination\n\n'
          '**Paradoxe** : sommes-nous libres de ne pas etre libres ?';
    }
    if (_has(q, ['conscience', 'inconscient', 'freud', 'psychanalyse', 'moi', 'identite'])) {
      return '**La conscience et l inconscient** :\n\n'
          '**Conscience** :\n'
          '  - Conscience immediate : perception directe de soi et du monde\n'
          '  - Conscience reflexive : retour de la pensee sur elle-meme\n'
          '  Descartes : "Je pense, donc je suis" (cogito)\n\n'
          '**L inconscient (Freud)** :\n'
          '  - Ca : pulsions et desirs refoulees\n'
          '  - Moi : instance qui mediate entre le Ca et le monde\n'
          '  - Surmoi : instance morale, introjection des interdits\n\n'
          '**Reve** : voie royale vers l inconscient\n\n'
          '**Critique** :\n'
          '  Sartre nie l inconscient : "mauvaise foi" plutot qu inconscient';
    }
    if (_has(q, ['bonheur', 'desir', 'plaisir', 'eudemonisme', 'hedonie', 'stoicisme', 'epicure'])) {
      return '**Le bonheur et le desir** :\n\n'
          '**Definitions** :\n'
          '  - Plaisir : satisfaction immediate et passagere\n'
          '  - Bonheur : etat durable de satisfaction totale\n\n'
          '**Epicure** : ataraxie (absence de trouble) + aponie (absence de douleur)\n'
          '  Desirs naturels et necessaires -> a satisfaire\n'
          '  Desirs vains -> a eliminer\n\n'
          '**Stoicisme** (Epictete, Marc-Aurele) :\n'
          '  Le bonheur ne depend que de nous : distinguer ce qui depend de nous / ce qui n en depend pas\n\n'
          '**Kant** : le bonheur est un ideal de l imagination, non de la raison\n'
          '  La morale ne doit pas viser le bonheur mais le devoir\n\n'
          '**Pascal** : "Tous les hommes recherchent le bonheur" mais le divertissement masque le vide';
    }
    if (_has(q, ['justice', 'droit', 'loi', 'etat', 'politique', 'contrat', 'social', 'rawls', 'rousseau'])) {
      return '**La justice et l Etat** :\n\n'
          '**Justice distributive** : donner a chacun ce qui lui revient\n'
          '  Aristote : l egalite proportionnelle\n'
          '  Rawls : le voile d ignorance -> choisir les regles sans savoir sa position sociale\n\n'
          '**Contrat social** :\n'
          '  Hobbes : l Etat evite la "guerre de tous contre tous"\n'
          '  Locke : le contrat protege les droits naturels (vie, liberte, propriete)\n'
          '  Rousseau : la volonte generale prime sur les interets particuliers\n\n'
          '**Distinction loi / droit** :\n'
          '  Loi : regles posees par l Etat\n'
          '  Droit naturel : droits inalienables (vie, liberte) anterieurs a l Etat';
    }
    if (_has(q, ['verite', 'science', 'connaissance', 'raison', 'empirisme', 'rationalisme', 'doute'])) {
      return '**La verite et la connaissance** :\n\n'
          '**Rationalisme** : la raison est source de verite (Descartes, Leibniz)\n'
          '  Le doute methodique -> certitude du cogito\n\n'
          '**Empirisme** : l experience est source de connaissance (Locke, Hume)\n'
          '  L esprit est une tabula rasa remplie par les sens\n\n'
          '**Kant** : synthese des deux\n'
          '  Les categories a priori (raison) organisent l experience (empirique)\n\n'
          '**La science** :\n'
          '  Popper : une theorie est scientifique si elle est refutable (falsifiabilite)\n'
          '  Kuhn : les paradigmes scientifiques evoluent par revolutions\n\n'
          '**Verite vs opinion** :\n'
          '  Doxa (opinion) vs Episteme (savoir veritable)';
    }
    return '**Philosophie - $level** :\n\n'
        'Je peux t aider avec :\n'
        '- La liberte et le libre arbitre\n'
        '- La conscience et l inconscient (Freud)\n'
        '- Le bonheur et le desir (Epicure, Stoiciens)\n'
        '- La justice et l Etat (Rousseau, Rawls)\n'
        '- La verite et la connaissance (Descartes, Kant)\n\n'
        'Quelle notion philosophique veux-tu approfondir ?';
  }

  // --- INFORMATIQUE ---

  static String _info(String q, String level) {
    if (_has(q, ['algorithme', 'algorithmes', 'boucle', 'condition', 'variable', 'tableau', 'tri'])) {
      return '**Algorithmique** :\n\n'
          '**Variable** : boite qui stocke une valeur\n'
          '  x = 5   # entier\n'
          '  nom = "Alice"   # chaine\n\n'
          '**Condition** :\n'
          '  si (x > 0) alors\n'
          '    afficher("positif")\n'
          '  sinon\n'
          '    afficher("negatif")\n\n'
          '**Boucle** :\n'
          '  pour i de 1 a 10 faire\n'
          '    afficher(i)\n\n'
          '  tantque (condition) faire\n'
          '    ...\n\n'
          '**Complexite** :\n'
          '  Tri par selection : O(n^2)\n'
          '  Tri rapide (quicksort) : O(n log n) en moyenne';
    }
    if (_has(q, ['python', 'def', 'fonction', 'list', 'dictionnaire', 'print', 'import'])) {
      return '**Python** :\n\n'
          '**Bases** :\n'
          '  x = 10\n'
          '  print("Bonjour")\n\n'
          '**Conditions** :\n'
          '  if x > 5:\n'
          '      print("grand")\n'
          '  elif x == 5:\n'
          '      print("egal")\n'
          '  else:\n'
          '      print("petit")\n\n'
          '**Boucles** :\n'
          '  for i in range(10):\n'
          '      print(i)\n\n'
          '**Listes** :\n'
          '  ma_liste = [1, 2, 3]\n'
          '  ma_liste.append(4)\n\n'
          '**Fonctions** :\n'
          '  def addition(a, b):\n'
          '      return a + b\n\n'
          '**Dictionnaires** :\n'
          '  d = {"nom": "Alice", "age": 20}\n'
          '  print(d["nom"])  # Alice';
    }
    if (_has(q, ['reseau', 'internet', 'ip', 'protocole', 'tcp', 'http', 'serveur', 'client'])) {
      return '**Reseaux et Internet** :\n\n'
          '**Adresse IP** : identifie une machine sur un reseau\n'
          '  IPv4 : 4 octets ex: 192.168.1.1\n'
          '  IPv6 : 128 bits (adresses plus nombreuses)\n\n'
          '**Protocoles** :\n'
          '  - TCP/IP : protocole de base d Internet\n'
          '  - HTTP : echange de pages web\n'
          '  - HTTPS : HTTP + chiffrement SSL/TLS\n'
          '  - DNS : traduit les noms de domaine en IP\n\n'
          '**Client-Serveur** :\n'
          '  Client : envoie des requetes (navigateur)\n'
          '  Serveur : repond aux requetes (heberge les sites)\n\n'
          '**Architecture d Internet** :\n'
          '  FAI -> routeurs -> serveurs\n'
          '  Routeur : dirige les paquets de donnees';
    }
    if (_has(q, ['base', 'donnee', 'sql', 'table', 'requete', 'select', 'insert', 'update', 'delete'])) {
      return '**Bases de donnees et SQL** :\n\n'
          '**Structure** : tables avec lignes (enregistrements) et colonnes (champs)\n\n'
          '**Commandes SQL** :\n\n'
          '  Lire :\n'
          '  SELECT * FROM eleves WHERE age > 18;\n\n'
          '  Inserer :\n'
          '  INSERT INTO eleves (nom, age) VALUES ("Alice", 20);\n\n'
          '  Modifier :\n'
          '  UPDATE eleves SET age = 21 WHERE nom = "Alice";\n\n'
          '  Supprimer :\n'
          '  DELETE FROM eleves WHERE id = 5;\n\n'
          '  Joindre :\n'
          '  SELECT * FROM eleves JOIN classes ON eleves.classe_id = classes.id;';
    }
    if (_has(q, ['flutter', 'dart', 'widget', 'stateful', 'stateless', 'build', 'scaffold'])) {
      return '**Flutter et Dart** :\n\n'
          '**Structure de base** :\n'
          '  void main() {\n'
          '    runApp(const MyApp());\n'
          '  }\n\n'
          '**Widget Stateless** (contenu fixe) :\n'
          '  class MonWidget extends StatelessWidget {\n'
          '    Widget build(BuildContext ctx) {\n'
          '      return Scaffold(\n'
          '        appBar: AppBar(title: Text("Titre")),\n'
          '        body: Center(child: Text("Bonjour")),\n'
          '      );\n'
          '    }\n'
          '  }\n\n'
          '**Widget Stateful** (contenu variable) :\n'
          '  class Compteur extends StatefulWidget ...\n'
          '  class _CompteurState extends State<Compteur> {\n'
          '    int _n = 0;\n'
          '    void _increment() => setState(() => _n++);\n'
          '    Widget build(BuildContext ctx) => Text("\$_n");\n'
          '  }';
    }
    return '**Informatique - $level** :\n\n'
        'Je peux t aider avec :\n'
        '- Les algorithmes et structures de donnees\n'
        '- Python (bases, fonctions, listes)\n'
        '- Les reseaux et Internet\n'
        '- Les bases de donnees et SQL\n'
        '- Flutter et Dart\n'
        '- La logique et la programmation en general\n\n'
        'Quelle notion ou quel langage veux-tu etudier ?';
  }

  // --- Generic fallback ---

  static String _generic(String subject, String level) {
    return 'Je suis pret a t aider en **$subject** au niveau **$level**.\n\n'
        'Pose-moi ta question ou donne-moi ton enonce, '
        'je vais t expliquer pas a pas !';
  }
}
