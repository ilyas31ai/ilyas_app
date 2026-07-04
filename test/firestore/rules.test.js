/**
 * Tests de sécurité Firestore — ScolarAI Educative
 *
 * Prérequis :
 *   1. Installer les dépendances : cd test/firestore && npm install
 *   2. Lancer l'émulateur Firebase : firebase emulators:start --only firestore
 *   3. Lancer les tests : npm test
 *
 * Les UIDs, rôles et structures de données reflètent exactement
 * le schéma Firestore de l'application.
 */

const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');

// ── Constantes ────────────────────────────────────────────────────────────────

const PROJECT_ID = 'ilyasapp-4762c';
const RULES_PATH = path.resolve(__dirname, '../../firestore.rules');

// UIDs de test (simulés)
const UID = {
  direction : 'uid-direction-001',
  prof1     : 'uid-prof-001',
  prof2     : 'uid-prof-002',
  eleve1    : 'uid-eleve-001',
  eleve2    : 'uid-eleve-002',
  parent1   : 'uid-parent-001',
  parent2   : 'uid-parent-002',
  inconnu   : 'uid-inconnu-999',
};

const CLASSE_ID  = 'classe-6A-001';
const CLASSE_NOM = '6A';
const DEVOIR_ID  = 'devoir-maths-001';
const RDV_ID     = 'rdv-parent1-prof1';
const NOTE_ID    = 'note-eleve1-001';
const COPIE_ID   = 'copie-eleve1-devoir1';
const SUB_ID     = 'sub-eleve1-devoir1';

// ── Setup ─────────────────────────────────────────────────────────────────────

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(RULES_PATH, 'utf8'),
      host : 'localhost',
      port : 8080,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();

  // Seed : profils utilisateurs
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();

    await db.collection('users').doc(UID.direction).set({
      uid: UID.direction, role: 'admin', email: 'direction@ecole.fr',
      displayName: 'Direction', enfantIds: [], enfantClasseIds: [],
    });
    await db.collection('users').doc(UID.prof1).set({
      uid: UID.prof1, role: 'professeur', email: 'prof1@ecole.fr',
      displayName: 'Prof Maths', matiere: 'Mathématiques',
      enfantIds: [], enfantClasseIds: [],
    });
    await db.collection('users').doc(UID.prof2).set({
      uid: UID.prof2, role: 'professeur', email: 'prof2@ecole.fr',
      displayName: 'Prof Français', matiere: 'Français',
      enfantIds: [], enfantClasseIds: [],
    });
    await db.collection('users').doc(UID.eleve1).set({
      uid: UID.eleve1, role: 'eleve', email: 'eleve1@ecole.fr',
      displayName: 'Alice', classeId: CLASSE_ID, classeNom: CLASSE_NOM,
      enfantIds: [], enfantClasseIds: [],
    });
    await db.collection('users').doc(UID.eleve2).set({
      uid: UID.eleve2, role: 'eleve', email: 'eleve2@ecole.fr',
      displayName: 'Bob', classeId: CLASSE_ID, classeNom: CLASSE_NOM,
      enfantIds: [], enfantClasseIds: [],
    });
    await db.collection('users').doc(UID.parent1).set({
      uid: UID.parent1, role: 'parent', email: 'parent1@mail.fr',
      displayName: 'Parent Alice',
      enfantIds: [UID.eleve1], enfantClasseIds: [CLASSE_ID],
    });
    await db.collection('users').doc(UID.parent2).set({
      uid: UID.parent2, role: 'parent', email: 'parent2@mail.fr',
      displayName: 'Parent Bob',
      enfantIds: [UID.eleve2], enfantClasseIds: [CLASSE_ID],
    });

    // Seed : devoir
    await db.collection('devoirs').doc(DEVOIR_ID).set({
      titre: 'Devoir maths', matiere: 'Mathématiques',
      classeNom: CLASSE_NOM, classeId: CLASSE_ID,
      professeurId: UID.prof1,
    });

    // Seed : note (non publiée)
    await db.collection('notes').doc(NOTE_ID).set({
      intitule: 'Contrôle maths', matiere: 'Mathématiques',
      eleveId: UID.eleve1, professeurId: UID.prof1,
      valeur: 15, sur: 20, publie: false,
    });

    // Seed : copie
    await db.collection('copies').doc(COPIE_ID).set({
      devoirId: DEVOIR_ID, eleveId: UID.eleve1,
      professeurId: UID.prof1, statut: 'brouillon',
    });

    // Seed : submission PDF
    await db.collection('submissions').doc(SUB_ID).set({
      assignmentId: DEVOIR_ID, studentId: UID.eleve1,
      teacherId: UID.prof1, statut: 'remis',
    });

    // Seed : RDV
    await db.collection('rdv').doc(RDV_ID).set({
      parentUid: UID.parent1, parentNom: 'Parent Alice',
      professeurId: UID.prof1, professeurNom: 'Prof Maths',
      eleveUid: UID.eleve1, eleveNom: 'Alice',
      classeNom: CLASSE_NOM, motif: 'Difficultés en maths',
      statut: 'demande', dateHeure: new Date(),
    });

    // Seed : fiche élève
    await db.collection('eleves').doc('eleve-fiche-001').set({
      email: 'eleve1@ecole.fr', authUid: UID.eleve1,
      classeId: CLASSE_ID, classeNom: CLASSE_NOM,
      nom: 'Dupont', prenom: 'Alice', adresse: '1 rue de la Paix',
    });
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// USERS
// ─────────────────────────────────────────────────────────────────────────────

describe('users — lecture', () => {
  test('élève lit son propre profil', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertSucceeds(db.collection('users').doc(UID.eleve1).get());
  });

  test('élève NE PEUT PAS lire le profil d\'un autre élève', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertFails(db.collection('users').doc(UID.eleve2).get());
  });

  test('professeur peut lire tous les profils', async () => {
    const db = testEnv.authenticatedContext(UID.prof1).firestore();
    await assertSucceeds(db.collection('users').doc(UID.eleve1).get());
    await assertSucceeds(db.collection('users').doc(UID.eleve2).get());
  });

  test('parent peut lire les profils (pour voir le nom de son enfant)', async () => {
    const db = testEnv.authenticatedContext(UID.parent1).firestore();
    await assertSucceeds(db.collection('users').doc(UID.eleve1).get());
  });

  test('non-authentifié NE PEUT PAS lire un profil', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.collection('users').doc(UID.eleve1).get());
  });
});

describe('users — update rôle (escalade de privilèges)', () => {
  test('élève NE PEUT PAS changer son rôle', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertFails(
      db.collection('users').doc(UID.eleve1).update({ role: 'admin' })
    );
  });

  test('élève NE PEUT PAS se donner le rôle professeur', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertFails(
      db.collection('users').doc(UID.eleve1).update({ role: 'professeur' })
    );
  });

  test('direction peut changer le rôle d\'un utilisateur', async () => {
    const db = testEnv.authenticatedContext(UID.direction).firestore();
    await assertSucceeds(
      db.collection('users').doc(UID.eleve1).update({ role: 'eleve' })
    );
  });

  test('élève peut changer son displayName', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertSucceeds(
      db.collection('users').doc(UID.eleve1).update({ displayName: 'Alice M.' })
    );
  });
});

describe('users — enfantClasseIds (protection contre la falsification)', () => {
  test('élève NE PEUT PAS modifier ses propres enfantClasseIds', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertFails(
      db.collection('users').doc(UID.eleve1).update({
        enfantClasseIds: ['classe-autre-999'],
      })
    );
  });

  test('parent peut synchroniser ses enfantClasseIds (usage légitime)', async () => {
    const db = testEnv.authenticatedContext(UID.parent1).firestore();
    await assertSucceeds(
      db.collection('users').doc(UID.parent1).update({
        enfantIds: [UID.eleve1],
        enfantClasseIds: [CLASSE_ID],
      })
    );
  });

  test('parent NE PEUT PAS modifier son rôle en synchronisant', async () => {
    const db = testEnv.authenticatedContext(UID.parent1).firestore();
    await assertFails(
      db.collection('users').doc(UID.parent1).update({
        role: 'admin',
        enfantClasseIds: [CLASSE_ID],
      })
    );
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// NOTES
// ─────────────────────────────────────────────────────────────────────────────

describe('notes — accès élève et parent', () => {
  test('élève lit sa propre note', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertSucceeds(db.collection('notes').doc(NOTE_ID).get());
  });

  test('élève NE PEUT PAS lire la note d\'un autre élève', async () => {
    // Il n'y a pas de note pour eleve2, mais on peut tester avec la note d'eleve1
    // eleve2 ≠ eleveId sur la note
    const db = testEnv.authenticatedContext(UID.eleve2).firestore();
    await assertFails(db.collection('notes').doc(NOTE_ID).get());
  });

  test('parent NE PEUT PAS lire une note non publiée de son enfant', async () => {
    const db = testEnv.authenticatedContext(UID.parent1).firestore();
    await assertFails(db.collection('notes').doc(NOTE_ID).get());
  });

  test('parent peut lire une note publiée de son enfant', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('notes').doc(NOTE_ID).update({ publie: true });
    });
    const db = testEnv.authenticatedContext(UID.parent1).firestore();
    await assertSucceeds(db.collection('notes').doc(NOTE_ID).get());
  });

  test('parent2 NE PEUT PAS lire la note de l\'enfant de parent1', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('notes').doc(NOTE_ID).update({ publie: true });
    });
    const db = testEnv.authenticatedContext(UID.parent2).firestore();
    await assertFails(db.collection('notes').doc(NOTE_ID).get());
  });

  test('élève NE PEUT PAS créer sa propre note', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertFails(
      db.collection('notes').add({
        eleveId: UID.eleve1, professeurId: UID.prof1, valeur: 20,
      })
    );
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// COPIES
// ─────────────────────────────────────────────────────────────────────────────

describe('copies — soumission et sécurité', () => {
  test('élève soumet une copie pour lui-même', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertSucceeds(
      db.collection('copies').add({
        devoirId: DEVOIR_ID, eleveId: UID.eleve1,
        professeurId: UID.prof1, statut: 'brouillon', reponses: [],
      })
    );
  });

  test('élève NE PEUT PAS soumettre une copie pour un autre élève', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertFails(
      db.collection('copies').add({
        devoirId: DEVOIR_ID, eleveId: UID.eleve2, // ← autre élève
        professeurId: UID.prof1, statut: 'brouillon',
      })
    );
  });

  test('élève peut modifier une copie en brouillon', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertSucceeds(
      db.collection('copies').doc(COPIE_ID).update({ reponses: ['A', 'B'] })
    );
  });

  test('élève NE PEUT PAS changer le devoirId d\'une copie', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertFails(
      db.collection('copies').doc(COPIE_ID).update({ devoirId: 'autre-devoir' })
    );
  });

  test('parent peut lire la copie de son enfant', async () => {
    const db = testEnv.authenticatedContext(UID.parent1).firestore();
    await assertSucceeds(db.collection('copies').doc(COPIE_ID).get());
  });

  test('parent2 NE PEUT PAS lire la copie de l\'enfant de parent1', async () => {
    const db = testEnv.authenticatedContext(UID.parent2).firestore();
    await assertFails(db.collection('copies').doc(COPIE_ID).get());
  });

  test('élève2 NE PEUT PAS lire la copie d\'élève1', async () => {
    const db = testEnv.authenticatedContext(UID.eleve2).firestore();
    await assertFails(db.collection('copies').doc(COPIE_ID).get());
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// SUBMISSIONS (PDF)
// ─────────────────────────────────────────────────────────────────────────────

describe('submissions — remises PDF', () => {
  test('élève crée sa propre remise', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertSucceeds(
      db.collection('submissions').add({
        studentId: UID.eleve1, teacherId: UID.prof1,
        assignmentId: DEVOIR_ID, statut: 'remis',
      })
    );
  });

  test('élève NE PEUT PAS créer une remise pour un autre élève', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertFails(
      db.collection('submissions').add({
        studentId: UID.eleve2, teacherId: UID.prof1, // ← autre élève
        assignmentId: DEVOIR_ID,
      })
    );
  });

  test('élève NE PEUT PAS changer le studentId ou assignmentId de sa remise', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertFails(
      db.collection('submissions').doc(SUB_ID).update({ studentId: UID.eleve2 })
    );
  });

  test('professeur peut annoter une remise qui lui est adressée', async () => {
    const db = testEnv.authenticatedContext(UID.prof1).firestore();
    await assertSucceeds(
      db.collection('submissions').doc(SUB_ID).update({ note: 15, commentaire: 'Bien' })
    );
  });

  test('prof2 NE PEUT PAS annoter une remise d\'un autre prof', async () => {
    const db = testEnv.authenticatedContext(UID.prof2).firestore();
    await assertFails(
      db.collection('submissions').doc(SUB_ID).update({ note: 10 })
    );
  });

  test('non-authentifié NE PEUT PAS lire une remise', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.collection('submissions').doc(SUB_ID).get());
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// RDV
// ─────────────────────────────────────────────────────────────────────────────

describe('rdv — demande de rendez-vous', () => {
  test('parent crée un RDV pour lui-même', async () => {
    const db = testEnv.authenticatedContext(UID.parent1).firestore();
    await assertSucceeds(
      db.collection('rdv').add({
        parentUid: UID.parent1, professeurId: UID.prof1,
        eleveUid: UID.eleve1, statut: 'demande',
        motif: 'Rencontre', dateHeure: new Date(),
      })
    );
  });

  test('parent NE PEUT PAS créer un RDV avec un autre parentUid', async () => {
    const db = testEnv.authenticatedContext(UID.parent1).firestore();
    await assertFails(
      db.collection('rdv').add({
        parentUid: UID.parent2, // ← usurpation
        professeurId: UID.prof1, eleveUid: UID.eleve2, statut: 'demande',
      })
    );
  });

  test('élève NE PEUT PAS créer un RDV', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertFails(
      db.collection('rdv').add({
        parentUid: UID.eleve1, professeurId: UID.prof1,
        eleveUid: UID.eleve1, statut: 'demande',
      })
    );
  });

  test('parent peut annuler son propre RDV', async () => {
    const db = testEnv.authenticatedContext(UID.parent1).firestore();
    await assertSucceeds(
      db.collection('rdv').doc(RDV_ID).update({ statut: 'annule' })
    );
  });

  test('parent NE PEUT PAS passer le statut directement à confirme (sans contre-proposition)', async () => {
    const db = testEnv.authenticatedContext(UID.parent1).firestore();
    await assertFails(
      db.collection('rdv').doc(RDV_ID).update({ statut: 'confirme' })
    );
  });

  test('parent NE PEUT PAS changer le professeurId du RDV', async () => {
    const db = testEnv.authenticatedContext(UID.parent1).firestore();
    await assertFails(
      db.collection('rdv').doc(RDV_ID).update({ professeurId: UID.prof2 })
    );
  });

  test('professeur peut accepter un RDV qui lui est adressé', async () => {
    const db = testEnv.authenticatedContext(UID.prof1).firestore();
    await assertSucceeds(
      db.collection('rdv').doc(RDV_ID).update({ statut: 'accepte' })
    );
  });

  test('professeur peut refuser un RDV', async () => {
    const db = testEnv.authenticatedContext(UID.prof1).firestore();
    await assertSucceeds(
      db.collection('rdv').doc(RDV_ID).update({
        statut: 'refuse', notesProfesseur: 'Indisponible ce jour',
      })
    );
  });

  test('professeur NE PEUT PAS changer le parentUid du RDV', async () => {
    const db = testEnv.authenticatedContext(UID.prof1).firestore();
    await assertFails(
      db.collection('rdv').doc(RDV_ID).update({ parentUid: UID.parent2 })
    );
  });

  test('prof2 NE PEUT PAS modifier un RDV qui ne lui est pas adressé', async () => {
    const db = testEnv.authenticatedContext(UID.prof2).firestore();
    await assertFails(
      db.collection('rdv').doc(RDV_ID).update({ statut: 'refuse' })
    );
  });

  test('parent2 NE PEUT PAS lire le RDV de parent1', async () => {
    const db = testEnv.authenticatedContext(UID.parent2).firestore();
    await assertFails(db.collection('rdv').doc(RDV_ID).get());
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// QUOTAS IA
// ─────────────────────────────────────────────────────────────────────────────

describe('quotas IA — protection des compteurs', () => {
  const today = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const docEleve1 = `${UID.eleve1}_${today}`;
  const docEleve2 = `${UID.eleve2}_${today}`;

  test('élève crée son propre document quota', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertSucceeds(
      db.collection('quotas').doc(docEleve1).set({ count: 1, role: 'eleve' })
    );
  });

  test('élève NE PEUT PAS écrire dans le quota d\'un autre élève', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertFails(
      db.collection('quotas').doc(docEleve2).set({ count: 1 })
    );
  });

  test('élève NE PEUT PAS créer un quota avec un docId forgé', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    // Essaie un docId qui ne correspond pas au pattern uid_YYYYMMDD
    await assertFails(
      db.collection('quotas').doc(`${UID.eleve1}_9999`).set({ count: 1 })
    );
  });

  test('direction peut lire tous les quotas', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('quotas').doc(docEleve1)
        .set({ count: 5, uid: UID.eleve1 });
    });
    const db = testEnv.authenticatedContext(UID.direction).firestore();
    await assertSucceeds(db.collection('quotas').doc(docEleve1).get());
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// MAÎTRISE (subcollection)
// ─────────────────────────────────────────────────────────────────────────────

describe('maitrise — données pédagogiques IA', () => {
  const NOTION_PATH = `users/${UID.eleve1}/maitrise/fractions`;

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(NOTION_PATH).set({
        notionId: 'fractions', label: 'Fractions', score: 60,
        matiere: 'Mathématiques',
      });
    });
  });

  test('élève lit ses propres notions', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertSucceeds(db.doc(NOTION_PATH).get());
  });

  test('élève NE PEUT PAS lire les notions d\'un autre élève', async () => {
    const db = testEnv.authenticatedContext(UID.eleve2).firestore();
    await assertFails(db.doc(NOTION_PATH).get());
  });

  test('parent1 lit les notions de son enfant (élève1)', async () => {
    const db = testEnv.authenticatedContext(UID.parent1).firestore();
    await assertSucceeds(db.doc(NOTION_PATH).get());
  });

  test('parent2 NE PEUT PAS lire les notions de l\'enfant de parent1', async () => {
    const db = testEnv.authenticatedContext(UID.parent2).firestore();
    await assertFails(db.doc(NOTION_PATH).get());
  });

  test('professeur peut lire les notions de tout élève', async () => {
    const db = testEnv.authenticatedContext(UID.prof1).firestore();
    await assertSucceeds(db.doc(NOTION_PATH).get());
  });

  test('élève peut écrire ses propres notions', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertSucceeds(db.doc(NOTION_PATH).update({ score: 80 }));
  });

  test('élève NE PEUT PAS écrire dans les notions d\'un autre', async () => {
    const db = testEnv.authenticatedContext(UID.eleve2).firestore();
    await assertFails(db.doc(NOTION_PATH).update({ score: 100 }));
  });

  test('parent NE PEUT PAS écrire dans les notions de son enfant', async () => {
    const db = testEnv.authenticatedContext(UID.parent1).firestore();
    await assertFails(db.doc(NOTION_PATH).update({ score: 100 }));
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// ÉLÈVES (fiches d'inscription — données sensibles)
// ─────────────────────────────────────────────────────────────────────────────

describe('eleves — protection des données personnelles', () => {
  test('direction peut lire toutes les fiches élèves', async () => {
    const db = testEnv.authenticatedContext(UID.direction).firestore();
    await assertSucceeds(
      db.collection('eleves').doc('eleve-fiche-001').get()
    );
  });

  test('professeur peut lire les fiches élèves', async () => {
    const db = testEnv.authenticatedContext(UID.prof1).firestore();
    await assertSucceeds(
      db.collection('eleves').doc('eleve-fiche-001').get()
    );
  });

  test('élève peut lire SA PROPRE fiche (via authUid)', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertSucceeds(
      db.collection('eleves').doc('eleve-fiche-001').get()
    );
  });

  test('élève2 NE PEUT PAS lire la fiche d\'élève1', async () => {
    const db = testEnv.authenticatedContext(UID.eleve2).firestore();
    await assertFails(
      db.collection('eleves').doc('eleve-fiche-001').get()
    );
  });

  test('non-authentifié NE PEUT PAS lire les fiches', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      db.collection('eleves').doc('eleve-fiche-001').get()
    );
  });

  test('élève NE PEUT PAS écrire dans les fiches', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertFails(
      db.collection('eleves').doc('eleve-fiche-001').update({ adresse: 'Forged' })
    );
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// DEVOIRS — accès par classe
// ─────────────────────────────────────────────────────────────────────────────

describe('devoirs — accès et création', () => {
  test('élève peut lire les devoirs', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertSucceeds(db.collection('devoirs').doc(DEVOIR_ID).get());
  });

  test('parent de la classe peut lire les devoirs', async () => {
    const db = testEnv.authenticatedContext(UID.parent1).firestore();
    await assertSucceeds(db.collection('devoirs').doc(DEVOIR_ID).get());
  });

  test('parent2 (même classe) peut lire les devoirs', async () => {
    const db = testEnv.authenticatedContext(UID.parent2).firestore();
    await assertSucceeds(db.collection('devoirs').doc(DEVOIR_ID).get());
  });

  test('prof peut créer un devoir pour sa classe', async () => {
    const db = testEnv.authenticatedContext(UID.prof1).firestore();
    await assertSucceeds(
      db.collection('devoirs').add({
        titre: 'Nouveau devoir', matiere: 'Mathématiques',
        classeNom: CLASSE_NOM, classeId: CLASSE_ID,
        professeurId: UID.prof1,
      })
    );
  });

  test('prof NE PEUT PAS créer un devoir avec un autre professeurId', async () => {
    const db = testEnv.authenticatedContext(UID.prof1).firestore();
    await assertFails(
      db.collection('devoirs').add({
        titre: 'Faux devoir', matiere: 'Mathématiques',
        classeNom: CLASSE_NOM, professeurId: UID.prof2, // ← usurpation
      })
    );
  });

  test('élève NE PEUT PAS créer un devoir', async () => {
    const db = testEnv.authenticatedContext(UID.eleve1).firestore();
    await assertFails(
      db.collection('devoirs').add({
        titre: 'Devoir élève', matiere: 'Maths',
        professeurId: UID.eleve1,
      })
    );
  });

  test('prof2 NE PEUT PAS modifier le devoir de prof1', async () => {
    const db = testEnv.authenticatedContext(UID.prof2).firestore();
    await assertFails(
      db.collection('devoirs').doc(DEVOIR_ID).update({ titre: 'Modifié' })
    );
  });
});
