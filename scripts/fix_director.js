/**
 * fix_director.js
 * Corrige un compte Directeur dont role='eleve' dans Firestore.
 *
 * Usage :
 *   node scripts/fix_director.js
 *
 * Prérequis : être authentifié avec `firebase login` (projet ilyasapp-4762c).
 */

const https = require('https');
const fs    = require('fs');
const path  = require('path');
const os    = require('os');

const PROJECT = 'ilyasapp-4762c';
const UID     = 'bAZ2krwHFeMdCox0DONQKN9Mum03';
const NAME    = 'harbi mohamed ali';
const BASE    = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

function getToken() {
  const cfgPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
  const t = cfg.tokens;
  if (!t || !t.access_token) throw new Error('Pas de token. Lancez : firebase login');
  if (Date.now() > t.expires_at) throw new Error('Token expiré. Lancez : firebase login');
  return t.access_token;
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
  const token = getToken();

  // ── 1. Patch users/{uid} ──────────────────────────────────────────────────
  const mask = 'updateMask.fieldPaths=role&updateMask.fieldPaths=schoolId&updateMask.fieldPaths=displayName';
  const r1 = await request('PATCH', `${BASE}/users/${UID}?${mask}`, token, {
    fields: {
      role:        fsField('string', 'direction'),
      schoolId:    fsField('string', UID),
      displayName: fsField('string', NAME),
    },
  });
  const ok1 = r1.status === 200;
  console.log(`users/${UID}  → role=${r1.data.fields?.role?.stringValue}  [${ok1 ? 'OK' : 'ERREUR ' + r1.status}]`);

  // ── 2. Créer / patcher schools/{uid} ─────────────────────────────────────
  const getR = await request('GET', `${BASE}/schools/${UID}`, token);
  let r2;
  if (getR.status === 200) {
    const mask2 = 'updateMask.fieldPaths=directeurId&updateMask.fieldPaths=statut';
    r2 = await request('PATCH', `${BASE}/schools/${UID}?${mask2}`, token, {
      fields: {
        directeurId: fsField('string', UID),
        statut:      fsField('string', 'actif'),
      },
    });
    console.log(`schools/${UID} → directeurId=${r2.data.fields?.directeurId?.stringValue}  [${r2.status === 200 ? 'OK' : 'ERREUR ' + r2.status}]`);
  } else {
    r2 = await request('POST', `${BASE}/schools?documentId=${UID}`, token, {
      fields: {
        nom:         fsField('string', "Etablissement de " + NAME),
        directeurId: fsField('string', UID),
        statut:      fsField('string', 'actif'),
        campusIds:   { arrayValue: { values: [] } },
      },
    });
    console.log(`schools/${UID} → créé  directeurId=${r2.data.fields?.directeurId?.stringValue}  [${r2.status === 200 ? 'OK' : 'ERREUR ' + r2.status}]`);
  }

  if (ok1 && r2.status === 200) {
    console.log('\nSUCCES — le compte est maintenant configuré en tant que Directeur.');
    console.log('Relancez l\'app ou reconnectez-vous pour voir l\'interface Direction.');
  } else {
    console.log('\nATTENTION — une ou plusieurs opérations ont échoué.');
  }
}

run().catch(e => { console.error('Erreur fatale:', e.message); process.exit(1); });
