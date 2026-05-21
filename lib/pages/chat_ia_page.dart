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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:speech_to_text/speech_to_text.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  final _tts = FlutterTts();
  final _speech = SpeechToText();

  List<Map<String, dynamic>> _messages = [];
  String _niveau = "Collège";
  String _matiere = "";
  String _chapitre = "";
  bool _isLoading = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  int? _speakingIndex;

  DatabaseReference? _dbRef;

  static const String _apiKey = String.fromEnvironment('OPENAI_API_KEY');

  // ─── Data tables ───────────────────────────────────────────────────────────

  static const _matieres = {
    "Collège":    ["Maths", "Français", "Anglais", "Histoire", "SVT"],
    "Lycée":      ["Maths", "Physique", "Français", "Philo", "SVT"],
    "BAC":        ["Maths", "Physique", "SES", "Philo", "SVT"],
    "Université": ["Algorithme", "Programmation", "Maths", "Réseaux"],
    "DELF":       ["A1", "A2", "B1", "B2", "C1"],
  };

  static const _chapitres = {
    "Collège/Maths":            ["Calcul", "Fractions", "Équations", "Géométrie", "Pythagore", "Pourcentages", "Volumes", "Aires"],
    "Collège/Français":         ["Grammaire", "Conjugaison", "Orthographe", "Dictée", "Lecture", "Rédaction", "Poésie", "Vocabulaire"],
    "Collège/Anglais":          ["Grammar", "Vocabulary", "Present Simple", "Past Simple", "Present Perfect", "Irregular Verbs"],
    "Collège/Histoire":         ["Antiquité", "Moyen Âge", "Renaissance", "Révolution", "Guerres mondiales"],
    "Collège/SVT":              ["Cellule", "Nutrition", "Reproduction", "Génétique", "Écosystèmes"],
    "BAC/Maths":                ["Suites", "Fonctions", "Dérivées", "Probabilités", "Matrices", "Géométrie"],
    "BAC/Physique":             ["Mécanique", "Électricité", "Ondes", "Chimie", "Forces"],
    "Université/Algorithme":    ["Variables", "Boucles", "Conditions", "Fonctions", "Tableaux", "Tri"],
    "Université/Programmation": ["Flutter", "Dart", "Python", "Java", "HTML/CSS", "API REST"],
    "Université/Réseaux":       ["TCP/IP", "DNS", "HTTP", "Sécurité", "Routage"],
  };

  List<String> get _currentMatieres => _matieres[_niveau] ?? [];

  List<String> get _currentChapitres {
    final key = "$_niveau/$_matiere";
    if (_chapitres.containsKey(key)) return _chapitres[key]!;
    if (_niveau == "DELF") {
      return ["Compréhension orale", "Compréhension écrite", "Production orale", "Production écrite", "Grammaire", "Vocabulaire"];
    }
    return [];
  }

  // ─── Init / dispose ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initTts();
    _initSpeech();
    _initStorage();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _tts.stop();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("fr-FR");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.45);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speakingIndex = null);
    });
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (_) => setState(() => _isListening = false),
    );
    if (mounted) setState(() {});
  }

  void _initStorage() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _dbRef = FirebaseDatabase.instance.ref('ai_chat/$uid');
      _loadFromFirebase();
    } else {
      _loadFromPrefs();
    }
  }

  // ─── Persistence ───────────────────────────────────────────────────────────

  Future<void> _loadFromFirebase() async {
    try {
      final snap = await _dbRef!.get();
      if (snap.exists && snap.value != null) {
        final raw = (snap.value as Map<Object?, Object?>)['data'] as String?;
        if (raw != null) {
          final list = (jsonDecode(raw) as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          if (mounted) {
            setState(() => _messages = list);
            _scrollToBottom();
          }
          return;
        }
      }
    } catch (_) {}
    await _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('ai_messages');
    if (data != null && mounted) {
      setState(() {
        _messages = data
            .map((e) => Map<String, dynamic>.from(jsonDecode(e) as Map))
            .toList();
      });
      _scrollToBottom();
    }
  }

  Future<void> _persist() async {
    final exportable = _messages.where((m) => m['type'] == 'text').toList();
    final encoded = jsonEncode(exportable);

    if (_dbRef != null) {
      try { await _dbRef!.set({'data': encoded}); } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'ai_messages',
      exportable.map((m) => jsonEncode(m)).toList(),
    );
  }

  Future<void> _clearMessages() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Effacer la conversation ?"),
        content: const Text("Tous les messages seront supprimés définitivement."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Effacer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try { await _dbRef?.remove(); } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ai_messages');
    setState(() => _messages.clear());
  }

  // ─── Scroll ────────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── Voice ─────────────────────────────────────────────────────────────────

  Future<void> _toggleListening() async {
    if (!_speechAvailable) return;

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      localeId: _matiere == "Anglais" ? "en_US" : "fr_FR",
      onResult: (result) {
        setState(() {
          _controller.text = result.recognizedWords;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
      },
    );
  }

  Future<void> _speak(String text, int index) async {
    if (_speakingIndex == index) {
      await _tts.stop();
      setState(() => _speakingIndex = null);
      return;
    }
    setState(() => _speakingIndex = index);
    await _tts.setLanguage(_matiere == "Anglais" ? "en-US" : "fr-FR");
    await _tts.speak(text);
  }

  // ─── OpenAI ────────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    if (_matiere.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Choisis une matière d'abord 📚")),
      );
      return;
    }

    _controller.clear();
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }

    final userMsg = {
      'type': 'text',
      'text': text,
      'isUser': true,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      // Build last-20-message history for multi-turn context
      final history = _messages
          .where((m) => m['type'] == 'text' && m['text'] != null)
          .toList();
      final window = history.length > 20 ? history.sublist(history.length - 20) : history;
      final apiHistory = window
          .map((m) => {
                'role': (m['isUser'] as bool) ? 'user' : 'assistant',
                'content': m['text'] as String,
              })
          .toList();

      final response = await http.post(
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $_apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {"role": "system", "content": _systemPrompt()},
            ...apiHistory,
          ],
          "max_tokens": 1500,
          "temperature": 0.7,
        }),
      );

      if (response.statusCode != 200) throw Exception("HTTP ${response.statusCode}");

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final reply = (data["choices"] as List)[0]["message"]["content"] as String;

      final aiMsg = {
        'type': 'text',
        'text': reply.trim(),
        'isUser': false,
        'ts': DateTime.now().millisecondsSinceEpoch,
      };
      if (!mounted) return;
      setState(() {
        _messages.add(aiMsg);
        _isLoading = false;
      });
      await _persist();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'type': 'text',
          'text': '❌ Erreur : vérifier la connexion ou la clé API.',
          'isUser': false,
          'ts': DateTime.now().millisecondsSinceEpoch,
        });
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  String _systemPrompt() => """Tu es SCOLAR AI, un assistant scolaire intelligent et bienveillant.

Niveau : $_niveau | Matière : $_matiere${_chapitre.isNotEmpty ? ' | Chapitre : $_chapitre' : ''}

Règles absolues :
- Réponds en français (en anglais si matière = "Anglais")
- Explique clairement, étape par étape, avec des exemples
- Encourage toujours l'élève
- N'utilise JAMAIS de LaTeX — écris les maths normalement : 1/2, x², 5×8, 25÷5
- Utilise des listes à puces et des titres courts pour structurer
- Adapte la profondeur au niveau $_niveau
- Si l'élève pose un exercice, donne-lui d'abord le temps de répondre avant de corriger""";

  // ─── Attachments ───────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null || !mounted) return;
    setState(() => _messages.add({
      'type': 'image',
      'path': img.path,
      'isUser': true,
      'ts': DateTime.now().millisecondsSinceEpoch,
    }));
    _scrollToBottom();
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || !mounted) return;
    setState(() => _messages.add({
      'type': 'pdf',
      'name': result.files.single.name,
      'isUser': true,
      'ts': DateTime.now().millisecondsSinceEpoch,
    }));
    _scrollToBottom();
  }

  // ─── PDF export ────────────────────────────────────────────────────────────

  Future<void> _exportPdf(String text) async {
    final clean = text
        .replaceAll(RegExp(r'\\[a-zA-Z]+\{[^}]*\}'), '')
        .replaceAll(RegExp(r'[\\${}]'), '')
        .trim();

    final pdf = pw.Document();
    final logo = await imageFromAssetBundle('assets/logo.png');

    pdf.addPage(pw.MultiPage(build: (ctx) => [
      pw.Row(children: [
        pw.Container(width: 48, height: 48, child: pw.Image(logo)),
        pw.SizedBox(width: 14),
        pw.Text("SCOLAR AI",
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      ]),
      pw.SizedBox(height: 6),
      pw.Text(
        "$_niveau — $_matiere${_chapitre.isNotEmpty ? ' — $_chapitre' : ''}",
        style: const pw.TextStyle(fontSize: 11),
      ),
      pw.Divider(),
      pw.SizedBox(height: 14),
      pw.Text(clean, style: const pw.TextStyle(fontSize: 13)),
    ]));

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      drawer: _buildDrawer(),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildMatiereBar(),
          if (_currentChapitres.isNotEmpty) _buildChapitreBar(),
          Expanded(child: _buildMessageList()),
          if (_isLoading) _buildTypingIndicator(),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ─── AppBar ────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF161B22),
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("SCOLAR AI",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(
            _matiere.isNotEmpty ? "$_niveau · $_matiere" : _niveau,
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white70),
          tooltip: "Effacer",
          onPressed: _clearMessages,
        ),
      ],
    );
  }

  // ─── Drawer ────────────────────────────────────────────────────────────────

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF161B22),
      child: Column(
        children: [
          DrawerHeader(
            margin: EdgeInsets.zero,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4C1D95), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Niveau scolaire",
                      style: TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(_niveau,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _matieres.keys.map((n) {
                final selected = n == _niveau;
                return ListTile(
                  leading: Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: selected ? const Color(0xFF2563EB) : Colors.white38,
                    size: 20,
                  ),
                  title: Text(n,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      )),
                  selected: selected,
                  selectedTileColor: Colors.white.withValues(alpha: 0.06),
                  onTap: () {
                    setState(() {
                      _niveau = n;
                      _matiere = "";
                      _chapitre = "";
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Matière / Chapitre bars ───────────────────────────────────────────────

  Widget _buildMatiereBar() {
    return Container(
      height: 52,
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _currentMatieres.map((m) {
          final sel = _matiere == m;
          return Padding(
            padding: const EdgeInsets.only(right: 8, top: 9, bottom: 9),
            child: ChoiceChip(
              label: Text(m),
              selected: sel,
              onSelected: (_) => setState(() { _matiere = m; _chapitre = ""; }),
              selectedColor: const Color(0xFF2563EB),
              backgroundColor: const Color(0xFF21262D),
              labelStyle: TextStyle(
                color: sel ? Colors.white : Colors.white60,
                fontSize: 13,
                fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChapitreBar() {
    return Container(
      height: 44,
      color: const Color(0xFF0D1117),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _currentChapitres.map((c) {
          final sel = _chapitre == c;
          return Padding(
            padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
            child: ChoiceChip(
              label: Text(c, style: const TextStyle(fontSize: 12)),
              selected: sel,
              onSelected: (_) => setState(() => _chapitre = c),
              selectedColor: const Color(0xFF6D28D9),
              backgroundColor: const Color(0xFF161B22),
              labelStyle: TextStyle(color: sel ? Colors.white : Colors.white54),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Message list ──────────────────────────────────────────────────────────

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 56, color: Color(0xFF2563EB)),
            const SizedBox(height: 16),
            const Text(
              "SCOLAR AI",
              style: TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Choisis une matière et pose ta question",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, i) => _buildBubble(_messages[i], i),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg, int index) {
    final isUser = msg['isUser'] as bool? ?? false;
    final type = msg['type'] as String? ?? 'text';

    if (type == 'image') {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(File(msg['path'] as String), width: 220),
          ),
        ),
      );
    }

    if (type == 'pdf') {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF21262D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Text(msg['name'] as String? ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    // Text bubble
    final maxW = MediaQuery.of(context).size.width * 0.80;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxW),
        margin: EdgeInsets.only(
          left: isUser ? 60 : 12,
          right: isUser ? 12 : 60,
          top: 3,
          bottom: 3,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF2563EB) : const Color(0xFF21262D),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              msg['text'] as String? ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.45),
            ),
            if (!isUser) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _chip(
                    icon: _speakingIndex == index ? Icons.stop_rounded : Icons.volume_up_rounded,
                    label: _speakingIndex == index ? "Stop" : "Écouter",
                    onTap: () => _speak(msg['text'] as String? ?? '', index),
                  ),
                  const SizedBox(width: 8),
                  _chip(
                    icon: Icons.picture_as_pdf_outlined,
                    label: "PDF",
                    onTap: () => _exportPdf(msg['text'] as String? ?? ''),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white60),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60)),
          ],
        ),
      ),
    );
  }

  // ─── Typing indicator ──────────────────────────────────────────────────────

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 12, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF21262D),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: const _TypingDots(),
      ),
    );
  }

  // ─── Input bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(top: BorderSide(color: Color(0xFF30363D))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file, size: 22),
              color: Colors.white54,
              tooltip: "Joindre un PDF",
              onPressed: _pickPdf,
            ),
            IconButton(
              icon: const Icon(Icons.image_outlined, size: 22),
              color: Colors.white54,
              tooltip: "Joindre une image",
              onPressed: _pickImage,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                maxLines: 5,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _matiere.isEmpty ? "Choisis une matière..." : "Pose ta question...",
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFF21262D),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                size: 22,
                color: _isListening
                    ? Colors.redAccent
                    : (_speechAvailable ? Colors.white54 : Colors.white24),
              ),
              tooltip: _speechAvailable ? "Dicter" : "Micro indisponible",
              onPressed: _speechAvailable ? _toggleListening : null,
            ),
            _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.send_rounded, size: 22, color: Color(0xFF2563EB)),
                    tooltip: "Envoyer",
                    onPressed: _sendMessage,
                  ),
          ],
        ),
      ),
    );
  }
}

// ─── Animated typing dots ──────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = (_ctrl.value + i / 3) % 1.0;
          final opacity = (0.3 + 0.7 * (1.0 - (2 * t - 1).abs())).clamp(0.3, 1.0);
          return Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}
