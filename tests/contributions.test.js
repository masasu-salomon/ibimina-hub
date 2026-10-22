const { api, createGroup } = require('./helpers');
const { resetStore } = require('../src/common/store');

beforeEach(resetStore);

describe('Contributions', () => {
  let group;
  let aline;
  let eric;

  beforeEach(async () => {
    group = await createGroup({ contributionAmount: 5000 });
    aline = (await api().post(`/api/groups/${group.id}/members`).send({ fullName: 'Uwase Aline', phone: '0781234567' })).body;
    eric = (await api().post(`/api/groups/${group.id}/members`).send({ fullName: 'Habimana Eric', phone: '0731234567' })).body;
  });

  const contribute = (body) => api().post(`/api/groups/${group.id}/contributions`).send(body);

  it('defaults the amount to the group contribution', async () => {
    const res = await contribute({ memberId: aline.id });
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ memberId: aline.id, amount: 5000 });
  });

  it('accepts a custom amount', async () => {
    const res = await contribute({ memberId: aline.id, amount: 2500 });
    expect(res.body.amount).toBe(2500);
  });

  it('rejects invalid amounts and unknown members', async () => {
    expect((await contribute({ memberId: aline.id, amount: 0 })).status).toBe(400);
    expect((await contribute({ memberId: aline.id, amount: 10.5 })).status).toBe(400);
    expect((await contribute({})).status).toBe(400);
    expect((await contribute({ memberId: 'ghost' })).status).toBe(404);
  });

  it('lists contributions, optionally for one member', async () => {
    await contribute({ memberId: aline.id });
    await contribute({ memberId: eric.id });

    const all = await api().get(`/api/groups/${group.id}/contributions`);
    expect(all.body).toHaveLength(2);

    const own = await api().get(`/api/groups/${group.id}/contributions?memberId=${eric.id}`);
    expect(own.body).toHaveLength(1);
  });

  it('computes the balance per member', async () => {
    await contribute({ memberId: aline.id });
    await contribute({ memberId: aline.id });
    await contribute({ memberId: eric.id, amount: 3000 });

    const res = await api().get(`/api/groups/${group.id}/balance`);
    expect(res.body.totalContributed).toBe(13000);
    expect(res.body.members).toEqual([
      expect.objectContaining({ fullName: 'Uwase Aline', contributions: 2, total: 10000 }),
      expect.objectContaining({ fullName: 'Habimana Eric', contributions: 1, total: 3000 }),
    ]);
  });
});
