const { Router } = require('express');
const pkg = require('../../../package.json');
const store = require('../../common/store');
const { log } = require('../../common/logger');

const router = Router();

// Used by load balancers / container orchestrators to check the service is up.
router.get('/', (req, res) => {
  res.json({
    status: 'ok',
    service: pkg.name,
    version: pkg.version,
    commit: process.env.GIT_SHA || 'unknown',
    uptime: process.uptime(),
  });
});

// Readiness: can the service reach its database? Kept separate from /health so
// a database blip does not make the load balancer pull the VM out of rotation.
router.get('/ready', async (req, res) => {
  try {
    const database = await store.ping();
    res.json({ status: 'ready', database });
  } catch (err) {
    log('error', 'Readiness check failed', { error: err.message });
    res.status(503).json({ status: 'not-ready', database: 'error' });
  }
});

module.exports = router;
