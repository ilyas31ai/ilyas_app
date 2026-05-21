import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {

  final TextEditingController controller =
      TextEditingController();

  final ScrollController scrollController =
      ScrollController();

  final ImagePicker picker =
      ImagePicker();

  List<Map<String, dynamic>> messages = [];

  String niveau = "Collège";
  String matiere = "";
String chapitre = "";



  // 🔊 TTS
  final FlutterTts flutterTts =
      FlutterTts();

  // 🔑 OPENAI — passed at build time via --dart-define=OPENAI_API_KEY=sk-...
  static const String apiKey =
      String.fromEnvironment('OPENAI_API_KEY');

  @override
  void initState() {
    super.initState();

    

    loadMessages();
  }

  // 🔊 VOIX
Future speak(String text) async {

  // 🇬🇧 Anglais seulement
  if (matiere == "Anglais") {

    await flutterTts.setLanguage(
      "en-US",
    );

  } else {

    // 🇫🇷 Tout le reste en français
    await flutterTts.setLanguage(
      "fr-FR",
    );

  }

  await flutterTts.setPitch(1.0);

  await flutterTts.setSpeechRate(0.45);

  await flutterTts.speak(text);
}


  // 📷 IMAGE
  Future<void> pickImage() async {

    final XFile? image =
        await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (image == null) return;

    setState(() {

      messages.add({
        "type": "image",
        "path": image.path,
        "isUser": true,
      });

      messages.add({
        "type": "text",
        "text":
            "📷 Image ajoutée",
        "isUser": false,
      });
    });

    scrollBottom();
  }

  // 🔽 SCROLL
  void scrollBottom() {

    Future.delayed(
      const Duration(milliseconds: 300),
      () {

        if (scrollController
            .hasClients) {

          scrollController.animateTo(

            scrollController.position
                .maxScrollExtent,

            duration:
                const Duration(
                    milliseconds: 300),

            curve: Curves.easeOut,
          );
        }
      },
    );
  }

  // 💾 SAVE
  Future<void> saveMessages() async {

    final prefs =
        await SharedPreferences
            .getInstance();

    List<String> encoded =
        messages
            .where((m) =>
                m["text"] !=
                    "⏳ L'IA réfléchit..." &&
                m["text"] !=
                    "⚠️ Choisis une matière 📚")
            .map((m) => jsonEncode(m))
            .toList();

    await prefs.setStringList(
      "messages",
      encoded,
    );
  }

  // 📂 LOAD
  Future<void> loadMessages() async {

    final prefs =
        await SharedPreferences
            .getInstance();

    List<String>? data =
        prefs.getStringList(
            "messages");

    if (data != null) {

      setState(() {

        messages = data
            .map((e) =>
                Map<String, dynamic>.from(
                    jsonDecode(e)))
            .toList();

      });

      scrollBottom();
    }
  }

  // 🗑️ CLEAR
  Future<void> clearMessages() async {

    final prefs =
        await SharedPreferences
            .getInstance();

    await prefs.remove("messages");

    setState(() {
      messages.clear();
    });
  }



  // 📄 PDF
  Future<void> generatePdf(
      String text) async {
String cleanText = text
    .replaceAll(r'\times', '×')
    .replaceAll(r'\pi', 'π')
    .replaceAll(r'\euro', '€')
    .replaceAll('π', 'pi')
    .replaceAll('€', 'euros')
    .replaceAll(r'\\times', 'x')
    .replaceAll(r'\\frac', '')
    .replaceAll(r'\\(', '')
    .replaceAll(r'\\)', '')
    .replaceAll(r'\frac', '')
    .replaceAll(r'\(', '')
    .replaceAll(r'\)', '')
    .replaceAll(r'\[', '')
    .replaceAll(r'\]', '')
    .replaceAll('{', '')
    .replaceAll('}', '')
    .replaceAll(r'\\', '')
    .replaceAll('\$', '');
    final pdf = pw.Document();

    final image =
        await imageFromAssetBundle(
      'assets/logo.png',
    );

    pdf.addPage(

      pw.MultiPage(

        build: (context) => [

          pw.Row(

            children: [

              pw.Container(

                width: 60,
                height: 60,

                child:
                    pw.Image(image),
              ),

              pw.SizedBox(width: 20),

              pw.Text(

                "ILYAS31AI",

                style:
                    pw.TextStyle(

                  fontSize: 28,

                  fontWeight:
                      pw.FontWeight
                          .bold,
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 30),

          pw.Text(
  cleanText,
  style: const pw.TextStyle(
    fontSize: 16,
  ),
),
        ],
      ),
    );

    await Printing.layoutPdf(

      onLayout: (format) async =>
          pdf.save(),
    );
  }

  // 📚 MATIÈRES
  List<String> getMatieres() {

    switch (niveau) {
     
      case "Collège":
        return [
          "Maths",
          "Français",
          "Anglais",
          "Histoire",
          "SVT"
        ];

      case "Lycée":
        return [
          "Maths",
          "Physique",
          "Français",
          "Philo",
          "SVT"
        ];

      case "BAC":
        return [
          "Maths",
          "Physique",
          "SES",
          "Philo",
          "SVT"
        ];

      case "Université":
        return [
          "Algorithme",
          "Programmation",
          "Maths",
          "Réseaux"
        ];

      case "DELF":
        return [
          "A1",
          "A2",
          "B1",
          "B2",
          "C1"
        ];

      default:
        return [];
    }
  }
List<String> getChapitres() {

  // 📘 COLLÈGE - MATHS
  if (niveau == "Collège" &&
      matiere == "Maths") {
    return [
      "Calcul",
      "Fractions",
      "Équations",
      "Géométrie",
      "Pythagore",
      "Pourcentages",
      "Volumes",
      "Aires",
    ];
  }

  // 🇫🇷 COLLÈGE - FRANÇAIS
  if (niveau == "Collège" &&
      matiere == "Français") {
    return [
      "Grammaire",
      "Conjugaison",
      "Orthographe",
      "Dictée",
      "Lecture",
      "Rédaction",
      "Poésie",
      "Vocabulaire",
    ];
  }

  // 🇬🇧 COLLÈGE - ANGLAIS
  if (niveau == "Collège" &&
      matiere == "Anglais") {
    return [
      "Grammar",
      "Vocabulary",
      "Present Simple",
      "Past Simple",
      "Present Perfect",
      "Irregular Verbs",
      "Listening",
      "Pronunciation",
    ];
  }

  // 🧠 BAC - MATHS
  if (niveau == "BAC" &&
      matiere == "Maths") {
    return [
      "Suites",
      "Fonctions",
      "Dérivées",
      "Probabilités",
      "Matrices",
      "Géométrie",
    ];
  }

  // ⚡ BAC - PHYSIQUE
  if (niveau == "BAC" &&
      matiere == "Physique") {
    return [
      "Mécanique",
      "Électricité",
      "Ondes",
      "Chimie",
      "Forces",
    ];
  }

  // 🎓 UNIVERSITÉ - ALGORITHME
  if (niveau == "Université" &&
      matiere == "Algorithme") {
    return [
      "Variables",
      "Boucles",
      "Conditions",
      "Fonctions",
      "Tableaux",
      "Algorithmes",
    ];
  }

  // 💻 UNIVERSITÉ - PROGRAMMATION
  if (niveau == "Université" &&
      matiere == "Programmation") {
    return [
      "Flutter",
      "Dart",
      "Python",
      "Java",
      "HTML",
      "API",
    ];
  }

  // 🇫🇷 DELF
  if (niveau == "DELF") {
    return [
      "Compréhension orale",
      "Compréhension écrite",
      "Production orale",
      "Production écrite",
      "Grammaire",
      "Vocabulaire",
    ];
  }

  return [];
}
  // 🤖 SEND
  void sendMessage() async {

    String userText =
        controller.text.trim();

    if (userText.isEmpty) return;

    controller.clear();

    setState(() {

      messages.add({
        "type": "text",
        "text": userText,
        "isUser": true,
      });

    });

    saveMessages();

    scrollBottom();

    if (matiere.isEmpty) {

      setState(() {

        messages.add({
          "type": "text",
          "text":
              "⚠️ Choisis une matière 📚",
          "isUser": false,
        });

      });

      scrollBottom();

      return;
    }

    setState(() {

      messages.add({
        "type": "text",
        "text":
            "⏳ L'IA réfléchit...",
        "isUser": false,
      });

    });

    scrollBottom();

    try {

      final response =
          await http.post(

        Uri.parse(
          "https://api.openai.com/v1/chat/completions",
        ),

        headers: {

          "Authorization":
              "Bearer $apiKey",

          "Content-Type":
              "application/json",
        },

        body: jsonEncode({

          "model":
              "gpt-3.5-turbo",

          "messages": [

            {
              "role": "system",

              "content":
"""
Tu es SCOLAR AI, un assistant scolaire intelligent, moderne et pédagogique.

════════════════════
📚 INFORMATIONS
════════════════════

- Matière : $matiere
- Niveau : $niveau
- Chapitre : $chapitre

════════════════════
🎯 TON RÔLE
════════════════════

Tu aides les élèves du :
- Collège
- Lycée
- BAC
- Université
- DELF

Tu peux :
- expliquer les leçons
- simplifier les notions difficiles
- créer des exercices
- créer des devoirs
- créer des examens
- corriger les réponses
- faire des résumés
- créer des fiches de révision
- aider aux devoirs
- donner des méthodes
- préparer aux contrôles
- préparer au BAC
- préparer au DELF
- aider en programmation
- motiver l'élève

════════════════════
📖 MÉTHODE DE RÉPONSE
════════════════════

- Réponds toujours clairement
- Utilise un français simple
- Sois pédagogique
- Explique étape par étape
- Donne des exemples
- Fais des réponses organisées
- Utilise des titres
- Adapte le niveau selon l'élève
- Encourage toujours l'élève
- Fais des réponses modernes et agréables à lire

════════════════════
📊 SUPPORT VISUEL
════════════════════

Quand c'est utile :
- utilise des tableaux
- utilise des listes
- explique avec étapes
- montre les tables de multiplication
- montre les formules importantes
- aide visuellement l'élève
- organise bien les réponses

Pour le primaire :
- utilise des exercices simples
- utilise les tables de multiplication
- explique lentement
- utilise des exemples faciles
- encourage beaucoup l'élève

Pour le collège et lycée :
- utilise des méthodes détaillées
- montre les calculs
- explique les formules
- donne des astuces
- montre les étapes importantes

Pour le BAC :
- fais des exercices type BAC
- explique les méthodes officielles
- donne des conseils d'examen
- aide à réviser rapidement
- montre les pièges à éviter

Pour l'université :
- donne des explications avancées
- utilise des exemples concrets
- explique la logique des concepts
- aide à comprendre la théorie
- aide en algorithmique
- aide en développement
- aide en réseaux
- aide en bases de données

════════════════════
🧮 RÈGLES POUR LES MATHS
════════════════════

- N'utilise jamais LaTeX
- N'écris jamais :

\\(
\\)
\\[
\\]
\\frac
\\times
\\div

- Écris les calculs normalement

Exemples :
- 1/2
- 3/4
- 5 × 8
- 25 ÷ 5
- x² + 3x

- Affiche les calculs étape par étape
- Utilise des tableaux si nécessaire
- Explique les formules simplement

════════════════════
💻 PROGRAMMATION
════════════════════

Si la matière est :
- Algorithme
- Programmation
- Réseaux
- Informatique

Alors :
- explique le code simplement
- montre des exemples
- corrige les erreurs
- aide en Flutter
- aide en Python
- aide en C
- aide en Java
- aide en HTML/CSS
- aide en SQL
- explique les bugs
- aide à créer des applications
- aide à comprendre les concepts

════════════════════
🇫🇷 DELF
════════════════════

Si le niveau est DELF :
- aide en compréhension
- aide en grammaire
- aide en conjugaison
- crée des dialogues
- crée des productions écrites
- corrige les fautes
- améliore le vocabulaire
- aide à parler français
- aide à préparer l'examen DELF

════════════════════
📝 EXERCICES
════════════════════

Si l'utilisateur demande un exercice :
- donne d'abord l'exercice
- attends la réponse
- puis corrige étape par étape

Si l'utilisateur demande une correction :
- explique les erreurs
- donne la bonne méthode
- encourage l'élève

════════════════════
⭐ IMPORTANT
════════════════════

- Sois intelligent
- Sois motivant
- Sois professionnel
- Réponds toujours proprement
- Fais des réponses modernes
- Fais des réponses agréables à lire
- Utilise des emojis quand c'est utile
- Donne envie d'apprendre
- Aide vraiment l'élève à progresser

"""
            },

            {
              "role": "user",
              "content": userText
            }

          ]
        }),
      );

      final data =
          jsonDecode(
              response.body);

      String reponse =
          data["choices"][0]
              ["message"]
              ["content"];

      setState(() {

        messages.removeLast();

        messages.add({
          "type": "text",
          "text": reponse,
          "isUser": false,
        });

      });

      saveMessages();

      scrollBottom();

    } catch (e) {

      setState(() {

        messages.removeLast();

        messages.add({

          "type": "text",

          "text":
              "❌ Erreur OpenAI",

          "isUser": false,
        });

      });

      scrollBottom();
    }
  }

  // 📎 PDF
  Future<void> pickPdf() async {

    FilePickerResult? result =
        await FilePicker.platform
            .pickFiles(

      type: FileType.custom,

      allowedExtensions: ['pdf'],
    );

    if (result != null) {

      String fileName =
          result.files.single.name;

      setState(() {

        messages.add({
          "type": "pdf",
          "name": fileName,
          "isUser": true,
        });

        messages.add({
          "type": "text",
          "text": "📄 PDF reçu",
          "isUser": false,
        });

      });

      saveMessages();

      scrollBottom();
    }
  }

  @override
  Widget build(
      BuildContext context) {

    return Scaffold(

      backgroundColor:
          Colors.black,

      drawer: Drawer(

        child: ListView(

          children: [

            const DrawerHeader(

              decoration:
                  BoxDecoration(
                color:
                    Colors.deepPurple,
              ),

              child: Text(

                "Choisir niveau",

                style: TextStyle(
                  color:
                      Colors.white,
                  fontSize: 20,
                ),
              ),
            ),
            
            buildNiveau(
                "Collège"),
            buildNiveau(
                "Lycée"),
            buildNiveau("BAC"),
            buildNiveau(
                "Université"),
            buildNiveau("DELF"),

          ],
        ),
      ),

      appBar: AppBar(

        backgroundColor:
            Colors.black,

        title:
            const Text("ILYAS31AI"),

        actions: [

          IconButton(

            icon: const Icon(
              Icons.delete,
            ),

            onPressed:
                clearMessages,
          ),
        ],
      ),

      body: Column(

        children: [

          // 📚 MATIÈRES
          Container(

            height: 60,

            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 10,
            ),

            child: ListView(

              scrollDirection:
                  Axis.horizontal,

              children:
                  getMatieres()
                      .map((m) {

                return Padding(

                  padding:
                      const EdgeInsets
                          .only(
                    right: 10,
                  ),

                  child:
                      ChoiceChip(

                    label:
                        Text(m),

                    selected:
                        matiere ==
                            m,

                    onSelected:
                        (_) {

                      setState(() {
                        matiere =
                            m;
                      });

                    },
                  ),
                );

              }).toList(),
            ),
          ),
// 📘 CHAPITRES
if (getChapitres().isNotEmpty)
  Container(
    height: 60,
    padding: const EdgeInsets.symmetric(
      horizontal: 10,
    ),
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: getChapitres().map((c) {
        return Padding(
          padding: const EdgeInsets.only(
            right: 10,
          ),
          child: ChoiceChip(
            label: Text(c),
            selected: chapitre == c,
            onSelected: (_) {
              setState(() {
                chapitre = c;
              });
            },
          ),
        );
      }).toList(),
    ),
  ),
          // 💬 CHAT
          Expanded(

            child:
                ListView.builder(

              controller:
                  scrollController,

              itemCount:
                  messages.length,

              itemBuilder:
                  (context,
                      index) {

                var msg =
                    messages[
                        index];

                // 📷 IMAGE
                if (msg["type"] ==
                    "image") {

                  return Align(

                    alignment:
                        Alignment
                            .centerRight,

                    child:
                        Container(

                      margin:
                          const EdgeInsets
                              .all(
                                  8),

                      child:
                          Image.file(

                        File(
                            msg["path"]),

                        width: 200,
                      ),
                    ),
                  );
                }

                // 📄 PDF
                if (msg["type"] ==
                    "pdf") {

                  return Align(

                    alignment:
                        Alignment
                            .centerRight,

                    child:
                        Container(

                      margin:
                          const EdgeInsets
                              .all(
                                  8),

                      padding:
                          const EdgeInsets
                              .all(
                                  10),

                      decoration:
                          BoxDecoration(

                        color: Colors
                            .blueGrey,

                        borderRadius:
                            BorderRadius.circular(
                                12),
                      ),

                      child:
                          SelectableText(

                        msg["name"],

                        style:
                            const TextStyle(
                          color: Colors
                              .white,
                        ),
                      ),
                    ),
                  );
                }

                // 💬 TEXT
                return Align(

                  alignment:
                      msg["isUser"]

                          ? Alignment
                              .centerRight

                          : Alignment
                              .centerLeft,

                  child:
                      Container(

                    constraints:
                        const BoxConstraints(
                      maxWidth: 500,
                    ),

                    margin:
                        const EdgeInsets
                            .all(8),

                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),

                    decoration:
                        BoxDecoration(

                      color: msg[
                              "isUser"]
                          ? Colors
                              .blue
                          : Colors
                              .grey
                              .shade800,

                      borderRadius:
                          BorderRadius
                              .circular(
                                  15),
                    ),

                    child: Column(

                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                      children: [

                        SelectableText(

                          msg["text"],

                          style:
                              const TextStyle(
                            color: Colors
                                .white,
                            fontSize:
                                16,
                          ),
                        ),

                        const SizedBox(
                            height:
                                10),

                        // 📄 PDF
                        if (!msg[
                            "isUser"])

                          ElevatedButton.icon(

                            onPressed:
                                () async {

                              String
                                  texte =
                                  msg["text"] ??
                                      "";

                              await generatePdf(
                                  texte);
                            },

                            icon:
                                const Icon(
                              Icons
                                  .picture_as_pdf,
                            ),

                            label:
                                const Text(
                              "PDF",
                            ),
                          ),

                        const SizedBox(
                            height:
                                8),

                        // 🔊 VOIX
                        if (!msg[
                            "isUser"])

                          ElevatedButton.icon(

                            onPressed:
                                () async {

                              String
                                  texte =
                                  msg["text"] ??
                                      "";

                              await speak(
                                  texte);
                            },

                            icon:
                                const Icon(
                              Icons
                                  .volume_up,
                            ),

                            label:
                                const Text(
                              "Lire",
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ✍️ INPUT
          Container(

            padding:
                const EdgeInsets
                    .all(10),

            child: Row(

              children: [

                // 📎 PDF
                IconButton(

                  icon:
                      const Icon(
                    Icons
                        .attach_file,
                    color:
                        Colors.white,
                  ),

                  onPressed:
                      pickPdf,
                ),

                // 📷 IMAGE
                IconButton(

                  icon:
                      const Icon(
                    Icons.image,
                    color:
                        Colors.white,
                  ),

                  onPressed:
                      pickImage,
                ),

                // ✍️ INPUT
                Expanded(

                  child:
                      TextField(

                    controller:
                        controller,

                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                    ),

                    onSubmitted:
                        (_) =>
                            sendMessage(),

                    decoration:
                        InputDecoration(

                      hintText:
                          "Message...",

                      hintStyle:
                          const TextStyle(
                        color: Colors
                            .white54,
                      ),

                      filled: true,

                      fillColor:
                          Colors
                              .grey
                              .shade900,

                      border:
                          OutlineInputBorder(

                        borderRadius:
                            BorderRadius.circular(
                                30),

                        borderSide:
                            BorderSide
                                .none,
                      ),
                    ),
                  ),
                ),

                // 🎤
                IconButton(

                  icon: const Icon(
  Icons.mic_off,
  color: Colors.white,
),
onPressed: null,
                ),

                // 🚀
                IconButton(

                  icon:
                      const Icon(
                    Icons.send,
                    color:
                        Colors.white,
                  ),

                  onPressed:
                      sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 📚 NIVEAU
  Widget buildNiveau(
      String name) {

    return ListTile(

      title: Text(name),

      onTap: () {

        setState(() {

          niveau = name;
          matiere = "";

        });

        Navigator.pop(context);
      },
    );
  }
}