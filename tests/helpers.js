const request = require('supertest');
const createApp = require('../src/app');

const app = createApp();
const api = () => request(app);

async function createGroup(overrides = {}) {
  const res = await api()
    .post('/api/groups')
    .send({ name: 'Abishyizehamwe Kicukiro', contributionAmount: 5000, frequency: 'weekly', ...overrides });
  return res.body;
}

module.exports = { api, createGroup };
