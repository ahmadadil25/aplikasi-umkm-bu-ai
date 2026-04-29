import http from 'node:http';
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
loadEnv(join(__dirname, '.env'));

const port = Number(process.env.PORT || 3000);
const provider = getProvider();
const model = getModel(provider);

const server = http.createServer(async (req, res) => {
  setCorsHeaders(res);

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  if (req.method === 'GET' && req.url === '/health') {
    sendJson(res, 200, {
      ok: true,
      provider,
      model,
      has_api_key: hasOpenAiApiKey(),
    });
    return;
  }

  if (req.method === 'POST' && req.url === '/api/ai-chat') {
    await handleAiChat(req, res);
    return;
  }

  sendJson(res, 404, { error: 'Route tidak ditemukan' });
});

server.listen(port, () => {
  console.log(`C-Kas AI backend running at http://localhost:${port}`);
  console.log(`Flutter emulator endpoint: http://10.0.2.2:${port}/api/ai-chat`);
});

async function handleAiChat(req, res) {
  if (!hasOpenAiApiKey()) {
    sendJson(res, 500, {
      error: 'OPENAI_API_KEY belum diisi di backend/.env',
    });
    return;
  }

  try {
    const payload = await readJsonBody(req);
    const question = String(payload.question || '').trim();

    if (!question) {
      sendJson(res, 400, { error: 'Pertanyaan kosong' });
      return;
    }

    if (isGreeting(question)) {
      sendJson(res, 200, {
        answer:
          'Halo, aku siap bantu soal C-Kas. Kamu bisa tanya ringkasan kas, pengeluaran, pemasukan, tren penjualan, modal, atau laporan warung.',
      });
      return;
    }

    if (isThanks(question)) {
      sendJson(res, 200, {
        answer: 'Sama-sama. Kalau butuh analisis kas lagi, tinggal tanya saja.',
      });
      return;
    }

    if (!isRelatedQuestion(question)) {
      sendJson(res, 200, { answer: outOfScopeWarning() });
      return;
    }

    const answer = await askOpenAi(payload);
    sendJson(res, 200, { answer });
  } catch (error) {
    console.error(error);
    sendJson(res, 500, {
      error: 'Gagal memproses AI chat',
    });
  }
}

function hasOpenAiApiKey() {
  const key = process.env.OPENAI_API_KEY || '';
  return key.trim() !== '' && key.trim() !== 'isi_api_key_openai_kamu';
}

async function askOpenAi(payload) {
  if (provider === 'openrouter') {
    return askOpenRouter(payload);
  }

  const response = await fetch('https://api.openai.com/v1/responses', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      instructions: buildInstructions(),
      input: buildInput(payload),
      max_output_tokens: 450,
      store: false,
    }),
  });

  const data = await response.json();

  if (!response.ok) {
    const message = data?.error?.message || 'Request ke OpenAI gagal';
    throw new Error(message);
  }

  return extractOutputText(data);
}

async function askOpenRouter(payload) {
  const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
      'HTTP-Referer': 'http://localhost:3000',
      'X-Title': 'C-Kas AI Backend',
    },
    body: JSON.stringify({
      model,
      messages: [
        {
          role: 'system',
          content: buildInstructions(),
        },
        {
          role: 'user',
          content: JSON.stringify(
            {
              question: payload.question,
              local_answer: payload.local_answer,
              summaries: payload.summaries,
              recent_transactions: payload.recent_transactions,
              instruction: payload.instruction,
            },
            null,
            2,
          ),
        },
      ],
      max_tokens: 450,
    }),
  });

  const data = await response.json();

  if (!response.ok) {
    const message = data?.error?.message || 'Request ke OpenRouter gagal';
    throw new Error(message);
  }

  const answer = data?.choices?.[0]?.message?.content;
  if (typeof answer === 'string' && answer.trim()) {
    return answer.trim();
  }

  throw new Error('Respons OpenRouter tidak berisi teks jawaban');
}

function getProvider() {
  const explicitProvider = (process.env.AI_PROVIDER || '').trim().toLowerCase();
  if (explicitProvider) return explicitProvider;

  const key = process.env.OPENAI_API_KEY || '';
  if (key.startsWith('sk-or-v1')) return 'openrouter';

  return 'openai';
}

function getModel(currentProvider) {
  if (currentProvider === 'openrouter') {
    return process.env.OPENROUTER_MODEL || 'openai/gpt-4o-mini';
  }

  return process.env.OPENAI_MODEL || 'gpt-5.4-mini';
}

function buildInstructions() {
  return [
    'Kamu adalah asisten kas untuk aplikasi C-Kas Warung.',
    'Jawab dalam bahasa Indonesia yang singkat, ramah, dan praktis.',
    'Gunakan hanya data transaksi yang diberikan dalam JSON.',
    'Jangan mengarang nominal, tanggal, atau transaksi yang tidak ada.',
    'Tolak pertanyaan di luar aplikasi C-Kas, transaksi, kas, laporan, modal, penjualan, pengeluaran, dan operasional warung.',
    'Jika data kurang, sebutkan bahwa analisis masih terbatas.',
    'Utamakan insight UMKM: pemasukan, pengeluaran, kas bersih, tren, modal, dan pengeluaran terbesar.',
  ].join(' ');
}

function isRelatedQuestion(question) {
  const normalizedQuestion = question.toLowerCase();
  const relatedKeywords = [
    'halo',
    'hallo',
    'hai',
    'hi',
    'hey',
    'pagi',
    'siang',
    'sore',
    'malam',
    'assalam',
    'terima kasih',
    'makasih',
    'thanks',
    'thank',
    'ok',
    'oke',
    'kas',
    'uang',
    'warung',
    'aplikasi',
    'c-kas',
    'ckas',
    'transaksi',
    'pemasukan',
    'pendapatan',
    'penjualan',
    'omzet',
    'pengeluaran',
    'biaya',
    'modal',
    'laba',
    'untung',
    'profit',
    'bersih',
    'saldo',
    'laporan',
    'riwayat',
    'history',
    'ringkasan',
    'rangkum',
    'analisis',
    'tren',
    'trend',
    'hari ini',
    'kemarin',
    'minggu',
    'bulan',
    'terbesar',
    'tertinggi',
    'rekomendasi',
    'saran',
    'estimasi',
    'stok',
    'belanja',
    'jual',
    'beli',
    'catat',
    'nota',
  ];

  return relatedKeywords.some((keyword) => normalizedQuestion.includes(keyword));
}

function isGreeting(question) {
  const normalizedQuestion = question.toLowerCase().trim();
  const greetings = [
    'halo',
    'hallo',
    'hai',
    'hi',
    'hey',
    'pagi',
    'selamat pagi',
    'siang',
    'selamat siang',
    'sore',
    'selamat sore',
    'malam',
    'selamat malam',
    'assalamualaikum',
    'assalam',
  ];

  return greetings.includes(normalizedQuestion);
}

function isThanks(question) {
  const normalizedQuestion = question.toLowerCase().trim();
  const thanks = [
    'terima kasih',
    'makasih',
    'thanks',
    'thank you',
    'ok',
    'oke',
    'sip',
    'mantap',
  ];

  return thanks.includes(normalizedQuestion);
}

function outOfScopeWarning() {
  return 'Maaf, aku hanya bisa membantu topik yang terkait aplikasi C-Kas, seperti transaksi, pemasukan, pengeluaran, kas bersih, tren penjualan, modal, dan laporan warung.';
}

function buildInput(payload) {
  return [
    {
      role: 'user',
      content: [
        {
          type: 'input_text',
          text: JSON.stringify(
            {
              question: payload.question,
              local_answer: payload.local_answer,
              summaries: payload.summaries,
              recent_transactions: payload.recent_transactions,
              instruction: payload.instruction,
            },
            null,
            2,
          ),
        },
      ],
    },
  ];
}

function extractOutputText(data) {
  if (typeof data.output_text === 'string' && data.output_text.trim()) {
    return data.output_text.trim();
  }

  const parts = [];
  for (const item of data.output || []) {
    for (const content of item.content || []) {
      if (typeof content.text === 'string') {
        parts.push(content.text);
      }
    }
  }

  const text = parts.join('\n').trim();
  if (text) return text;

  throw new Error('Respons OpenAI tidak berisi teks jawaban');
}

function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';

    req.on('data', (chunk) => {
      body += chunk;
      if (body.length > 1024 * 1024) {
        req.destroy();
        reject(new Error('Payload terlalu besar'));
      }
    });

    req.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (error) {
        reject(error);
      }
    });

    req.on('error', reject);
  });
}

function sendJson(res, statusCode, data) {
  res.writeHead(statusCode, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(data));
}

function setCorsHeaders(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
}

function loadEnv(path) {
  if (!existsSync(path)) return;

  const lines = readFileSync(path, 'utf8').split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;

    const separator = trimmed.indexOf('=');
    if (separator === -1) continue;

    const key = trimmed.slice(0, separator).trim();
    const value = trimmed.slice(separator + 1).trim();

    if (!process.env[key]) {
      process.env[key] = value.replace(/^["']|["']$/g, '');
    }
  }
}
