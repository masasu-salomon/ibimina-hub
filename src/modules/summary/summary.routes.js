const { Router } = require('express');
const service = require('./summary.service');

const router = Router({ mergeParams: true });

router.get('/', (req, res) => {
  res.json(service.getSummary(req.params.groupId));
});

module.exports = router;