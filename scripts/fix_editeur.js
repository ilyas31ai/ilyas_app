/**
 * fix_editeur.js
 * Corrige le role Firestore du compte Éditeur (editeur.scolarai@gmail.com),
 * bloqué à 'eleve' depuis son premier login (comportement par défaut de
 * UserService.syncProfile() — aucune saisie ne permet de choisir le rôle
 * 'editeur' à l'inscription, et firestore.rules interdit à un compte de
 * changer son propre champ `role` par une écriture client classique).
 *
 * L'accès à l'Espace Éditeur reste entièrement gouverné par la liste blanche
 * UID (EditeurAccessService / isEditeurUid() dans firestore.rules) — ce script
 * ne fait que corriger le rôle affiché pour activer la navigation dédiée
 * (onglets Tableau de bord / Support / Statistiques dans MainShell).
 *
 * Usage :
 *   node scripts/fix_editeur.js
 *
 * Prérequis : être authentifié avec `firebase login` (projet ilyasapp-4762c).
 */

const https = require('https');
const fs    = require('fs');
const path  = require('path');
const os    = require('os');
const { execSync } = require('child_process');

const PROJECT = 'ilyasapp-4762c';
const UID     = 'BClcAaJaPOaURt79hmT8dBfQ6M22'; // editeur.scolarai@gmail.com
const BASE    = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

// Le cache access_token/expires_at de firebase-tools.json n'est pas toujours à
// jour (le CLI rafraîchit en interne sans forcément le persister). On passe
// donc systématiquement par le refresh_token pour obtenir un access_token
// frais, comme lors de la méthode de reset mot de passe (2026-08-02).
async function getToken() {
  const cfgPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
  const refreshToken = cfg.tokens?.refresh_token;
  if (!refreshToken) throw new Error('Pas de refresh_token. Lancez : firebase login');

  const globalNpmRoot = execSync('npm root -g', { encoding: 'utf8' }).trim();
  const authPath = path.join(globalNpmRoot, 'firebase-tools', 'lib', 'auth.js');
  const { getAccessToken } = require(authPath);
  const scopesPath = path.join(globalNpmRoot, 'firebase-tools', 'lib', 'scopes.js');
  const scopes = require(scopesPath);

  const result = await getAccessToken(refreshToken, [scopes.CLOUD_PLATFORM]);
  return result.access_token;
}

function request(method, url, token, body) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const opts = {
      hostname: u.hostname,
      path: u.pathname + u.search,
      method,
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    };
    const raw = body ? JSON.stringify(body) : null;
    if (raw) opts.headers['Content-Length'] = Buffer.byteLength(raw);
    const req = https.request(opts, res => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => resolve({ status: res.statusCode, data: JSON.parse(d) }));
    });
    req.on('error', reject);
    if (raw) req.write(raw);
    req.end();
  });
}

function fsField(type, value) { return { [type + 'Value']: value }; }

async function run() {
  const token = await getToken();

  const getR = await request('GET', `${BASE}/users/${UID}`, token);
  if (getR.status !== 200) {
    console.log(`ERREUR — impossible de lire users/${UID} [${getR.status}]`);
    console.log(JSON.stringify(getR.data));
    process.exit(1);
  }
  const currentRole = getR.data.fields?.role?.stringValue;
  console.log(`users/${UID} → role actuel = ${currentRole}`);

  const mask = 'updateMask.fieldPaths=role';
  const r = await request('PATCH', `${BASE}/users/${UID}?${mask}`, token, {
    fields: { role: fsField('string', 'editeur') },
  });
  const ok = r.status === 200;
  console.log(`users/${UID}  → role=${r.data.fields?.role?.stringValue}  [${ok ? 'OK' : 'ERREUR ' + r.status}]`);

  if (ok) {
    console.log('\nSUCCES — le compte Éditeur a maintenant role=editeur.');
    console.log('Reconnectez-vous (ou relancez l\'app) pour voir la navigation dédiée Éditeur.');
  } else {
    console.log('\nATTENTION — la mise à jour a échoué.');
    console.log(JSON.stringify(r.data));
  }
}

run().catch(e => { console.error('Erreur fatale:', e.message); process.exit(1); });
