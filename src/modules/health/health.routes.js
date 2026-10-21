const { Router } = require('express');
const pkg = require('../../../package.json');

const router = Router();

// Used by load balancers / container orchestrators to check the service is up.
router.get('/', (req, res) => {
  res.json({ status: 'ok', service: pkg.name, version: pkg.version, uptime: process.uptime() });
});

module.exports = router;
