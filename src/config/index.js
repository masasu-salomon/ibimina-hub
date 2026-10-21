// Central place for runtime configuration. Values come from environment
// variables so the same build can run locally, in a container or in the cloud.
const config = {
  port: Number(process.env.PORT) || 3000,
  env: process.env.NODE_ENV || 'development',
  currency: process.env.CURRENCY || 'RWF',
};

module.exports = config;
