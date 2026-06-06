// Runnable hello-world: HTTP + Postgres (schema applied on start) + Valkey cache + OTLP.
//
// This is the copyable reference for the quickstart stack. 12-factor: all config via env,
// logs to stdout. Telemetry is emitted automatically by @opentelemetry/auto-instrumentations-node
// (loaded via `node --require .../register`, see Dockerfile) when OTEL_SDK_DISABLED=false —
// no code changes needed. It auto-instruments http/express + pg + redis.
'use strict';

const express = require('express');
const { Pool } = require('pg');
const { createClient } = require('redis');

const pool = new Pool({
  host: process.env.DB_HOST || 'db',
  port: 5432,
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
  database: process.env.POSTGRES_DB,
});

// The app owns its schema, applied on startup. CREATE TABLE IF NOT EXISTS is fine for this
// stub; for real migrations use Prisma (see AGENTS.md).
async function migrate() {
  await pool.query('CREATE TABLE IF NOT EXISTS visits (id SERIAL PRIMARY KEY)');
}

const cache = createClient({
  socket: { host: process.env.VALKEY_HOST || 'valkey', port: 6379 },
  password: process.env.VALKEY_PASSWORD,
});
cache.on('error', (err) => console.error('valkey error', err));

const app = express();

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.get('/', async (_req, res) => {
  try {
    await pool.query('INSERT INTO visits DEFAULT VALUES');
    const { rows } = await pool.query('SELECT COUNT(*)::int AS n FROM visits');
    const dbVisits = rows[0].n;
    const valkeyHits = await cache.incr('hits');
    res.json({ hello: 'quickstart', db_visits: dbVisits, valkey_hits: valkeyHits });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: String(err) });
  }
});

async function main() {
  await cache.connect();
  await migrate();
  app.listen(8000, '0.0.0.0', () => console.log('listening on :8000'));
}

main().catch((err) => {
  console.error('startup failed', err);
  process.exit(1);
});
