const { randomUUID } = require('crypto');

// In-memory data store. Each module owns its own collection, which keeps the
// modules independent and makes it easy to swap in a real database (or split a
// module into its own service) later without touching the others.
class Collection {
  constructor() {
    this.items = new Map();
  }

  insert(data) {
    const item = { id: randomUUID(), ...data, createdAt: new Date().toISOString() };
    this.items.set(item.id, item);
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
  if (!collections.has(name)) collections.set(name, new Collection());
  return collections.get(name);
}

function resetStore() {
  collections.forEach((c) => c.clear());
}

module.exports = { collection, resetStore };
