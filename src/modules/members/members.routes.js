const { Router } = require('express');
const service = require('./members.service');

const router = Router({ mergeParams: true });

router.post('/', (req, res) => {
  res.status(201).json(service.addMember(req.params.groupId, req.body));
});

router.get('/', (req, res) => {
  res.json(service.listMembers(req.params.groupId));
});

module.exports = router;
