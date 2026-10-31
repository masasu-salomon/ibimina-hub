const createApp = require('./app');
const config = require('./config');

const app = createApp();

app.listen(config.port, () => {
  console.log(`Ibimina Hub API running on http://localhost:${config.port} (${config.env})`);
});
