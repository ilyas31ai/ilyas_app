// Script temporaire de test — génère plusieurs dossiers d'inscription PDF
// avec des mises en page différentes pour valider le pipeline OCR/parsing
// de l'import élève. Ne fait pas partie de l'app (dossier tool/, non
// embarqué dans le build).
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main() async {
  final outDir = Directory('build/test_pdfs');
  await outDir.create(recursive: true);

  await _write(outDir, 'dossier_a_standard.pdf', [
    "Prénom : Ahmed",
    "Nom : Benali",
    "Date de naissance : 12/05/2015",
    "Sexe : Masculin",
    "Classe : CM2 A",
    "Matricule : MAT-2024-0456",
    "Nom du père : Karim Benali",
    "Téléphone père : 0612345678",
    "Email père : karim.benali@example.com",
    "Nom de la mère : Yasmine Haddad",
    "Téléphone mère : 0698765432",
    "Email mère : yasmine.haddad@example.com",
    "Adresse : 12 rue des Lilas",
    "Ville : Lyon",
    "Contact d'urgence : Fatima Benali",
    "Téléphone d'urgence : 0611223344",
    "Allergies : aucune",
    "Groupe sanguin : O+",
  ]);

  await _write(outDir, 'dossier_b_labels_separes.pdf', [
    "Nom",
    "Martin",
    "Prénom",
    "Lucie",
    "Date de naissance",
    "03/09/2016",
    "Sexe",
    "F",
    "Classe",
    "6e B",
    "Nom du père",
    "Jean Martin",
    "Téléphone du père",
    "0755443322",
    "Nom de la mère",
    "Sophie Dubois",
    "Téléphone de la mère",
    "0766778899",
    "Email de la mère",
    "sophie.dubois@example.com",
    "Adresse",
    "45 avenue Victor Hugo",
    "Ville",
    "Marseille",
  ]);

  await _write(outDir, 'dossier_c_parents_avant_eleve.pdf', [
    "FICHE D'INSCRIPTION - ECOLE ATLAS",
    "",
    "Informations Parents",
    "Nom du père: Rachid Amrani",
    "Téléphone père: 0611112222",
    "Nom de la mère: Nadia Amrani",
    "Téléphone mère: 0633334444",
    "Email mère: nadia.amrani@example.com",
    "",
    "Informations Élève",
    "Nom de l'élève: Amrani",
    "Prénom de l'élève: Yasmine",
    "Né(e) le: 21/11/2014",
    "Genre: Féminin",
    "Niveau: CE2",
    "N° matricule: 2024-778",
    "Adresse: 8 impasse des Oliviers",
    "Ville: Marrakech",
  ]);

  stdout.writeln('PDFs générés dans ${outDir.path}');
}

Future<void> _write(Directory dir, String name, List<String> lines) async {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: lines
            .map((l) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Text(l, style: const pw.TextStyle(fontSize: 14)),
                ))
            .toList(),
      ),
    ),
  );
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(await doc.save());
  stdout.writeln('  -> ${file.path}');
}
