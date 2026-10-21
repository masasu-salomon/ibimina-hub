const { api, createGroup } = require('./helpers');
const { resetStore } = require('../src/common/store');

beforeEach(resetStore);

describe('GET /health', () => {
  it('reports the service is up', async () => {
    const res = await api().get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ status: 'ok', service: 'ibimina-hub' });
  });
});

describe('Groups', () => {
  it('creates a savings group', async () => {
    const res = await api()
      .post('/api/groups')
      .send({ name: 'Twiyubake Nyamirambo', contributionAmount: 10000, frequency: 'monthly', location: 'Kigali' });

    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({
      name: 'Twiyubake Nyamirambo',
      contributionAmount: 10000,
      frequency: 'monthly',
      location: 'Kigali',
    });
    expect(res.body.id).toBeDefined();
  });

  it('rejects an invalid group and lists every problem', async () => {
    const res = await api().post('/api/groups').send({ name: 'A', contributionAmount: -5, frequency: 'daily' });

    expect(res.status).toBe(400);
    expect(res.body.details).toHaveLength(3);
  });

  it('lists groups and fetches one by id', async () => {
    const group = await createGroup();
    await createGroup({ name: 'Dufatanye Huye' });

    const list = await api().get('/api/groups');
    expect(list.body).toHaveLength(2);

    const one = await api().get(`/api/groups/${group.id}`);
    expect(one.status).toBe(200);
    expect(one.body.name).toBe(group.name);
  });

  it('returns 404 for an unknown group', async () => {
    const res = await api().get('/api/groups/does-not-exist');
    expect(res.status).toBe(404);
  });

  it('returns 400 for malformed JSON', async () => {
    const res = await api().post('/api/groups').set('Content-Type', 'application/json').send('{bad json');
    expect(res.status).toBe(400);
  });
});
