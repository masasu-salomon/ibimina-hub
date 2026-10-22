const { Router } = require('express');
const service = require('./payouts.service');
const { badRequest } = require('../../common/errors');

const router = Router({ mergeParams: true });

router.get('/next', (req, res) => {
  const next = service.getNextPayout(req.params.groupId);
  if (!next) throw badRequest('A group needs at least 2 members before payouts');
  res.json(next);
});

router.post('/', (req, res) => {
  res.status(201).json(service.makePayout(req.params.groupId));
});

router.get('/', (req, res) => {
  res.json(service.listPayouts(req.params.groupId));
});

module.exports = router;