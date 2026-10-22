const { api, createGroup } = require('./helpers');
const { resetStore } = require('../src/common/store');

beforeEach(resetStore);

describe('Payouts and summary', () => {
  let group;
  let members;

  const addMember = async (fullName, phone) =>
    (await api().post(`/api/groups/${group.id}/members`).send({ fullName, phone })).body;

  // Every member pays the fixed contribution once.
  const contributeAll = () =>
    Promise.all(members.map((m) => api().post(`/api/groups/${group.id}/contributions`).send({ memberId: m.id })));

  beforeEach(async () => {
    group = await createGroup({ contributionAmount: 5000 });
    members = [
      await addMember('Uwase Aline', '0781234567'),
      await addMember('Habimana Eric', '0731234567'),
      await addMember('Mukamana Grace', '0791234567'),
    ];
  });

  it('needs at least 2 members', async () => {
    const lonely = await createGroup({ name: 'Solo Group' });
    await api().post(`/api/groups/${lonely.id}/members`).send({ fullName: 'Only One', phone: '0781111111' });

    expect((await api().get(`/api/groups/${lonely.id}/payouts/next`)).status).toBe(400);
    expect((await api().post(`/api/groups/${lonely.id}/payouts`)).status).toBe(400);
  });

  it('shows the first member is next and the pot is not ready yet', async () => {
    const res = await api().get(`/api/groups/${group.id}/payouts/next`);
    expect(res.body).toMatchObject({
      round: 1,
      member: { fullName: 'Uwase Aline' },
      amount: 15000,
      potBalance: 0,
      ready: false,
    });
  });

  it('refuses a payout when the pot is short', async () => {
    const res = await api().post(`/api/groups/${group.id}/payouts`);
    expect(res.status).toBe(409);
  });

  it('pays members in rotation and starts a new round', async () => {
    const paidTo = [];
    for (let i = 0; i < 4; i += 1) {
      await contributeAll();
      const res = await api().post(`/api/groups/${group.id}/payouts`);
      expect(res.status).toBe(201);
      paidTo.push(res.body.memberId);
    }

    expect(paidTo).toEqual([members[0].id, members[1].id, members[2].id, members[0].id]);

    const history = await api().get(`/api/groups/${group.id}/payouts`);
    expect(history.body.map((p) => p.round)).toEqual([1, 1, 1, 2]);
  });

  it('summarises the group', async () => {
    await contributeAll();
    await api().post(`/api/groups/${group.id}/payouts`);
    await contributeAll();

    const res = await api().get(`/api/groups/${group.id}/summary`);
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({
      currency: 'RWF',
      memberCount: 3,
      totalContributed: 30000,
      totalPaidOut: 15000,
      potBalance: 15000,
      payoutsMade: 1,
      nextPayout: { member: { fullName: 'Habimana Eric' }, ready: true },
    });
  });

  it('returns 404 for an unknown group summary', async () => {
    expect((await api().get('/api/groups/nope/summary')).status).toBe(404);
  });
});