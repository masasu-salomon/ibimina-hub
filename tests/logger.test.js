const { api } = require('./helpers');
const { resetStore } = require('../src/common/store');
const { log } = require('../src/common/logger');

let output;
const ORIGINAL_ENV = { NODE_ENV: process.env.NODE_ENV, LOG_LEVEL: process.env.LOG_LEVEL };

// Capture only the lines our logger writes (jest itself reports on stderr).
beforeEach(() => {
  resetStore();
  output = [];
  jest.spyOn(process.stdout, 'write').mockImplementation((chunk) => {
    output.push(String(chunk));
    return true;
  });
  process.env.NODE_ENV = 'production';
  delete process.env.LOG_LEVEL;
});

afterEach(() => {
  jest.restoreAllMocks();
  process.env.NODE_ENV = ORIGINAL_ENV.NODE_ENV;
  if (ORIGINAL_ENV.LOG_LEVEL === undefined) delete process.env.LOG_LEVEL;
  else process.env.LOG_LEVEL = ORIGINAL_ENV.LOG_LEVEL;
});

const lines = () => output.join('').trim().split('\n').filter(Boolean).map((l) => JSON.parse(l));

describe('request logger', () => {
  it('writes one JSON line per request without the body or query string', async () => {
    const res = await api()
      .post('/api/groups?phone=0781234567')
      .send({ name: 'Twiyubake Nyamirambo', contributionAmount: 10000, frequency: 'monthly', secret: '0789999999' });
    expect(res.status).toBe(201);

    const logged = lines();
    expect(logged).toHaveLength(1);
    expect(logged[0]).toEqual({
      time: expect.any(String),
      level: 'info',
      msg: 'request',
      method: 'POST',
      path: '/api/groups',
      status: 201,
      duration_ms: expect.any(Number),
    });
    expect(new Date(logged[0].time).toISOString()).toBe(logged[0].time);

    const raw = output.join('');
    expect(raw).not.toContain('0781234567');
    expect(raw).not.toContain('0789999999');
    expect(raw).not.toContain('Twiyubake');
  });

  it('uses warn for 4xx responses', async () => {
    await api().get('/api/groups/does-not-exist');
    expect(lines()[0]).toMatchObject({ level: 'warn', status: 404 });
  });

  it('logs nothing when NODE_ENV=test', async () => {
    process.env.NODE_ENV = 'test';
    await api().get('/health');
    log('error', 'should not appear');
    expect(output).toEqual([]);
  });

  it('respects LOG_LEVEL', async () => {
    process.env.LOG_LEVEL = 'warn';
    await api().get('/health');
    expect(output).toEqual([]);

    await api().get('/api/groups/does-not-exist');
    expect(lines()).toHaveLength(1);
  });
});

describe('log helper', () => {
  it('prints the message and extra fields as one JSON line', () => {
    log('error', 'Failed to save record', { collection: 'groups' });
    expect(lines()).toEqual([
      { time: expect.any(String), level: 'error', msg: 'Failed to save record', collection: 'groups' },
    ]);
  });
});

describe('error handler', () => {
  it('logs unexpected errors as one JSON line without the query string', () => {
    const { errorHandler } = require('../src/common/errors');
    const res = { status: jest.fn().mockReturnThis(), json: jest.fn() };

    errorHandler(new Error('boom'), { method: 'GET', originalUrl: '/api/groups?phone=0781234567' }, res, () => {});

    expect(res.status).toHaveBeenCalledWith(500);
    expect(lines()).toEqual([
      expect.objectContaining({ level: 'error', msg: 'Unexpected error', method: 'GET', path: '/api/groups', error: 'boom' }),
    ]);
    expect(output.join('')).not.toContain('0781234567');
  });
});
