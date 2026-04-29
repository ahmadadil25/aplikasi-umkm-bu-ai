# C-Kas AI Backend

Backend kecil untuk mode AI online di aplikasi C-Kas.

## Cara Menjalankan

1. Copy `.env.example` menjadi `.env`.
2. Isi `OPENAI_API_KEY` di `.env`.
3. Jalankan:

```powershell
npm start
```

Endpoint untuk emulator Android:

```text
http://10.0.2.2:3000/api/ai-chat
```

Endpoint untuk tes dari laptop:

```text
http://localhost:3000/api/ai-chat
```

## OpenAI atau OpenRouter

Kalau key kamu diawali `sk-proj` atau `sk-`, backend memakai OpenAI.

Kalau key kamu diawali `sk-or-v1`, backend otomatis memakai OpenRouter. Untuk OpenRouter, model default-nya:

```env
OPENROUTER_MODEL=openai/gpt-4o-mini
```

## Format Response

Aplikasi Flutter mengharapkan backend membalas:

```json
{
  "answer": "Jawaban AI"
}
```
