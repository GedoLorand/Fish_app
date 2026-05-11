const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const vision = require('@google-cloud/vision');
const axios = require('axios');

console.log('Cloud Function module loaded: analyzeImageForFish (Google Vision)');

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
