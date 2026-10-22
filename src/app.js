const express = require('express');
const { notFoundHandler, errorHandler } = require('./common/errors');
const healthRoutes = require('./modules/health/health.routes');
const groupRoutes = require('./modules/groups/groups.routes');
const memberRoutes = require('./modules/members/members.routes');

function createApp() {
  const app = express();
  app.use(express.json());

  app.use('/health', healthRoutes);
  app.use('/api/groups', groupRoutes);
  app.use('/api/groups/:groupId/members', memberRoutes);

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}

module.exports = createApp;
