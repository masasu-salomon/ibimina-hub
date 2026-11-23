// The pg driver is mocked, so these tests never need a real database.
const mockQuery = jest.fn();
const mockEnd = jest.fn();
jest.mock('pg', () => ({
  Pool: jest.fn().mockImplementation(() => ({ query: mockQuery, end: mockEnd, on: jest.fn() })),
}));

const DATABASE_URL = 'postgres://user:pass@localhost:5432/ibimina';
let store;
let Pool;

beforeEach(() => {
  jest.resetModules();
  mockQuery.mockReset().mockResolvedValue({ rows: [] });
  mockEnd.mockReset().mockResolvedValue();
  ({ Pool } = require('pg'));
  store = require('../src/common/store');
});

afterEach(async () => {
  await store.close();
  delete process.env.DATABASE_URL;
});

describe('store without DATABASE_URL', () => {
  it('stays in memory and never creates a pool', async () => {
    await store.init();
    const item = store.collection('groups').insert({ name: 'Twiyubake' });

    expect(Pool).not.toHaveBeenCalled();
    expect(store.collection('groups').findById(item.id)).toEqual(item);
    await expect(store.ping()).resolves.toBe('not-configured');
  });
});

describe('store with DATABASE_URL', () => {
  beforeEach(() => {
    process.env.DATABASE_URL = DATABASE_URL;
  });

  it('creates the table and loads saved rows back into the right collections', async () => {
    const group = { id: '11111111-1111-4111-8111-111111111111', name: 'Twiyubake', createdAt: '2026-01-01T00:00:00.000Z' };
    const member = { id: '22222222-2222-4222-8222-222222222222', groupId: group.id, fullName: 'Aline Uwase' };
    mockQuery
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [{ collection: 'groups', data: group }, { collection: 'members', data: member }] });

    await store.init();

    expect(Pool).toHaveBeenCalledWith(expect.objectContaining({ connectionString: DATABASE_URL }));
    expect(Pool.mock.calls[0][0]).not.toHaveProperty('ssl');
    expect(mockQuery.mock.calls[0][0]).toMatch(/CREATE TABLE IF NOT EXISTS records/);
    expect(mockQuery.mock.calls[0][0]).toMatch(/id uuid PRIMARY KEY/);
    expect(store.collection('groups').findById(group.id)).toEqual(group);
    expect(store.collection('members').findById(member.id)).toEqual(member);
    expect(store.collection('groups').findById(member.id)).toBeNull();
  });

  it('returns the item synchronously and sends exactly one parameterised INSERT', async () => {
    await store.init();
    mockQuery.mockClear();

    const item = store.collection('groups').insert({ name: 'Dufatanye Huye' });

    expect(item).not.toBeInstanceOf(Promise);
    expect(item).toMatchObject({ name: 'Dufatanye Huye', id: expect.any(String) });
    expect(mockQuery).toHaveBeenCalledTimes(1);
    const [sql, params] = mockQuery.mock.calls[0];
    expect(sql).toBe('INSERT INTO records (collection, id, data, created_at) VALUES ($1, $2, $3, $4)');
    expect(sql).not.toContain('Dufatanye');
    expect(params).toEqual(['groups', item.id, item, item.createdAt]);
  });

  it('keeps working when the database write fails', async () => {
    await store.init();
    mockQuery.mockRejectedValueOnce(new Error('connection lost'));

    const item = store.collection('groups').insert({ name: 'Abishyizehamwe' });
    await new Promise(setImmediate);

    expect(store.collection('groups').findById(item.id)).toEqual(item);
  });

  it('ping returns ok, and throws when the database is down', async () => {
    await store.init();
    await expect(store.ping()).resolves.toBe('ok');

    mockQuery.mockRejectedValueOnce(new Error('timeout'));
    await expect(store.ping()).rejects.toThrow('timeout');
  });

  it('init fails and closes the pool when the database is unreachable', async () => {
    mockQuery.mockRejectedValueOnce(new Error('ECONNREFUSED'));

    await expect(store.init()).rejects.toThrow('ECONNREFUSED');
    expect(mockEnd).toHaveBeenCalledTimes(1);
    await expect(store.ping()).resolves.toBe('not-configured');
  });

  it('close ends the pool', async () => {
    await store.init();
    await store.close();

    expect(mockEnd).toHaveBeenCalledTimes(1);
  });
});
