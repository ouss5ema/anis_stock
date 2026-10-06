const { env } = require('../config/env');

const SENSITIVE = /password|passwd|token|secret|authorization|cookie|database_url|jwt/i;

function sanitizeMeta(meta) {
  if (!meta || typeof meta !== 'object') {
    return meta;
  }

  if (Array.isArray(meta)) {
    return meta.map(sanitizeMeta);
  }

  const cleaned = {};
  for (const [key, value] of Object.entries(meta)) {
    if (SENSITIVE.test(key)) {
      cleaned[key] = '[redacted]';
      continue;
    }
    if (typeof value === 'string' && SENSITIVE.test(value)) {
      cleaned[key] = '[redacted]';
      continue;
    }
    if (value && typeof value === 'object') {
      cleaned[key] = sanitizeMeta(value);
      continue;
    }
    cleaned[key] = value;
  }
  return cleaned;
}

function write(level, message, meta) {
  const payload = {
    level,
    time: new Date().toISOString(),
    message,
    ...(meta ? { meta: sanitizeMeta(meta) } : {}),
  };

  if (level === 'error') {
    console.error(JSON.stringify(payload));
    return;
  }

  if (env.NODE_ENV === 'production' && level === 'debug') {
    return;
  }

  console.log(JSON.stringify(payload));
}

const logger = {
  debug: (message, meta) => write('debug', message, meta),
  info: (message, meta) => write('info', message, meta),
  warn: (message, meta) => write('warn', message, meta),
  error: (message, meta) => write('error', message, meta),
};

module.exports = { logger };
