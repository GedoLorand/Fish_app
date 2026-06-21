Local AI proxy for development.

Usage:

1. Install:

```bash
cd backend/ai_proxy
npm install
```

2. Run (reads `OPENAI_API_KEY` from env or from `android/key.properties`):

```bash
OPENAI_API_KEY=sk-... npm start
```

3. POST to `http://localhost:3000/v1/ai` with JSON `{ "prompt": "..." }` or `{ "species": "..." }`.
