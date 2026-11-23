// Tiny structured logger: one JSON object per line on stdout, which Docker and
// Azure collect as-is. No dependency needed.
const LEVELS = { debug: 10, info: 20, warn: 30, error: 40 };

// Read the environment on every call so LOG_LEVEL / NODE_ENV changes (e.g. in
// tests) take effect without reloading the module.
function enabled(level) {
  if (process.env.NODE_ENV === 'test') return false;
  const min = LEVELS[process.env.LOG_LEVEL] || LEVELS.info;
  return LEVELS[level] >= min;
}

function log(level, msg, extra = {}) {
  if (!enabled(level)) return;
  const line = { time: new Date().toISOString(), level, msg, ...extra };
  process.stdout.write(`${JSON.stringify(line)}\n`);
}

// Logs one line per finished response. Only the method, path, status and
// timing are recorded: never the body or query string, because they can hold
// members' phone numbers.
function requestLogger(req, res, next) {
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    const status = res.statusCode;
    let level = 'info';
    if (status >= 500) level = 'error';
    else if (status >= 400) level = 'warn';
    log(level, 'request', {
      method: req.method,
      path: req.originalUrl.split('?')[0],
      status,
      duration_ms: Number(process.hrtime.bigint() - start) / 1e6,
    });
  });
  next();
}

module.exports = { log, requestLogger };
