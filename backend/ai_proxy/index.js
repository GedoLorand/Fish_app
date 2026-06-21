const express = require('express');
const axios = require('axios');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json());

function readKeyFromAndroidProps() {
  try {
    const propsPath = path.resolve(__dirname, '..', '..', 'android', 'key.properties');
    const txt = fs.readFileSync(propsPath, 'utf8');
    for (const line of txt.split(/\r?\n/)) {
      const p = line.trim();
      if (p.startsWith('OPENAI_API_KEY=')) return p.split('=')[1];
    }
  } catch (e) {
    // ignore
  }
  return null;
}

const OPENAI_KEY = process.env.OPENAI_API_KEY || readKeyFromAndroidProps();
if (!OPENAI_KEY) console.warn('Warning: OPENAI_API_KEY not set. Set env var or add to android/key.properties');

app.post('/v1/ai', async (req, res) => {
  const { prompt, type, species } = req.body || {};
  if (!prompt && !species) return res.status(400).json({ error: 'missing prompt or species' });
  const userText = prompt || (species ? `Tell me about this species: ${species}` : '');
  try {
    const resp = await axios.post('https://api.openai.com/v1/chat/completions', {
      model: 'gpt-3.5-turbo',
      messages: [
        { role: 'system', content: 'You are a concise assistant that provides factual species information when requested.' },
        { role: 'user', content: userText }
      ],
      max_tokens: 600,
      temperature: 0.2,
    }, {
      headers: {
        Authorization: `Bearer ${OPENAI_KEY}`,
        'Content-Type': 'application/json'
      }
    });
    const text = resp.data.choices?.[0]?.message?.content || JSON.stringify(resp.data);
    return res.json({ ok: true, text });
  } catch (err) {
    console.error('OpenAI proxy error', err?.response?.data || err.message);
    return res.status(500).json({ error: 'openai_error', details: err?.response?.data || err.message });
  }
});

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`AI proxy listening on http://localhost:${port}`));
