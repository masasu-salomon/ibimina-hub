const { Router } = require('express');
const service = require('./contributions.service');

const router = Router({ mergeParams: true });

router.post('/contributions', (req, res) => {
  res.status(201).json(service.recordContribution(req.params.groupId, req.body));
});

router.get('/contributions', (req, res) => {
  res.json(service.listContributions(req.params.groupId, { memberId: req.query.memberId }));
});

router.get('/balance', (req, res) => {
  res.json(service.getBalance(req.params.groupId));
});

module.exports = router;
