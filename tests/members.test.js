const { api, createGroup } = require('./helpers');
const { resetStore } = require('../src/common/store');
const { parseRwandanPhone } = require('../src/modules/members/phone');

beforeEach(resetStore);

describe('parseRwandanPhone', () => {
  it.each([
    ['0781234567', '250781234567', 'MTN'],
    ['+250 791 234 567', '250791234567', 'MTN'],
    ['250721234567', '250721234567', 'Airtel'],
    ['073-123-4567', '250731234567', 'Airtel'],
  ])('parses %s', (input, phone, provider) => {
    expect(parseRwandanPhone(input)).toEqual({ phone, provider });
  });

  it.each(['0771234567', '078123456', '0881234567', '', undefined])('rejects %s', (input) => {
    expect(parseRwandanPhone(input)).toBeNull();
  });
});

describe('Members', () => {
  let group;
  beforeEach(async () => {
    group = await createGroup();
  });

  const addMember = (body) => api().post(`/api/groups/${group.id}/members`).send(body);

  it('adds members in payout order', async () => {
    const first = await addMember({ fullName: 'Uwase Aline', phone: '0781234567' });
    const second = await addMember({ fullName: 'Habimana Eric', phone: '0731234567' });

    expect(first.status).toBe(201);
    expect(first.body).toMatchObject({ phone: '250781234567', provider: 'MTN', position: 1 });
    expect(second.body).toMatchObject({ provider: 'Airtel', position: 2 });

    const list = await api().get(`/api/groups/${group.id}/members`);
    expect(list.body.map((m) => m.fullName)).toEqual(['Uwase Aline', 'Habimana Eric']);
  });

  it('rejects an invalid phone number', async () => {
    const res = await addMember({ fullName: 'Uwase Aline', phone: '12345' });
    expect(res.status).toBe(400);
  });

  it('rejects the same phone twice in one group', async () => {
    await addMember({ fullName: 'Uwase Aline', phone: '0781234567' });
    const res = await addMember({ fullName: 'Someone Else', phone: '+250781234567' });
    expect(res.status).toBe(409);
  });

  it('returns 404 for an unknown group', async () => {
    const res = await api().post('/api/groups/nope/members').send({ fullName: 'Uwase Aline', phone: '0781234567' });
    expect(res.status).toBe(404);
  });
});
