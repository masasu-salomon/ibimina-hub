const { randomUUID } = require('crypto');
const { Pool } = require('pg');
const { log } = require('./logger');

// Data store. Each module owns its own collection, which keeps the modules
// independent. Reads always come from the in-memory Maps, so the services stay
// synchronous. When DATABASE_URL is set, every insert is also written through to
// PostgreSQL, and init() loads the saved rows back into memory on startup.
// Without DATABASE_URL (laptops, CI, tests) it is purely in memory.

const CREATE_TABLE = `
  CREATE TABLE IF NOT EXISTS records (
    collection text NOT NULL,
    id uuid PRIMARY KEY,
    data jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
  )`;
const INSERT_RECORD = 'INSERT INTO records (collection, id, data, created_at) VALUES ($1, $2, $3, $4)';
const SELECT_RECORDS = 'SELECT collection, data FROM records ORDER BY created_at, id';

let pool = null;

// Fire-and-forget write. The request has already been answered from memory, so
// a database error is logged and never thrown.
function persist(name, item) {
  if (!pool) return;
  pool.query(INSERT_RECORD, [name, item.id, item, item.createdAt]).catch((err) => {
    log('error', 'Failed to save record to the database', { collection: name, id: item.id, error: err.message });
  });
}

class Collection {
  constructor(name) {
    this.name = name;
    this.items = new Map();
  }

  insert(data) {
    const item = { id: randomUUID(), ...data, createdAt: new Date().toISOString() };
    this.items.set(item.id, item);
    persist(this.name, item);
    return item;
  }

  findById(id) {
    return this.items.get(id) || null;
  }

  findAll(predicate = () => true) {
    return [...this.items.values()].filter(predicate);
  }

  clear() {
    this.items.clear();
  }
}

const collections = new Map();

function collection(name) {
  if (!collections.has(name)) collections.set(name, new Collection(name));
  return collections.get(name);
}

// Clears memory only (used by tests); never deletes rows in the database.
function resetStore() {
  collections.forEach((c) => c.clear());
}

// Connects to PostgreSQL, creates the table if needed and loads every saved row
// back into its collection. Does nothing when DATABASE_URL is not set.
async function init() {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) return;

  // sslmode comes from the URL (sslmode=require is verified like verify-full).
  // The timeout stops startup and /health/ready hanging if the server is unreachable.
  const newPool = new Pool({ connectionString, connectionTimeoutMillis: 5000 });
  // An idle client losing its connection must not crash the process.
  newPool.on('error', (err) => log('error', 'Idle database connection failed', { error: err.message }));

  try {
    await newPool.query(CREATE_TABLE);
    const { rows } = await newPool.query(SELECT_RECORDS);
    rows.forEach((row) => collection(row.collection).items.set(row.data.id, row.data));
    pool = newPool;
    log('info', 'Connected to PostgreSQL', { records: rows.length });
  } catch (err) {
    await newPool.end().catch(() => {});
    throw err;
  }
}

// Returns 'ok' when the database answers, 'not-configured' without
// DATABASE_URL, and throws when the database cannot be reached.
async function ping() {
  if (!pool) return 'not-configured';
  await pool.query('SELECT 1');
  return 'ok';
}

async function close() {
  if (!pool) return;
  const current = pool;
  pool = null;
  await current.end();
}

module.exports = { collection, resetStore, init, ping, close };
