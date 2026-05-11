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
    const fishRegex = /fish|salmon|trout|carp|bass|cod|perch|tilapia|pike|mackerel/i;
    const combinedText = apiResp.labels.map(l => l.description).join(' ').toLowerCase() + ' ' + JSON.stringify(apiResp.raw).toLowerCase();
    const isFish = fishRegex.test(combinedText);
    return { isFish, labels: apiResp.labels, raw: apiResp.raw };
  } catch (err) {
    console.error('Vision detection error:', err && (err.stack || err.message) || err);
    throw new functions.https.HttpsError('internal', `Detection API error: ${err && (err.message || err)}`);
  }
});
