import 'package:flutter_test/flutter_test.dart';
import 'package:scolar_ai_educative/services/document_import/regex_student_field_parser.dart';

void main() {
  final parser = RegexStudentFieldParser();

  test('dossier standard (labels + valeur sur la même ligne)', () {
    final r = parser.parse([
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
    ].join('\n'));

    expect(r.prenom.value, 'Ahmed');
    expect(r.nom.value, 'Benali');
    expect(r.dateNaissance.value, '2015-05-12');
    expect(r.sexe.value, 'M');
    expect(r.classe.value, 'CM2 A');
    expect(r.matricule.value, 'MAT-2024-0456');
    expect(r.pereNom.value, 'Karim Benali');
    expect(r.pereTelephone.value, '0612345678');
    expect(r.pereEmail.value, 'karim.benali@example.com');
    expect(r.mereNom.value, 'Yasmine Haddad');
    expect(r.mereTelephone.value, '0698765432');
    expect(r.mereEmail.value, 'yasmine.haddad@example.com');
    expect(r.adresse.value, '12 rue des Lilas');
    expect(r.ville.value, 'Lyon');
    expect(r.contactUrgenceNom.value, 'Fatima Benali');
    expect(r.contactUrgenceTelephone.value, '0611223344');
    expect(r.autresInfos, contains('Allergies'));
  });

  test('espaces parasites autour de "@" (artefact OCR courant) retirés des emails, '
      'sans que "père"/"mère" dans "Email père :"/"Email mère :" ne soit volé par pereNom/mereNom', () {
    final r = parser.parse([
      "Email père : karim.benali @ example.com",
      "Email mère : yasmine.haddad @ example.com",
    ].join('\n'));

    expect(r.pereEmail.value, 'karim.benali@example.com');
    expect(r.mereEmail.value, 'yasmine.haddad@example.com');
    expect(r.pereNom.found, isFalse);
    expect(r.mereNom.found, isFalse);
  });

  test('dossier avec labels et valeurs sur des lignes séparées, champs absents laissés vides', () {
    final r = parser.parse([
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
    ].join('\n'));

    expect(r.nom.value, 'Martin');
    expect(r.prenom.value, 'Lucie');
    expect(r.dateNaissance.value, '2016-09-03');
    expect(r.sexe.value, 'F');
    expect(r.classe.value, '6e B');
    expect(r.pereNom.value, 'Jean Martin');
    expect(r.pereTelephone.value, '0755443322');
    expect(r.mereNom.value, 'Sophie Dubois');
    expect(r.mereEmail.value, 'sophie.dubois@example.com');

    // Champs absents du document : ne doivent jamais être inventés.
    expect(r.matricule.found, isFalse);
    expect(r.pereEmail.found, isFalse);
    expect(r.contactUrgenceNom.found, isFalse);
    expect(r.contactUrgenceTelephone.found, isFalse);
  });

  test('section parents avant section élève + libellés alternatifs (né(e) le, genre, niveau)', () {
    final r = parser.parse([
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
    ].join('\n'));

    // Le nom/prénom de l'élève ne doit PAS être confondu avec ceux du père.
    expect(r.nom.value, 'Amrani');
    expect(r.prenom.value, 'Yasmine');
    expect(r.pereNom.value, 'Rachid Amrani');
    expect(r.dateNaissance.value, '2014-11-21');
    expect(r.sexe.value, 'F');
    expect(r.classe.value, 'CE2');
    expect(r.matricule.value, '2024-778');
    expect(r.mereEmail.value, 'nadia.amrani@example.com');
    expect(r.adresse.value, '8 impasse des Oliviers');
    expect(r.ville.value, 'Marrakech');
  });
}
