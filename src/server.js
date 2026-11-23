const createApp = require('./app');
const config = require('./config');
const store = require('./common/store');
const { log } = require('./common/logger');

async function start() {
  try {
    await store.init();
  } catch (err) {
    // Exit so Docker restarts the container and a failed deploy rolls back.
    log('error', 'Could not connect to the database', { error: err.message });
    process.exit(1);
  }

  const app = createApp();
  const server = app.listen(config.port, () => {
    log('info', `Ibimina Hub API running on http://localhost:${config.port} (${config.env})`, {
      database: process.env.DATABASE_URL ? 'postgres' : 'in-memory',
    });
  });

  // Docker sends SIGTERM on stop: finish open requests, then close the pool.
  const shutdown = (signal) => {
    log('info', 'Shutting down', { signal });
    setTimeout(() => process.exit(1), 10000).unref();
    server.close(async () => {
      await store.close().catch((err) => log('error', 'Error closing the database pool', { error: err.message }));
      process.exit(0);
    });
  };
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

start();
