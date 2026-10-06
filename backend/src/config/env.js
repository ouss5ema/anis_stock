require('dotenv').config();

const { z } = require('zod');

const WEAK_SECRETS = new Set([
  'change-me-in-production',
  'replace-with-a-long-random-secret',
  'dev-only-change-me',
]);

const envSchema = z.object({
  DATABASE_URL: z.string().min(1, 'DATABASE_URL is required'),
  JWT_SECRET: z.string().min(16, 'JWT_SECRET must be at least 16 characters'),
  JWT_EXPIRES_IN: z.string().default('7d'),
  PORT: z.coerce.number().int().positive().default(3000),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  CORS_ORIGIN: z.string().default('*'),
  ALLOW_REGISTER: z.enum(['true', 'false']).optional(),
});

function isWeakSecret(secret) {
  const lower = secret.toLowerCase();
  return [...WEAK_SECRETS].some((weak) => lower.includes(weak));
}

function loadEnv() {
  const parsed = envSchema.safeParse(process.env);

  if (!parsed.success) {
    const details = parsed.error.issues
      .map((issue) => `${issue.path.join('.')}: ${issue.message}`)
      .join('\n');
    throw new Error(`Invalid environment configuration:\n${details}`);
  }

  const data = parsed.data;
  data.ALLOW_REGISTER =
    data.ALLOW_REGISTER === undefined
      ? data.NODE_ENV !== 'production'
      : data.ALLOW_REGISTER === 'true';

  if (data.NODE_ENV === 'production') {
    if (isWeakSecret(data.JWT_SECRET) || data.JWT_SECRET.length < 32) {
      throw new Error('JWT_SECRET must be a unique strong value of at least 32 characters in production');
    }
    if (!data.CORS_ORIGIN || data.CORS_ORIGIN.trim() === '*') {
      throw new Error('CORS_ORIGIN must be an explicit HTTPS origin in production (wildcard is not allowed)');
    }
  }

  return data;
}

const env = loadEnv();

module.exports = { env };
