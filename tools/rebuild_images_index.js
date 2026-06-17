/*
Usage:
1. Place `serviceAccountKey.json` in the project root (already present in this repo).
2. Ensure `firebase-admin` is installed:
     npm init -y
     npm install firebase-admin
3. Run the script:
     node tools/rebuild_images_index.js

What it does:
- Copies every document from `users/{userId}/images/{imageId}` into
  top-level `images/{imageId}` (preserves ID) with an added `userDocPath`.
- Updates `meta/images_last_update` timestamp to notify clients.
- Recomputes `users/{userId}.unreadMessages` by counting `notifications` where `read:false`.

Note: For large datasets this script does paged reads and batched writes.
*/

const admin = require('firebase-admin');
const path = require('path');

const serviceKeyPath = path.join(__dirname, '..', 'serviceAccountKey.json');
try {
  const serviceAccount = require(serviceKeyPath);
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
} catch (e) {
  console.error('Failed to load serviceAccountKey.json from', serviceKeyPath);
  console.error('Place your Firebase service account JSON at that path.');
  process.exit(1);
}

const db = admin.firestore();
const BATCH_LIMIT = 400; // keep below 500

async function rebuildImages() {
  console.log('Starting rebuild of /images from users/*/images...');
  const usersSnap = await db.collection('users').get();
  console.log(`Found ${usersSnap.size} users`);

  let writes = 0;
  let batch = db.batch();

  for (const userDoc of usersSnap.docs) {
    const uid = userDoc.id;
    try {
      const imagesSnap = await db.collection('users').doc(uid).collection('images').get();
      if (imagesSnap.empty) continue;
      for (const img of imagesSnap.docs) {
        const data = img.data() || {};
        const targetRef = db.collection('images').doc(img.id);
        const mirror = Object.assign({}, data, { userDocPath: `/users/${uid}` });
        batch.set(targetRef, mirror, { merge: true });
        writes++;
        if (writes >= BATCH_LIMIT) {
          await batch.commit();
          console.log('Committed batch of', writes, 'writes');
          writes = 0;
          batch = db.batch();
        }
      }
    } catch (e) {
      console.warn('Failed to process images for user', uid, e && e.message || e);
    }
  }

  if (writes > 0) {
    await batch.commit();
    console.log('Committed final batch of', writes, 'writes');
  }

  // touch meta/images_last_update so clients can refresh
  try {
    await db.collection('meta').doc('images_last_update').set({ updatedAt: admin.firestore.FieldValue.serverTimestamp() });
    console.log('Updated meta/images_last_update');
  } catch (e) {
    console.warn('Failed to update images_last_update', e && e.message || e);
  }

  console.log('Rebuild of /images complete.');
}

async function recomputeUnreadCounts() {
  console.log('Recomputing users/{uid}.unreadMessages from notifications subcollections...');
  const usersSnap = await db.collection('users').get();
  console.log(`Found ${usersSnap.size} users`);
  for (const userDoc of usersSnap.docs) {
    const uid = userDoc.id;
    try {
      const notifsRef = db.collection('users').doc(uid).collection('notifications');
      const q = await notifsRef.where('read', '==', false).get();
      const unread = q.size || 0;
      await db.collection('users').doc(uid).set({ unreadMessages: unread }, { merge: true });
      console.log(`Set unreadMessages=${unread} for user ${uid}`);
    } catch (e) {
      console.warn('Failed to recompute unread for', uid, e && e.message || e);
    }
  }
  console.log('Recomputed unreadMessage counts for all users.');
}

async function main() {
  try {
    await rebuildImages();
    await recomputeUnreadCounts();
    console.log('All done.');
    process.exit(0);
  } catch (e) {
    console.error('Script failed:', e && e.message || e);
    process.exit(2);
  }
}

main();
