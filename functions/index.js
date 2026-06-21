const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const vision = require('@google-cloud/vision');
const axios = require('axios');
let sendgrid;
try {
  sendgrid = require('@sendgrid/mail');
} catch (e) {
  console.warn('sendgrid not installed; report email notifications will be disabled');
}

console.log('Cloud Function module loaded: analyzeImageForFish (Google Vision)');

// Load additional function modules (ai_api exports `api`) and merge exports
try {
  const _ai = require('./ai_api');
  Object.assign(exports, _ai || {});
  console.log('Loaded ai_api module and merged exports');
} catch (e) {
  console.warn('ai_api module not loaded:', e && e.message);
}

/**
 * Callable function: analyzeImageForFish
 * Uses Google Cloud Vision labelDetection to detect likely labels in an image.
 * Accepts: { imageUrl?: string, imageBase64?: string }
 */
exports.analyzeImageForFish = functions.https.onCall(async (data, context) => {
  console.log('analyzeImageForFish called. incoming data keys:', Object.keys(data || {}));
  console.log('analyzeImageForFish context.auth:', context && context.auth ? { uid: context.auth.uid, token: context.auth.token ? 'present' : 'no-token' } : null);

  // Normalize payload
  let imageUrl = data && data.imageUrl;
  let imageBase64 = data && data.imageBase64;
  if ((!imageUrl || typeof imageUrl !== 'string') && data && typeof data.data === 'object') {
    if (typeof data.data.imageUrl === 'string') imageUrl = data.data.imageUrl;
    if (typeof data.data.imageBase64 === 'string') imageBase64 = data.data.imageBase64;
  }

  console.log('Resolved inputs: imageUrl present=', !!imageUrl, 'imageBase64 present=', !!imageBase64);
  if ((!imageUrl || typeof imageUrl !== 'string') && (!imageBase64 || typeof imageBase64 !== 'string')) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing or invalid imageUrl or imageBase64');
  }

  // helper: create signed URL for gs:// paths (used only if caller sends gs://)
  async function ensurePublicUrl(url) {
    if (!url || typeof url !== 'string') return url;
    if (url.startsWith('gs://')) {
      const withoutPrefix = url.replace('gs://', '');
      const idx = withoutPrefix.indexOf('/');
      if (idx <= 0) return url;
      const bucketName = withoutPrefix.slice(0, idx);
      const filePath = withoutPrefix.slice(idx + 1);
      try {
        const [signedUrl] = await admin.storage().bucket(bucketName).file(filePath).getSignedUrl({
          action: 'read',
          expires: Date.now() + 15 * 60 * 1000 // 15 minutes
        });
        console.log('Generated signed URL for', url);
        return signedUrl;
      } catch (e) {
        console.warn('Failed to create signed URL for', url, e && e.message || e);
        return url;
      }
    }
    return url;
  }

  // Perform Vision label detection
  const visionClient = new vision.ImageAnnotatorClient();
  async function performVisionDetection({ imageUrl, imageBase64 }) {
    let imageContentBuffer = null;
    if (imageBase64 && typeof imageBase64 === 'string') {
      // Accept either raw base64 or data URL
      const m = imageBase64.match(/^data:.*;base64,(.*)$/);
      const b64 = m ? m[1] : imageBase64;
      imageContentBuffer = Buffer.from(b64, 'base64');
    } else if (imageUrl && typeof imageUrl === 'string') {
      // If gs://, convert to signed https URL first
      const publicUrl = await ensurePublicUrl(imageUrl);
      console.log('Fetching image bytes for Vision:', publicUrl && publicUrl.slice ? publicUrl.slice(0, 200) : publicUrl);
      const resp = await axios.get(publicUrl, { responseType: 'arraybuffer', timeout: 20000 });
      imageContentBuffer = Buffer.from(resp.data);
    }

    if (!imageContentBuffer) throw new Error('Failed to obtain image bytes for Vision analysis');

    console.log('Calling Vision labelDetection');
    const [result] = await visionClient.labelDetection({ image: { content: imageContentBuffer } });
    const annotations = result.labelAnnotations || [];
    const labels = annotations.map(a => ({ description: String(a.description || ''), score: typeof a.score === 'number' ? a.score : null }));
    return { labels, raw: result };
  }

  try {
    const apiResp = await performVisionDetection({ imageUrl, imageBase64 });

    // Detect fish keywords in labels/raw
    const fishRegex = /fish|salmon|trout|carp|bass|cod|perch|tilapia|pike|mackerel|catfish|herring|sardine/i;
    const combinedText = apiResp.labels.map(l => l.description).join(' ').toLowerCase() + ' ' + JSON.stringify(apiResp.raw).toLowerCase();
    const isFish = fishRegex.test(combinedText);

    const result = { isFish, labels: apiResp.labels, raw: apiResp.raw };

    // Persist detection result to Firestore so the client (uploader) can read later
    try {
      const db = admin.firestore();
      let docId = null;
      if (imageUrl && imageUrl.startsWith('gs://')) {
        const without = imageUrl.replace('gs://', '');
        docId = without.replace(/\//g, '__');
      } else if (imageUrl) {
        // use URL-encoded key
        docId = encodeURIComponent(imageUrl).slice(0, 150);
      } else {
        docId = `img_${Date.now()}`;
      }
      await db.collection('imageDetections').doc(docId).set({
        imageUrl: imageUrl || null,
        isFish: result.isFish,
        labels: result.labels,
        raw: result.raw,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      console.log('Wrote detection result to imageDetections/', docId);
    } catch (e) {
      console.warn('Failed to persist detection result to Firestore:', e && e.message || e);
    }

    return result;
  } catch (err) {
    console.error('Vision detection error:', err && (err.stack || err.message) || err);
    throw new functions.https.HttpsError('internal', `Detection API error: ${err && (err.message || err)}`);
  }
});

// Storage trigger: generate a small thumbnail for uploaded images.
const path = require('path');
const os = require('os');
const fs = require('fs');
let sharp;
try {
  sharp = require('sharp');
} catch (e) {
  console.warn('sharp not available:', e && e.message || e);
}

// Firestore trigger: when a report is created, send an email notification to the app owner (if SendGrid is configured)
if (functions && functions.firestore && typeof functions.firestore.document === 'function') {
  exports.onReportCreated = functions.firestore
    .document('reports/{reportId}')
    .onCreate(async (snap, context) => {
      const report = snap.data() || {};
      const apiKey = process.env.SENDGRID_API_KEY || functions.config && functions.config().sendgrid && functions.config().sendgrid.key;
      if (!sendgrid || !apiKey) {
        console.log('SendGrid not configured; skipping report email for', context.params.reportId);
        return null;
      }
      try {
        sendgrid.setApiKey(apiKey);
        const ownerEmail = 'gedolorand@gmail.com';
        const reporter = report.reporterEmail || report.reporterName || report.reporterUid || 'ismeretlen';
        const subject = `Jelentés érkezett: ${report.reason || 'ok'}`;
        const bodyLines = [];
        bodyLines.push(`Jelentő: ${reporter}`);
        bodyLines.push(`Kép tulajdonos: ${report.imageOwnerName || report.imageOwnerUid || 'ismeretlen'}`);
        bodyLines.push(`Kép doc/id: ${report.imageDocId || 'n/a'}`);
        bodyLines.push(`Kép URL: ${report.imageUrl || 'n/a'}`);
        bodyLines.push(`Ok: ${report.reason || 'n/a'}`);
        if (report.note) bodyLines.push(`Megjegyzés: ${report.note}`);
        bodyLines.push(`Idő: ${new Date().toISOString()}`);

        const msg = {
          to: ownerEmail,
          from: ownerEmail,
          subject: subject,
          text: bodyLines.join('\n'),
        };
        await sendgrid.send(msg);
        console.log('Sent report email for', context.params.reportId);
      } catch (e) {
        console.warn('Failed to send report email:', e && e.message || e);
      }
      return null;
    });
} else {
  console.warn('Firestore triggers not available; skipping onReportCreated registration');
}

// Some firebase-functions versions used in analysis/deploy may not expose
// `functions.storage.object` as a function at module load time (causes
// TypeError during analysis). Guard registration so the codebase can be
// analyzed and other triggers (like our Firestore mirror) can still deploy.
if (functions && functions.storage && typeof functions.storage.object === 'function') {
  exports.generateThumbnail = functions.storage.object().onFinalize(async (object) => {
    // Only process image files.
    const contentType = object.contentType || '';
    if (!contentType.startsWith('image/')) {
      console.log('Not an image, skipping thumbnail generation:', object.name);
      return null;
    }

    // Avoid processing already-generated thumbnails (we'll prefix with 'thumb_')
    const filePath = object.name; // e.g. user_images/uid/123.jpg
    if (!filePath) return null;
    const fileName = path.basename(filePath);
    if (fileName.startsWith('thumb_')) {
      console.log('Already a thumbnail, skipping:', filePath);
      return null;
    }

    if (!sharp) {
      console.warn('sharp not installed; thumbnail generation skipped');
      return null;
    }

    const bucket = admin.storage().bucket(object.bucket);
    const tempDir = os.tmpdir();
    const tempFilePath = path.join(tempDir, fileName);
    const thumbFileName = 'thumb_' + fileName;
    const thumbFilePath = path.join(path.dirname(filePath), thumbFileName);

    try {
      // Download original image
      await bucket.file(filePath).download({ destination: tempFilePath });
      console.log('Downloaded original image to', tempFilePath);

      // Resize using sharp
      const thumbBuffer = await sharp(tempFilePath)
        .resize({ width: 400, withoutEnlargement: true })
        .jpeg({ quality: 70 })
        .toBuffer();

      // Write the thumbnail to temp file then upload
      const tempThumbPath = path.join(tempDir, thumbFileName);
      fs.writeFileSync(tempThumbPath, thumbBuffer);

      await bucket.upload(tempThumbPath, {
        destination: thumbFilePath,
        metadata: { contentType: 'image/jpeg' },
      });
      console.log('Uploaded thumbnail to', thumbFilePath);

      // Cleanup temp files
      try { fs.unlinkSync(tempFilePath); } catch (_) {}
      try { fs.unlinkSync(tempThumbPath); } catch (_) {}
      return null;
    } catch (err) {
      console.error('Thumbnail generation failed for', filePath, err && (err.stack || err.message) || err);
      try { fs.unlinkSync(tempFilePath); } catch (_) {}
      return null;
    }
  });
} else {
  console.warn('Storage triggers not available in this firebase-functions version; skipping generateThumbnail registration.');
}

// Mirror user image documents to top-level /images collection so all users can
// query them reliably. This handles create/update/delete on
// /users/{userId}/images/{imageId}.
if (functions && functions.firestore && typeof functions.firestore.document === 'function') {
  exports.mirrorUserImage = functions.firestore
    .document('users/{userId}/images/{imageId}')
    .onWrite(async (change, context) => {
      const db = admin.firestore();
      const userId = context.params.userId;
      const imageId = context.params.imageId;
      try {
        if (!change.after.exists) {
          // deleted -> remove mirror
          await db.collection('images').doc(imageId).delete();
          console.log('mirrorUserImage: deleted mirror for', imageId);
          return null;
        }
        const data = change.after.data();
        if (!data) return null;
        const mirror = Object.assign({}, data, { userDocPath: `/users/${userId}` });
        await db.collection('images').doc(imageId).set(mirror);
        console.log('mirrorUserImage: mirrored', imageId, 'from user', userId);
      } catch (e) {
        console.warn('mirrorUserImage: failed for', imageId, e && e.message || e);
      }
      return null;
    });
} else {
  try {
    const { onDocumentWritten } = require('firebase-functions/v2/firestore');

    function parseProtoFields(fields) {
      const obj = {};
      for (const k in fields) {
        const v = fields[k];
        if (!v) { obj[k] = null; continue; }
        if (v.stringValue !== undefined) obj[k] = v.stringValue;
        else if (v.integerValue !== undefined) obj[k] = Number(v.integerValue);
        else if (v.doubleValue !== undefined) obj[k] = Number(v.doubleValue);
        else if (v.booleanValue !== undefined) obj[k] = v.booleanValue;
        else if (v.mapValue && v.mapValue.fields) obj[k] = parseProtoFields(v.mapValue.fields);
        else if (v.arrayValue && Array.isArray(v.arrayValue.values)) {
          obj[k] = v.arrayValue.values.map(item => {
            if (item.stringValue !== undefined) return item.stringValue;
            if (item.integerValue !== undefined) return Number(item.integerValue);
            if (item.doubleValue !== undefined) return Number(item.doubleValue);
            if (item.booleanValue !== undefined) return item.booleanValue;
            if (item.mapValue && item.mapValue.fields) return parseProtoFields(item.mapValue.fields);
            return null;
          });
        } else obj[k] = null;
      }
      return obj;
    }

    function extractDataFromV2(snapshot) {
      if (!snapshot) return null;
      if (typeof snapshot.data === 'function') return snapshot.data();
      if (snapshot.fields) return parseProtoFields(snapshot.fields);
      return snapshot;
    }

    exports.mirrorUserImage = onDocumentWritten('users/{userId}/images/{imageId}', async (event) => {
      const db = admin.firestore();
      const userId = event.params && event.params.userId;
      const imageId = event.params && event.params.imageId;
      try {
        const before = event.data && event.data.before;
        const after = event.data && event.data.after;
        const afterData = extractDataFromV2(after);
        if (!afterData) {
          // deleted
          await db.collection('images').doc(imageId).delete();
          console.log('mirrorUserImage(v2): deleted mirror for', imageId);
          return null;
        }
        const mirror = Object.assign({}, afterData, { userDocPath: `/users/${userId}` });
        await db.collection('images').doc(imageId).set(mirror);
        console.log('mirrorUserImage(v2): mirrored', imageId, 'from user', userId);
      } catch (e) {
        console.warn('mirrorUserImage(v2): failed for', imageId, e && e.message || e);
      }
      return null;
    });
  } catch (e) {
    console.warn('Firestore triggers not available in this firebase-functions version; skipping mirrorUserImage registration.', e && e.message || e);
  }
}

// Firestore trigger: when a message is created under supported /messages subcollections,
// notify the image owner by incrementing their unreadMessages counter and writing
// a notification document under users/{ownerId}/notifications/{autoId}.
function _handleMessageCreated(snap, context) {
  return (async () => {
    try {
      const msg = snap.data() || {};
      const senderUid = msg.senderUid || null;
      // Determine parent image document (parent of this messages collection)
      const parent = snap.ref.parent.parent; // DocumentReference
      if (!parent) {
        console.log('onMessageCreated: no parent doc for message', context && context.params && context.params.messageId);
        return null;
      }
      const imageSnap = await parent.get();
      if (!imageSnap.exists) {
        console.log('onMessageCreated: parent image doc not found', parent.path);
        return null;
      }
      const imageData = imageSnap.data() || {};
      const ownerId = imageData.ownerId || imageData.owner || null;
      if (!ownerId) {
        console.log('onMessageCreated: no ownerId on image', parent.path);
        return null;
      }
      if (senderUid && senderUid === ownerId) {
        // Owner commented on own image; don't increment
        console.log('onMessageCreated: sender is owner, skipping increment', ownerId);
        return null;
      }

      const db = admin.firestore();
      const userRef = db.collection('users').doc(ownerId);
      // Increment unreadMessages atomically
      await userRef.set({ unreadMessages: admin.firestore.FieldValue.increment(1) }, { merge: true });

      // Create a notification document for richer UI/history
      const notif = {
        type: 'message',
        imagePath: parent.path,
        imageId: parent.id || null,
        messageId: context && context.params && context.params.messageId,
        fromUid: senderUid || null,
        excerpt: (typeof msg.text === 'string' ? (msg.text.length > 300 ? msg.text.substring(0, 300) + '...' : msg.text) : null),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
      };
      await userRef.collection('notifications').add(notif);
      console.log('onMessageCreated: notified owner', ownerId, 'for image', parent.path);
    } catch (e) {
      console.warn('onMessageCreated: handler failed', e && e.message || e);
    }
    return null;
  })();
}

// Register explicit, supported Firestore triggers so the CLI discovers them reliably.
if (functions && functions.firestore && typeof functions.firestore.document === 'function') {
  // Top-level images collection messages
  exports.onMessageCreated_images = functions.firestore
    .document('images/{imageId}/messages/{messageId}')
    .onCreate((snap, context) => _handleMessageCreated(snap, context));

  // Per-user images (mirror may also create these) messages
  exports.onMessageCreated_userImages = functions.firestore
    .document('users/{userId}/images/{imageId}/messages/{messageId}')
    .onCreate((snap, context) => _handleMessageCreated(snap, context));
} else {
  console.warn('Firestore triggers not available; skipping onMessageCreated registration');
}

// Fallback: register v2 style triggers so the CLI can discover them during deploy
try {
  const { onDocumentCreated } = require('firebase-functions/v2/firestore');
  function parseProtoFields(fields) {
    const obj = {};
    for (const k in fields) {
      const v = fields[k];
      if (!v) { obj[k] = null; continue; }
      if (v.stringValue !== undefined) obj[k] = v.stringValue;
      else if (v.integerValue !== undefined) obj[k] = Number(v.integerValue);
      else if (v.doubleValue !== undefined) obj[k] = Number(v.doubleValue);
      else if (v.booleanValue !== undefined) obj[k] = v.booleanValue;
      else if (v.mapValue && v.mapValue.fields) obj[k] = parseProtoFields(v.mapValue.fields);
      else if (v.arrayValue && Array.isArray(v.arrayValue.values)) {
        obj[k] = v.arrayValue.values.map(item => {
          if (item.stringValue !== undefined) return item.stringValue;
          if (item.integerValue !== undefined) return Number(item.integerValue);
          if (item.doubleValue !== undefined) return Number(item.doubleValue);
          if (item.booleanValue !== undefined) return item.booleanValue;
          if (item.mapValue && item.mapValue.fields) return parseProtoFields(item.mapValue.fields);
          return null;
        });
      } else obj[k] = null;
    }
    return obj;
  }

  function extractDataFromV2(snapshot) {
    if (!snapshot) return null;
    if (typeof snapshot.data === 'function') return snapshot.data();
    if (snapshot.fields) return parseProtoFields(snapshot.fields);
    return snapshot;
  }

  // images/{imageId}/messages/{messageId}
  exports.onMessageCreated_images_v2 = onDocumentCreated('images/{imageId}/messages/{messageId}', async (event) => {
    try {
      const after = event.data && event.data; // proto-like
      const msg = extractDataFromV2(after) || {};
      const senderUid = msg.senderUid || null;
      const imageId = event.params && event.params.imageId;
      if (!imageId) return null;
      const parentPath = `images/${imageId}`;
      const parentRef = admin.firestore().doc(parentPath);
      const imageSnap = await parentRef.get();
      if (!imageSnap.exists) {
        console.log('onMessageCreated_images_v2: parent image not found', parentPath);
        return null;
      }
      const imageData = imageSnap.data() || {};
      const ownerId = imageData.ownerId || imageData.owner || null;
      if (!ownerId) return null;
      if (senderUid && senderUid === ownerId) return null;
      const userRef = admin.firestore().collection('users').doc(ownerId);
      await userRef.set({ unreadMessages: admin.firestore.FieldValue.increment(1) }, { merge: true });
      const notif = {
        type: 'message',
        imagePath: parentPath,
        imageId: imageId,
        messageId: event.params && event.params.messageId,
        fromUid: senderUid || null,
        excerpt: (typeof msg.text === 'string' ? (msg.text.length > 300 ? msg.text.substring(0, 300) + '...' : msg.text) : null),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
      };
      await userRef.collection('notifications').add(notif);
      console.log('onMessageCreated_images_v2: notified owner', ownerId, 'for image', parentPath);
    } catch (e) {
      console.warn('onMessageCreated_images_v2 failed', e && e.message || e);
    }
    return null;
  });

  // users/{userId}/images/{imageId}/messages/{messageId}
  exports.onMessageCreated_userImages_v2 = onDocumentCreated('users/{userId}/images/{imageId}/messages/{messageId}', async (event) => {
    try {
      const after = event.data && event.data;
      const msg = extractDataFromV2(after) || {};
      const senderUid = msg.senderUid || null;
      const userId = event.params && event.params.userId;
      const imageId = event.params && event.params.imageId;
      if (!userId || !imageId) return null;
      const parentPath = `users/${userId}/images/${imageId}`;
      const parentRef = admin.firestore().doc(parentPath);
      const imageSnap = await parentRef.get();
      if (!imageSnap.exists) {
        console.log('onMessageCreated_userImages_v2: parent image not found', parentPath);
        return null;
      }
      const imageData = imageSnap.data() || {};
      const ownerId = imageData.ownerId || imageData.owner || userId || null;
      if (!ownerId) return null;
      if (senderUid && senderUid === ownerId) return null;
      const userRef = admin.firestore().collection('users').doc(ownerId);
      await userRef.set({ unreadMessages: admin.firestore.FieldValue.increment(1) }, { merge: true });
      const notif = {
        type: 'message',
        imagePath: parentPath,
        imageId: imageId,
        messageId: event.params && event.params.messageId,
        fromUid: senderUid || null,
        excerpt: (typeof msg.text === 'string' ? (msg.text.length > 300 ? msg.text.substring(0, 300) + '...' : msg.text) : null),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
      };
      await userRef.collection('notifications').add(notif);
      console.log('onMessageCreated_userImages_v2: notified owner', ownerId, 'for image', parentPath);
    } catch (e) {
      console.warn('onMessageCreated_userImages_v2 failed', e && e.message || e);
    }
    return null;
  });
} catch (e) {
  // If v2 API not available, it's fine — deploy will proceed with whatever triggers are registered
  console.warn('v2 Firestore trigger registration skipped:', e && e.message || e);
}
