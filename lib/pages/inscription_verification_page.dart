import 'package:flutter/material.dart';

import '../models/inscription_model.dart';
import '../services/inscription_service.dart';
import '../widgets/inscription_card.dart';

/// Liste des dossiers importés en attente de vérification manuelle.
class InscriptionVerificationPage extends StatelessWidget {
  const InscriptionVerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Vérification',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<Inscription>>(
        stream: InscriptionService.draftsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            );
          }
          final drafts = snap.data ?? [];
          if (drafts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Aucun dossier à vérifier pour le moment.\nImportez un PDF d\'inscription pour commencer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: drafts.length,
            itemBuilder: (_, i) {
              final draft = drafts[i];
              return InscriptionCard(
                inscription: draft,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InscriptionVerificationFormPage(inscription: draft),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Écran de contrôle : permet de modifier/corriger les données extraites,
/// puis de valider (création automatique élève/parent(s)/matricule) ou
/// d'annuler (aucun élève n'est créé tant que la validation n'a pas eu lieu).
class InscriptionVerificationFormPage extends StatefulWidget {
  final Inscription inscription;
  const InscriptionVerificationFormPage({super.key, required this.inscription});

  @override
  State<InscriptionVerificationFormPage> createState() =>
      _InscriptionVerificationFormPageState();
}

class _InscriptionVerificationFormPageState
    extends State<InscriptionVerificationFormPage> {
  late final TextEditingController _nomCtrl;
  late final TextEditingController _prenomCtrl;
  late final TextEditingController _adresseCtrl;
  late final TextEditingController _classeCtrl;
  late final TextEditingController _emailEleveCtrl;
  late final TextEditingController _p1NomCtrl;
  late final TextEditingController _p1TelCtrl;
  late final TextEditingController _p1EmailCtrl;
  late final TextEditingController _p2NomCtrl;
  late final TextEditingController _p2TelCtrl;
  late final TextEditingController _p2EmailCtrl;
  late final TextEditingController _urgNomCtrl;
  late final TextEditingController _urgTelCtrl;
  late final TextEditingController _urgLienCtrl;

  DateTime? _dateNaissance;
  String _sexe = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final i = widget.inscription;
    _nomCtrl = TextEditingController(text: i.eleve.nom);
    _prenomCtrl = TextEditingController(text: i.eleve.prenom);
    _adresseCtrl = TextEditingController(text: i.eleve.adresse);
    _classeCtrl = TextEditingController(text: i.eleve.classeDemandee);
    _emailEleveCtrl = TextEditingController(text: i.eleve.emailEleve);
    _dateNaissance = i.eleve.dateNaissance;
    _sexe = i.eleve.sexe;

    _p1NomCtrl = TextEditingController(text: i.parent1.nomComplet);
    _p1TelCtrl = TextEditingController(text: i.parent1.telephone);
    _p1EmailCtrl = TextEditingController(text: i.parent1.email);

    final p2 = i.parent2;
    _p2NomCtrl = TextEditingController(text: p2?.nomComplet ?? '');
    _p2TelCtrl = TextEditingController(text: p2?.telephone ?? '');
    _p2EmailCtrl = TextEditingController(text: p2?.email ?? '');

    _urgNomCtrl = TextEditingController(text: i.urgence.nom);
    _urgTelCtrl = TextEditingController(text: i.urgence.telephone);
    _urgLienCtrl = TextEditingController(text: i.urgence.lien);
  }

  @override
  void dispose() {
    for (final c in [
      _nomCtrl, _prenomCtrl, _adresseCtrl, _classeCtrl, _emailEleveCtrl,
      _p1NomCtrl, _p1TelCtrl, _p1EmailCtrl,
      _p2NomCtrl, _p2TelCtrl, _p2EmailCtrl,
      _urgNomCtrl, _urgTelCtrl, _urgLienCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateNaissance ?? DateTime(now.year - 6),
      firstDate: DateTime(now.year - 25),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF2563EB),
            surface: Color(0xFF161B22),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dateNaissance = picked);
  }

  Future<void> _valider() async {
    if (_saving) return;
    if (_nomCtrl.text.trim().isEmpty || _prenomCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Le nom et le prénom de l\'élève sont obligatoires'),
        backgroundColor: Color(0xFFDC2626),
      ));
      return;
    }

    setState(() => _saving = true);

    final eleve = EleveInfo(
      nom: _nomCtrl.text.trim(),
      prenom: _prenomCtrl.text.trim(),
      dateNaissance: _dateNaissance,
      sexe: _sexe,
      adresse: _adresseCtrl.text.trim(),
      classeDemandee: _classeCtrl.text.trim(),
      emailEleve: _emailEleveCtrl.text.trim().toLowerCase(),
    );
    final parent1 = ParentInfo(
      nomComplet: _p1NomCtrl.text.trim(),
      telephone: _p1TelCtrl.text.trim(),
      email: _p1EmailCtrl.text.trim(),
    );
    final parent2Raw = ParentInfo(
      nomComplet: _p2NomCtrl.text.trim(),
      telephone: _p2TelCtrl.text.trim(),
      email: _p2EmailCtrl.text.trim(),
    );
    final parent2 = parent2Raw.isEmpty ? null : parent2Raw;
    final urgence = ContactUrgence(
      nom: _urgNomCtrl.text.trim(),
      telephone: _urgTelCtrl.text.trim(),
      lien: _urgLienCtrl.text.trim(),
    );

    await InscriptionService.updateDraft(
      widget.inscription.id,
      eleve: eleve,
      parent1: parent1,
      parent2: parent2,
      urgence: urgence,
    );
    final confirmed = widget.inscription.copyWith(
      eleve: eleve,
      parent1: parent1,
      parent2: parent2,
      urgence: urgence,
    );
    await InscriptionService.confirmInscription(confirmed);

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Dossier validé : élève et matricule créés, en attente de décision'),
      backgroundColor: Color(0xFF16A34A),
    ));
  }

  Future<void> _annuler() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Annuler ce dossier ?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Le brouillon sera supprimé et aucun élève ne sera créé.',
          style: TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Annuler le dossier', style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await InscriptionService.cancelDraft(widget.inscription.id);
    if (!mounted) return;
    Navigator.pop(context);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Vérification du dossier',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Élève'),
            _field('Nom', _nomCtrl),
            _field('Prénom', _prenomCtrl),
            _dateField(),
            _sexeField(),
            _field('Adresse', _adresseCtrl, maxLines: 2),
            _field('Classe demandée', _classeCtrl),
            _field('Email du compte élève', _emailEleveCtrl,
                keyboard: TextInputType.emailAddress),
            const SizedBox(height: 10),
            _sectionTitle('Parent 1'),
            _field('Nom complet', _p1NomCtrl),
            _field('Téléphone', _p1TelCtrl, keyboard: TextInputType.phone),
            _field('Email', _p1EmailCtrl, keyboard: TextInputType.emailAddress),
            const SizedBox(height: 10),
            _sectionTitle('Parent 2 (optionnel)'),
            _field('Nom complet', _p2NomCtrl),
            _field('Téléphone', _p2TelCtrl, keyboard: TextInputType.phone),
            _field('Email', _p2EmailCtrl, keyboard: TextInputType.emailAddress),
            const SizedBox(height: 10),
            _sectionTitle('Contact d\'urgence'),
            _field('Nom', _urgNomCtrl),
            _field('Téléphone', _urgTelCtrl, keyboard: TextInputType.phone),
            _field('Lien avec l\'élève', _urgLienCtrl),
          ],
        ),
      ),
      bottomNavigationBar: _actionsBar(),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 10),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2),
        ),
      );

  Widget _field(String label, TextEditingController ctrl,
      {int maxLines = 1, TextInputType? keyboard}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          filled: true,
          fillColor: const Color(0xFF161B22),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: border,
          enabledBorder: border,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2563EB)),
          ),
        ),
      ),
    );
  }

  Widget _dateField() {
    final label = _dateNaissance != null
        ? '${_dateNaissance!.day.toString().padLeft(2, '0')}/'
            '${_dateNaissance!.month.toString().padLeft(2, '0')}/'
            '${_dateNaissance!.year}'
        : 'Date de naissance';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Row(
            children: [
              const Icon(Icons.cake_outlined, color: Colors.white38, size: 18),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                    color: _dateNaissance != null ? Colors.white : Colors.white38,
                    fontSize: 14),
              ),
              const Spacer(),
              const Icon(Icons.calendar_today_outlined, color: Colors.white24, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sexeField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: _sexeChip('Masculin')),
          const SizedBox(width: 10),
          Expanded(child: _sexeChip('Féminin')),
        ],
      ),
    );
  }

  Widget _sexeChip(String value) {
    final selected = _sexe == value;
    return InkWell(
      onTap: () => setState(() => _sexe = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2563EB).withValues(alpha: 0.18)
              : const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? const Color(0xFF2563EB) : Colors.white.withValues(alpha: 0.07)),
        ),
        child: Text(
          value,
          style: TextStyle(
              color: selected ? const Color(0xFF2563EB) : Colors.white60,
              fontWeight: FontWeight.w600,
              fontSize: 13),
        ),
      ),
    );
  }

  Widget _actionsBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(color: Color(0xFF161B22)),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : _annuler,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFDC2626)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Annuler'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _valider,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check, size: 18),
                label: Text(_saving ? 'Validation…' : 'Valider'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
