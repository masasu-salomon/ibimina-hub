const { Router } = require('express');
const service = require('./groups.service');

const router = Router();

router.post('/', (req, res) => {
  res.status(201).json(service.createGroup(req.body));
});

router.get('/', (req, res) => {
  res.json(service.listGroups());
});

router.get('/:groupId', (req, res) => {
  res.json(service.getGroup(req.params.groupId));
});

module.exports = router;
