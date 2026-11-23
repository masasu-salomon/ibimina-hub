const { api } = require('./helpers');
const store = require('../src/common/store');

afterEach(() => jest.restoreAllMocks());

describe('GET /health/ready', () => {
  it('is ready with no database configured when DATABASE_URL is unset', async () => {
    expect(process.env.DATABASE_URL).toBeUndefined();

    const res = await api().get('/health/ready');

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ready', database: 'not-configured' });
  });

  it('reports ready when the database answers', async () => {
    jest.spyOn(store, 'ping').mockResolvedValue('ok');

    const res = await api().get('/health/ready');

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ready', database: 'ok' });
  });

  it('returns 503 when the database cannot be reached', async () => {
    jest.spyOn(store, 'ping').mockRejectedValue(new Error('connect ECONNREFUSED'));

    const res = await api().get('/health/ready');

    expect(res.status).toBe(503);
    expect(res.body).toEqual({ status: 'not-ready', database: 'error' });
  });

  it('leaves the liveness check untouched', async () => {
    jest.spyOn(store, 'ping').mockRejectedValue(new Error('down'));

    const res = await api().get('/health');

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});
