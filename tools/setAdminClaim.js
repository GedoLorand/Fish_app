/*
Usage:
1. Place your service account JSON downloaded from Firebase Console here as `serviceAccountKey.json`.
2. Run:
   npm init -y
   npm install firebase-admin
   node tools/setAdminClaim.js
This script sets the custom claim { admin: true } on the user with email 'gedolorand@gmail.com'.
*/

const admin = require('firebase-admin');
const path = require('path');

const serviceKeyPath = path.join(__dirname, '..', 'serviceAccountKey.json');

try {
  const serviceAccount = require(serviceKeyPath);
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
} catch (e) {
  console.error('Failed to load serviceAccountKey.json. Place the file at:', serviceKeyPath);
  process.exit(1);
}

const ADMIN_EMAIL = 'gedolorand@gmail.com';

async function setAdmin(email) {
  try {
    const user = await admin.auth().getUserByEmail(email);
    console.log('Found user:', user.uid, user.email);
    await admin.auth().setCustomUserClaims(user.uid, { admin: true });
    console.log('Custom claim {admin:true} set for', email);
  } catch (err) {
    console.error('Error setting admin claim:', err);
  }
}

setAdmin(ADMIN_EMAIL).then(() => process.exit(0));
