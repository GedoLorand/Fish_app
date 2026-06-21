const functions = require('firebase-functions');
const express = require('express');
const axios = require('axios');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// Simple in-memory cache to reduce repeated Wikipedia calls (per-instance)
const CACHE_TTL = 60 * 60; // seconds
const CACHE_MAX = 1000;
const wikiCache = new Map(); // key -> { ts, value }

function getFromCache(key) {
  const entry = wikiCache.get(key);
  if (!entry) return null;
  if ((Date.now() / 1000) - entry.ts > CACHE_TTL) {
    wikiCache.delete(key);
    return null;
  }
  return entry.value;
}

function setCache(key, value) {
  if (wikiCache.size >= CACHE_MAX) {
    // simple eviction: delete first inserted key
    const firstKey = wikiCache.keys().next().value;
    if (firstKey) wikiCache.delete(firstKey);
  }
  wikiCache.set(key, { ts: Date.now() / 1000, value });
}

async function requestWithRetry(url, opts = {}) {
  const maxAttempts = 3; // initial + 2 retries
  const baseDelay = 300; // ms
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await axios.get(url, opts);
    } catch (err) {
      const status = err?.response?.status;
      // Retry on 403 (sometimes transient from rate-limits), 5xx, network errors or timeouts
      const shouldRetry = (status && (status === 403 || status >= 500)) || !err.response;
      if (!shouldRetry || attempt === maxAttempts) {
        throw err;
      }
      const delay = baseDelay * Math.pow(2, attempt - 1);
      console.warn(`requestWithRetry attempt ${attempt} failed for ${url} (status=${status}). Retrying in ${delay}ms`);
      await new Promise(r => setTimeout(r, delay));
    }
  }
}

// No external paid AI providers used. This service provides free Wikipedia summaries only.

app.post('/v1/ai', async (req, res) => {
  const { prompt, species } = req.body || {};
  const forceWiki = (req.body && req.body.forceWiki) || (req.query && req.query.forceWiki);
  if (!prompt && !species) return res.status(400).json({ error: 'missing prompt or species' });
  const queryText = prompt || species || '';

  // helper: fetch wikipedia summary (returns text or null)
  async function fetchWikipediaSummary(text, lang = 'hu') {
    try {
      const raw = (text || '').slice(0, 250);
      const wikiQuery = encodeURIComponent(raw);
      if (!wikiQuery) return null;
      const cacheKey = `${lang}:${wikiQuery}`;
      const cached = getFromCache(cacheKey);
      if (cached) return cached;
      // 1) Try title search (fast)
      try {
        const searchUrl = `https://${lang}.wikipedia.org/w/rest.php/v1/search/title?q=${wikiQuery}&limit=1`;
        const searchResp = await requestWithRetry(searchUrl, { timeout: 4000, headers: { 'User-Agent': 'login_fish_app/1.0 (contact:gedolorand@gmail.com)', 'Accept': 'application/json' } });
        const pages = searchResp.data && searchResp.data.pages;
        if (Array.isArray(pages) && pages.length > 0 && pages[0] && pages[0].key) {
          const key = pages[0].key;
          const summaryUrl = `https://${lang}.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(key)}`;
          try {
            const sumResp = await requestWithRetry(summaryUrl, { timeout: 4000, headers: { 'User-Agent': 'login_fish_app/1.0 (contact:gedolorand@gmail.com)', 'Accept': 'application/json' } });
            if (sumResp.data && (sumResp.data.extract || sumResp.data.extract_html)) {
              const txt = sumResp.data.extract || (sumResp.data.extract_html && sumResp.data.extract_html.replace(/<[^>]+>/g, '')) || null;
              if (txt) setCache(cacheKey, txt);
              return txt;
            }
          } catch (err) {
            const status = err?.response?.status || err?.code || 'N/A';
            const body = err?.response?.data ? (typeof err.response.data === 'string' ? err.response.data : JSON.stringify(err.response.data).slice(0, 1000)) : '';
            console.error('fetchWikipediaSummary request failed (title summary)', { url: summaryUrl, status, body });
            throw err;
          }
        }
      } catch (e) {
        // ignore title-search errors and fall through to full-text search
      }

      // 2) Fallback: full-text search via MediaWiki API
      try {
        const apiSearch = `https://${lang}.wikipedia.org/w/api.php?action=query&list=search&srsearch=${wikiQuery}&format=json&srlimit=1`;
        const apiResp = await requestWithRetry(apiSearch, { timeout: 4000, headers: { 'User-Agent': 'login_fish_app/1.0 (contact:gedolorand@gmail.com)', 'Accept': 'application/json' } });
        const hits = apiResp.data && apiResp.data.query && apiResp.data.query.search;
        if (Array.isArray(hits) && hits.length > 0 && hits[0] && hits[0].title) {
          const title = hits[0].title;
          const summaryUrl2 = `https://${lang}.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(title)}`;
          try {
            const sumResp2 = await requestWithRetry(summaryUrl2, { timeout: 4000, headers: { 'User-Agent': 'login_fish_app/1.0 (contact:gedolorand@gmail.com)', 'Accept': 'application/json' } });
            if (sumResp2.data && (sumResp2.data.extract || sumResp2.data.extract_html)) {
              const txt2 = sumResp2.data.extract || (sumResp2.data.extract_html && sumResp2.data.extract_html.replace(/<[^>]+>/g, '')) || null;
              if (txt2) setCache(cacheKey, txt2);
              return txt2;
            }
          } catch (err2) {
            const status2 = err2?.response?.status || err2?.code || 'N/A';
            const body2 = err2?.response?.data ? (typeof err2.response.data === 'string' ? err2.response.data : JSON.stringify(err2.response.data).slice(0, 1000)) : '';
            console.error('fetchWikipediaSummary request failed (api summary)', { url: summaryUrl2, status: status2, body: body2 });
            throw err2;
          }
        }
      } catch (e) {
        // ignore
      }
    } catch (e) {
      console.error('fetchWikipediaSummary error', e && (e.stack || e.message) || e);
    }
    return null;
  }

  // Always use Wikipedia as the source (no paid AI providers).
  const lang = (req.body && req.body.lang) || (req.query && req.query.lang) || 'hu';
  const wikiText = await fetchWikipediaSummary(queryText, lang);
  if (wikiText) return res.json({ ok: true, text: wikiText, source: 'wikipedia', lang });
  return res.status(503).json({ ok: false, error: 'wikipedia_unavailable', message: 'Wikipedia lookup failed or blocked from this environment. Kérlek próbáld később.' });
});

// Simple status endpoint for debugging key presence (does NOT reveal the key)
app.get('/v1/ai/status', (req, res) => {
  return res.json({
    ok: true,
    mode: 'wikipedia-only',
    message: 'This function returns Wikipedia summaries only (no paid AI providers).'
  });
});

exports.api = functions.https.onRequest(app);
